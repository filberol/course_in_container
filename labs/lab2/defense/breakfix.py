#!/usr/bin/env python3
"""Live break-fix для защиты. По BREAKFIX_ID из сида печатает сценарий сбоя:
команду вброса, ожидаемый симптом и что студент должен восстановить.

Для преподавателя. С --apply вбрасывает сбой в кластер (namespace варианта).
Студент готовится ко всем шести заранее.
"""
import argparse
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from seed import params  # noqa: E402

SCENARIOS = {
    1: {
        "name": "БД масштабирована в ноль",
        "inject": "scale deploy/db --replicas=0",
        "symptom": "страница result отдаёт 5xx, worker не может подключиться к БД",
        "restore": "вернуть реплики БД, дождаться Ready",
    },
    2: {
        "name": "подменён пароль в Secret",
        "inject": "patch secret db-secret -p '{\"stringData\":{\"POSTGRES_PASSWORD\":\"wrong\"}}'",
        "symptom": "worker/result: authentication failed, поды в CrashLoopBackOff",
        "restore": "вернуть корректный пароль в Secret и перезапустить зависимые поды",
    },
    3: {
        "name": "readinessProbe на несуществующий путь",
        "inject": "patch deploy/vote --type=json "
                  "-p '[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/readinessProbe/httpGet/path\",\"value\":\"/nope\"}]'",
        "symptom": "поды vote NotReady, Endpoints сервиса пуст, трафик не идёт",
        "restore": "вернуть рабочий путь пробы",
    },
    4: {
        "name": "образ с несуществующим тегом",
        "inject": "set image deploy/vote vote=dockersamples/examplevotingapp_vote:nope",
        "symptom": "ImagePullBackOff, выкат застрял",
        "restore": "kubectl rollout undo или вернуть корректный тег",
    },
    5: {
        "name": "рассогласование selector Service и label подов",
        "inject": "patch svc/vote -p '{\"spec\":{\"selector\":{\"app\":\"vote-broken\"}}}'",
        "symptom": "поды здоровы, но Service без Endpoints, трафик не доходит",
        "restore": "вернуть selector в соответствие label подов",
    },
    6: {
        "name": "повреждённый/удалённый PVC",
        "inject": "delete pvc -l app=db --wait=false",
        "symptom": "под БД не стартует, том не привязывается",
        "restore": "пересоздать PVC, объяснить последствия для данных (data gravity)",
    },
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--isu", required=True)
    ap.add_argument("--id", type=int, help="переопределить сценарий (по умолчанию из сида)")
    ap.add_argument("--apply", action="store_true", help="вбросить сбой в кластер")
    args = ap.parse_args()

    p = params(args.isu)
    sid = args.id or p["BREAKFIX_ID"]
    s = SCENARIOS[sid]
    ns = p["NS"]

    print(f"BREAKFIX_ID = {sid}: {s['name']}")
    print(f"  namespace : {ns}")
    print(f"  вброс     : kubectl -n {ns} {s['inject']}")
    print(f"  симптом   : {s['symptom']}")
    print(f"  починить  : {s['restore']}")

    if args.apply:
        cmd = ["kubectl", "-n", ns] + s["inject"].split()
        print(f"\nвыполняю: {' '.join(cmd)}")
        subprocess.run(cmd, check=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
