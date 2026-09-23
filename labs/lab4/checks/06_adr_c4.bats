#!/usr/bin/env bats
# Задание 6 — ADR и C4. Контракт наблюдает исход: не менее двух ADR в
# каноническом формате и две C4-диаграммы (Context, Container) в Mermaid.
# Проверяется наличие обязательных секций, не их содержание.

setup() {
  source "${BATS_TEST_DIRNAME}/lib.sh"
}

# файл содержит все четыре канонические секции ADR (в любом регистре, ru/en)
_is_adr() {
  local f="$1"
  grep -qiE 'context|контекст' "$f" &&
  grep -qiE 'decision|решени' "$f" &&
  grep -qiE 'status|статус' "$f" &&
  grep -qiE 'consequence|последстви' "$f"
}

# 06.1 минимум два ADR в каноническом формате
@test "06.1 at least two ADRs in canonical format" {
  local dir="$WORKDIR/docs/adr" f n=0
  [ -d "$dir" ]
  for f in "$dir"/*.md; do
    [ -e "$f" ] || continue
    _is_adr "$f" && n=$(( n + 1 ))
  done
  [ "$n" -ge 2 ]
}

# 06.2 C4 уровня Context: mermaid-блок, помеченный как context
@test "06.2 C4 context diagram present as mermaid" {
  local f
  f="$(find_first 'docs/c4.md' || find_first '**/c4.md' || find_first 'docs/*c4*.md' || true)"
  [ -n "$f" ]
  grep -q '```mermaid' "$f"
  grep -qiE 'context|контекст' "$f"
}

# 06.3 C4 уровня Container: mermaid-блок с контейнерами системы
@test "06.3 C4 container diagram present as mermaid" {
  local f
  f="$(find_first 'docs/c4.md' || find_first '**/c4.md' || find_first 'docs/*c4*.md' || true)"
  [ -n "$f" ]
  grep -qiE 'container|контейнер' "$f"
  # реальные контейнеры системы, а не placeholder
  grep -qi 'vote' "$f"
  grep -qiE 'prometheus|grafana' "$f"
}
