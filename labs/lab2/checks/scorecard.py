#!/usr/bin/env python3
"""Собирает TAP-вывод bats в scorecard.json и выносит решение по воротам допуска.

Ворота = все контракты зелёные. Балл здесь НЕ выставляется: scorecard лишь
подтверждает «работает и результаты настоящие» и служит картой для защиты.
"""
import argparse
import datetime
import json
import re
import sys

TAP = re.compile(r"^(ok|not ok)\s+\d+\s+(.*)$")


def parse(stream):
    suites = {}
    for line in stream:
        line = line.rstrip("\n")
        m = TAP.match(line)
        if not m:
            continue
        ok = m.group(1) == "ok"
        name = m.group(2).strip()
        suite = name.split(".", 1)[0] if "." in name.split()[0] else "misc"
        s = suites.setdefault(suite, {"pass": 0, "fail": 0, "failed": []})
        if ok:
            s["pass"] += 1
        else:
            s["fail"] += 1
            s["failed"].append(name)
    return suites


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--isu", required=True)
    ap.add_argument("--out", default="scorecard.json")
    args = ap.parse_args()

    suites = parse(sys.stdin)
    total_pass = sum(s["pass"] for s in suites.values())
    total_fail = sum(s["fail"] for s in suites.values())
    admitted = total_fail == 0 and total_pass > 0

    card = {
        "isu": args.isu,
        "generated_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "totals": {"pass": total_pass, "fail": total_fail},
        "suites": suites,
        "gate": "admitted" if admitted else "blocked",
    }
    with open(args.out, "w") as f:
        json.dump(card, f, ensure_ascii=False, indent=2)

    mark = "ДОПУЩЕН" if admitted else "ЗАБЛОКИРОВАН"
    print(f"\n[{mark}] пройдено {total_pass}, провалено {total_fail} -> {args.out}")
    for suite, s in sorted(suites.items()):
        for name in s["failed"]:
            print(f"  ✗ {name}")
    return 0 if admitted else 1


if __name__ == "__main__":
    raise SystemExit(main())
