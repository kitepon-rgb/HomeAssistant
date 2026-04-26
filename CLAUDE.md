# HomeAssistant 統合プロジェクト

## 概要
ローカルのLinuxサーバー（192.168.1.2）にHome Assistantを立て、家電操作の口として運用する。判断ロジックは別プロジェクトのベル（[OpenClaw](../OpenClaw/)）が担う。HAは「叩いたら家電が動くAPI」だけを提供し、自動化・条件分岐はベル側に集約する。

## 命名注意
- ローカルディレクトリ名: `HomeAssitant`（"s" 抜けのタイポだが、リネームせずそのまま運用）
- GitHubリポジトリ名: `HomeAssistant`（正しい綴り）

## アーキテクチャ
- デバイス統合層: 当プロジェクト（Linuxサーバー上のDocker Container）
- 判断・対話層: [OpenClaw](../OpenClaw/) のベル
- 接続: `OpenClaw/tools/home-assistant.js`（MCPツール `home_control`） → HA REST API

## FALLBACK禁止ルール（最重要）
「動けばいい」フォールバック・暫定対応コードは原則禁止。
- catchして握り潰し、デフォルト値返却するような無音フォールバックはしない
- 想定外の状況は早めに失敗（fail-fast）し、原因を含む日本語エラーメッセージを返す
- やむを得ずフォールバックを入れる場合は `# FALLBACK-ALLOWED: 理由` コメントで根拠を明記する
- 例: HA_TOKEN未設定なら起動継続せず即失敗、HTTP接続失敗もECONNREFUSED等の原因を含めて返す

OpenClaw側のCLAUDE.mdと方針を揃える。

## ディレクトリ構成
- `docker-compose.yml` — HA本体のコンテナ定義
- `config/` — HAの `/config` にbind mountされる
  - `configuration.yaml` — seed設定（Git管理）
  - `.storage/`、`secrets.yaml`、ログ等はGit管理外（`.gitignore`参照）
- `deploy/deploy.sh` — Windows側からLinuxサーバーへ rsync + docker compose up
- `.env` — デプロイ先サーバー情報（Git管理外、`.env.example`参照）

## デプロイ先
- Linuxサーバー: 192.168.1.2（kitepon.dynv6.net）
- リモートパス: `/srv/homeassistant/`
- HAアクセス: http://192.168.1.2:8123（ローカルネットワーク内のみ、Caddy配下に置かない・外部公開しない）

## 関連リポジトリ
- [OpenClaw](../OpenClaw/) — ベル本体。家電操作の道具 `home_control` をMCPツールとして当HAに対して呼ぶ
