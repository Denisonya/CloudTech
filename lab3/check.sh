#!/usr/bin/env bash
set -euo pipefail

# Скрипт можно запускать из любой папки проекта.
cd "$(dirname "$0")/.."
PYTHON="${PYTHON:-python}"

echo "Проверка кода Ruff:"
"$PYTHON" -m ruff check --config lab3/pyproject.toml lab2/backend lab3/tests lab3/scan-summary.py

# Пароль создается заново при каждом запуске и не сохраняется в репозитории.
export TEST_DB_PASSWORD
TEST_DB_PASSWORD="$(openssl rand -hex 16)"
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    echo "::add-mask::$TEST_DB_PASSWORD"
fi
export TEST_DB_PORT="${TEST_DB_PORT:-55433}"
export POSTGRES_DB=lab3_test
export POSTGRES_USER=lab3_test
export POSTGRES_PASSWORD="$TEST_DB_PASSWORD"
export POSTGRES_HOST=127.0.0.1
export POSTGRES_PORT="$TEST_DB_PORT"

# У каждого запуска свой Compose-проект, отдельный от lab0, lab1 и lab2.
compose=(docker compose -p "lab3-tests-$$" -f lab3/docker-compose.test.yml)
cleanup() {
    "${compose[@]}" down --volumes
}
trap cleanup EXIT

echo "Запуск тестовой PostgreSQL:"
"${compose[@]}" up -d --wait --wait-timeout 60

echo "Проверка API pytest:"
"$PYTHON" -m pytest -c lab3/pyproject.toml lab3/tests -v
