#!/usr/bin/env python3
"""Детерминированный сид Лаб 2: номер ИСУ -> параметры варианта.

Механика открытая. Секрета в сиде нет — привязка работы к личности держится
на canary-токене в артефакте и повторном прогоне на защите, а не на скрытности
параметров. Открытость нужна, чтобы студент мог сам пересчитать свой вариант.

Использование:
    seed.py --isu 123456            таблица параметров
    seed.py --isu 123456 --env      строки KEY=value для source
    seed.py --isu 123456 --get NS   одно значение (для Makefile/скриптов)
"""
import argparse
import hashlib
import sys

# Публичная соль курса. Меняется по семестрам, чтобы варианты не переносились между потоками.
SALT = "ipoiiur-lab2-2026a"


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
        "NS": f"vote-{isu4}",
        "CANARY": f"k2-{(h >> 32) & 0xFFFFFF:06x}",
        "REPLICAS_VOTE": pick([3, 4, 5], 8),
        "PVC_SIZE": pick(["512Mi", "1Gi", "2Gi"], 16),
        "MAX_UNAVAIL": pick([0, 1], 24),
        "BREAKFIX_ID": pick([1, 2, 3, 4, 5, 6], 40),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="Параметры варианта Лаб 2 по номеру ИСУ")
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
