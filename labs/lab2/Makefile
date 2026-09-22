# Лаб 2 — harness. Хостовые зависимости: kind, kubectl, bats, jq, python3, ttyd, coreutils.
# Установить всё: make setup.  Задавайте свой номер ИСУ:  make check ISU=123456

ISU ?=
CLUSTER ?= lab2

ifndef ISU
  $(warning ISU не задан. Пример: make check ISU=123456)
endif

NS := $(shell python3 seed.py --isu $(ISU) --get NS 2>/dev/null)

.PHONY: help setup seed check check-suite evidence grade render selftest trainer clean

help:
	@echo "Цели:"
	@echo "  make setup                установить хостовые зависимости + venv"
	@echo "  make trainer              запустить страницу-тренажёр (+ терминал)"
	@echo "  make seed        ISU=<ису> параметры варианта"
	@echo "  make check       ISU=<ису> все контракты"
	@echo "  make check-suite SUITE=NN_name ISU=<ису>  один блок контрактов"
	@echo "  make evidence    ISU=<ису> снимок состояния + хеш E"
	@echo "  make grade       ISU=<ису> [преподаватель] повтор + вопросы + break-fix"
	@echo "  make clean                 удалить kind-кластер $(CLUSTER)"

# установка хостовых зависимостей (mac: brew) + venv тренажёра
setup:
	@bash weblab/setup.sh

seed:
	@python3 seed.py --isu $(ISU)

check:
	@test -n "$(ISU)" || { echo "нужен ISU=<ису>"; exit 2; }
	@eval $$(python3 seed.py --isu $(ISU) --env); \
	 export NS CANARY REPLICAS_VOTE PVC_SIZE MAX_UNAVAIL BREAKFIX_ID; \
	 bats --tap --timing checks/ | tee .scorecard.tap; \
	 python3 checks/scorecard.py --isu $(ISU) < .scorecard.tap

# контракты одного задания (быстро): make check-suite SUITE=03_scaling ISU=<ису>
check-suite:
	@test -n "$(ISU)" || { echo "нужен ISU=<ису>"; exit 2; }
	@eval $$(python3 seed.py --isu $(ISU) --env); \
	 export NS CANARY REPLICAS_VOTE PVC_SIZE MAX_UNAVAIL BREAKFIX_ID; \
	 bats --tap --timing checks/$(SUITE).bats | tee .scorecard.tap

evidence:
	@test -n "$(ISU)" || { echo "нужен ISU=<ису>"; exit 2; }
	@bash evidence/collect.sh $(ISU)

# Прогон на машине преподавателя: свежий кластер, применить закоммиченные манифесты,
# повторить контракты, затем персональные вопросы и вброс сбоя.
grade:
	@test -n "$(ISU)" || { echo "нужен ISU=<ису>"; exit 2; }
	kubectl apply -f manifests/
	@$(MAKE) --no-print-directory check ISU=$(ISU)
	@echo "==== персональные вопросы ===="
	@python3 defense/questions.py --isu $(ISU)
	@echo "==== live break-fix ===="
	@python3 defense/breakfix.py --isu $(ISU)

# [преподаватель] отрендерить эталонные манифесты варианта из solution/manifests
render:
	@test -n "$(ISU)" || { echo "нужен ISU=<ису>"; exit 2; }
	python3 solution/render.py --isu $(ISU)

# [преподаватель] самопроверка harness: применить эталон варианта и прогнать контракты
selftest: render
	kubectl apply -f solution/rendered/
	@$(MAKE) --no-print-directory check ISU=$(ISU)

# тренажёр на хосте: страница-валидатор + встроенный терминал (кластер поднимаешь сам)
trainer:
	bash weblab/serve.sh

clean:
	-kind delete cluster --name $(CLUSTER)
