# dify 環境移行メモ

「検証エージェント」アプリ + ナレッジ2件を別マシンへ複製するための一式。

- **Dify バージョン**: 1.16.0（移行先も必ず一致させる）
- **ベクトルDB**: Weaviate 1.27.0
- **埋め込み**: Ollama `bge-m3`（`http://host.docker.internal:11434`）
- **特殊対応**: sandbox Code ノードで `tshark` を使うためカスタムイメージ + seccomp 緩和

移行対象:

| レイヤ | 中身 | このリポジトリ |
|---|---|---|
| データ | DB(アプリ/ナレッジ/チャンク)・アップロードファイル・ベクトル・プラグイン | `data/dify_bundle_*.tar.gz` |
| 設定 | override compose・カスタム Dockerfile・変更済み設定 | `config/` |
| 環境変数 | `.env`（標準の .env.example と同一） | `.env.template` |
| イメージ | 公開分は pull／`dify-sandbox-tshark` のみ自前 | 同梱せず（下記手順で build） |

---

## 移行手順（移行先マシン）

### 0. 前提

- Docker / Docker Compose
- Dify 本体 checkout: `git clone https://github.com/langgenius/dify && cd dify && git checkout 1.16.0`（`docker/` 一式が要る）
- Ollama が動いていて `bge-m3` が pull 済み、移行先から到達可能なこと

### 1. このリポジトリを配置

```bash
git clone https://github.com/zen-1/memo.git dify-memo
cd dify-memo
```

### 2. 設定ファイルを dify/docker/ へ反映

```bash
DIFY_DOCKER=/path/to/dify/docker

cp config/docker-compose.override.yaml           "$DIFY_DOCKER"/
cp config/sandbox-tshark/Dockerfile              "$DIFY_DOCKER"/sandbox-tshark/Dockerfile   # mkdir -p 先に
cp config/ssrf_proxy/squid.conf.template         "$DIFY_DOCKER"/ssrf_proxy/
cp config/volumes/sandbox/conf/config.yaml       "$DIFY_DOCKER"/volumes/sandbox/conf/
cp config/volumes/sandbox/dependencies/python-requirements.txt \
                                                 "$DIFY_DOCKER"/volumes/sandbox/dependencies/
cp .env.template                                 "$DIFY_DOCKER"/.env
cp dify-bundle.sh                                "$DIFY_DOCKER"/
```

> `.env` は Dify 標準の `.env.example` と同一。`SECRET_KEY`（空）や `DB_PASSWORD` 等の
> デフォルト値は **移行元と一致させる必要がある**（DB内の暗号化認証情報と
> `storage/privkeys` の復号に使われるため）。勝手に変えない。

### 3. カスタム sandbox イメージをビルド

```bash
cd "$DIFY_DOCKER"
docker build -t dify-sandbox-tshark:0.2.15 ./sandbox-tshark
```

（完全オフラインなら移行元で `./dify-bundle.sh images` → 移行先で `./dify-bundle.sh load`）

### 4. データを復元

```bash
cd "$DIFY_DOCKER"
./dify-bundle.sh import /path/to/dify-memo/data/dify_bundle_XXXX.tar.gz
```

`volumes/{db/data,app/storage,weaviate,plugin_daemon,sandbox}` を展開して `docker compose up -d`。

### 5. 確認

1. `docker compose ps` 全て up
2. Web UI ログイン（初期アカウントは移行元のものが引き継がれる）
3. 設定 > モデルプロバイダー で Ollama の Base URL を確認・必要なら修正
4. 「検証エージェント」を開き、ナレッジ検索が retrieval できるか実行テスト
5. pcap を使う Code ノードなら tshark が動くか確認

---

## バンドルの作り直し（移行元）

```bash
cd /path/to/dify/docker
./dify-bundle.sh export --lean data/dify_bundle_$(date +%Y%m%d).tar.gz
# 一時的に docker compose down → up（数十秒のダウンタイム）
```

- `--lean`: 過去会話の添付 `*.pcap`（約260MB）を除外。アプリ・ナレッジ・ベクトルは維持。→ 20〜30MB
- 外すと過去会話のファイルも含む（約250MB）

---

## 注意

- `data/*.tar.gz` には DB がまるごと入る（ナレッジ本文、会話ログ、暗号化された認証情報）。
  リポジトリは **private 必須**。
- 実 `.env` はコミットしない（`.gitignore` 済み）。標準値のままなら `.env.template` で足りる。
