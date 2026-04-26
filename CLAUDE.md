# HomeAssistant 統合プロジェクト

## 概要
ローカルのLinuxサーバー（192.168.1.2）にHome Assistantを立て、家電操作の口として運用する。判断ロジックは別プロジェクトのベル（[OpenClaw](../OpenClaw/)）が担う。HAは「叩いたら家電が動くAPI」だけを提供し、自動化・条件分岐はベル側に集約する。

## 命名注意
- ローカルディレクトリ名: `HomeAssitant`（"s" 抜けのタイポだが、リネームせずそのまま運用）
- GitHubリポジトリ名: `HomeAssistant`（正しい綴り）

## アーキテクチャ
- デバイス統合層: 当プロジェクト（Linuxサーバー上の Container、現状 rootless Podman）
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
- `deploy/deploy.sh` — Windows側からLinuxサーバーへ rsync + `${COMPOSE_CMD}` (default: `podman compose`) で起動
- `.env` — デプロイ先サーバー情報（Git管理外、`.env.example`参照）

## デプロイ先
- Linuxサーバー: 192.168.1.2（kitepon.dynv6.net）。**Bazzite (immutable Fedora atomic)** で運用、SSH ユーザー名は `kite`
- リモートパス: `/home/kite/homeassistant/`（既存コンテナも `~/<service>/docker-compose.yml` パターンで揃えてある）
- コンテナランタイム: **rootless Podman 5.8.2**（既存コンテナと同じ流儀）。`podman compose` は内部で `docker-compose` plugin を呼ぶ Bazzite 流儀で動く
- `network_mode: host` は rootless でも動く（mDNS/Tuya UDP/SSDP 受信OK、8123 は非特権ポート）
- `privileged: true` / `/run/dbus` mount は rootless では効かないため compose から除外。USB/Bluetooth 必要時は rootful 切替を別途検討
- SELinux は **Permissive** モードなので bind mount への `:Z` 付与は不要
- HAアクセス: http://192.168.1.2:8123（ローカルネットワーク内のみ、Caddy配下に置かない・外部公開しない）

## 実装ステータス（2026-04-26時点）

- ✅ HA scaffold (`docker-compose.yml` / `config/configuration.yaml` / `deploy/deploy.sh` / `.env.example` / `README.md` / 当ファイル)
- ✅ rootless Podman + Bazzite + ホーム配下運用に scaffold を最適化（実機 SSH 確認済み）
- ✅ OpenClaw 側 `home_control` MCP ツール実装・コミット済み（OpenClaw commit `565e463`）
- ✅ ベル persona に「自宅環境」セクション追記、wiki seed テンプレ `memory/wiki/concepts/home-devices.md` 作成
- ⏸️ Linuxサーバーへのデプロイ・HA 初期セットアップ・統合追加（Quo 手動）
- ⏸️ Long-Lived Token 発行 → OpenClaw `.env` 追記（Quo 手動）
- ⏸️ wiki seed `<TBD>` 埋め → `node scripts/wiki-approve.js home-devices`（Quo 手動）
- ⏸️ ベル再起動して `home_control` 認識確認（Phase 2 E2E）
- 🔮 Phase 3（TTS 出力 Style-Bert-VITS2） / Phase 4（サテライト）は後回し、Phase 1+2 安定後に判断

詳細プラン: `~/.claude/plans/c-users-kite-documents-program-openclaw-recursive-petal.md`

## サーバー将来リプレイス
192.168.1.2 は将来リプレイス予定（時期未定、Quo告知 2026-04-26）。サーバー固有値は全部 `.env` で上書き可能（`HA_SERVER` / `HA_REMOTE_DIR` / `COMPOSE_CMD`）なので、リプレイス時は新サーバー実情を SSH で確認 → `.env` 書換 → `bash deploy/deploy.sh` 再実行で済む。詳細は memory `linux_server_environment.md`。

## 関連リポジトリ
- [OpenClaw](../OpenClaw/) — ベル本体。家電操作の道具 `home_control` をMCPツールとして当HAに対して呼ぶ
