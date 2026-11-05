#!/usr/bin/env bash
set -euo pipefail
umask 077
cd "$(dirname "$0")/.."
deploy_dir="${LAB3_DEPLOY_DIR:-$HOME/.local/share/cloudtech-lab3}"
project="${LAB3_PROJECT_NAME:-lab3}"
exec 9> "$deploy_dir/deploy.lock"
flock -n 9 || { echo "Другой деплой уже выполняется" >&2; exit 1; }

# После неудачного деплоя current-release по-прежнему указывает на рабочую версию.
if [[ -n "${1:-}" ]]; then
    target="$1"
elif [[ -f "$deploy_dir/failed-release" ]]; then
    target="$(cat "$deploy_dir/current-release")"
else
    target="$(cat "$deploy_dir/previous-release")"
fi
[[ "$target" =~ ^[0-9a-f]{40}$ ]] || { echo "Некорректный SHA релиза" >&2; exit 1; }
release_dir="$deploy_dir/releases/$target"
[[ -f "$release_dir/images.env" && -f "$release_dir/docker-compose.yml" ]] \
    || { echo "Сохраненная конфигурация релиза не найдена" >&2; exit 1; }
unset POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD BACKEND_IMAGE FRONTEND_IMAGE APP_PORT
compose=(docker compose -p "$project" --env-file "$deploy_dir/.env" \
    --env-file "$release_dir/images.env" -f "$release_dir/docker-compose.yml")

# Проверяем наличие всех образов до изменения контейнеров. Откат работает без реестра.
while IFS= read -r image; do
    docker image inspect "$image" > /dev/null
done < <("${compose[@]}" config --images)
started=$SECONDS
printf 'Откат на релиз: %s\n' "$target"
printf '%s\n' "$target" > "$deploy_dir/failed-release"
"${compose[@]}" up -d --no-build --pull never --wait --wait-timeout 120
"${compose[@]}" ps
address="$("${compose[@]}" port frontend 80)"
[[ "$address" =~ ^127\.0\.0\.1:[0-9]+$ ]] || exit 1
bash lab3/smoke.sh "http://$address"
current="$(cat "$deploy_dir/current-release")"
if [[ "$current" != "$target" ]]; then
    printf '%s\n' "$current" > "$deploy_dir/previous-release"
fi
printf '%s\n' "$target" > "$deploy_dir/current-release"
rm -f "$deploy_dir/failed-release"
printf 'Откат завершен за %s с. Текущий релиз: %s\n' "$((SECONDS-started))" "$target"
