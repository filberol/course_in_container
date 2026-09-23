#!/usr/bin/env bats
# Задание 5 — SLI/SLO, бюджет ошибок, blast radius. Контракт наблюдает исход:
# slo.yaml валиден, несёт цель из сида, корректный бюджет ошибок в минутах и
# описанный blast radius. Значения-якоря (цель, окно) сверяются с сидом точно.

setup() {
  source "${BATS_TEST_DIRNAME}/lib.sh"
  SLO="$(find_first 'slo.yaml' || find_first 'slo.yml' \
    || find_first '**/slo.yaml' || find_first '**/slo.yml' || true)"
}

# py-хелпер: загрузить slo.yaml и напечатать поле по «плоскому» поиску ключа
_slo_py() {
  python3 - "$SLO" "$1" <<'PY'
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
key = sys.argv[2]
def walk(o):
    if isinstance(o, dict):
        for k, v in o.items():
            if str(k).lower() == key.lower():
                yield v
            yield from walk(v)
    elif isinstance(o, list):
        for it in o:
            yield from walk(it)
vals = list(walk(doc))
print(vals[0] if vals else "")
PY
}

# 05.1 slo.yaml валиден и содержит цель SLO и окно из сида
@test "05.1 slo.yaml is valid and SLO target matches seed" {
  [ -n "$SLO" ]
  python3 -c "import yaml,sys; yaml.safe_load(open('$SLO'))"
  # цель: допускаем запись «99.9» или «99.9%»
  run bash -c "grep -Eoq '${SLO_TARGET}%?' '$SLO'"
  [ "$status" -eq 0 ]
  # окно: допускаем «30», «30d», «30 дней»
  run bash -c "grep -Eoq '${SLO_WINDOW_DAYS}[[:space:]]*(d|дн)?' '$SLO'"
  [ "$status" -eq 0 ]
}

# 05.2 бюджет ошибок посчитан в минутах и близок к (100-target)% от окна
@test "05.2 error budget in minutes is computed correctly" {
  [ -n "$SLO" ]
  local got expect tol
  got="$(_slo_py error_budget_minutes)"
  [ -n "$got" ]
  # ожидание: (100 - SLO_TARGET)/100 * WINDOW_DAYS * 24 * 60
  expect="$(python3 -c "print((100-float('$SLO_TARGET'))/100*$SLO_WINDOW_DAYS*24*60)")"
  # допуск 5% (студент мог округлить)
  run python3 -c "g=float('$got'); e=float('$expect'); import sys; sys.exit(0 if abs(g-e)<=max(1.0,e*0.05) else 1)"
  [ "$status" -eq 0 ]
}

# 05.3 blast radius описывает отказ redis и db
@test "05.3 blast radius covers redis and db failure" {
  [ -n "$SLO" ]
  grep -qi 'blast' "$SLO"
  grep -qi 'redis' "$SLO"
  grep -qi 'db\|postgres\|база' "$SLO"
}
