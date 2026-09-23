#!/usr/bin/env bats
# Задание 5 — форма git-истории: ветка, Conventional Commit, аннотированный тег.
# Контракт слеп к способу: смотрим на объекты git (ветки/коммиты/теги), а не на
# конкретные команды, которыми студент их создал. REPO задаёт lib.sh.

setup() {
  source "${BATS_TEST_DIRNAME}/lib.sh"
}

# 05.1 существует ветка с префиксом feature/lab1
@test "05.1 feature/lab1 branch exists" {
  run git_in for-each-ref --format='%(refname:short)' refs/heads
  echo "$output" | grep -qE '^feature/lab1'
}

# 05.2 в истории ветки есть коммит с заголовком по Conventional Commits
@test "05.2 conventional commit present on feature branch" {
  # subject первой строки: type(scope)?!?: описание. Типы из спецификации.
  run git_in log --format='%s' -n 50 feature/lab1
  echo "$output" | grep -qE '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([^)]+\))?!?: .+'
}

# 05.3 существует аннотированный тег с canary-токеном в сообщении
@test "05.3 annotated tag carries canary token" {
  # перечисляем только аннотированные теги (object type = tag) и ищем canary в теле.
  run bash -c "
    for t in \$(git -C \"$REPO\" tag 2>/dev/null); do
      [ \"\$(git -C \"$REPO\" cat-file -t \"\$t\" 2>/dev/null)\" = tag ] || continue
      git -C \"$REPO\" tag -n99 -l \"\$t\" 2>/dev/null
    done
  "
  echo "$output" | grep -qF "$CANARY"
}
