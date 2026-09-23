#!/usr/bin/env bats
# Задание 4 — оптимизация образа. Контракт слеп к способу (multi-stage / alpine /
# .dockerignore проходят одинаково): проверяем размер и работоспособность.

CUSTOM_IMAGE="vote-custom:v1"
OPT_IMAGE="vote-opt:v2"

setup() {
  source "${BATS_TEST_DIRNAME}/lib.sh"
}

# 04.1 оптимизированный образ работает: отдаёт страницу с формой голосования
@test "04.1 optimized image serves working page" {
  image_exists "$OPT_IMAGE"
  body="$(serve_and_fetch "$OPT_IMAGE" /)"
  echo "$body" | grep -qi 'name="vote"'
}

# 04.2 размер vote-opt не превышает SIZE_BUDGET_PCT% от vote-custom
@test "04.2 optimized image within size budget" {
  local opt custom
  opt="$(image_size "$OPT_IMAGE")"
  custom="$(image_size "$CUSTOM_IMAGE")"
  [ "$opt" -gt 0 ] && [ "$custom" -gt 0 ]
  # opt <= custom * budget / 100  ->  opt*100 <= custom*budget (целочисленно)
  [ $(( opt * 100 )) -le $(( custom * SIZE_BUDGET_PCT )) ]
}

# 04.3 кастомизация уцелела после оптимизации: canary и iframe в отданной странице
@test "04.3 customization survives optimization" {
  run image_label "$OPT_IMAGE" lab1.canary
  [ "$output" = "$CANARY" ]

  body="$(serve_and_fetch "$OPT_IMAGE" /)"
  echo "$body" | grep -qF "$CANARY"
  echo "$body" | grep -qF "$IFRAME_URL"
}
