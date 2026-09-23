#!/usr/bin/env bats
# Задание 2 — идемпотентность и дрейф. Контракт наблюдает свойство состояния:
# plan без изменений после apply, обнаружение внесённого дрейфа, лечение через apply.

setup() {
  source "${BATS_TEST_DIRNAME}/lib.sh"
}

# 02.1 plan после apply идемпотентен (detailed-exitcode = 0, нет изменений)
@test "02.1 plan is idempotent after apply (no changes)" {
  # -detailed-exitcode: 0 = нет изменений, 1 = ошибка, 2 = есть изменения
  run tf plan -detailed-exitcode -input=false
  [ "$status" -eq 0 ]
}

# 02.2 внесённый вручную дрейф обнаруживается на этапе plan
@test "02.2 manual drift is detected by plan" {
  # вносим дрейф мимо Terraform: меняем реплики vote в кластере
  local other=$(( REPLICAS_VOTE + 1 ))
  kc scale deploy/vote --replicas="$other"
  kc rollout status deploy/vote --timeout=60s
  # теперь plan обязан показать изменения -> код 2
  run tf plan -detailed-exitcode -input=false
  [ "$status" -eq 2 ]
}

# 02.3 apply лечит дрейф: vote возвращается к декларированному числу реплик
@test "02.3 apply reconciles drift back to declared replicas" {
  tf apply -auto-approve -input=false
  kc rollout status deploy/vote --timeout=120s
  run kc get deploy vote -o jsonpath='{.spec.replicas}'
  [ "$output" = "$REPLICAS_VOTE" ]
}
