#!/usr/bin/env python3
"""Детерминированный сид Лаб 3: номер ИСУ -> параметры варианта конвейера.

Механика открытая. Секрета в сиде нет — привязка работы к личности держится
на canary-токене в артефакте (тег/лейбл образа или trailer коммита) и повторном
прогоне на защите, а не на скрытности параметров. Открытость нужна, чтобы студент
мог сам пересчитать свой вариант.

Использование:
    seed.py --isu 123456            таблица параметров
    seed.py --isu 123456 --env      строки KEY=value для source
    seed.py --isu 123456 --get TAG_SCHEME   одно значение (для Makefile/скриптов)
"""
import argparse
import hashlib
import sys

# Публичная соль курса. Меняется по семестрам, чтобы варианты не переносились между потоками.
SALT = "ipoiiur-lab3-2026a"


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
        # canary-токен — якорь личности. Студент проставляет его как OCI-лейбл образа
        # (org.opencontainers.image.revision-подобный) ИЛИ trailer в коммите релиза.
        "CANARY": f"k3-{(h >> 32) & 0xFFFFFF:06x}",
        # имя образа приложения в реестре (owner-часть детерминирована сидом)
        "IMAGE": f"vote-{isu4}",
        # outcome: схема тегирования артефакта, которую конвейер обязан реализовать
        #   semver — тег вида vMAJOR.MINOR.PATCH из релизного тега git
        #   sha    — короткий commit-sha (трассируемость)
        #   branch — имя ветки как подвижная ссылка
        "TAG_SCHEME": pick(["semver", "sha", "branch"], 8),
        # outcome: обязательный набор DevSecOps-сканеров-гейтов сверх Trivy.
        # Trivy (образ) присутствует всегда; сид добавляет второй сканер-гейт.
        #   sca      — сканер зависимостей (например, trivy fs / grype / osv)
        #   sast     — статический анализ кода (например, semgrep)
        #   secrets  — поиск секретов в истории (например, gitleaks)
        "SEC_GATE": pick(["sca", "sast", "secrets"], 16),
        # outcome: среда промоушена, куда конвейер продвигает прошедший артефакт
        "PROMOTE_ENV": pick(["stage", "preprod", "qa"], 24),
        # порог допуска сканера образов: сборка валится начиная с этого уровня
        "FAIL_ON": pick(["CRITICAL", "HIGH"], 32),
        "BREAKFIX_ID": pick([1, 2, 3, 4, 5, 6], 40),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="Параметры варианта Лаб 3 по номеру ИСУ")
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
