#!/usr/bin/env python3
"""[преподаватель] Рендерит эталонные манифесты варианта из solution/manifests.

Шаблоны параметризованы сидом (${NS}, ${CANARY}, ${REPLICAS_VOTE}, ${PVC_SIZE},
${MAX_UNAVAIL}). Эталон — ответ к работе и средство самопроверки harness;
в шаблон, раздаваемый студентам, каталог solution/ не входит.
"""
import argparse
import glob
import os
import string
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
from seed import params  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--isu", required=True)
    ap.add_argument("--src", default=os.path.join(HERE, "manifests"))
    ap.add_argument("--out", default=os.path.join(HERE, "rendered"))
    args = ap.parse_args()

    mapping = {k: str(v) for k, v in params(args.isu).items()}
    os.makedirs(args.out, exist_ok=True)

    n = 0
    for src in sorted(glob.glob(os.path.join(args.src, "*.yaml"))):
        with open(src) as f:
            rendered = string.Template(f.read()).safe_substitute(mapping)
        with open(os.path.join(args.out, os.path.basename(src)), "w") as f:
            f.write(rendered)
        n += 1

    print(f"отрендерено {n} файлов -> {args.out}  (ISU={args.isu}, NS={mapping['NS']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
