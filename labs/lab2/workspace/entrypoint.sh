#!/usr/bin/env bash
# Поднимает встроенный dockerd (DinD), затем фронт code-server на :8080.
set -e

if ! docker info >/dev/null 2>&1; then
  echo "запускаю встроенный dockerd..."
  dockerd >/var/log/dockerd.log 2>&1 &
  for _ in $(seq 1 30); do
    docker info >/dev/null 2>&1 && break
    sleep 1
  done
  docker info >/dev/null 2>&1 || { echo "dockerd не поднялся — нужен --privileged"; cat /var/log/dockerd.log; exit 1; }
fi

echo "фронт: http://localhost:8080  (harness в /work)"
exec code-server --bind-addr 0.0.0.0:8080 --auth none /work
