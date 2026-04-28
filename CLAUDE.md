# HomeAssistant 統合プロジェクト

## 概要
ローカルのLinuxサーバー（192.168.1.2）にHome Assistantを立て、家電操作の口として運用する。判断ロジックは別プロジェクトのベル（[OpenClaw](../OpenClaw/)）が担う。HAは「叩いたら家電が動くAPI」だけを提供し、自動化・条件分岐はベル側に集約する。

## 命名注意
- ローカルディレクトリ名: `HomeAssitant`（"s" 抜けのタイポだが、リネームせずそのまま運用）
- GitHubリポジトリ名: `HomeAssistant`（正しい綴り）

## アーキテクチャ
- デバイス統合層: 当プロジェクト（Linuxサーバー上の Container、Docker rootful）
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
- `deploy/deploy.sh` — ssh 越しに サーバー側 `git pull && ${COMPOSE_CMD} pull && up -d` を叩く（既存 OpenCClaw と同じ「GitHub経由 → サーバーで pull」方式）
- `.env` — デプロイ先サーバー情報（Git管理外、`.env.example`参照）

## デプロイ先
- Linuxサーバー: 192.168.1.2（kitepon.dynv6.net）。**Ubuntu Server LTS** で運用、SSH ユーザー名は `kite`
- リモートパス: `/home/kite/homeassistant/`（既存コンテナも `~/<service>/docker-compose.yml` パターンで揃えてある）
- コンテナランタイム: **Docker Engine rootful**（apt 公式 docker-ce）。`docker compose` プラグインを使用
- `network_mode: host` は Docker rootful でも動く（mDNS/Tuya UDP/SSDP 受信OK）
- `privileged: true` / `/run/dbus` mount は Docker rootful では利用可能だが、現状の HA 用途では不要なため compose から除外。USB/Bluetooth 必要時に有効化を検討
- Ubuntu は **AppArmor** 環境（`:Z` は SELinux 固有のため非サポート、付与不要）
- `restart: unless-stopped` は Docker daemon 起動時に自動再起動する（systemd で docker.service が有効であれば OS 再起動時にも自動起動）。Podman rootless で必要だった systemd unit 生成や linger 設定は不要
- HAアクセス: http://192.168.1.2:8123（ローカルネットワーク内のみ、Caddy配下に置かない・外部公開しない）

## 実装ステータス（2026-04-27時点 — Phase 1+2 完走）

- ✅ HA scaffold（`docker-compose.yml` / `config/configuration.yaml` / `deploy/deploy.sh` / `.env.example` / `README.md` / 当ファイル）
- ✅ Docker rootful + Ubuntu Server + ホーム配下運用、サーバー 192.168.1.2 で稼働中
- ✅ HA UI 初期セットアップ完了、Owner=`kitepon`、Caddy 配下に置かない・ローカル LAN 限定
- ✅ HACS 取り込み（GitHub Releases 公式 zip）、Nature Remo を NaNaLinks フォークで追加
- ✅ Nature Remo 統合（Remo×2: リビング Remo + 寝室 Remo nano、合計 12 エンティティ）
- ✅ Tuya 統合（SmartLife OAuth、`switch.terehi_socket` / `switch.90cm水槽の照明_socket` / `switch.90cm水槽の水流_socket`）
- ✅ iRobot 統合（Roomba 掃除機 + Braava jet 床拭き、自動 BLID/PW 取得方式）
- ✅ ベル `home_control` MCP ツール実装・コミット済み（OpenClaw commit `565e463`、zod 互換修正 `68bf9ae`）
- ✅ ベル persona に「自宅環境」セクション追記、wiki seed `memory/wiki/concepts/home-devices.md` を実 entity_id で作成（手書き保持、`locked: true`）
- ✅ Long-Lived Token 発行 → Windows + サーバー両方の `.env` に `HA_BASE_URL` / `HA_TOKEN` 追記
- ✅ ファイアウォール 8123 ポートを LAN 内（192.168.1.0/24）に開放
- ✅ ベルから `home_control` 経由で実機家電取得 E2E 確認（照明・エアコン・スマートプラグ・ロボット）
- 🟡 Google Cast 統合は自動検出が動かず保留、必要時に手動 IP 指定で追加
- 🔮 Phase 3（TTS 出力 Style-Bert-VITS2） / Phase 4（サテライト）は後回し、運用しながら判断

## 運用上の罠（memory に詳細記録）

- **OpenClaw の `.env` は Windows ローカルとサーバーで別物**、新 env は両方に追記が必要（`memory/openclaw_dual_env_files.md`）
- **新 MCP ツール追加時は `openclaw-mcp` コンテナとベルの両方を再起動**（`memory/openclaw_new_tool_requires_restarts.md`）
- **MCP ツールの zod schema で `z.record(z.any())` は使用禁止**（tools/list 全体がクラッシュする、`memory/openclaw_mcp_zod_record_pitfall.md`）
- **OpenClaw の `wiki-approve.js` は手書き seed 本文を消す**、`locked: true` で叩かない運用（`memory/openclaw_wiki_approve_behavior.md`）
- **HA `http:` の `use_x_forwarded_for` 単独指定不可**、`trusted_proxies` 必須（recovery mode に陥る）

詳細プラン: `~/.claude/plans/c-users-kite-documents-program-openclaw-recursive-petal.md`

## サーバーリプレイス（2026-04-28 移行完了）
192.168.1.2 は Bazzite + rootless Podman → **Ubuntu Server LTS + Docker Engine rootful** へ移行完了（2026-04-28）。サーバー固有値は全部 `.env` で上書き可能（`HA_SERVER` / `HA_REMOTE_DIR` / `COMPOSE_CMD`）。詳細は memory `linux_server_environment.md`。

## 関連リポジトリ
- [OpenClaw](../OpenClaw/) — ベル本体。家電操作の道具 `home_control` をMCPツールとして当HAに対して呼ぶ
