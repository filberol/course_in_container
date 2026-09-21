# manifests/

Сюда вы кладёте свои манифесты Kubernetes (`*.yaml`).

Готовых решений здесь нет и не будет — в этом смысл. `make check` проверяет
результат (контракт задания), а не конкретный текст манифеста. Способ выбираете вы.

Ориентир по объёму: Deployment/StatefulSet для пяти сервисов, Service для сетевого
доступа, ConfigMap/Secret для конфигурации, PVC для PostgreSQL. Имена и label —
на ваше усмотрение, но `make check` ожидает селектор `app=<vote|result|worker|redis|db>`.
