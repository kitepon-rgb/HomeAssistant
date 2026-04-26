#!/usr/bin/env bash
# Windows (WSL2 or Git Bash) からLinuxサーバーへ Home Assistant の構成をデプロイする。
# 前提: SSH 鍵で HA_SERVER に passwordless login できること、リモート側に Docker / docker compose が入っていること。
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "✗ .env が見つかりません。.env.example をコピーして編集してください" >&2
  exit 1
fi

# shellcheck disable=SC1091
source .env

if [[ -z "${HA_SERVER:-}" || -z "${HA_REMOTE_DIR:-}" ]]; then
  echo "✗ .env に HA_SERVER と HA_REMOTE_DIR を定義してください" >&2
  exit 1
fi

echo "→ rsync to ${HA_SERVER}:${HA_REMOTE_DIR}"
rsync -avz --delete \
  --exclude='.git/' \
  --exclude='.env' \
  --exclude='.env.local' \
  --exclude='.claude/' \
  --exclude='.spotter/' \
  --exclude='.vscode/' \
  --exclude='config/.storage/' \
  --exclude='config/.cloud/' \
  --exclude='config/secrets.yaml' \
  --exclude='config/home-assistant.log*' \
  --exclude='config/home-assistant_v2.db*' \
  --exclude='config/deps/' \
  ./ "${HA_SERVER}:${HA_REMOTE_DIR}/"

echo "→ docker compose up -d on ${HA_SERVER}"
ssh "$HA_SERVER" "cd '${HA_REMOTE_DIR}' && docker compose pull && docker compose up -d"

echo "✓ Deploy complete. http://192.168.1.2:8123 にアクセス"
