#!/usr/bin/env bash
set -euo pipefail

REPO="ydb-platform/ydb"
BRANCH="main"
DASHBOARDS_PATH="ydb/deploy/helm/ydb-prometheus/dashboards"
OUT_DIR="$(cd "$(dirname "$0")" && pwd)/../grafana/dashboards"

for cmd in curl jq; do
  command -v "$cmd" >/dev/null || { echo "Нужна утилита: $cmd" >&2; exit 1; }
done

mkdir -p "$OUT_DIR"

API_URL="https://api.github.com/repos/${REPO}/contents/${DASHBOARDS_PATH}?ref=${BRANCH}"

echo "Получаю список дашбордов: $API_URL"

AUTH_HEADER=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  AUTH_HEADER=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

response=$(curl -fsSL ${AUTH_HEADER[@]+"${AUTH_HEADER[@]}"} "$API_URL")

files=$(echo "$response" \
  | jq -r '.[] | select(.type=="file" and (.name | endswith(".json"))) | "\(.name)\t\(.download_url)"')

if [[ -z "$files" ]]; then
  echo "JSON-файлы не найдены в ${DASHBOARDS_PATH}." >&2
  echo "Содержимое каталога:" >&2
  echo "$response" | jq -r '.[].name' >&2
  exit 1
fi

while IFS=$'\t' read -r name url; do
  echo "Скачиваю $name"
  curl -fsSL ${AUTH_HEADER[@]+"${AUTH_HEADER[@]}"} "$url" -o "${OUT_DIR}/${name}"
done <<< "$files"

echo "Готово. Файлы в: $OUT_DIR"
