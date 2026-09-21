#!/usr/bin/env bash
# Снимает состояние кластера в evidence/out/, сворачивает в хеш E.
# Коммит этого каталога фиксирует E во времени (commitment). На защите
# преподаватель поднимает кластер из того же коммита и сверяет.
set -euo pipefail

ISU="${1:?нужен номер ИСУ}"
NS="$(python3 seed.py --isu "$ISU" --get NS)"
OUT="evidence/out"
mkdir -p "$OUT"

dump() { kubectl -n "$NS" get "$1" -o json > "$OUT/$2" 2>/dev/null || echo '{}' > "$OUT/$2"; }

dump all,pvc,cm,secret          state.json
dump events                     events.json
kubectl -n "$NS" rollout history deploy/vote > "$OUT/rollout.txt" 2>/dev/null || true
cp -f scorecard.json "$OUT/scorecard.json" 2>/dev/null || true

# Хеш по отсортированному дайджесту всех файлов — детерминированно и независимо от порядка.
( cd "$OUT" && find . -type f -exec sha256sum {} + | sort ) > "$OUT/manifest.sha256"
E="$(sha256sum "$OUT/manifest.sha256" | cut -d' ' -f1)"

cat > "evidence/stamp.json" <<JSON
{
  "isu": "$ISU",
  "namespace": "$NS",
  "collected_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "evidence_hash": "$E"
}
JSON

echo "E = $E"
echo "записано в evidence/stamp.json — закоммитьте каталог evidence/"
