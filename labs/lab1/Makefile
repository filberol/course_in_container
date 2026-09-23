# Лаб 1 — harness. Хостовые зависимости ставит `make setup` из labs/.
# Тренажёр — глобальный: `make trainer` из labs/. Здесь только цели по варианту.
#   make check ISU=123456

ISU ?=

PROJECT := $(shell python3 seed.py --isu $(ISU) --get PROJECT 2>/dev/null)

.PHONY: help seed check check-suite clean

help:
	@echo "Цели (ISU=<ису>):"
	@echo "  make seed                  параметры варианта"
	@echo "  make check                 все контракты"
	@echo "  make check-suite SUITE=NN_name   один блок контрактов"
	@echo "  make clean                 снять compose-проект $(PROJECT)"

seed:
	@python3 seed.py --isu $(ISU)

check:
	@test -n "$(ISU)" || { echo "нужен ISU=<ису>"; exit 2; }
	@set -a; eval "$$(python3 seed.py --isu $(ISU) --env)"; set +a; \
	 bats --tap --timing checks/ | tee .scorecard.tap; \
	 if grep -q '^not ok' .scorecard.tap; then echo "== ЕСТЬ КРАСНОЕ =="; false; else echo "== ДОПУЩЕН =="; fi

# контракты одного задания (быстро): make check-suite SUITE=03_custom ISU=<ису>
check-suite:
	@test -n "$(ISU)" || { echo "нужен ISU=<ису>"; exit 2; }
	@set -a; eval "$$(python3 seed.py --isu $(ISU) --env)"; set +a; \
	 bats --tap --timing checks/$(SUITE).bats | tee .scorecard.tap

clean:
	-docker compose -p $(PROJECT) down -v
