# Глобальный workspace лаб. Один тренажёр обслуживает все labs/labN/.
# Хостовые зависимости: kind, kubectl, bats, jq, python3, ttyd, coreutils.
.PHONY: setup trainer

# установка хостовых зависимостей + venv тренажёра
setup:
	@bash trainer/setup.sh

# глобальный тренажёр (страница + терминал); лабу выбираешь на странице
trainer:
	@bash trainer/serve.sh
