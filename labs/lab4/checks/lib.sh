# Хелперы контрактных проверок Лаб 4. Источаются из setup() каждого .bats.
# Параметры варианта приходят из окружения (Makefile их экспортирует из seed.py).
# Капстоун: Terraform + Ansible + Prometheus/Grafana + доки SLO/ADR/C4.

: "${NS:?namespace не задан — запускайте через make check}"
: "${CLUSTER:?имя кластера не задано — запускайте через make check}"
: "${REPLICAS_VOTE:?число реплик vote не задано}"
: "${SLO_TARGET:?цель SLO не задана}"
: "${SLO_WINDOW_DAYS:?окно SLO не задано}"
: "${CANARY:?canary-токен не задан}"

# Рабочий каталог студента: где лежат main.tf, playbook, docs/. По умолчанию workdir/
# рядом с лабой; при локальной проверке автор указывает WORKDIR на свой solution/.
WORKDIR="${WORKDIR:-${BATS_TEST_DIRNAME}/../workdir}"

# kube-контекст кластера варианта (kind называет контекст kind-<name>)
KCTX="kind-${CLUSTER}"

# kubectl в контексте и namespace варианта
kc() { kubectl --context "$KCTX" -n "$NS" "$@"; }

# Портируемый таймаут: timeout (Linux) / gtimeout (mac+coreutils) / иначе без ограничения.
_to() {
  local s="$1"; shift
  if command -v timeout >/dev/null 2>&1; then timeout "$s" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$s" "$@"
  else "$@"; fi
}

# terraform в рабочем каталоге студента
tf() { _to 300 terraform -chdir="$WORKDIR" "$@"; }

# Дождаться готовности подов по label-селектору app=<name>
wait_ready() {
  local app="$1" timeout="${2:-120s}"
  kc wait --for=condition=ready pod -l "app=$app" --timeout="$timeout"
}

# Есть ли Service с точным именем в namespace варианта
svc_exists() {
  kc get svc "$1" -o name >/dev/null 2>&1
}

# Эфемерный под с curl ВНУТРИ кластера: запустить, дождаться завершения, вернуть
# его логи. Никаких фоновых port-forward (они держат служебные дескрипторы bats
# и вешают прогон) и надёжнее, чем `run --rm -i` для короткого вывода.
inpod() {   # inpod "<sh-команда>"
  local p="lab4p-$RANDOM" i ph
  kubectl --context "$KCTX" -n "$NS" run "$p" --image=curlimages/curl:8.9.0 --restart=Never \
      --command -- sh -c "$1" >/dev/null 2>&1
  for i in $(seq 1 40); do
    ph=$(kubectl --context "$KCTX" -n "$NS" get pod "$p" -o jsonpath='{.status.phase}' 2>/dev/null)
    { [ "$ph" = "Succeeded" ] || [ "$ph" = "Failed" ]; } && break
    sleep 1
  done
  kubectl --context "$KCTX" -n "$NS" logs "$p" 2>/dev/null
  kubectl --context "$KCTX" -n "$NS" delete pod "$p" --ignore-not-found >/dev/null 2>&1
}

# HTTP-код сервиса изнутри кластера: http_code <service> <port> [path]
http_code() {
  local svc="$1" port="$2" path="${3:-/}"
  inpod "curl -s -o /dev/null -w code=%{http_code} http://$svc:$port$path" \
    | sed -n 's/.*code=\([0-9]*\).*/\1/p'
}

# Тело ответа сервиса изнутри кластера: http_body <service> <port> [path]
http_body() {
  local svc="$1" port="$2" path="${3:-/}"
  inpod "curl -s --max-time 8 http://$svc:$port$path"
}

# Первый найденный файл по glob в рабочем каталоге студента (или пусто)
find_first() {   # find_first "<glob>"
  local f
  for f in $WORKDIR/$1; do [ -e "$f" ] && { echo "$f"; return 0; }; done
  return 1
}
