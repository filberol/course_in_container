#!/usr/bin/env bats
# Задание 2 — образ vote и его слои.

BASE_IMAGE="dockersamples/examplevotingapp_vote"

setup() {
  source "${BATS_TEST_DIRNAME}/lib.sh"
}

# 02.1 базовый образ vote скачан локально
@test "02.1 base vote image present locally" {
  image_exists "$BASE_IMAGE"
}

# 02.2 история образа показывает несколько слоёв
@test "02.2 image history shows multiple layers" {
  run history_layers "$BASE_IMAGE"
  [ "$output" -ge 2 ]
}
