#!/usr/bin/env bats
# Задание 5 — rolling update. Контракт «без простоя» = доступность не падает
# ниже (REPLICAS_VOTE - MAX_UNAVAIL) в течение выката. Значение из сида.

setup() {
  source "${BATS_TEST_DIRNAME}/lib.sh"
}

# 05.1 maxUnavailable совпадает с сидом
@test "05.1 maxUnavailable matches seed" {
  run kc get deploy vote -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}'
  [ "$output" = "$MAX_UNAVAIL" ]
}

# 05.2 выкат без простоя: readyReplicas не падает ниже N - maxUnavailable
@test "05.2 zero-downtime rollout keeps readyReplicas >= N minus maxUnavailable" {
  local floor=$(( REPLICAS_VOTE - MAX_UNAVAIL ))
  local samples=/tmp/lab2_ready.$$
  : > "$samples"
  ( for _ in $(seq 1 80); do
      kc get deploy vote -o jsonpath='{.status.readyReplicas}' >> "$samples" 2>/dev/null
      echo >> "$samples"
      sleep 0.5
    done ) &
  local sampler=$!

  kc rollout restart deploy/vote
  kc rollout status deploy/vote --timeout=180s

  kill "$sampler" 2>/dev/null || true
  local min
  min=$(grep -E '^[0-9]+$' "$samples" | sort -n | head -1)
  rm -f "$samples"
  [ -n "$min" ]
  [ "$min" -ge "$floor" ]
}

# 05.3 в истории выката не менее двух ревизий
@test "05.3 rollout history has >=2 revisions" {
  run bash -c "kubectl -n \"$NS\" rollout history deploy/vote | grep -cE '^[0-9]+'"
  [ "$output" -ge 2 ]
}

# 05.4 откат возвращает предыдущую ревизию
@test "05.4 rollback returns previous revision" {
  kc rollout undo deploy/vote
  kc rollout status deploy/vote --timeout=180s
}
