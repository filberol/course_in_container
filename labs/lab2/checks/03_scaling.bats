#!/usr/bin/env bats
# Задание 3 — масштабирование и самовосстановление.

setup() {
  source "${BATS_TEST_DIRNAME}/lib.sh"
}

# 03.1 vote имеет REPLICAS_VOTE готовых реплик
@test "03.1 vote has REPLICAS_VOTE ready replicas" {
  run kc get deploy vote -o jsonpath='{.status.readyReplicas}'
  [ "$output" = "$REPLICAS_VOTE" ]
}

# 03.2 самовосстановление: удаление пода возвращается к N
@test "03.2 self-healing restores to N replicas" {
  pod="$(kc get pod -l app=vote -o name | head -1)"
  kc delete "$pod" --wait=false
  kc rollout status deploy/vote --timeout=120s
  run kc get deploy vote -o jsonpath='{.status.readyReplicas}'
  [ "$output" = "$REPLICAS_VOTE" ]
}

# 03.3 Service балансирует минимум по двум подам
@test "03.3 Service load-balances across >=2 pods" {
  seen="$(lb_hostnames 24 | grep -c .)"
  # за 24 запроса через ClusterIP kube-proxy распределяет по подам ->
  # уникальных hostname (из "Processed by container ID …") должно быть >= 2
  [ "$seen" -ge 2 ]
}
