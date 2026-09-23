#!/usr/bin/env bats
# Задание 2 — стратегия тегирования и canary-якорь. Схема тегирования и способ
# посадки canary приходят из сида (TAG_SCHEME, CANARY, IMAGE). Проверка слепа
# к инструменту сборки: docker build, buildx, build-push-action проходят одинаково.

setup() {
  source "${BATS_TEST_DIRNAME}/lib.sh"
}

# 02.1 конвейер собирает образ приложения (стадия build)
@test "02.1 pipeline builds the image" {
  pipeline_mentions 'docker build|buildx|build-push-action|docker/build|kaniko|nerdctl build'
}

# 02.2 тег образа проставляется по схеме из сида (semver | sha | branch)
@test "02.2 tag scheme matches seed" {
  case "$TAG_SCHEME" in
    semver)
      # semver: тег вида vX.Y.Z берётся из релизного git-тега (github.ref / ref_name)
      run bash -c "{ pipeline_run_text; pipeline_uses_text; } | grep -Eiq 'v?[0-9]+\\.[0-9]+\\.[0-9]+|github\\.ref_name|github\\.ref|semver|tags/v'"
      [ "$status" -eq 0 ] ;;
    sha)
      # sha: короткий commit-sha как тег артефакта
      run bash -c "{ pipeline_run_text; pipeline_uses_text; } | grep -Eiq 'github\\.sha|git rev-parse|short-sha|:sha|\\{sha\\}'"
      [ "$status" -eq 0 ] ;;
    branch)
      # branch: имя ветки как подвижная ссылка
      run bash -c "{ pipeline_run_text; pipeline_uses_text; } | grep -Eiq 'github\\.ref_name|github\\.head_ref|branch|git rev-parse --abbrev-ref'"
      [ "$status" -eq 0 ] ;;
    *) false ;;
  esac
}

# 02.3 canary-якорь из сида вшит в артефакт: OCI-лейбл образа ИЛИ trailer коммита релиза
@test "02.3 canary anchored in image label or release commit trailer" {
  # способ A: canary как лейбл в шагах сборки (--label ... = CANARY / labels: с CANARY)
  in_pipeline=1
  { pipeline_run_text; pipeline_uses_text; } | grep -Fiq "$CANARY" || in_pipeline=0

  # способ B: canary как trailer в истории коммитов репозитория
  in_git=1
  gwt log --format='%(trailers)%b' 2>/dev/null | grep -Fiq "$CANARY" || \
    gwt log --format='%B' 2>/dev/null | grep -Fiq "$CANARY" || in_git=0

  [ "$in_pipeline" -eq 1 ] || [ "$in_git" -eq 1 ]
}
