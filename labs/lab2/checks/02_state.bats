#!/usr/bin/env bats
# Задание 2 — состояние и data gravity. Контракты слепы к способу:
# StatefulSet или Deployment+PVC проходят одинаково, если данные пережили рестарт.

setup() {
  source "${BATS_TEST_DIRNAME}/lib.sh"
}

# 02.1 PVC базы данных привязан и размер совпадает с сидом
@test "02.1 db PVC bound and size matches seed" {
  run kc get pvc -l app=db -o jsonpath='{.items[0].status.phase}'
  [ "$output" = "Bound" ]
  run kc get pvc -l app=db -o jsonpath='{.items[0].spec.resources.requests.storage}'
  [ "$output" = "$PVC_SIZE" ]
}

# 02.2 голос переживает рестарт пода БД (data gravity)
@test "02.2 vote survives db pod restart" {
  cast_vote a
  wait_count_at_least a 1
  before="$(read_count a)"

  pod="$(kc get pod -l app=db -o name | head -1)"
  kc delete "$pod" --wait=true
  wait_ready db 120s

  after="$(read_count a)"
  [ "$after" -ge "$before" ]      # счётчик не обнулился -> состояние сохранилось на томе
}

# 02.3 redis остаётся эфемерным (без PVC)
@test "02.3 redis is ephemeral (no PVC)" {
  run kc get pvc -l app=redis -o name
  [ -z "$output" ]
}
