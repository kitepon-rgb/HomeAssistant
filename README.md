# HomeAssistant

ベル（[OpenClaw](../OpenClaw/)）の家電操作レイヤーとして、Home AssistantをLinuxサーバー（192.168.1.2）にDockerで立てる構成。

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
| `deploy/deploy.sh` | Windows→Linuxサーバーへ rsync+起動 |
| `.env` | デプロイ先情報（Git管理外、`.env.example` 参照） |

## 初回セットアップ

1. `.env.example` を `.env` にコピー（既定値で動くはず：`kite@192.168.1.2:/home/kite/homeassistant` + `podman compose`）
2. Linuxサーバー（192.168.1.2）に SSH 鍵で passwordless login できることを確認 (`ssh kite@192.168.1.2 'echo ok'`)
3. `bash deploy/deploy.sh` を実行（リモート側ディレクトリは rsync が自動作成）
4. ブラウザで http://192.168.1.2:8123 を開き HA 初期セットアップ（Owner 作成）
5. 統合追加（HA UI → Settings → Devices & Services → Add Integration）:
   - Nature Remo（公式トークン要、`home.nature.global` で発行）
   - Tuya（SmartLife アカウント OAuth）
   - iRobot（BLID/パスワード要）
   - Google Cast（自動検出）
6. ベル統合用に HA UI の Profile → Long-Lived Access Tokens を発行
7. OpenClaw 側 `.env` に `HA_BASE_URL=http://192.168.1.2:8123` と `HA_TOKEN=<トークン>` を貼る

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

サーバー (192.168.1.2) は **Bazzite (immutable Fedora atomic) + rootless Podman 5.8.2**。既存の Caddy / Nextcloud / OpenClaw MCP / その他 10 個のコンテナが全部 rootless で稼働している。HA も同じ流儀で、ホームディレクトリ (`/home/kite/homeassistant/`) に置いて `podman compose` で起動する。

- `network_mode: host` は rootless でも動く（Nature Remo mDNS / Tuya UDP / SSDP 全部受信できる）。8123 は非特権ポートなので問題なし
- `privileged: true` と `/run/dbus` mount は rootless では無効化。USB/Bluetooth が必要になったら rootful 切替を別途検討
- SELinux は **Permissive** モードなので bind mount への `:Z` 付与は不要
- `podman compose` は内部で `docker-compose` plugin (5.1.2) を呼び出す Bazzite の流儀で動く

Docker に切替たい場合は `.env` で `COMPOSE_CMD="docker compose"` を指定する。

## デプロイ

```bash
bash deploy/deploy.sh
```

`rsync` で構成を同期し、リモートで `${COMPOSE_CMD} pull && up -d` を実行する。
`.storage/`・ログ・DB・`.env`・`secrets.yaml` は同期対象外（リモート側で永続化）。

## 関連プロジェクト

- [OpenClaw](../OpenClaw/) — ベル本体（AI秘書）。家電操作の道具 `home_control` を当HAに対して呼ぶ
