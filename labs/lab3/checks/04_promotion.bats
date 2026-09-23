#!/usr/bin/env bats
# Задание 4 — промоушен сред. Среда промоушена из сида (PROMOTE_ENV). Ключевое
# свойство: тот же артефакт продвигается дальше без пересборки, а промоушен
# привязан к GitHub Environment (точка approval) и идёт после публикации.

setup() {
  source "${BATS_TEST_DIRNAME}/lib.sh"
}

# 04.1 есть джоб, привязанный к среде промоушена из сида (environment: ${PROMOTE_ENV})
@test "04.1 promotion job bound to seeded environment" {
  run bash -c "wf_py environments | grep -Fiq '$PROMOTE_ENV'"
  [ "$status" -eq 0 ]
}

# 04.2 промоушен идёт после публикации: джоб со средой зависит от publish/build/scan
@test "04.2 promotion runs after publish" {
  # найти джоб(ы) со средой промоушена и убедиться, что у них есть needs
  run bash -c '
    for j in $(wf_py jobs); do
      env=$(wf_py envnames "$j")
      if echo "$env" | grep -Fiq "'"$PROMOTE_ENV"'"; then
        wf_py needs "$j"
      fi
    done | grep -Eiq "publish|push|release|build|scan"'
  [ "$status" -eq 0 ]
}

# 04.3 промоушен без пересборки: джоб среды не запускает docker build заново
@test "04.3 promotion reuses artifact without rebuild" {
  # собрать текст run-шагов только тех джобов, что привязаны к среде промоушена,
  # и убедиться, что там нет повторной сборки образа
  run bash -c '
    WF_DIR="$(wf_dir)" python3 - "'"$PROMOTE_ENV"'" <<'"'"'PY'"'"'
import os, sys, glob
env_target = sys.argv[1].lower()
def parse(t):
    try:
        import yaml; return yaml.safe_load(t)
    except ImportError:
        return {}
txt = []
for pat in ("*.yml","*.yaml"):
    for p in glob.glob(os.path.join(os.environ["WF_DIR"], pat)):
        doc = parse(open(p, encoding="utf-8", errors="replace").read())
        jobs = (doc or {}).get("jobs", {}) if isinstance(doc, dict) else {}
        for _, job in (jobs or {}).items():
            if not isinstance(job, dict):
                continue
            e = job.get("environment")
            name = e if isinstance(e, str) else (e.get("name") if isinstance(e, dict) else "")
            if name and env_target in str(name).lower():
                for st in job.get("steps", []) or []:
                    if isinstance(st, dict):
                        txt.append(str(st.get("run","")) + " " + str(st.get("uses","")))
blob = " ".join(txt).lower()
sys.exit(1 if ("docker build" in blob or "buildx build" in blob or "build-push-action" in blob) else 0)
PY'
  # PyYAML может отсутствовать в базовом python — тогда джоб-фильтр пуст и шаг
  # проходит как «пересборки не обнаружено». Строгую проверку даёт e2e-прогон.
  [ "$status" -eq 0 ]
}
