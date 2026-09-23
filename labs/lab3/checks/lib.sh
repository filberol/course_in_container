# Хелперы контрактных проверок Лаб 3. Источаются из setup() каждого .bats.
# Параметры варианта приходят из окружения (Makefile их экспортирует из seed.py).
#
# Проверки СТАТИЧЕСКИЕ: смотрят на структуру и поведение конвейера, а не запускают
# тяжёлую сборку. Субстрат — git-репозиторий с CI-конвейером в WORKDIR (по умолчанию
# текущий каталог). Метод-слепота: контракт проверяет, что конвейер ОБЛАДАЕТ
# свойством (есть стадия scan с гейтом), а не точный текст YAML.

: "${IMAGE:?переменные варианта не заданы — запускайте через make check}"
: "${CANARY:?переменные варианта не заданы — запускайте через make check}"

# Корень репозитория студента. Тренажёр стартует терминал в workdir/, туда же
# студент кладёт .github/workflows/. Переопределяется через WORKDIR.
: "${WORKDIR:=.}"

# Портируемый таймаут: timeout (Linux) / gtimeout (mac+coreutils) / иначе без ограничения.
_to() {
  local s="$1"; shift
  if command -v timeout >/dev/null 2>&1; then timeout "$s" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$s" "$@"
  else "$@"; fi
}

# Каталог workflow-файлов конвейера.
wf_dir() { echo "$WORKDIR/.github/workflows"; }

# Все workflow-файлы (*.yml, *.yaml). Печатает по пути на строку.
wf_files() {
  find "$(wf_dir)" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null
}

# Есть ли хотя бы один workflow.
have_wf() { [ -n "$(wf_files)" ]; }

