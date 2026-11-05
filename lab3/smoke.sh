#!/usr/bin/env bash
set -euo pipefail
base_url="${1:-http://127.0.0.1:8083}"
base_url="${base_url%/}"
curl_options=(--fail-with-body --silent --show-error --retry 5 \
    --retry-all-errors --retry-delay 2 --max-time 10)

echo "Проверка frontend: $base_url/"
curl "${curl_options[@]}" "$base_url/" --output /dev/null --write-out 'HTTP %{http_code}\n'
echo "Проверка NGINX: $base_url/healthz"
curl "${curl_options[@]}" "$base_url/healthz" --write-out '\nHTTP %{http_code}\n'
echo "Проверка API и PostgreSQL: $base_url/api/notes"
curl "${curl_options[@]}" "$base_url/api/notes" --write-out '\nHTTP %{http_code}\n'
echo "Сервис доступен после деплоя."
