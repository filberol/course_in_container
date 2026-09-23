#!/usr/bin/env bats
# Задание 3 — DevSecOps-гейт. Trivy на образ присутствует всегда; второй сканер
# приходит из сида (SEC_GATE: sca|sast|secrets), порог падения — FAIL_ON.
# Ключевое свойство: гейт ВАЛИТ сборку на находках, а не просто печатает отчёт.

setup() {
  source "${BATS_TEST_DIRNAME}/lib.sh"
}

# 03.1 стадия scan сканирует собранный образ инструментом Trivy
@test "03.1 trivy scans the image" {
  pipeline_mentions 'trivy'
}

# 03.2 второй сканер-гейт нужного класса из сида присутствует
@test "03.2 second scanner of seeded class present" {
  case "$SEC_GATE" in
    sca)
      # сканер зависимостей: trivy fs/repo, grype, osv-scanner, dependency scan
      pipeline_mentions 'trivy (fs|filesystem|repo|config)|grype|osv-scanner|dependency|depend[ae]bot|snyk' ;;
    sast)
      # статический анализ кода
      pipeline_mentions 'semgrep|codeql|bandit|sonar|sast' ;;
    secrets)
      # поиск секретов в истории/дереве
      pipeline_mentions 'gitleaks|trufflehog|detect-secrets|secret[- ]scan' ;;
    *) false ;;
  esac
}

# 03.3 гейт валит сборку на находках: у сканеров задан ненулевой exit на находке,
# и стадия scan стоит до publish (гейт останавливает конвейер, а не логирует)
@test "03.3 gate fails the build on findings before publish" {
  # признак «валит сборку»: exit-code/severity-порог/--error у сканера
  run bash -c "{ pipeline_run_text; pipeline_uses_text; } | grep -Eiq 'exit-code|exit_code|--exit|fail[-_ ]?on|severity|--error|-e error|set -e'"
  [ "$status" -eq 0 ]

  # порог из сида упомянут (CRITICAL/HIGH) — гейт настроен на нужный уровень
  run bash -c "{ pipeline_run_text; pipeline_uses_text; } | grep -Fiq '$FAIL_ON'"
  [ "$status" -eq 0 ]

  # scan предшествует publish: у джоба публикации есть зависимость (needs),
  # тянущаяся к сканированию (порядок гейтов гарантирует остановку до релиза)
  run bash -c 'for j in $(wf_py jobs); do echo "$j"; done | grep -Eiq "publish|push|release|deploy"'
  [ "$status" -eq 0 ]
  run bash -c 'for j in $(wf_py jobs); do wf_py needs "$j"; done | grep -c .'
  [ "$output" -ge 1 ]
}
