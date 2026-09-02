# dify 環境移行メモ

「検証エージェント」アプリ + ナレッジ2件を別マシンへ複製するための一式（`main` ブランチ）。

- **Dify バージョン**: 1.16.0
- **ベクトルDB**: Weaviate 1.27.0
- **埋め込み**: Ollama `bge-m3`（`http://host.docker.internal:11434`）
- **特殊対応**: sandbox Code ノードで `tshark` を使うためカスタムイメージ + seccomp 緩和

## 構成

```
docker/               動作可能な docker/ 一式（Dify 本体 clone 不要）
  ├── docker-compose.yaml, .env.example, nginx/, ssrf_proxy/ ...  （1.16.0 相当）
  ├── docker-compose.override.yaml       tshark 用の image 差し替え + seccomp 緩和 + host-gateway
  ├── ssrf_proxy/squid.conf.template     変更済み（cache deny all）
  ├── sandbox-tshark/Dockerfile          dify-sandbox に tshark を入れるカスタムイメージ
  └── dify-bundle.sh                     データ/イメージの export・import
data/
  └── dify_bundle.tar.gz                 DB・アップロード・ベクトル・プラグイン・.env
                                         + volumes/sandbox（変更済み config.yaml / scapy,pycrate）
                                         lean で ~20MB
dify-restore.sh                          移行先での一括セットアップ
```

> `volumes/`（DB・アップロード・ベクトル・プラグイン・sandbox 設定）と実 `.env` は
> data バンドルから復元されるのでリポジトリには入れていない。

---

## 移行手順（移行先マシン）

### 0. 前提

- Docker / Docker Compose
- Ollama 起動済み、`bge-m3` pull 済み、移行先から到達可能

### 1. 取得して復元

```bash
git clone -b main https://github.com/zen-1/memo.git dify-memo
cd dify-memo
./dify-restore.sh
```

`dify-restore.sh` がやること:

1. バージョン確認（`dify-api:1.16.0`）
2. `.env` を `.env.example` から作成（標準値。**変更しない** — 下記理由）
3. `dify-sandbox-tshark:0.2.15` をビルド（既にあればスキップ）
4. `data/dify_bundle.tar.gz` を `dify-bundle.sh import` で復元
   （stack down → `volumes/{db/data,app/storage,weaviate,plugin_daemon,sandbox}` 展開 → up）
5. 確認手順を表示

オプション: `--bundle FILE` `--no-build` `--no-import` `--force-env` `--docker-dir DIR` `--help`

完全オフラインなら移行元で `docker/dify-bundle.sh images` → 移行先で `docker/dify-bundle.sh load`、
その上で `./dify-restore.sh --no-build`。

### 2. 確認

```bash
cd docker && docker compose ps        # 全て up
```

1. Web UI にログイン（移行元のアカウントが引き継がれる）
2. 設定 > モデルプロバイダー > Ollama の Base URL を確認・必要なら修正
3. 「検証エージェント」を実行しナレッジ検索が retrieval できるか
4. pcap を使う Code ノードがあれば tshark 動作も確認

---

## なぜ .env を変えてはいけないか

Dify 標準の `.env.example` のまま運用している。`SECRET_KEY`（空）、`DB_PASSWORD`、
`WEAVIATE_API_KEY` などのデフォルト値は **移行元と一致していないと**、DB 内の
暗号化済み認証情報や `storage/privkeys` を復号できず、モデルプロバイダー等が壊れる。
本番運用するなら移行後に全部ローテーションすること。

---

## バンドルの作り直し（移行元）

```bash
cd /path/to/dify/docker        # 実運用中の docker/
./dify-bundle.sh export --lean /path/to/dify-memo/data/dify_bundle.tar.gz
```

- `--lean`: 過去会話の添付 `*.pcap`（約260MB）を除外。アプリ・ナレッジ・ベクトルは維持 → ~20MB
- 一時的に `docker compose down → up`（数十秒のダウンタイム）

## 注意

- `data/*.tar.gz` は DB まるごと（ナレッジ本文・会話ログ・暗号化認証情報）。**private 必須**。
- 実 `.env` はコミットしない（`.gitignore` 済み）。
