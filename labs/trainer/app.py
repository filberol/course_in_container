#!/usr/bin/env python3
"""Глобальный тренажёр лаб. Один движок обслуживает все labs/labN/.

Лаба — самодостаточный пакет: seed.py (params), content.py (TASKS/FILES/…),
checks/*.bats, stubs/, solution/, defense/, Makefile. Движок подгружает активную
лабу, отдаёт её задания и файлы, гоняет её контракты (`make -C labN`). Кластер
студент поднимает сам в терминале; «Проверить» только валидирует состояние.
"""
import glob
import importlib.util
import json
import os
import re
import signal
import string
import subprocess
import sys
import threading

from flask import Flask, jsonify, request, send_from_directory

HERE = os.path.dirname(os.path.abspath(__file__))   # labs/trainer
LABS = os.path.dirname(HERE)                          # labs/
STATE = os.path.join(HERE, ".state.json")

app = Flask(__name__, static_folder=HERE, static_url_path="")
TAP = re.compile(r"^(ok|not ok)\s+\d+\s+(\S+)")


# ---------- обнаружение и загрузка лаб ----------
def lab_dir(lab):
    return os.path.join(LABS, lab)


def is_lab(d):
    return (os.path.isdir(d) and os.path.basename(d).startswith("lab")
            and all(os.path.exists(os.path.join(d, f))
                    for f in ("content.py", "seed.py", "Makefile")))


def discover():
    return [os.path.basename(d) for d in sorted(glob.glob(os.path.join(LABS, "lab*")))
            if is_lab(d)]


_cache = {}


def load_mod(lab, name):
    key = (lab, name)
    if key not in _cache:
        d = lab_dir(lab)
        if d not in sys.path:
            sys.path.insert(0, d)
        path = os.path.join(d, name + ".py")
        spec = importlib.util.spec_from_file_location(f"{lab}_{name}", path)
        m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(m)
        _cache[key] = m
    return _cache[key]


def title(lab):
    try:
        return getattr(load_mod(lab, "content"), "TITLE", lab)
    except Exception:
        return lab


def labs_list():
    return [{"id": l, "title": title(l)} for l in discover()]


# ---------- состояние ----------
def load_state():
    st = {"lab": "", "isu": os.environ.get("LAB_ISU", "")}
    if os.path.exists(STATE):
        st.update(json.load(open(STATE)))
    labs = discover()
    if st["lab"] not in labs:
        st["lab"] = labs[0] if labs else ""
    return st


def save_state(s):
    json.dump(s, open(STATE, "w"))


def subst(t, p):
    return string.Template(t).safe_substitute(p)


def ensure_files(lab, p):
    md = os.path.join(lab_dir(lab), "manifests")
    os.makedirs(md, exist_ok=True)
    for f in load_mod(lab, "content").FILES:
        dst = os.path.join(md, f)
        if not os.path.exists(dst):
            src = os.path.join(lab_dir(lab), "stubs", f)
            raw = open(src).read() if os.path.exists(src) else ""
            open(dst, "w").write(subst(raw, p))


def suite_stem(lab, sid):
    g = glob.glob(os.path.join(lab_dir(lab), "checks", f"{sid}_*.bats"))
    return os.path.splitext(os.path.basename(g[0]))[0] if g else None


# ---------- проверка (фоновый поток) ----------
JOB = {"running": False, "log": [], "results": None, "gate": None, "done": False}


def log(m):
    JOB["log"].append(m)


def run(cmd, cwd, timeout=None):
    log("$ " + " ".join(cmd))
    p = subprocess.Popen(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         stdin=subprocess.DEVNULL, text=True, bufsize=1, start_new_session=True)
    killed = {"t": False}

    def _wd():
        killed["t"] = True
        try:
            os.killpg(os.getpgid(p.pid), signal.SIGKILL)
        except ProcessLookupError:
            pass

    timer = threading.Timer(timeout, _wd) if timeout else None
    if timer:
        timer.start()
    for line in p.stdout:
        log(line.rstrip("\n"))
    p.wait()
    if timer:
        timer.cancel()
    if killed["t"]:
        log("!! таймаут — процесс убит watchdog'ом")
        return 124
    return p.returncode


def parse_tap(lab):
    path = os.path.join(lab_dir(lab), ".scorecard.tap")
    res = {}
    if os.path.exists(path):
        for line in open(path):
            m = TAP.match(line.strip())
            if m:
                res[m.group(2)] = (m.group(1) == "ok")
    return res