# --- парсер конвейера на python3 -------------------------------------------
# Предпочитаем PyYAML; при его отсутствии — минимальный отступный ридер внутри
# самого скрипта. И то и другое даёт список стадий/джобов/шагов и текст run-строк.
# Никаких сетевых вызовов, только чтение файлов из wf_dir.
#
#   wf_py <subcommand> [args]
#     jobs                    -> имена джобов, по одному на строку
#     steps                   -> все шаги всех джобов: "job\tname\tuses\trun-первая-строка"
#     runtext                 -> склеенный текст всех run:-блоков (для grep по командам)
#     usestext                -> склеенный текст всех uses: (какие actions задействованы)
#     needs <job>             -> зависимости джоба (needs), по одной на строку
#     triggers                -> ключи блока on: (push, pull_request, workflow_dispatch…)
#     envnames <job>          -> имена environment: у джоба (для промоушена/approval)
#     valid                   -> код 0, если все workflow парсятся как YAML
wf_py() {
  WF_DIR="$(wf_dir)" python3 - "$@" <<'PY'
import os, sys, glob

WF_DIR = os.environ.get("WF_DIR", "")

def load_files():
    docs = {}
    for pat in ("*.yml", "*.yaml"):
        for p in sorted(glob.glob(os.path.join(WF_DIR, pat))):
            with open(p, encoding="utf-8", errors="replace") as f:
                docs[p] = f.read()
    return docs

def parse(text):
    try:
        import yaml
        return yaml.safe_load(text)
    except ImportError:
        return _mini_yaml(text)

def _mini_yaml(text):
    # Достаточный отступный ридer для GitHub-Actions-подобных workflow:
    # словари/списки/скаляры, блочные скаляры (|, >) как одна строка текста.
    lines = [l.rstrip("\n") for l in text.splitlines()
             if l.strip() and not l.lstrip().startswith("#")]
    pos = [0]

    def indent(l):
        return len(l) - len(l.lstrip(" "))

    def scalar(v):
        v = v.strip()
        if v and v[0] in "\"'" and v[-1:] == v[0]:
            v = v[1:-1]
        return v

    def parse_block(base):
        # список?
        if pos[0] < len(lines) and lines[pos[0]].lstrip().startswith("- "):
            out = []
            while pos[0] < len(lines):
                l = lines[pos[0]]
                if indent(l) < base or not l.lstrip().startswith("- "):
                    break
                pos[0] += 1
                rest = l.lstrip()[2:]
                if ":" in rest and not rest.strip().startswith("#"):
                    # инлайн ключ: начинаем словарь элемента
                    item = {}
                    k, _, v = rest.partition(":")
                    v = v.strip()
                    if v in ("|", ">", "|-", ">-"):
                        item[k.strip()] = read_block_scalar(indent(l) + 2)
                    elif v:
                        item[k.strip()] = scalar(v)
                    else:
                        item[k.strip()] = parse_block(indent(l) + 2)
                    item.update(_dict_tail(indent(l) + 2))
                    out.append(item)
                else:
                    out.append(scalar(rest))
            return out
        return _dict_tail(base)

    def _dict_tail(base):
        out = {}
        while pos[0] < len(lines):
            l = lines[pos[0]]
            ind = indent(l)
            if ind < base or l.lstrip().startswith("- "):
                break
            if ":" not in l:
                pos[0] += 1
                continue
            pos[0] += 1
            k, _, v = l.lstrip().partition(":")
            k = k.strip(); v = v.strip()
            if v in ("|", ">", "|-", ">-"):
                out[k] = read_block_scalar(ind + 1)
            elif v:
                out[k] = scalar(v)
            else:
                out[k] = parse_block(ind + 1)
            if out[k] == {}:
                out[k] = None
        return out

    def read_block_scalar(min_ind):
        buf = []
        while pos[0] < len(lines):
            l = lines[pos[0]]
            if indent(l) < min_ind:
                break
            buf.append(l.strip())
            pos[0] += 1
        return "\n".join(buf)

    return parse_block(0)

def jobs_of(doc):
    if not isinstance(doc, dict):
        return {}
    j = doc.get("jobs")
    return j if isinstance(j, dict) else {}

def all_jobs():
    out = {}
    for _, text in load_files().items():
        for name, body in jobs_of(parse(text)).items():
            out[name] = body if isinstance(body, dict) else {}
    return out

def steps_of(job):
    s = job.get("steps") if isinstance(job, dict) else None
    return s if isinstance(s, list) else []

cmd = sys.argv[1] if len(sys.argv) > 1 else ""

if cmd == "valid":
    ok = True
    for p, text in load_files().items():
        try:
            parse(text)
        except Exception:
            ok = False
    sys.exit(0 if ok and load_files() else 1)

elif cmd == "jobs":
    for name in all_jobs():
        print(name)

elif cmd == "steps":
    for jn, job in all_jobs().items():
        for st in steps_of(job):
            if not isinstance(st, dict):
                continue
            name = str(st.get("name", ""))
            uses = str(st.get("uses", ""))
            run = str(st.get("run", "")).splitlines()
            run0 = run[0] if run else ""
            print(f"{jn}\t{name}\t{uses}\t{run0}")

elif cmd == "runtext":
    for _, job in all_jobs().items():
        for st in steps_of(job):
            if isinstance(st, dict) and st.get("run"):
                print(str(st["run"]))

elif cmd == "usestext":
    for _, job in all_jobs().items():
        for st in steps_of(job):
            if isinstance(st, dict) and st.get("uses"):
                print(str(st["uses"]))

elif cmd == "needs":
    target = sys.argv[2] if len(sys.argv) > 2 else ""
    job = all_jobs().get(target, {})
    n = job.get("needs")
    if isinstance(n, str):
        print(n)
    elif isinstance(n, list):
        for x in n:
            print(x)

elif cmd == "triggers":
    for _, text in load_files().items():
        doc = parse(text)
        if isinstance(doc, dict):
            on = doc.get("on") or doc.get(True)  # PyYAML читает on: как True
            if isinstance(on, dict):
                for k in on:
                    print(k)
            elif isinstance(on, list):
                for k in on:
                    print(k)
            elif isinstance(on, str):
                print(on)

elif cmd == "envnames":
    target = sys.argv[2] if len(sys.argv) > 2 else ""
    job = all_jobs().get(target, {})
    e = job.get("environment")
    if isinstance(e, str):
        print(e)
    elif isinstance(e, dict) and e.get("name"):
        print(e["name"])

elif cmd == "environments":
    for _, job in all_jobs().items():
        e = job.get("environment") if isinstance(job, dict) else None
        if isinstance(e, str):
            print(e)
        elif isinstance(e, dict) and e.get("name"):
            print(e["name"])
PY
}

# Текст всех run:-шагов конвейера (нижним регистром) — для grep по командам.
pipeline_run_text() { wf_py runtext | tr 'A-Z' 'a-z'; }

# Текст всех uses: (задействованные actions) — нижним регистром.
pipeline_uses_text() { wf_py usestext | tr 'A-Z' 'a-z'; }

# Есть ли в конвейере команда/строка (регэксп) в run: ИЛИ uses:.
# Метод-слепо: инструмент могли вызвать как action (uses) или как shell (run).
pipeline_mentions() {   # pipeline_mentions <extended-regex>
  { pipeline_run_text; pipeline_uses_text; } | grep -Eiq "$1"
}

# Есть ли джоб/шаг, чьё имя ИЛИ команда намекает на стадию (регэксп).
# Проверяем имена джобов, имена шагов и run-строки одновременно.
pipeline_has_stage() {  # pipeline_has_stage <extended-regex>
  { wf_py jobs; wf_py steps; } | grep -Eiq "$1"
}

# Git в WORKDIR.
gwt() { git -C "$WORKDIR" "$@"; }
