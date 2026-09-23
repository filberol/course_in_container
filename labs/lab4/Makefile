# Лаб 4 — harness (капстоун). Хостовые зависимости ставит `make setup` из labs/.
# Тренажёр — глобальный: `make trainer` из labs/. Здесь только цели по варианту.
#   make check ISU=123456

ISU ?=
CLUSTER := $(shell python3 seed.py --isu $(ISU) --get CLUSTER 2>/dev/null)

NS := $(shell python3 seed.py --isu $(ISU) --get NS 2>/dev/null)

.PHONY: help seed check check-suite clean

help:
	@echo "Цели (ISU=<ису>):"
	@echo "  make seed                  параметры варианта"
	@echo "  make check                 все контракты"
	@echo "  make check-suite SUITE=NN_name   один блок контрактов"
	@echo "  make clean                 удалить kind-кластер $(CLUSTER)"

seed:
	@python3 seed.py --isu $(ISU)

check:
	@test -n "$(ISU)" || { echo "нужен ISU=<ису>"; exit 2; }
	@set -a; eval "$$(python3 seed.py --isu $(ISU) --env)"; set +a; \
	 bats --tap --timing checks/ | tee .scorecard.tap; \
	 if grep -q '^not ok' .scorecard.tap; then echo "== ЕСТЬ КРАСНОЕ =="; false; else echo "== ДОПУЩЕН =="; fi

# контракты одного задания (быстро): make check-suite SUITE=02_drift ISU=<ису>
check-suite:
	@test -n "$(ISU)" || { echo "нужен ISU=<ису>"; exit 2; }
	@set -a; eval "$$(python3 seed.py --isu $(ISU) --env)"; set +a; \
	 bats --tap --timing checks/$(SUITE).bats | tee .scorecard.tap

clean:
	-kind delete cluster --name $(CLUSTER)
