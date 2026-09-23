#!/usr/bin/env bats
# Задание 4 — наблюдаемость. Контракты наблюдают исход: Prometheus реально
# скрейпит цели, Grafana отвечает здоровьем, дашборд несёт сид-canary, разбор
# инцидента ссылается на конкретную метрику. Обращения к сервисам — только
# foreground через inpod (эфемерный под), без фоновых port-forward.

setup() {
  source "${BATS_TEST_DIRNAME}/lib.sh"
}

# 04.1 Prometheus скрейпит хотя бы одну живую цель (health=up)
@test "04.1 prometheus scrapes at least one healthy target" {
  # имя сервиса Prometheus у чартов бывает разным — пробуем частые варианты
  local svc port body
  for svc in prometheus prometheus-server prometheus-operated; do
    for port in 9090 80; do
      body="$(http_body "$svc" "$port" /api/v1/targets 2>/dev/null)"
      printf '%s' "$body" | grep -q '"health":"up"' && return 0
    done
  done
  echo "нет здоровой цели в Prometheus (проверены prometheus/-server/-operated :9090,:80)"
  return 1
}

# 04.2 Grafana отвечает здоровьем (api/health -> ok)
@test "04.2 grafana health endpoint reports ok" {
  local svc port body
  for svc in grafana; do
    for port in 3000 80; do
      body="$(http_body "$svc" "$port" /api/health 2>/dev/null)"
      printf '%s' "$body" | grep -qi '"database"[[:space:]]*:[[:space:]]*"ok"' && return 0
    done
  done
  echo "Grafana /api/health не вернула ok на grafana :3000/:80"
  return 1
}

# 04.3 дашборд Grafana несёт метрику vote и сид-canary
@test "04.3 grafana dashboard carries vote metric and seed canary" {
  # дашборд студент кладёт в рабочий каталог как provisioning JSON; ищем сид-canary
  # и упоминание сервиса vote в определении дашборда (исход, не способ доставки)
  local f
  f="$(find_first 'grafana/**/*.json' || find_first 'grafana/*.json' \
    || find_first '**/dashboards/*.json' || find_first '*dashboard*.json' || true)"
  [ -n "$f" ]
  grep -Fq "$CANARY" "$f"
  grep -Eiq 'vote' "$f"
}

# 04.4 разбор инцидента следует методу симптом->гипотеза->причина и ссылается на метрику
@test "04.4 incident writeup follows symptom-hypothesis-cause and cites a metric" {
  local f
  f="$(find_first 'docs/incident.md' || find_first '**/incident.md' || true)"
  [ -n "$f" ]
  grep -qi 'симптом' "$f"
  grep -qi 'гипотез' "$f"
  grep -qi 'причин' "$f"
  # ссылка на конкретику: имя метрики/панели, PromQL или единица (up, %, rate(, _total)
  grep -Eiq 'up\b|rate\(|_total|%|panel|панел|метрик' "$f"
}
