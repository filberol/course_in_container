# Хелперы контрактных проверок. Источаются из setup() каждого .bats.
# Параметры варианта приходят из окружения (Makefile их экспортирует из seed.py).

: "${NS:?namespace не задан — запускайте через make check}"

# kubectl в namespace варианта
kc() { kubectl -n "$NS" "$@"; }

# Дождаться готовности подов по label-селектору app=<name>
wait_ready() {
  local app="$1" timeout="${2:-120s}"
  kc wait --for=condition=ready pod -l "app=$app" --timeout="$timeout"
}

# Проброс порта Service на локальный порт, печатает PID (закрывать вызывающему)
portforward() {
  local svc="$1" local_port="$2" svc_port="$3"
  kc port-forward "svc/$svc" "$local_port:$svc_port" >/dev/null 2>&1 &
  echo $!
  sleep 2
}

# HTTP-код по URL
http_code() { curl -s -o /dev/null -w '%{http_code}' "$1"; }

# Отдать голос за вариант (a|b): POST на сервис vote
cast_vote() {
  local option="$1" pf
  pf=$(portforward vote 15000 80)
  curl -s -X POST --data "vote=$option" http://127.0.0.1:15000/ >/dev/null || true
  kill "$pf" 2>/dev/null || true
}

# Число голосов за вариант в PostgreSQL (worker переносит из redis не мгновенно).
# Допущение: под БД доступен как deploy/db или statefulset/db, psql внутри контейнера,
# таблица votes(vote text). Схема — из example-voting-app.
read_count() {
  local option="$1"
  kc exec deploy/db 2>/dev/null -- \
     psql -U postgres -tAc "select count(*) from votes where vote='$option'" 2>/dev/null \
    || kc exec statefulset/db -- \
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
  kubectl -n "$NS" run "lab2-lb-$RANDOM" --image=curlimages/curl:8.9.0 \
      --restart=Never -q --rm -i --command -- \
      sh -c "for i in \$(seq 1 $n); do curl -s http://vote/; done" 2>/dev/null \
    | sed -n 's/.*Processed by container ID \([A-Za-z0-9._-]*\).*/\1/p' | sort -u
}
