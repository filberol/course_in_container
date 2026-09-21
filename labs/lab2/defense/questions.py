#!/usr/bin/env python3
"""Генерирует персональные вопросы к защите из манифестов студента.

Читает manifests/*.yaml, достаёт СОБСТВЕННЫЕ значения студента (реплики,
maxUnavailable, наличие PVC, путь readinessProbe) и подставляет их в вопросы.
Репетировать общую теорию бесполезно — спрашивают про конкретный выбор.
"""
import argparse
import glob
import os
import sys

try:
    import yaml
except ImportError:
    sys.exit("нужен pyyaml:  pip install pyyaml")

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from seed import params  # noqa: E402


def load_docs(path):
    docs = []
    for fn in glob.glob(os.path.join(path, "**", "*.y*ml"), recursive=True):
        with open(fn) as f:
            docs.extend(d for d in yaml.safe_load_all(f) if d)
    return docs


def app_of(doc):
    md = doc.get("metadata", {})
    labels = md.get("labels", {})
    return labels.get("app") or md.get("name", "")


def find(docs, kinds, app):
    for d in docs:
        if d.get("kind") in kinds and app in app_of(d):
            return d
    return None


def replicas(dep):
    return (dep or {}).get("spec", {}).get("replicas")


def max_unavailable(dep):
    ru = (dep or {}).get("spec", {}).get("strategy", {}).get("rollingUpdate", {})
    return ru.get("maxUnavailable")


def readiness_path(dep, app):
    try:
        c = dep["spec"]["template"]["spec"]["containers"]
        for cont in c:
            hp = cont.get("readinessProbe", {}).get("httpGet")
            if hp:
                return hp.get("path", "/")
    except (KeyError, TypeError):
        pass
    return None


def has_pvc(docs, app):
    for d in docs:
        if d.get("kind") == "PersistentVolumeClaim" and app in app_of(d):
            return True
        if d.get("kind") == "StatefulSet" and app in app_of(d):
            if d.get("spec", {}).get("volumeClaimTemplates"):
                return True
    return False


def build(docs, p):
    q = []
    vote = find(docs, {"Deployment", "StatefulSet"}, "vote")
    result = find(docs, {"Deployment", "StatefulSet"}, "result")

    r = replicas(vote) or p["REPLICAS_VOTE"]
    q.append(f"vote на {r} реплик. Если все {r} упадут разом — что станет с голосами, "
             f"уже лежащими в очереди redis (LPUSH), кто и когда их обработает?")

    mu = max_unavailable(vote)
    mu = p["MAX_UNAVAIL"] if mu is None else mu
    q.append(f"maxUnavailable={mu}. Сколько подов минимум держат трафик в момент выката "
             f"и почему выбрано именно это значение, а не другое?")

    if not has_pvc(docs, "redis") and has_pvc(docs, "db"):
        q.append("У redis нет PVC, у db есть. Обоснуйте асимметрию через blast radius "
                 "и свяжите с диаграммой отказа из Лаб 1.")

    rp = readiness_path(result, "result")
    if rp:
        q.append(f"readinessProbe result бьёт в {rp}. Что увидит Service, если проба начнёт "
                 f"отдавать 500 — куда пойдёт трафик и что станет с Endpoints?")

    q.append("Покажите в своём манифесте место, где control loop узнаёт, что фактических "
             "реплик меньше желаемого.")
    return q


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--isu", required=True)
    ap.add_argument("--manifests", default="manifests")
    args = ap.parse_args()

    docs = load_docs(args.manifests)
    if not docs:
        print("манифесты не найдены — нечего спрашивать", file=sys.stderr)
        return 1
    for i, question in enumerate(build(docs, params(args.isu)), 1):
        print(f"{i}. {question}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
