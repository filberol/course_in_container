# Контент Лаб 2: заголовок, задания, подсказки, ярлыки контрактов.
# ${NS}, ${PVC_SIZE}, ${REPLICAS_VOTE}, ${CANARY}, ${MAX_UNAVAIL} подставляются из сида.

TITLE = "Лаб 2 · Оркестрация"
TERMINAL_HINT = "cd lab2 && kind create cluster --name lab2 && kubectl apply -f manifests/"

FILES = ["db.yaml", "redis.yaml", "vote.yaml", "result.yaml", "worker.yaml"]

TASKS = [
    {
        "id": "01",
        "title": "Задание 1. Развёртывание приложения",
        "body": "Подними пять сервисов (vote, result, worker, redis, db) в namespace "
                "${NS}. Пароль PostgreSQL храни в Secret и подавай в контейнер через "
                "secretKeyRef, а не открытым текстом. Service базы должен называться "
                "ровно «db», Redis — ровно «redis»: приложение ходит по этим именам.",
        "hints": [
            "Начни с redis и db — от них зависят остальные. Каждому: Deployment + Service.",
            "Secret (stringData: POSTGRES_PASSWORD: postgres) → в db через "
            "env.valueFrom.secretKeyRef. worker и result подключаются с паролем postgres.",
            "На каждом объекте label app: <имя>. По этим label работают Service-селекторы "
            "и проверки.",
        ],
        "checks": ["01.1", "01.2", "01.3", "01.4"],
    },
    {
        "id": "02",
        "title": "Задание 2. Состояние и data gravity",
        "body": "База — с PersistentVolumeClaim размера ${PVC_SIZE}. Redis оставь "
                "эфемерным, без тома. Данные должны пережить рестарт пода БД.",
        "hints": [
            "PVC (accessModes: [ReadWriteOnce], requests.storage: ${PVC_SIZE}), "
            "смонтируй в /var/lib/postgresql/data.",
            "Postgres не любит непустой каталог данных — задай env PGDATA "
            "на подкаталог, например /var/lib/postgresql/data/pgdata.",
            "У redis тома быть не должно — это и есть контраст stateful/stateless.",
        ],
        "checks": ["02.1", "02.2", "02.3"],
    },
    {
        "id": "03",
        "title": "Задание 3. Масштабирование и самовосстановление",
        "body": "Задай vote ${REPLICAS_VOTE} реплик. Удаление одного пода не должно "
                "ронять сервис: контроллер поднимет замену, а Service продолжит отвечать "
                "и балансировать по нескольким подам.",
        "hints": [
            "spec.replicas: ${REPLICAS_VOTE} у Deployment vote.",
            "Балансировку видно только изнутри кластера через ClusterIP-имя vote — "
            "проверка сама шлёт туда 24 запроса из временного пода.",
        ],
        "checks": ["03.1", "03.2", "03.3"],
    },
    {
        "id": "04",
        "title": "Задание 4. Health-пробы и canary",
        "body": "Настрой readinessProbe и livenessProbe на vote и result. На vote добавь "
                "label lab2.canary=${CANARY} и переменную окружения CANARY=${CANARY}.",
        "hints": [
            "vote и result слушают HTTP на порту 80 — httpGet path: / port: 80 подойдёт "
            "для обеих проб.",
            "lab2.canary — это label в spec.template.metadata.labels, а CANARY — env "
            "контейнера. Значение одно и то же, из сида.",
        ],
        "checks": ["04.1", "04.2", "04.3"],
    },
    {
        "id": "05",
        "title": "Задание 5. Rolling update",
        "body": "Задай стратегию выката vote с maxUnavailable=${MAX_UNAVAIL}. Проверка "
                "сама выкатит новую ревизию и убедится, что доступность не падает ниже "
                "${REPLICAS_VOTE} − ${MAX_UNAVAIL}, а откат возвращает предыдущую.",
        "hints": [
            "strategy.type: RollingUpdate, rollingUpdate.maxUnavailable: ${MAX_UNAVAIL}, "
            "maxSurge: 1.",
            "maxUnavailable=0 значит «ни один под не выключаем, пока новый не готов» — "
            "выкат без просадки, но нужен запас по ресурсам (за счёт maxSurge).",
        ],
        "checks": ["05.1", "05.2", "05.3", "05.4"],
    },
]

CHECK_LABELS = {
    "01.1": "namespace из сида",
    "01.2": "пять сервисов Ready",
    "01.3": "сквозной путь голоса",
    "01.4": "пароль БД через Secret",
    "02.1": "PVC нужного размера",
    "02.2": "данные переживают рестарт",
    "02.3": "redis без тома",
    "03.1": "нужное число реплик vote",
    "03.2": "самовосстановление",
    "03.3": "балансировка по ≥2 подам",
    "04.1": "readiness + liveness пробы",
    "04.2": "vote отвечает 200",
    "04.3": "canary в label и env",
    "05.1": "maxUnavailable из сида",
    "05.2": "выкат без простоя",
    "05.3": "≥2 ревизии в истории",
    "05.4": "откат работает",
}
