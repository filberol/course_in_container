# Рабочая директория — Лаб 1

Здесь ты строишь решение. Проверки смотрят на состояние Docker (образы, контейнеры,
отданные страницы) и на git-историю, а не на текст файлов — раскладку можно менять.

Клонируй приложение и подними его (в терминале ниже):

    git clone https://github.com/dockersamples/example-voting-app
    cd example-voting-app
    docker compose -p ${PROJECT} -f docker-compose.images.yml up -d

Твой вариант (из сида):

    PROJECT          ${PROJECT}
    CANARY           ${CANARY}
    IFRAME_URL       ${IFRAME_URL}
    порт vote        ${VOTE_PORT}
    порт result      ${RESULT_PORT}
    бюджет размера   ${SIZE_BUDGET_PCT}% от кастомного образа

Заготовки для заданий 3–4 — `Dockerfile.custom` и `custom_index.html` (пока только
комментарии-подсказки). Клонированный репозиторий git — тоже под рукой: ветку, коммит
и тег из задания 5 делай в нём.
