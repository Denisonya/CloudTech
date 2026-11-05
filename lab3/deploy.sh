#!/usr/bin/env bash
set -euo pipefail
umask 077
cd "$(dirname "$0")/.."

images_file="${1:-lab3/release/images.env}"
# Настройки и данные релиза находятся вне временного checkout runner.
deploy_dir="${LAB3_DEPLOY_DIR:-$HOME/.local/share/cloudtech-lab3}"
project="${LAB3_PROJECT_NAME:-lab3}"

image_tag=""
backend_image=""
frontend_image=""
while IFS='=' read -r key value; do
    case "$key" in
        IMAGE_TAG) image_tag="$value" ;;
        BACKEND_IMAGE) backend_image="$value" ;;
        FRONTEND_IMAGE) frontend_image="$value" ;;
        *) echo "Неизвестное поле в images.env: $key" >&2; exit 1 ;;
    esac
done < "$images_file"

# Не выполняем содержимое артефакта как shell-код.
[[ "$image_tag" =~ ^[0-9a-f]{40}$ ]] || { echo "Некорректный тег релиза" >&2; exit 1; }
[[ "$backend_image" =~ ^ghcr\.io/denisonya/cloudtech-backend@sha256:[0-9a-f]{64}$ ]] \
    || { echo "Некорректная ссылка backend" >&2; exit 1; }
[[ "$frontend_image" =~ ^ghcr\.io/denisonya/cloudtech-frontend@sha256:[0-9a-f]{64}$ ]] \
    || { echo "Некорректная ссылка frontend" >&2; exit 1; }

mkdir -p "$deploy_dir"
exec 9> "$deploy_dir/deploy.lock"
flock -n 9 || { echo "Другой деплой уже выполняется" >&2; exit 1; }

if [[ ! -f "$deploy_dir/.env" ]]; then
    port="${APP_PORT:-8083}"
    [[ "$port" =~ ^[1-9][0-9]{0,4}$ ]] && (( port <= 65535 )) \
        || { echo "Некорректный APP_PORT" >&2; exit 1; }
    printf 'POSTGRES_DB=notes\nPOSTGRES_USER=notes\nPOSTGRES_PASSWORD=%s\nAPP_PORT=%s\n' \
        "$(openssl rand -hex 24)" "$port" > "$deploy_dir/.env"
fi

release_dir="$deploy_dir/releases/$image_tag"
mkdir -p "$release_dir"
cp lab3/docker-compose.deploy.yml "$release_dir/docker-compose.yml"
cp "$images_file" "$release_dir/images.env"

# Значения берем только из сохраненных файлов, а не из окружения runner.
unset POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD BACKEND_IMAGE FRONTEND_IMAGE APP_PORT
compose=(docker compose -p "$project" --env-file "$deploy_dir/.env" \
    --env-file "$release_dir/images.env" -f "$release_dir/docker-compose.yml")

# Только скачиваем проверенные образы, сборки на машине деплоя нет.
"${compose[@]}" pull
"${compose[@]}" up -d --no-build --pull never --wait --wait-timeout 120
"${compose[@]}" ps

address="$("${compose[@]}" port frontend 80)"
[[ "$address" =~ ^127\.0\.0\.1:[0-9]+$ ]] \
    || { echo "Не удалось определить адрес frontend" >&2; exit 1; }
service_url="http://$address"

# Сохраняем сведения о текущем и предыдущем релизах.
if [[ -f "$deploy_dir/current-release" ]]; then
    current="$(cat "$deploy_dir/current-release")"
    if [[ "$current" != "$image_tag" ]]; then
        printf '%s\n' "$current" > "$deploy_dir/previous-release"
    fi
fi
printf '%s\n' "$image_tag" > "$deploy_dir/current-release"
echo "Релиз $image_tag развернут: $service_url"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf 'service_url=%s\n' "$service_url" >> "$GITHUB_OUTPUT"
fi
