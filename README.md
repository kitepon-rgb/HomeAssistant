# HomeAssistant

ベル（[OpenClaw](../OpenClaw/)）の家電操作レイヤーとして、Home AssistantをLinuxサーバー（192.168.1.2）に Docker rootful で立てる構成。

> ローカルディレクトリ名は `HomeAssitant`（"s" 抜けタイポ）、GitHubリポジトリ名は `HomeAssistant`（正）。

## 役割分担

- **当プロジェクト**: Home Assistant本体（家電統合HUB）。Nature Remo・SmartLife（Tuya）・iRobot・Google Cast等を1つのAPIに束ねる
- **[OpenClaw](../OpenClaw/)**: ベル本体。状況判断と自然言語対話。当HAをMCPツール `home_control` 経由で叩く

判断ロジックはHA側の自動化機能には載せず、すべてベル側で行う。

## ディレクトリ構成

| パス | 役割 |
|---|---|
| `docker-compose.yml` | HA本体のコンテナ定義 |
| `config/configuration.yaml` | HAのseed設定（最小限） |
| `config/.storage/`, `secrets.yaml` 等 | HAが書き込む状態（Git管理外） |
| `deploy/deploy.sh` | Windows→Linuxサーバーへ git pull+起動 |
| `.env` | デプロイ先情報（Git管理外、`.env.example` 参照） |

## 現状（2026-04-27時点）

| Phase | 内容 | 状態 |
|---|---|---|
| 1 | HA scaffold（compose / config / deploy script / docs） | ✅ 完了 |
| 1 | Linux サーバー (192.168.1.2) へのデプロイ + HA 初期セットアップ | ✅ 完了、稼働中 |
| 1 | 統合追加（Nature Remo×2 / Tuya×3 / iRobot Roomba+Braava / HACS） | ✅ 完了 |
| 2 | OpenClaw 側 `home_control` MCP ツール実装 | ✅ 完了（commit `565e463`、`68bf9ae` で zod 修正） |
| 2 | OpenClaw `.env`（Windows + サーバー両方）への `HA_BASE_URL` / `HA_TOKEN` 追記 | ✅ 完了 |
| 2 | wiki seed `home-devices.md` の entity_id マッピング | ✅ 完了（手書き seed、`locked: true`） |
| 2 | ベルから `home_control` 経由で家電操作 E2E | ✅ 完了（ベル運用中） |
| 3 | TTS 出力（Style-Bert-VITS2、ベルが部屋スピーカーで応答） | 🔮 後回し |
| 4 | サテライトマイク/スピーカー（寝室・風呂） | 🔮 後回し |

**ベルが操作可能なエンティティ（実機確認 2026-04-27）:**
- 照明 2: 寝室（Nature Remo nano）/ リビング シーリングファン
- エアコン 2: 寝室 / リビング（ダイキン）
- スマートプラグ 3: テレビ電源 / 90cm水槽の照明 / 90cm水槽の水流ポンプ
- ロボット 2: Roomba（掃除機）/ Braava jet（床拭き）
- 温度・湿度・照度・人感センサー等多数（Nature Remo 系が自動生成）

**保留中:**
- Google Cast（自動検出が動かず一旦保留、必要時に手動IP指定で追加）
- 192.168.1.42 → Nature Remo nano だったと判明
- 「水槽ヒーター」想定 → 実態は「水槽の水流」と判明

詳細プラン: `~/.claude/plans/c-users-kite-documents-program-openclaw-recursive-petal.md`

## 運用モデル

既存 `OpenCClaw` と同じ **GitHub経由 → サーバーで git pull** 方式。
- Windows 側で編集 → `git push`
- サーバー側で `git pull && docker compose up -d`（`deploy/deploy.sh` が ssh 越しに自動化）

## 初回セットアップ

1. **GitHubリポジトリ作成 & push**（Windows側）:
   ```bash
   gh repo create kitepon-rgb/HomeAssistant --public --source=. --remote=origin --push
   ```
2. **サーバーで初回 clone**:
   ```bash
   ssh kite@192.168.1.2
   cd ~ && git clone https://github.com/kitepon-rgb/HomeAssistant.git homeassistant
   exit
   ```
