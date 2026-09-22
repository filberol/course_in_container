# Лаб 2 — harness. Хостовые зависимости ставит `make setup` из labs/.
# Тренажёр — глобальный: `make trainer` из labs/. Здесь только цели по варианту.
#   make check ISU=123456

ISU ?=
CLUSTER ?= lab2

NS := $(shell python3 seed.py --isu $(ISU) --get NS 2>/dev/null)

.PHONY: help seed check check-suite render selftest clean

help:
	@echo "Цели (ISU=<ису>):"
	@echo "  make seed                  параметры варианта"
	@echo "  make check                 все контракты"
	@echo "  make check-suite SUITE=NN_name   один блок контрактов"
	@echo "  make render                [преподаватель] отрендерить эталон варианта"
	@echo "  make selftest              [преподаватель] эталон + apply + все контракты"
	@echo "  make clean                 удалить kind-кластер $(CLUSTER)"

seed:
	@python3 seed.py --isu $(ISU)

check:
	@test -n "$(ISU)" || { echo "нужен ISU=<ису>"; exit 2; }
	@set -a; eval "$$(python3 seed.py --isu $(ISU) --env)"; set +a; \
	 bats --tap --timing checks/ | tee .scorecard.tap; \
	 grep -q '^not ok' .scorecard.tap && { echo "== ЕСТЬ КРАСНОЕ =="; false; } || echo "== ДОПУЩЕН =="

# контракты одного задания (быстро): make check-suite SUITE=03_scaling ISU=<ису>
check-suite:
	@test -n "$(ISU)" || { echo "нужен ISU=<ису>"; exit 2; }
	@set -a; eval "$$(python3 seed.py --isu $(ISU) --env)"; set +a; \
	 bats --tap --timing checks/$(SUITE).bats | tee .scorecard.tap

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
