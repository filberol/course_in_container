# Лаб 2 — harness. Требует: kind, kubectl, python3, bats, jq.
# Задавайте свой номер ИСУ:  make check ISU=123456

ISU ?=
CLUSTER ?= lab2

ifndef ISU
  $(warning ISU не задан. Пример: make check ISU=123456)
endif

NS := $(shell python3 seed.py --isu $(ISU) --get NS 2>/dev/null)

.PHONY: help seed check evidence grade render selftest clean

help:
	@echo "Цели:"
	@echo "  make seed     ISU=<ису>   параметры варианта"
	@echo "  make check    ISU=<ису>   прогнать контракты заданий (тренажёр)"
	@echo "  make evidence ISU=<ису>   снять состояние кластера, посчитать хеш E"
	@echo "  make grade    ISU=<ису>   [преподаватель] повтор + вопросы + break-fix"
	@echo "  make clean                удалить kind-кластер $(CLUSTER)"

seed:
	@python3 seed.py --isu $(ISU)

check:
	@test -n "$(ISU)" || { echo "нужен ISU=<ису>"; exit 2; }
	@eval $$(python3 seed.py --isu $(ISU) --env); \
	 export NS CANARY REPLICAS_VOTE PVC_SIZE MAX_UNAVAIL BREAKFIX_ID; \
	 bats --tap checks/ | tee .scorecard.tap | python3 checks/scorecard.py --isu $(ISU)

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

clean:
	-kind delete cluster --name $(CLUSTER)
