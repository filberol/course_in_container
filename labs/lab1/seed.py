#!/usr/bin/env python3
"""Детерминированный сид Лаб 1: номер ИСУ -> параметры варианта.

Механика открытая. Секрета в сиде нет — привязка работы к личности держится
на canary-токене в артефакте и повторном прогоне на защите, а не на скрытности
параметров. Открытость нужна, чтобы студент мог сам пересчитать свой вариант.

Использование:
    seed.py --isu 123456                таблица параметров
    seed.py --isu 123456 --env          строки KEY=value для source
    seed.py --isu 123456 --get PROJECT  одно значение (для Makefile/скриптов)
"""
import argparse
import hashlib
import sys

# Публичная соль курса. Меняется по семестрам, чтобы варианты не переносились между потоками.
SALT = "ipoiiur-lab1-2026a"

# Источники для встраиваемого iframe (outcome-параметр: значение видно в отданной странице).
IFRAME_URLS = [
    "https://12factor.net/",
    "https://docs.docker.com/get-started/",
    "https://semver.org/lang/ru/",
    "https://www.conventionalcommits.org/ru/v1.0.0/",
    "https://keepachangelog.com/ru/1.0.0/",
    "https://git-scm.com/doc",
    "https://docs.docker.com/compose/",
    "https://opencontainers.org/",
]


def _digest(isu: str) -> int:
    raw = hashlib.sha256(f"{isu}:{SALT}".encode()).digest()
    return int.from_bytes(raw, "big")


def params(isu: str) -> dict:
    h = _digest(isu)

    def pick(seq, shift):
        return seq[(h >> shift) % len(seq)]

    isu4 = f"{h & 0xFFFF:04x}"
    return {
        "ISU": isu,
        # Имя compose-проекта: изолирует контейнеры/сеть варианта, служит статус-namespace.
        "PROJECT": f"vote-{isu4}",
        # Canary-токен (якорь личности): метка образа + переменная окружения + в тексте страницы.
        "CANARY": f"d1-{(h >> 32) & 0xFFFFFF:06x}",
        # Outcome-параметр: URL, который обязан появиться в iframe отданной страницы vote.
        "IFRAME_URL": pick(IFRAME_URLS, 8),
        # Порты публикации на хосте — контракт приложения, одинаковы у всех.
        "VOTE_PORT": 8080,
        "RESULT_PORT": 8081,
        # Бюджет размера: оптимизированный образ должен быть не тяжелее этой доли от кастомного.
        "SIZE_BUDGET_PCT": pick([60, 70, 80], 16),
        "BREAKFIX_ID": pick([1, 2, 3, 4, 5, 6], 40),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="Параметры варианта Лаб 1 по номеру ИСУ")
    ap.add_argument("--isu", required=True, help="номер ИСУ студента")
    ap.add_argument("--env", action="store_true", help="вывод KEY=value для source")
    ap.add_argument("--get", metavar="KEY", help="напечатать одно значение")
    args = ap.parse_args()

    p = params(args.isu)

    if args.get:
        if args.get not in p:
            print(f"неизвестный ключ: {args.get}", file=sys.stderr)
            return 2
        print(p[args.get])
        return 0

    if args.env:
        for k, v in p.items():
            print(f"{k}={v}")
        return 0

    width = max(len(k) for k in p)
    for k, v in p.items():
        print(f"{k.ljust(width)}  {v}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
