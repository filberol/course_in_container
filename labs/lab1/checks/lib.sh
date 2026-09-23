# Хелперы контрактных проверок Лаб 1 (Docker). Источаются из setup() каждого .bats.
# Параметры варианта приходят из окружения (Makefile экспортирует их из seed.py).

: "${PROJECT:?PROJECT не задан — запускайте через make check}"
# Страхуем остальные переменные значениями по умолчанию, чтобы lib.sh не падал,
# если .bats источается напрямую (в норме их задаёт seed.py --env).
: "${VOTE_PORT:=8080}"
: "${RESULT_PORT:=8081}"
: "${CANARY:=}"
: "${IFRAME_URL:=}"
: "${SIZE_BUDGET_PCT:=70}"

# Портируемый таймаут: timeout (Linux) / gtimeout (mac+coreutils) / иначе без ограничения.
_to() {
  local s="$1"; shift
  if command -v timeout >/dev/null 2>&1; then timeout "$s" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$s" "$@"
  else "$@"; fi
}

# docker compose в проекте варианта (имя проекта изолирует контейнеры и сеть).
dc() { docker compose -p "$PROJECT" "$@"; }

# HTTP-код по localhost:<port><path>. Всё foreground, без фоновых процессов.
http_code() {   # http_code <port> [path]
  _to 15 curl -s -o /dev/null -w '%{http_code}' "http://localhost:$1${2:-/}" 2>/dev/null || echo 000
}

# Тело страницы по localhost:<port><path> (для поиска canary/iframe в отданном HTML).
page_body() {   # page_body <port> [path]
  _to 15 curl -s "http://localhost:$1${2:-/}" 2>/dev/null || true
}

# Число запущенных (running) контейнеров в проекте.
count_running() {
  _to 15 docker ps --filter "label=com.docker.compose.project=$PROJECT" \
    --filter status=running -q 2>/dev/null | grep -c .
}

# Образ существует локально?
image_exists() {   # image_exists <ref>
  docker image inspect "$1" >/dev/null 2>&1
}

# Размер образа в байтах (docker image inspect .Size).
image_size() {   # image_size <ref>
  docker image inspect "$1" --format '{{.Size}}' 2>/dev/null || echo 0
}

# Значение label образа.
image_label() {   # image_label <ref> <key>
  docker image inspect "$1" --format "{{index .Config.Labels \"$2\"}}" 2>/dev/null || true
}

# Число слоёв в истории образа (строки docker image history без заголовка).
history_layers() {   # history_layers <ref>
  _to 20 docker image history "$1" -q 2>/dev/null | grep -c .
}

# Запустить одноразовый контейнер из образа на порту VOTE_PORT, дождаться 200,
# вернуть тело страницы, затем снять контейнер. Всё foreground — без `&`.
# Порт освобождаем заранее, имя контейнера уникальное.
serve_and_fetch() {   # serve_and_fetch <image> [path]
  local img="$1" path="${2:-/}" name="lab1probe-$$-$RANDOM" i body=""
  docker rm -f "$name" >/dev/null 2>&1 || true
  docker run -d --name "$name" -p "$VOTE_PORT:80" "$img" >/dev/null 2>&1 || {
    docker rm -f "$name" >/dev/null 2>&1 || true
    return 1
  }
  for i in $(seq 1 20); do
    [ "$(http_code "$VOTE_PORT" "$path")" = "200" ] && break
    sleep 1
  done
  body="$(page_body "$VOTE_PORT" "$path")"
  docker rm -f "$name" >/dev/null 2>&1 || true
  printf '%s' "$body"
}

# git в каталоге репозитория студента (REPO задаётся окружением или ищется от workdir).
# По умолчанию берём клон example-voting-app внутри рабочей директории лабы.
: "${REPO:=$PWD/workdir/example-voting-app}"
git_in() { git -C "$REPO" "$@" 2>/dev/null; }