def check_job(lab, isu, suite=None):
    JOB.update(running=True, log=[], results=None, gate=None, done=False)
    d = lab_dir(lab)
    try:
        log("== Проверяю доступность кластера ==")
        if run(["kubectl", "cluster-info", "--request-timeout=5s"], d) != 0:
            log("")
            log("Кластера нет. Подними его сам в терминале ниже (cd %s)." % lab)
            JOB["gate"] = "blocked"
            return
        stem = suite_stem(lab, suite) if suite else None
        if stem:
            log("== Проверяю задание %s ==" % suite)
            run(["make", "check-suite", "SUITE=" + stem, "ISU=" + isu], d, timeout=400)
            JOB["results"] = parse_tap(lab)
        else:
            log("== Прогоняю все контракты (несколько минут) ==")
            run(["make", "check", "ISU=" + isu], d, timeout=900)
            JOB["results"] = parse_tap(lab)
            JOB["gate"] = "admitted" if JOB["results"] and all(JOB["results"].values()) else "blocked"
        log("== Готово ==")
    except Exception as e:
        log("!! ошибка: " + repr(e))
    finally:
        JOB["running"] = False
        JOB["done"] = True


# ---------- API ----------
@app.get("/")
def index():
    return send_from_directory(HERE, "index.html")


@app.get("/api/state")
def api_state():
    st = load_state()
    lab, isu = st["lab"], st["isu"]
    p, tasks, files, labels, hint = {}, [], [], {}, ""
    if lab:
        C = load_mod(lab, "content")
        p = load_mod(lab, "seed").params(isu) if isu else {}
        if isu:
            ensure_files(lab, p)
        md = os.path.join(lab_dir(lab), "manifests")
        files = [{"name": f, "content": open(os.path.join(md, f)).read()
                  if os.path.exists(os.path.join(md, f)) else ""} for f in C.FILES]
        tasks = [{**t, "body": subst(t["body"], p),
                  "hints": [subst(h, p) for h in t["hints"]]} for t in C.TASKS]
        labels = C.CHECK_LABELS
        hint = subst(getattr(C, "TERMINAL_HINT", ""), p)
    return jsonify(lab=lab, labs=labs_list(), title=title(lab) if lab else "",
                   isu=isu, params=(p or {k: "—" for k in ["NS"]}),
                   tasks=tasks, files=files, labels=labels, terminal_hint=hint,
                   ttyd_port=int(os.environ.get("TTYD_PORT", "7681")))


@app.post("/api/lab")
def api_lab():
    st = load_state()
    lab = (request.json or {}).get("lab", "")
    if lab in discover():
        st["lab"] = lab
        save_state(st)
    return jsonify(ok=True)


@app.post("/api/isu")
def api_isu():
    st = load_state()
    st["isu"] = (request.json or {}).get("isu", "").strip()
    save_state(st)
    return jsonify(ok=True)


@app.put("/api/file")
def api_file():
    st = load_state()
    lab = st["lab"]
    d = request.json or {}
    name = d.get("name", "")
    if name not in load_mod(lab, "content").FILES:
        return jsonify(ok=False, error="unknown file"), 400
    md = os.path.join(lab_dir(lab), "manifests")
    os.makedirs(md, exist_ok=True)
    open(os.path.join(md, name), "w").write(d.get("content", ""))
    return jsonify(ok=True)


@app.post("/api/check")
def api_check():
    st = load_state()
    lab, isu = st["lab"], st["isu"]
    if not lab:
        return jsonify(ok=False, error="лаба не выбрана"), 400
    if not isu:
        return jsonify(ok=False, error="сначала укажи номер ИСУ"), 400
    if JOB["running"]:
        return jsonify(ok=False, error="проверка уже идёт"), 409
    suite = (request.json or {}).get("suite") if request.is_json else None
    threading.Thread(target=check_job, args=(lab, isu, suite), daemon=True).start()
    return jsonify(ok=True)


@app.get("/api/check")
def api_check_status():
    return jsonify(running=JOB["running"], done=JOB["done"], log=JOB["log"],
                   results=JOB["results"], gate=JOB["gate"])


@app.get("/api/cluster")
def api_cluster():
    st = load_state()
    lab, isu = st["lab"], st["isu"]
    ctx = subprocess.run(["kubectl", "config", "current-context"],
                         capture_output=True, text=True).stdout.strip()
    reachable = subprocess.run(["kubectl", "cluster-info", "--request-timeout=3s"],
                               capture_output=True, text=True).returncode == 0
    pods = []
    if reachable and lab and isu:
        ns = load_mod(lab, "seed").params(isu).get("NS")
        if ns:
            r = subprocess.run(["kubectl", "-n", ns, "get", "pods", "--no-headers"],
                               capture_output=True, text=True)
            for line in r.stdout.splitlines():
                pa = line.split()
                if len(pa) >= 3:
                    pods.append({"name": pa[0], "ready": pa[1], "status": pa[2]})
    return jsonify(reachable=reachable, context=ctx, pods=pods)


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=int(os.environ.get("PORT", "8899")), threaded=True)
