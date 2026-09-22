# Хелперы контрактных проверок. Источаются из setup() каждого .bats.
# Параметры варианта приходят из окружения (Makefile их экспортирует из seed.py).

: "${NS:?namespace не задан — запускайте через make check}"

# kubectl в namespace варианта
kc() { kubectl -n "$NS" "$@"; }

# Портируемый таймаут: timeout (Linux) / gtimeout (mac+coreutils) / иначе без ограничения.
_to() {
  local s="$1"; shift
  if command -v timeout >/dev/null 2>&1; then timeout "$s" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$s" "$@"
  else "$@"; fi
}

# Дождаться готовности подов по label-селектору app=<name>
wait_ready() {
  local app="$1" timeout="${2:-120s}"
  kc wait --for=condition=ready pod -l "app=$app" --timeout="$timeout"
}

# Проброс порта Service на локальный порт, печатает PID (закрывать вызывающему)
# Эфемерный под с curl ВНУТРИ кластера: запустить, дождаться завершения, вернуть
# его логи. Никаких фоновых port-forward (они держат служебные дескрипторы bats
# и вешают прогон) и надёжнее, чем `run --rm -i` для короткого вывода.
inpod() {   # inpod "<sh-команда>"
  local p="lab2p-$RANDOM" i ph
  kubectl -n "$NS" run "$p" --image=curlimages/curl:8.9.0 --restart=Never \
      --command -- sh -c "$1" >/dev/null 2>&1
  for i in $(seq 1 40); do
    ph=$(kubectl -n "$NS" get pod "$p" -o jsonpath='{.status.phase}' 2>/dev/null)
    { [ "$ph" = "Succeeded" ] || [ "$ph" = "Failed" ]; } && break
    sleep 1
  done
  kubectl -n "$NS" logs "$p" 2>/dev/null
  kubectl -n "$NS" delete pod "$p" --ignore-not-found >/dev/null 2>&1
}

# HTTP-код сервиса vote изнутри кластера
vote_http_code() {
  inpod 'curl -s -o /dev/null -w code=%{http_code} http://vote/' \
    | sed -n 's/.*code=\([0-9]*\).*/\1/p'
}

# Отдать голос за вариант (a|b): POST на сервис vote
cast_vote() {
  inpod "curl -s -X POST --data vote=$1 http://vote/" >/dev/null 2>&1 || true
}

# Число голосов за вариант в PostgreSQL (worker переносит из redis не мгновенно).
# Допущение: под БД доступен как deploy/db или statefulset/db, psql внутри контейнера,
# таблица votes(vote text). Схема — из example-voting-app.
read_count() {
  local option="$1"
  _to 15 kubectl -n "$NS" exec deploy/db -- \
     psql -U postgres -tAc "select count(*) from votes where vote='$option'" 2>/dev/null \
    || _to 15 kubectl -n "$NS" exec statefulset/db -- \
     psql -U postgres -tAc "select count(*) from votes where vote='$option'" 2>/dev/null \
    || echo 0
}

# Дождаться, пока счётчик достигнет хотя бы target (worker успел перенести)
wait_count_at_least() {
  local option="$1" target="$2" i
  for i in $(seq 1 30); do
    [ "$(read_count "$option")" -ge "$target" ] && return 0
    sleep 2
  done
  return 1
}

# Уникальные hostname подов, обслуживших запросы к Service vote.
# vote выводит "Processed by container ID <hostname>". Запросы идут через ClusterIP
# из эфемерного пода внутри кластера, поэтому kube-proxy реально балансирует
# (port-forward к Service закрепился бы на одном поде и балансировку бы не показал).
lb_hostnames() {
  local n="${1:-20}"
  inpod "for i in \$(seq 1 $n); do curl -s --max-time 3 http://vote/; done" \
    | sed -n 's/.*Processed by container ID \([A-Za-z0-9._-]*\).*/\1/p' | sort -u
}
