# Контент Лаб 1: заголовок, задания, подсказки по контрактам, ярлыки контрактов.
# ${PROJECT}, ${CANARY}, ${IFRAME_URL}, ${VOTE_PORT}, ${RESULT_PORT},
# ${SIZE_BUDGET_PCT} подставляются из сида.

TITLE = "Лаб 1 · Контейнеры"
TERMINAL_HINT = ("git clone https://github.com/dockersamples/example-voting-app && "
                 "cd example-voting-app && "
                 "docker compose -p ${PROJECT} -f docker-compose.images.yml up -d")

TASKS = [
    {
        "id": "01",
        "title": "Задание 1. Запуск приложения",
        "body": "Поднять example-voting-app через docker compose в проекте ${PROJECT}. "
                "Пять сервисов (vote, result, worker, redis, db) должны быть запущены, "
                "vote отвечать на порту ${VOTE_PORT}, result — на ${RESULT_PORT}. Голос "
                "с формы vote должен дойти до базы: проголосовать и убедиться, что "
                "результат виден.",
        "checks": ["01.1", "01.2", "01.3", "01.4"],
    },
    {
        "id": "02",
        "title": "Задание 2. Образ и его слои",
        "body": "Скачать базовый образ vote (dockersamples/examplevotingapp_vote) и "
                "разобрать его. Образ должен присутствовать локально, а история сборки "
                "(docker image history) — показывать несколько слоёв. Зафиксировать "
                "размер образа: он станет точкой отсчёта для оптимизации в задании 4.",
        "checks": ["02.1", "02.2"],
    },
    {
        "id": "03",
        "title": "Задание 3. Кастомный образ vote",
        "body": "Собрать образ vote-custom поверх dockersamples/examplevotingapp_vote. "
                "Навесить на образ label lab1.canary=${CANARY}. В шаблон страницы vote "
                "добавить iframe с источником ${IFRAME_URL}. Запустить контейнер на порту "
                "${VOTE_PORT}: страница должна отдавать форму голосования, iframe с этим "
                "URL и токен ${CANARY}.",
        "checks": ["03.1", "03.2", "03.3"],
    },
    {
        "id": "04",
        "title": "Задание 4. Оптимизация образа",
        "body": "Собрать образ vote-opt с той же кастомизацией (iframe ${IFRAME_URL}, "
                "label lab1.canary=${CANARY}), но легче: применить multi-stage, alpine-базу "
                "или .dockerignore. Итоговый размер — не более ${SIZE_BUDGET_PCT}% от "
                "кастомного образа из задания 3. Контейнер обязан работать: отдавать "
                "страницу с iframe и токеном.",
        "checks": ["04.1", "04.2", "04.3"],
    },
    {
        "id": "05",
        "title": "Задание 5. Git: ветка, коммит, тег",
        "body": "Зафиксировать работу в git: создать ветку feature/lab1, добавить файлы "
                "кастомизации отдельным коммитом с сообщением в формате Conventional "
                "Commits (например feat(vote): ...) и навесить аннотированный тег с "
                "токеном ${CANARY} в сообщении.",
        "checks": ["05.1", "05.2", "05.3"],
    },
]

CHECK_LABELS = {
    "01.1": "Проект поднят",
    "01.2": "5 контейнеров Up",
    "01.3": "vote отвечает 200",
    "01.4": "result отвечает 200",
    "02.1": "Базовый образ скачан",
    "02.2": "История слоёв видна",
    "03.1": "Образ vote-custom собран",
    "03.2": "Canary в label и странице",
    "03.3": "iframe с нужным URL",
    "04.1": "Образ vote-opt работает",
    "04.2": "Размер в пределах бюджета",
    "04.3": "Canary и iframe сохранены",
    "05.1": "Ветка feature/lab1",
    "05.2": "Conventional Commit",
    "05.3": "Аннотированный тег с canary",
}

HINTS = {
    "01.1": "Подними проект с фиксированным именем: docker compose -p ${PROJECT} "
            "-f docker-compose.images.yml up -d — так контейнеры варианта видны проверке.",
    "01.2": "Дождись, пока все пять поднимутся: docker compose -p ${PROJECT} ps. "
            "redis и db стартуют первыми (healthcheck), от них зависят остальные.",
    "01.3": "vote публикуется на ${VOTE_PORT}. Проверь: curl -s -o /dev/null -w '%{http_code}' "
            "http://localhost:${VOTE_PORT}/ должен вернуть 200.",
    "01.4": "result публикуется на ${RESULT_PORT}. Если 200 не приходит — смотри "
            "docker compose -p ${PROJECT} logs result.",
    "02.1": "Образ должен лежать локально: docker pull dockersamples/examplevotingapp_vote "
            "(compose с -f docker-compose.images.yml подтягивает его сам).",
    "02.2": "docker image history dockersamples/examplevotingapp_vote покажет слои. "
            "Проверка ждёт, что строк-слоёв больше одной.",
    "03.1": "Собери из Dockerfile.custom: docker build -f Dockerfile.custom -t vote-custom:v1 . "
            "FROM dockersamples/examplevotingapp_vote — не пересобирай приложение с нуля.",
    "03.2": "LABEL lab1.canary=\"${CANARY}\" в Dockerfile.custom. Тот же токен ${CANARY} "
            "впиши в custom_index.html — проверка ищет его в отданной странице.",
    "03.3": "COPY custom_index.html поверх шаблона vote (внутри образа он в "
            "templates/index.html). В странице — <iframe src=\"${IFRAME_URL}\" ...>.",
    "04.1": "vote-opt должен работать так же: запусти на ${VOTE_PORT} и получи 200. "
            "Оптимизация не должна ломать приложение.",
    "04.2": "Сравни docker image inspect ...Size у vote-opt и vote-custom. Цель — "
            "vote-opt ≤ ${SIZE_BUDGET_PCT}% от vote-custom. Помогают alpine-база, "
            "multi-stage, .dockerignore.",
    "04.3": "Кастомизация обязана уцелеть после оптимизации: label lab1.canary=${CANARY}, "
            "iframe ${IFRAME_URL} и токен ${CANARY} — в отданной странице vote-opt.",
    "05.1": "git checkout -b feature/lab1. Проверка ищет ветку с префиксом feature/lab1 "
            "в git-истории (merge-base с рабочей веткой).",
    "05.2": "Коммит с файлами кастомизации: git commit -m \"feat(vote): custom page with "
            "iframe\". Заголовок — по Conventional Commits: type(scope): описание.",
    "05.3": "git tag -a <имя> -m \"...${CANARY}...\" — аннотированный (не lightweight) тег, "
            "токен ${CANARY} должен быть в сообщении тега.",
}
