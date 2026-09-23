#!/usr/bin/env bats
# Задание 1 — запуск приложения через docker compose.

setup() {
  source "${BATS_TEST_DIRNAME}/lib.sh"
}

# 01.1 проект варианта поднят (есть контейнеры с меткой проекта)
@test "01.1 compose project is up" {
  run count_running
  [ "$output" -ge 1 ]
}

# 01.2 в проекте запущено не менее пяти контейнеров (vote, result, worker, redis, db)
@test "01.2 five services are running" {
  run count_running
  [ "$output" -ge 5 ]
}

# 01.3 vote отвечает 200 на своём порту
@test "01.3 vote endpoint returns 200" {
  local code
  code="$(http_code "$VOTE_PORT" /)"
  [ "$code" = "200" ]
}

# 01.4 result отвечает 200 на своём порту
@test "01.4 result endpoint returns 200" {
  local code
  code="$(http_code "$RESULT_PORT" /)"
  [ "$code" = "200" ]
}
