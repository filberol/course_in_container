#!/usr/bin/env bash
# Глобальный тренажёр лаб на хосте: терминал (ttyd) + страница-валидатор (Flask).
# Терминал по умолчанию открывается в рабочей директории активной лабы (labs/.current).
set -e
cd "$(dirname "$0")/.."                       # labs/
PORT="${PORT:-8899}"
TTYD_PORT="${TTYD_PORT:-7681}"
VENV=".venv"

command -v ttyd >/dev/null || { echo "нужен ttyd: brew install ttyd (или apt)"; exit 1; }
[ -d "$VENV" ] || python3 -m venv "$VENV"
"$VENV/bin/pip" install -q flask >/dev/null 2>&1 || true

pkill -f "ttyd .*-p $TTYD_PORT" 2>/dev/null || true
# каждая сессия терминала стартует в workdir активной лабы (путь в .current)
ttyd -W -p "$TTYD_PORT" bash -c 'd=$(cat .current 2>/dev/null); [ -n "$d" ] && cd "$d"; exec bash' \
     >/tmp/labs-ttyd.log 2>&1 &

echo "терминал: http://localhost:$TTYD_PORT"
echo "страница: http://localhost:$PORT"
PORT="$PORT" TTYD_PORT="$TTYD_PORT" exec "$VENV/bin/python" trainer/app.py
