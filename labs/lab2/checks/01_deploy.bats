#!/usr/bin/env bats
# Задание 1 — развёртывание приложения.

setup() {
  source "${BATS_TEST_DIRNAME}/lib.sh"
}

# 01.1 namespace совпадает с сидом
@test "01.1 namespace matches seed" {
  run kubectl get ns "$NS" -o name
  [ "$status" -eq 0 ]
}

# 01.2 все пять сервисов имеют готовые поды
@test "01.2 all five services have ready pods" {
  for app in vote result worker redis db; do
    wait_ready "$app" 180s
  done
}

# 01.3 сквозной путь: vote -> redis -> worker -> db
@test "01.3 e2e vote reaches db" {
  cast_vote a
  wait_count_at_least a 1
}

# 01.4 пароль БД приходит из Secret (secretKeyRef, не открытым текстом)
@test "01.4 db password via secretKeyRef" {
  run bash -c "kubectl -n \"$NS\" get deploy,statefulset -l app=db -o json | \
    jq -e '[.items[].spec.template.spec.containers[].env[]? |
            select(.name==\"POSTGRES_PASSWORD\")] |
            (length > 0) and all(.[]; .valueFrom.secretKeyRef != null)'"
  [ "$status" -eq 0 ]
}
