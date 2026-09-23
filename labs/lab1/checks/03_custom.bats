#!/usr/bin/env bats
# Задание 3 — кастомный образ vote с canary-меткой и iframe.
# Контракт слеп к способу: смотрим на образ и на отданную им страницу,
# а не на текст Dockerfile.custom.

CUSTOM_IMAGE="vote-custom:v1"

setup() {
  source "${BATS_TEST_DIRNAME}/lib.sh"
}

# 03.1 образ vote-custom собран локально
@test "03.1 custom image is built" {
  image_exists "$CUSTOM_IMAGE"
}

# 03.2 образ несёт label lab1.canary из сида, и токен виден в отданной странице
@test "03.2 canary in image label and served page" {
  run image_label "$CUSTOM_IMAGE" lab1.canary
  [ "$output" = "$CANARY" ]

  body="$(serve_and_fetch "$CUSTOM_IMAGE" /)"
  echo "$body" | grep -qF "$CANARY"
}

# 03.3 страница содержит iframe с URL варианта и форму голосования
@test "03.3 page has iframe with variant URL and vote form" {
  body="$(serve_and_fetch "$CUSTOM_IMAGE" /)"
  echo "$body" | grep -qi '<iframe'
  echo "$body" | grep -qF "$IFRAME_URL"
  # форма голосования оригинала должна уцелеть (name="vote")
  echo "$body" | grep -qi 'name="vote"'
}
