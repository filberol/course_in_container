#!/usr/bin/env bats
# Задание 1 — инфраструктура кодом: plan и apply. Контракт слеп к тексту HCL:
# проверяется наблюдаемый исход (кластер поднят, namespace и сервисы есть),
# а не конкретные ресурсы или их имена в конфигурации.

setup() {
  source "${BATS_TEST_DIRNAME}/lib.sh"
}

# 01.1 конфигурация Terraform валидна (terraform validate)
@test "01.1 terraform configuration is valid" {
  tf validate
}

# 01.2 kind-кластер варианта поднят и API отвечает
@test "01.2 kind cluster is up and API responds" {
  run bash -c "kind get clusters | grep -Fxq \"$CLUSTER\""
  [ "$status" -eq 0 ]
  _to 30 kubectl --context "$KCTX" version >/dev/null
}

# 01.3 namespace совпадает с сидом и создан через Terraform
@test "01.3 namespace matches seed" {
  run kubectl --context "$KCTX" get ns "$NS" -o name
  [ "$status" -eq 0 ]
}

# 01.4 сервисы db и redis существуют с точными именами
@test "01.4 db and redis services exist with exact names" {
  svc_exists db
  svc_exists redis
}
