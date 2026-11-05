#!/usr/bin/env bash
set -euo pipefail
umask 077
cd "$(dirname "$0")/.."
deploy_dir="${LAB3_DEPLOY_DIR:-$HOME/.local/share/cloudtech-lab3}"
project="${LAB3_PROJECT_NAME:-lab3}"
exec 9> "$deploy_dir/deploy.lock"
flock -n 9 || { echo "Другой деплой уже выполняется" >&2; exit 1; }
[[ ! -f "$deploy_dir/failed-release" ]] || { echo "Сначала восстановите текущий релиз" >&2; exit 1; }
current="$(cat "$deploy_dir/current-release")"
[[ "$current" =~ ^[0-9a-f]{40}$ ]] || exit 1
release_dir="$deploy_dir/releases/$current"
unset POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD BACKEND_IMAGE FRONTEND_IMAGE APP_PORT
compose=(docker compose -p "$project" --env-file "$deploy_dir/.env" \
    --env-file "$release_dir/images.env" -f "$release_dir/docker-compose.yml")
address="$("${compose[@]}" port frontend 80)"
[[ "$address" =~ ^127\.0\.0\.1:[0-9]+$ ]] || exit 1
bash lab3/smoke.sh "http://$address"
backend_image="$(sed -n 's/^BACKEND_IMAGE=//p' "$release_dir/images.env")"
[[ "$backend_image" =~ ^ghcr\.io/denisonya/cloudtech-backend@sha256:[0-9a-f]{64}$ ]] || exit 1
broken="rollback-demo-$(date -u +%Y%m%dT%H%M%SZ)"
broken_dir="$deploy_dir/releases/$broken"
mkdir -p "$broken_dir"
# Отдельный демонстрационный образ с неверной командой запуска.
printf 'FROM %s\nCMD ["python", "-m", "backend.rollback_missing"]\n' "$backend_image" \
    > "$broken_dir/Dockerfile"
DOCKER_BUILDKIT=0 docker build -t "cloudtech-lab3-broken:$broken" "$broken_dir"
printf 'services:\n  backend:\n    image: cloudtech-lab3-broken:%s\n' "$broken" \
    > "$broken_dir/override.yml"
printf 'Рабочий релиз перед демонстрацией: %s\nБитый образ: cloudtech-lab3-broken:%s\n' "$current" "$broken"
printf '%s\n' "$broken" > "$deploy_dir/failed-release"
if "${compose[@]}" -f "$broken_dir/override.yml" up -d --no-build --pull never \
    --no-deps --wait --wait-timeout 20 backend; then
    echo "Битый релиз неожиданно прошел healthcheck" >&2
    exit 1
fi
"${compose[@]}" -f "$broken_dir/override.yml" ps -a
"${compose[@]}" -f "$broken_dir/override.yml" logs --tail 8 backend
status="$(curl --silent --show-error --max-time 10 --output /dev/null \
    --write-out '%{http_code}' "http://$address/api/notes" || true)"
printf 'API после сломанного деплоя: HTTP %s\n' "$status"
[[ "$status" != 200 ]] || { echo "API неожиданно доступен" >&2; exit 1; }
echo "Сломанный деплой подтвержден. Восстановление: bash lab3/rollback.sh"
