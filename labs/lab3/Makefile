# Лаб 3 — harness. Хостовые зависимости ставит `make setup` из labs/.
# Тренажёр — глобальный: `make trainer` из labs/. Здесь только цели по варианту.
#   make check ISU=123456
#
# Субстрат — git-репозиторий с CI-конвейером (кластера/kubectl нет). Проверки
# СТАТИЧЕСКИЕ: парсинг .github/workflows/*.yml, git-история, наличие скриптов.
# По умолчанию проверяется каталог WORKDIR (для тренажёра — workdir/).

ISU ?=
WORKDIR ?= workdir

.PHONY: help seed check check-suite clean

help:
	@echo "Цели (ISU=<ису>):"
	@echo "  make seed                        параметры варианта"
	@echo "  make check                       все контракты"
	@echo "  make check-suite SUITE=NN_name   один блок контрактов"
	@echo "  make clean                       убрать артефакты прогона"

seed:
	@python3 seed.py --isu $(ISU)

check:
	@test -n "$(ISU)" || { echo "нужен ISU=<ису>"; exit 2; }
	@set -a; eval "$$(python3 seed.py --isu $(ISU) --env)"; export WORKDIR="$(WORKDIR)"; set +a; \
	 bats --tap --timing checks/ | tee .scorecard.tap; \
	 if grep -q '^not ok' .scorecard.tap; then echo "== ЕСТЬ КРАСНОЕ =="; false; else echo "== ДОПУЩЕН =="; fi

# контракты одного задания (быстро): make check-suite SUITE=03_devsecops ISU=<ису>
check-suite:
	@test -n "$(ISU)" || { echo "нужен ISU=<ису>"; exit 2; }
	@set -a; eval "$$(python3 seed.py --isu $(ISU) --env)"; export WORKDIR="$(WORKDIR)"; set +a; \
	 bats --tap --timing checks/$(SUITE).bats | tee .scorecard.tap

clean:
	-rm -f .scorecard.tap
