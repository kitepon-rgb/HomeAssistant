#!/usr/bin/env bash
# Linuxサーバーで git pull + ${COMPOSE_CMD} up -d を実行する。
#
# 運用モデル: 既存の OpenCClaw と同じ「GitHub clone → サーバー上で git pull」方式。
#   - 初回: 手動で `ssh ${HA_SERVER}` した上で `git clone <repo> ${HA_REMOTE_DIR}` する
#   - 以降: Windows 側で git push → このスクリプトが ssh 越しに git pull + compose up を叩く
#
# 前提:
#   - SSH 鍵で HA_SERVER に passwordless login できる
#   - サーバー側 ${HA_REMOTE_DIR} に当リポジトリが clone 済み
#   - サーバー側に podman / podman compose (or docker) が入っている
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

# コンテナランタイム。サーバーは rootless Podman 運用なので default は "podman compose"。
# Docker に切替えるなら .env で COMPOSE_CMD="docker compose" を指定。
: "${COMPOSE_CMD:=podman compose}"

echo "→ git pull on ${HA_SERVER}:${HA_REMOTE_DIR}"
ssh "$HA_SERVER" "cd '${HA_REMOTE_DIR}' && git pull --ff-only"

echo "→ ${COMPOSE_CMD} pull && up -d on ${HA_SERVER}"
ssh "$HA_SERVER" "cd '${HA_REMOTE_DIR}' && ${COMPOSE_CMD} pull && ${COMPOSE_CMD} up -d"

echo "✓ Deploy complete. http://192.168.1.2:8123 にアクセス"
