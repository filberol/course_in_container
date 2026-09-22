#!/usr/bin/env bash
# Глобальный тренажёр лаб на хосте: терминал (ttyd) + страница-валидатор (Flask).
# Кластер и манифесты студент поднимает сам в терминале активной лабы.
set -e
cd "$(dirname "$0")/.."                       # labs/
PORT="${PORT:-8899}"
TTYD_PORT="${TTYD_PORT:-7681}"
VENV=".venv"

command -v ttyd >/dev/null || { echo "нужен ttyd: brew install ttyd (или apt)"; exit 1; }
[ -d "$VENV" ] || python3 -m venv "$VENV"
"$VENV/bin/pip" install -q flask >/dev/null 2>&1 || true

pkill -f "ttyd .*-p $TTYD_PORT" 2>/dev/null || true
ttyd -W -p "$TTYD_PORT" bash >/tmp/labs-ttyd.log 2>&1 &

echo "терминал: http://localhost:$TTYD_PORT"
echo "страница: http://localhost:$PORT"
PORT="$PORT" TTYD_PORT="$TTYD_PORT" exec "$VENV/bin/python" trainer/app.py
