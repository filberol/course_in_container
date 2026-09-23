# Рабочая директория — Лаб 4 (капстоун)

Здесь ты строишь решение. Раскладка свободная (проверки смотрят на состояние
кластера и на артефакты-исходы, а не на конкретный текст HCL) — структуру можно
менять под себя. Ниже — заготовки с подсказками.

Поднять и применить (в терминале ниже):

    terraform init
    terraform validate
    terraform plan
    terraform apply
    kubectl config use-context kind-${CLUSTER}

Дерево заготовок:

    main.tf              # провайдеры, kind-кластер ${CLUSTER}, namespace ${NS}, сервисы
    ansible/site.yml     # идемпотентный playbook (модули, не shell)
    ansible/inventory.ini # инвентарь (localhost для kubernetes.core)
    grafana/dashboard.json # дашборд с панелью vote и тегом canary=${CANARY}
    slo.yaml             # SLI/SLO vote, бюджет ошибок, blast radius
    docs/incident.md     # разбор инцидента: симптом -> гипотеза -> причина
    docs/c4.md           # C4 Context и Container (Mermaid)
    docs/adr/            # ADR в каноническом формате (минимум два)

Порядок задач: 1) terraform up · 2) идемпотентность и дрейф · 3) Ansible ·
4) наблюдаемость и разбор инцидента · 5) SLO и бюджет ошибок · 6) ADR и C4.
