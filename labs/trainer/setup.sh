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

# PyYAML для системного python3 — строгие ворота Лаб 3 (парсинг workflow-ов).
# Без него проверки используют встроенный мягкий ридер.
echo "== PyYAML для проверок Лаб 3 =="
python3 -m pip install -q --user pyyaml 2>/dev/null \
  || python3 -m pip install -q --break-system-packages pyyaml 2>/dev/null \
  || echo "  не поставился — Лаб 3 упадёт на встроенный ридер (мягче для 04.3)"

echo "готово. Запуск: make trainer"
