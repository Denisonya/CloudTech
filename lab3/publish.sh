#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

: "${GITHUB_REPOSITORY:?Скрипт предназначен для GitHub Actions}"
: "${GITHUB_SHA:?Не задан SHA коммита}"
if [[ ! "$GITHUB_REPOSITORY" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] \
    || [[ ! "$GITHUB_SHA" =~ ^[0-9a-f]{40}$ ]]; then
    echo "Некорректное имя репозитория или SHA коммита" >&2
    exit 1
fi

# GHCR требует имена образов в нижнем регистре.
registry_prefix="ghcr.io/${GITHUB_REPOSITORY,,}"
declare -A references

for service in backend frontend; do
    local_image="notes-$service:$GITHUB_SHA"
    repository="$registry_prefix-$service"
    remote_image="$repository:$GITHUB_SHA"
    expected_id="$(docker image inspect --format '{{.Id}}' "$local_image")"

    # Перетегируем уже собранный и проверенный образ, без повторной сборки.
    docker tag "$local_image" "$remote_image"
    docker push "$remote_image"

    # Проверяем, что из реестра читается тот же образ, который прошел Trivy.
    docker pull "$remote_image"
    actual_id="$(docker image inspect --format '{{.Id}}' "$remote_image")"
    if [[ "$actual_id" != "$expected_id" ]]; then
        echo "ID опубликованного образа отличается от проверенного: $remote_image" >&2
        exit 1
    fi

    digests="$(docker image inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "$remote_image")"
    reference=""
    while IFS= read -r candidate; do
        if [[ "$candidate" == "$repository@sha256:"* ]]; then
            reference="$candidate"
            break
        fi
    done <<< "$digests"
    if [[ -z "$reference" ]]; then
        echo "Не удалось получить digest опубликованного образа: $remote_image" >&2
        exit 1
    fi
    references[$service]="$reference"
    echo "Проверено: $remote_image соответствует просканированному образу $expected_id"
done

# В файле только ссылки на образы, без учетных данных.
mkdir -p lab3/release
printf 'IMAGE_TAG=%s\nBACKEND_IMAGE=%s\nFRONTEND_IMAGE=%s\n' \
    "$GITHUB_SHA" "${references[backend]}" "${references[frontend]}" \
    > lab3/release/images.env
cat lab3/release/images.env

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
        echo "## Публикация в GHCR"
        echo
        echo "Оба образа опубликованы после успешного Trivy и проверены повторным скачиванием."
        echo
        echo '```text'
        cat lab3/release/images.env
        echo '```'
    } >> "$GITHUB_STEP_SUMMARY"
fi