3. **`.env.example` を `.env` にコピー**（Windows側、deploy.sh 用）— 既定値で動く
4. **`bash deploy/deploy.sh`**（Windows側）— サーバーで `git pull && docker compose pull && up -d` が走る
5. ブラウザで http://192.168.1.2:8123 を開き HA 初期セットアップ（Owner 作成）
6. 統合追加（HA UI → Settings → Devices & Services → Add Integration）:
   - Nature Remo（公式トークン要、`home.nature.global` で発行）
   - Tuya（SmartLife アカウント OAuth）
   - iRobot（BLID/パスワード要）
   - Google Cast（自動検出）
7. ベル統合用に HA UI の Profile → Long-Lived Access Tokens を発行
8. OpenClaw 側 `.env` に `HA_BASE_URL=http://192.168.1.2:8123` と `HA_TOKEN=<トークン>` を貼る

## 更新フロー（2回目以降）

```bash
# Windows 側で編集
git add ... && git commit -m "..." && git push
bash deploy/deploy.sh   # サーバーで git pull → compose up -d
```

## 連携対象デバイス（ネットワーク調査済み）

| 機器 | IP | HA統合 |
|---|---|---|
| Nature Remo | 192.168.1.6 | Nature Remo（公式組込） |
| Tuyaスマートプラグ ×3 | .8 / .12 / .20 | Tuya（公式組込） |
| iRobot ルンバ ×2 | .15 / .25 | iRobot（公式組込） |
| Google端末（Chromecast/Nest） | .37 | Google Cast（公式組込） |
| Brotherプリンタ | .5 | brother_printer（HACS、後付け候補） |
| Panasonicテレビ | .10 | Nature Remo IR経由（VIERA直接統合は要HTTP/UPnPテスト） |
| Espressif系不明機器 | .42 | Phase 1作業中に物理確認 |
| Tuyaスマートプラグ残2台用途 | - | SmartLife側の登録名で判別 |

## ネットワーク構成

- HAは `network_mode: host` で動く（mDNS/Tuya UDPブロードキャスト探索のため）
- HAアクセスは `http://192.168.1.2:8123`（**ローカルネットワーク内のみ**、Caddyリバースプロキシ配下には置かない・外部公開しない）

## コンテナランタイム（サーバー実情）

サーバー (192.168.1.2) は **Ubuntu Server LTS + Docker Engine rootful**（apt 公式 docker-ce）。既存の Caddy / Nextcloud / OpenClaw MCP / その他コンテナが稼働している。HA もホームディレクトリ (`/home/kite/homeassistant/`) に置いて `docker compose` で起動する。

- `network_mode: host` は Docker rootful でも動く（Nature Remo mDNS / Tuya UDP / SSDP 全部受信できる）
- `privileged: true` と `/run/dbus` mount は利用可能だが、現状の HA 用途では不要。USB/Bluetooth が必要になったら有効化を検討
- Ubuntu は **AppArmor** 環境のため bind mount への `:Z` 付与は不要（SELinux 固有機能）
- `restart: unless-stopped` は Docker daemon 起動時に自動再起動する（OS 再起動時も docker.service 経由で自動起動）

## デプロイ

```bash
bash deploy/deploy.sh
```

`git pull` で構成を同期し、リモートで `${COMPOSE_CMD} pull && up -d` を実行する。
`.storage/`・ログ・DB・`.env`・`secrets.yaml` は同期対象外（リモート側で永続化）。

## サーバーリプレイス（2026-04-28 移行完了）

192.168.1.2 は Bazzite + rootless Podman → **Ubuntu Server LTS + Docker Engine rootful** へ移行完了（2026-04-28）。サーバー固有値は `.env` で上書き可能（`HA_SERVER` / `HA_REMOTE_DIR` / `COMPOSE_CMD`）。

`docker-compose.yml` 本体に手を入れる必要があるのは USB/Bluetooth pass-through で privileged を有効化する時くらい。

## 関連プロジェクト

- [OpenClaw](../OpenClaw/) — ベル本体（AI秘書）。家電操作の道具 `home_control` を当HAに対して呼ぶ
