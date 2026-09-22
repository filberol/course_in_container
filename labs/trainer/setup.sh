#!/usr/bin/env bash
# Хостовые зависимости лаб: инструменты проверок + venv для страницы-тренажёра.
set -e
cd "$(dirname "$0")/.."                       # labs/

if command -v brew >/dev/null 2>&1; then
  echo "== brew install =="
  brew install kind kubernetes-cli bats-core jq ttyd coreutils
else
  echo "brew не найден. Установи вручную: kind, kubectl, bats, jq, ttyd, coreutils."
  echo "docker — из Docker Desktop или пакетов дистрибутива."
fi

echo "== venv тренажёра =="
python3 -m venv .venv
.venv/bin/pip install -q flask

echo "готово. Запуск: make trainer"
