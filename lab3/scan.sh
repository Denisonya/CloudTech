#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

backend_image="${1:?Укажите backend image}"
frontend_image="${2:?Укажите frontend image}"
trivy="${TRIVY_BIN:-lab3/.tools/trivy}"
reports="${TRIVY_REPORT_DIR:-lab3/trivy-reports}"
export TRIVY_CACHE_DIR="${TRIVY_CACHE_DIR:-$PWD/lab3/.trivy-cache}"
mkdir -p "$reports"
"$trivy" --version > "$reports/scanner-version.txt"

# Сначала сохраняем полные отчеты для обоих образов, даже если найдены CVE.
"$trivy" image --image-src docker --scanners vuln --timeout 10m --no-progress     --format json --output "$reports/backend.json" "$backend_image"
"$trivy" image --image-src docker --scanners vuln --timeout 10m --no-progress     --format json --output "$reports/frontend.json" "$frontend_image"

for name in backend frontend; do
    "$trivy" convert --format table --severity HIGH,CRITICAL         --output "$reports/$name.txt" "$reports/$name.json"
done
if [[ -f "$TRIVY_CACHE_DIR/db/metadata.json" ]]; then
    cp "$TRIVY_CACHE_DIR/db/metadata.json" "$reports/db-metadata.json"
fi
python lab3/scan-summary.py "$reports"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    cat "$reports/summary.md" >> "$GITHUB_STEP_SUMMARY"
fi

# Security-gate: CRITICAL блокируют дальнейшие шаги. HIGH остаются в отчете.
# Проверяем оба образа и не скрываем уязвимости без выпущенного исправления.
result=0
for image in "$backend_image" "$frontend_image"; do
    if "$trivy" image --image-src docker --scanners vuln --timeout 10m         --no-progress --skip-db-update --severity CRITICAL --exit-code 1 "$image"; then
        echo "CRITICAL не найдены: $image"
    else
        result=1
    fi
done
exit "$result"
