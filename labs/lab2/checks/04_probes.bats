#!/usr/bin/env bats
# Задание 4 — health-пробы и canary.

setup() {
  source "${BATS_TEST_DIRNAME}/lib.sh"
}

# 04.1 vote и result имеют readiness и liveness пробы
@test "04.1 vote and result have readiness and liveness probes" {
  for app in vote result; do
    run bash -c "kubectl -n \"$NS\" get deploy -l app=$app -o json | \
      jq -e '.items[0].spec.template.spec.containers[0] |
             (.readinessProbe != null) and (.livenessProbe != null)'"
    [ "$status" -eq 0 ]
  done
}

# 04.2 эндпоинт vote отвечает 200 (проба рабочая)
@test "04.2 vote endpoint returns 200" {
  pf=$(portforward vote 15004 80)
  code=$(http_code http://127.0.0.1:15004/)
  kill "$pf" 2>/dev/null || true
  [ "$code" = "200" ]
}

# 04.3 canary в label и env сервиса vote совпадает с сидом
@test "04.3 canary in vote label and env matches seed" {
  run kc get deploy vote -o jsonpath='{.spec.template.metadata.labels.lab2\.canary}'
  [ "$output" = "$CANARY" ]

  run bash -c "kubectl -n \"$NS\" get deploy vote -o json | \
    jq -r '.spec.template.spec.containers[0].env[]? | select(.name==\"CANARY\") | .value'"
  [ "$output" = "$CANARY" ]
}
