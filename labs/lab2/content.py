# Контент Лаб 2: заголовок, задания, подсказки по контрактам, ярлыки контрактов.
# ${NS}, ${PVC_SIZE}, ${REPLICAS_VOTE}, ${CANARY}, ${MAX_UNAVAIL} подставляются из сида.

TITLE = "Лаб 2 · Оркестрация"
TERMINAL_HINT = "kind create cluster --name lab2 && kubectl apply -f manifests/"

TASKS = [
    {
        "id": "01",
        "title": "Задание 1. Развёртывание приложения",
        "body": "Поднять пять сервисов (vote, result, worker, redis, db) в namespace "
                "${NS}. Пароль PostgreSQL хранить в Secret и подавать в контейнер через "
                "secretKeyRef, а не открытым текстом. Service базы должен называться "
                "ровно «db», Redis — ровно «redis»: приложение ходит по этим именам.",
        "checks": ["01.1", "01.2", "01.3", "01.4"],
    },
    {
        "id": "02",
        "title": "Задание 2. Состояние и data gravity",
        "body": "База — с PersistentVolumeClaim размера ${PVC_SIZE}. Redis оставить "
                "эфемерным, без тома. Данные должны пережить рестарт пода БД.",
        "checks": ["02.1", "02.2", "02.3"],
    },
    {
        "id": "03",
        "title": "Задание 3. Масштабирование и самовосстановление",
        "body": "Задать vote ${REPLICAS_VOTE} реплик. Удаление одного пода не должно "
                "ронять сервис: контроллер поднимет замену, а Service продолжит отвечать "
                "и балансировать по нескольким подам.",
        "checks": ["03.1", "03.2", "03.3"],
    },
    {
        "id": "04",
        "title": "Задание 4. Health-пробы и canary",
        "body": "Настроить readinessProbe и livenessProbe на vote и result. На vote "
                "добавить label lab2.canary=${CANARY} и переменную окружения CANARY=${CANARY}.",
        "checks": ["04.1", "04.2", "04.3"],
    },
    {
        "id": "05",
        "title": "Задание 5. Rolling update",
        "body": "Задать стратегию выката vote с maxUnavailable=${MAX_UNAVAIL}. Проверка "
                "сама выкатит новую ревизию и убедится, что доступность не падает ниже "
                "${REPLICAS_VOTE} − ${MAX_UNAVAIL}, а откат возвращает предыдущую.",
        "checks": ["05.1", "05.2", "05.3", "05.4"],
    },
]

CHECK_LABELS = {
    "01.1": "NameSpace",
    "01.2": "Сервисы Ready",
    "01.3": "Голосование",
    "01.4": "Пароль через Secret",
    "02.1": "PVC нужного размера",
    "02.2": "Данные переживают рестарт",
    "02.3": "Redis без тома",
    "03.1": "Число реплик vote",
    "03.2": "Самовосстановление",
    "03.3": "Балансировка",
    "04.1": "Пробы",
    "04.2": "vote отвечает 200",
    "04.3": "Canary в label и env",
    "05.1": "maxUnavailable",
    "05.2": "Выкат без простоя",
    "05.3": "≥2 ревизии в истории",
    "05.4": "Откат работает",
}

HINTS = {
    "01.1": "Все объекты — в namespace ${NS}: создай его (kind: Namespace) или задавай "
            "metadata.namespace у каждого.",
    "01.2": "Начни с redis и db — от них зависят остальные. Каждому Deployment + Service; "
            "все поды должны стать Ready.",
    "01.3": "worker и result ходят в db с паролем postgres и в redis по имени redis. "
            "Проверка голосует и ждёт, что голос дойдёт до БД.",
    "01.4": "Secret (stringData: POSTGRES_PASSWORD: postgres) → в db через "
            "env.valueFrom.secretKeyRef, не открытым текстом.",
    "02.1": "PVC: accessModes [ReadWriteOnce], requests.storage ${PVC_SIZE}; смонтируй "
            "в /var/lib/postgresql/data.",
    "02.2": "Postgres не любит непустой каталог данных — задай env PGDATA на подкаталог, "
            "например /var/lib/postgresql/data/pgdata.",
    "02.3": "У redis тома быть не должно — это и есть контраст stateful/stateless.",
    "03.1": "spec.replicas: ${REPLICAS_VOTE} у Deployment vote.",
    "03.2": "Ничего настраивать не нужно: Deployment сам поднимет замену удалённому поду "
            "до ${REPLICAS_VOTE}.",
    "03.3": "Балансировку видно только изнутри кластера через ClusterIP-имя vote — "
            "проверка шлёт 24 запроса из временного пода.",
    "04.1": "vote и result слушают HTTP на порту 80 — httpGet path: / port: 80 подойдёт "
            "для обеих проб.",
    "04.2": "readinessProbe должна реально отдавать 200 на / :80 — иначе под не станет "
            "Ready и Endpoints сервиса будет пуст.",
    "04.3": "lab2.canary — label в spec.template.metadata.labels, CANARY — env контейнера. "
            "Значение одно, из сида: ${CANARY}.",
    "05.1": "strategy.type: RollingUpdate, rollingUpdate.maxUnavailable: ${MAX_UNAVAIL}, "
            "maxSurge: 1.",
    "05.2": "maxUnavailable=0 — не выключаем ни один под, пока новый не готов: выкат без "
            "просадки, за счёт maxSurge.",
    "05.3": "Проверка сама делает rollout restart — вторая ревизия появится, если стратегия "
            "выката задана корректно.",
    "05.4": "kubectl rollout undo вернёт предыдущую ревизию — это работает из коробки при "
            "корректном Deployment.",
}
