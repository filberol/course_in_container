#!/usr/bin/env bats
# Задание 3 — Ansible идемпотентно. Контракт наблюдает исход двух прогонов:
# повторный прогон не вносит изменений (changed=0). Как именно достигнута
# идемпотентность — дело студента, проверяется свойство результата.

setup() {
  source "${BATS_TEST_DIRNAME}/lib.sh"
  PLAYBOOK="$(find_first 'ansible/*.yml' || find_first 'ansible/*.yaml' \
    || find_first 'playbook.yml' || find_first 'playbook.yaml' || true)"
  ADIR="$WORKDIR/ansible"
  [ -d "$ADIR" ] || ADIR="$WORKDIR"
}

# число из строки play recap: recap_field <output> <field>
recap_field() {
  printf '%s' "$1" | sed -n "s/.*$2=\([0-9]*\).*/\1/p" | tail -1
}

# один прогон playbook, вывод в $output, код в $status.
# _to (портируемый таймаут) экспортируется, чтобы быть видимым в подоболочке bash -c.
run_play() {
  export -f _to
  run bash -c "cd \"$ADIR\" && ANSIBLE_FORCE_COLOR=0 _to 300 ansible-playbook \"$PLAYBOOK\" 2>&1"
}

# 03.1 первый прогон playbook завершается без ошибок
@test "03.1 first playbook run completes without failures" {
  [ -n "$PLAYBOOK" ]
  run_play
  [ "$status" -eq 0 ]
  [ "$(recap_field "$output" failed)" = "0" ]
}

# 03.2 повторный прогон идемпотентен (changed=0)
@test "03.2 second playbook run is idempotent (changed=0)" {
  [ -n "$PLAYBOOK" ]
  run_play
  [ "$status" -eq 0 ]
  [ "$(recap_field "$output" changed)" = "0" ]
}
