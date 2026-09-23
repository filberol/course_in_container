#!/usr/bin/env bats
# Задание 5 — метрики DORA. Скрипт по git-истории считает как минимум частоту
# развёртываний и время поставки изменения. Контракт слеп к языку: sh или py.

setup() {
  source "${BATS_TEST_DIRNAME}/lib.sh"
}

# 05.1 скрипт метрик DORA существует и исполняется из корня репозитория
@test "05.1 dora metrics script exists and runs" {
  run bash -c "ls \"$WORKDIR\"/metrics/dora.* 2>/dev/null | head -1"
  [ -n "$output" ]
  local script="$output"
  # запускается без аргументов и завершается успешно (ограничим по времени)
  run bash -c "cd \"$WORKDIR\" && _to 30 sh \"$script\" 2>/dev/null || _to 30 python3 \"$script\" 2>/dev/null"
  [ "$status" -eq 0 ]
}

# 05.2 скрипт считает частоту развёртываний — упоминает теги/релизы в git-истории
@test "05.2 script computes deployment frequency from git" {
  run bash -c "grep -REiq 'git tag|git for-each-ref|refs/tags|deployment.?freq|частот' \"$WORKDIR\"/metrics/dora.* 2>/dev/null"
  [ "$status" -eq 0 ]
}

# 05.3 скрипт считает время поставки изменения (lead time) — работает с датами коммитов
@test "05.3 script computes lead time for changes" {
  run bash -c "grep -REiq 'lead.?time|committerdate|%ct|%ci|creatordate|поставк' \"$WORKDIR\"/metrics/dora.* 2>/dev/null"
  [ "$status" -eq 0 ]
}
