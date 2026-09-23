#!/usr/bin/env python3
"""Глобальный тренажёр лаб. Один движок обслуживает все labs/labN/.

Лаба — самодостаточный пакет: seed.py (params), content.py (TITLE/TASKS/…),
checks/*.bats, scaffold/ (шаблон рабочей директории), Makefile.
Движок засевает рабочую директорию labN/workdir/ из scaffold/ (с подстановкой
сида), даёт файловое дерево с созданием файлов/папок, гоняет контракты
(`make -C labN`). Кластер студент поднимает сам в терминале (его cwd = workdir).
"""
import glob
import importlib.util
import json
import os
import re
import shutil
import signal
import string
import subprocess
import sys
import threading

from flask import Flask, jsonify, request, send_from_directory

HERE = os.path.dirname(os.path.abspath(__file__))   # labs/trainer
LABS = os.path.dirname(HERE)                          # labs/
STATE = os.path.join(HERE, ".state.json")
CURRENT = os.path.join(LABS, ".current")             # путь workdir для терминала (ttyd)

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
        spec = importlib.util.spec_from_file_location(f"{lab}_{name}", os.path.join(d, name + ".py"))
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


# ---------- рабочая директория (workdir) ----------
def workdir(lab):
    return os.path.join(lab_dir(lab), "workdir")


def seed_workdir(lab, p):
    """Засеять labN/workdir/ из labN/scaffold/ (с подстановкой сида), если её ещё нет."""
    wd, src = workdir(lab), os.path.join(lab_dir(lab), "scaffold")
    if os.path.exists(wd) or not os.path.isdir(src):
        return
    for root, _dirs, files in os.walk(src):
        rel = os.path.relpath(root, src)
        dst = os.path.join(wd, rel) if rel != "." else wd
        os.makedirs(dst, exist_ok=True)
        for f in files:
            raw = open(os.path.join(root, f)).read()
            open(os.path.join(dst, f), "w").write(subst(raw, p))


def safe(lab, rel):
    wd = workdir(lab)
    full = os.path.normpath(os.path.join(wd, (rel or "").lstrip("/")))
    if full != wd and not full.startswith(wd + os.sep):
        raise ValueError("path escapes workdir")
    return full


def tree(lab):
    wd = workdir(lab)
    out = []
    if not os.path.isdir(wd):
        return out
    for root, dirs, files in os.walk(wd):
        dirs.sort()
        rel = os.path.relpath(root, wd)
        for name in sorted(dirs) + sorted(files):
            path = name if rel == "." else os.path.join(rel, name)
            out.append({"path": path, "type": "dir" if name in dirs else "file"})
    return sorted(out, key=lambda x: x["path"])


# ---------- проверка (фоновый поток) ----------
JOB = {"running": False, "log": [], "results": None, "gate": None, "done": False, "pgid": None}


def log(m):
    JOB["log"].append(m)


def run(cmd, cwd, timeout=None):
    log("$ " + " ".join(cmd))
    p = subprocess.Popen(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         stdin=subprocess.DEVNULL, text=True, bufsize=1, start_new_session=True)
    try:
        JOB["pgid"] = os.getpgid(p.pid)   # чтобы /api/check/stop мог убить всю группу
    except ProcessLookupError:
        JOB["pgid"] = None
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
    JOB["pgid"] = None
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


def suite_stem(lab, sid):
    g = glob.glob(os.path.join(lab_dir(lab), "checks", f"{sid}_*.bats"))
    return os.path.splitext(os.path.basename(g[0]))[0] if g else None


def check_job(lab, isu, suite=None):
    JOB.update(running=True, log=[], results=None, gate=None, done=False, pgid=None)
    d = lab_dir(lab)
    try:
        log("== Проверяю доступность кластера ==")
        if run(["kubectl", "cluster-info", "--request-timeout=5s"], d) != 0:
            log("")
            log("Кластера нет. Подними его сам в терминале (его cwd — твоя рабочая директория).")
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
    p, tasks, labels, hints, hint = {}, [], {}, {}, ""
    if lab:
        C = load_mod(lab, "content")
        p = load_mod(lab, "seed").params(isu) if isu else {}
        if isu:
            seed_workdir(lab, p)
            open(CURRENT, "w").write(workdir(lab))    # cwd терминала = workdir активной лабы
        tasks = [{**t, "body": subst(t["body"], p)} for t in C.TASKS]
        labels = C.CHECK_LABELS
        hints = {k: subst(v, p) for k, v in getattr(C, "HINTS", {}).items()}
        hint = subst(getattr(C, "TERMINAL_HINT", ""), p)
    return jsonify(lab=lab, labs=labs_list(), title=title(lab) if lab else "",
                   isu=isu, params=(p or {}), tasks=tasks, labels=labels, hints=hints,
                   terminal_hint=hint, ttyd_port=int(os.environ.get("TTYD_PORT", "7681")))


@app.get("/api/tree")
def api_tree():
    return jsonify(tree=tree(load_state()["lab"]))


@app.route("/api/file", methods=["GET", "PUT"])
def api_file():
    st = load_state()
    lab = st["lab"]
    if request.method == "GET":
        try:
            path = safe(lab, request.args.get("path", ""))
            return jsonify(content=open(path).read() if os.path.isfile(path) else "")
        except (ValueError, OSError) as e:
            return jsonify(error=str(e)), 400
    d = request.json or {}
    try:
        path = safe(lab, d.get("path", ""))
        os.makedirs(os.path.dirname(path), exist_ok=True)
        open(path, "w").write(d.get("content", ""))
        return jsonify(ok=True)
    except (ValueError, OSError) as e:
        return jsonify(ok=False, error=str(e)), 400


@app.post("/api/mkdir")
def api_mkdir():
    st = load_state()
    try:
        os.makedirs(safe(st["lab"], (request.json or {}).get("path", "")), exist_ok=True)
        return jsonify(ok=True)
    except (ValueError, OSError) as e:
        return jsonify(ok=False, error=str(e)), 400


@app.post("/api/rm")
def api_rm():
    st = load_state()
    try:
        path = safe(st["lab"], (request.json or {}).get("path", ""))
        if os.path.isdir(path):
            shutil.rmtree(path)
        elif os.path.exists(path):
            os.remove(path)
        return jsonify(ok=True)
    except (ValueError, OSError) as e:
        return jsonify(ok=False, error=str(e)), 400


@app.post("/api/mv")
def api_mv():
    st = load_state()
    d = request.json or {}
    try:
        src, dst = safe(st["lab"], d.get("from", "")), safe(st["lab"], d.get("to", ""))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        os.rename(src, dst)
        return jsonify(ok=True)
    except (ValueError, OSError) as e:
        return jsonify(ok=False, error=str(e)), 400


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


@app.post("/api/check/stop")
def api_check_stop():
    if JOB["running"] and JOB.get("pgid"):
        try:
            os.killpg(JOB["pgid"], signal.SIGKILL)   # убить make/bats/kubectl разом
        except ProcessLookupError:
            pass
        log("== Остановлено пользователем ==")
        return jsonify(ok=True)
    return jsonify(ok=False, error="нечего останавливать"), 400


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
