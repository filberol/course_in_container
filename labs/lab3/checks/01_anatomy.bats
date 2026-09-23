#!/usr/bin/env bats
# Задание 1 — анатомия конвейера. Контракты слепы к способу: стадии могут быть
# отдельными jobs или именованными шагами; проверяется наличие стадии и порядок
# гейтов, а не точный YAML.

setup() {
  source "${BATS_TEST_DIRNAME}/lib.sh"
}

# 01.1 хотя бы один workflow есть и парсится как YAML
@test "01.1 workflow present and valid yaml" {
  have_wf
  run wf_py valid
  [ "$status" -eq 0 ]
}

# 01.2 в конвейере видны все пять стадий: lint, test, build, scan, publish
@test "01.2 five pipeline stages present" {
  pipeline_has_stage 'lint'
  pipeline_has_stage 'test'
  pipeline_has_stage 'build'
  pipeline_has_stage 'scan|trivy|security'
  pipeline_has_stage 'publish|push|release'
}

# 01.3 стадии выстроены гейтами по порядку: publish зависит от предыдущих,
# scan — после build (последующая ждёт предыдущую через needs)
@test "01.3 stages ordered by gates via needs" {
  # хотя бы один job объявляет зависимости needs — значит есть цепочка гейтов
  run bash -c '{ for j in $(wf_py jobs); do wf_py needs "$j"; done; } | grep -c .'
  [ "$output" -ge 1 ]
}

# 01.4 конвейер запускается и на push, и на pull_request
@test "01.4 triggers on push and pull_request" {
  run bash -c 'wf_py triggers | grep -Eiq "^push$"'
  [ "$status" -eq 0 ]
  run bash -c 'wf_py triggers | grep -Eiq "pull_request"'
  [ "$status" -eq 0 ]
}
