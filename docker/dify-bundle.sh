#!/usr/bin/env bash
#
# dify-bundle.sh — 別環境へまるごと移すためのバンドル作成 / 復元
#
#   ./dify-bundle.sh export [--lean] [出力先.tar.gz]   … データ (DB/ファイル/ベクトル/.env)
#   ./dify-bundle.sh import <バンドル.tar.gz>
#   ./dify-bundle.sh images [出力先.tar.gz]           … Docker イメージ一式 (オフライン移行用)
#   ./dify-bundle.sh load   <イメージ.tar.gz>
#
# 移行先がインターネットに出られる場合: images/load は不要。
#   docker/ 一式をコピー → dify-sandbox-tshark をビルド → docker compose up -d で pull される。
#     docker build -t dify-sandbox-tshark:0.2.15 ./sandbox-tshark
# オフライン(air-gapped)の場合のみ images/load を使う (~1GB)。
#
# 対象: PostgreSQL データ / アップロードファイル / Weaviate / プラグイン / .env
# 前提: 移行元と移行先は同じ Dify バージョン (現在 1.16.0)
#
# --lean: 会話履歴の添付ファイル (*.pcap 等の大きい upload) を除外。
#         アプリ定義とナレッジ本体・ベクトルは維持される。数百MB→数十MB。
#
set -euo pipefail

# docker compose 一式のあるディレクトリ。スクリプトを dify/docker/ 直下に置くか、
# DIFY_DOCKER_DIR=/path/to/dify/docker で指定する。
DOCKER_DIR="${DIFY_DOCKER_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
if [ ! -f "$DOCKER_DIR/docker-compose.yaml" ]; then
  echo "docker-compose.yaml が見つかりません: $DOCKER_DIR" >&2
  echo "DIFY_DOCKER_DIR=/path/to/dify/docker を指定してください" >&2
  exit 1
fi
cd "$DOCKER_DIR"

# バンドルに含めるパス (docker/ からの相対)
PATHS=(
  volumes/db/data          # apps(DSL) / datasets / documents / segments / 暗号化された認証情報
  volumes/app/storage      # アップロード元ファイル・画像・テナント秘密鍵
  volumes/weaviate         # ベクトル (これを含めれば再インデックス不要)
  volumes/plugin_daemon    # インストール済みプラグイン (ollama 等)
  volumes/sandbox          # コード実行サンドボックスの依存・設定
  .env                     # SECRET_KEY を含む。無いと認証情報を復号できない
)

# 常に除外 (再生成される作業ディレクトリ・一時ファイル)
EXCLUDES=(
  --exclude='volumes/plugin_daemon/cwd'
  --exclude='volumes/app/storage/workflow-state-*.json'
  --exclude='volumes/app/storage/test_debug'
)

need_sudo() { [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null; }
SUDO=""; need_sudo && SUDO="sudo"

cmd_export() {
  local lean=0
  [ "${1:-}" = "--lean" ] && { lean=1; shift; }
  local out="${1:-dify_bundle_$(date +%Y%m%d_%H%M%S).tar.gz}"
  local excludes=("${EXCLUDES[@]}")
  if [ "$lean" -eq 1 ]; then
    excludes+=(--exclude='volumes/app/storage/upload_files/*/*.pcap')
    echo ">> lean モード: 会話添付の *.pcap を除外します"
  fi

  echo ">> スタックを停止します (整合性のため)"
  docker compose down

  echo ">> tar 作成: $out"
  local existing=()
  for p in "${PATHS[@]}"; do [ -e "$p" ] && existing+=("$p") || echo "   skip (無し): $p"; done
  $SUDO tar czf "$out" -C "$DOCKER_DIR" "${excludes[@]}" "${existing[@]}"
  need_sudo && $SUDO chown "$(id -u):$(id -g)" "$out"

  echo ">> スタックを再起動します"
  docker compose up -d

  echo
  echo "完了: $out  ($(du -h "$out" | cut -f1))"
  echo "移行先の docker/ 直下で:  ./dify-bundle.sh import $out"
}

cmd_import() {
  local bundle="${1:?バンドル .tar.gz を指定してください}"
  [ -f "$bundle" ] || { echo "見つかりません: $bundle" >&2; exit 1; }

  echo ">> スタックを停止します"
  docker compose down 2>/dev/null || true

  if [ -e volumes/db/data ] || [ -e volumes/app/storage ]; then
    echo "!! 既存の volumes/ が上書きされます。5秒以内に Ctrl-C で中断"
    sleep 5
  fi

  echo ">> 展開中..."
  $SUDO tar xzf "$bundle" -C "$DOCKER_DIR"

  echo ">> 起動します"
  docker compose up -d

  cat <<'EOF'

--- 復元後チェック ---
1. .env の SECRET_KEY がバンドル由来のものになっているか (認証情報の復号に必須)
2. Dify イメージのタグが移行元と一致しているか (docker-compose.yaml: 1.16.0)
3. 埋め込みモデル (ollama / bge-m3) のエンドポイントが移行先から到達可能か
   → 設定 > モデルプロバイダー で URL を確認・修正
4. アプリを開いてナレッジ検索ノードが retrieval できるか実行テスト
EOF
}

cmd_images() {
  local out="${1:-dify_images_$(date +%Y%m%d_%H%M%S).tar.gz}"
  local imgs
  imgs=$(docker compose config --images | sort -u)
  echo ">> 保存するイメージ:"; echo "$imgs" | sed 's/^/   /'
  echo ">> docker save -> gzip: $out (数分かかります)"
  # shellcheck disable=SC2086
  docker save $imgs | gzip > "$out"
  echo "完了: $out  ($(du -h "$out" | cut -f1))"
}

cmd_load() {
  local f="${1:?イメージ tar.gz を指定してください}"
  [ -f "$f" ] || { echo "見つかりません: $f" >&2; exit 1; }
  echo ">> docker load..."
  gunzip -c "$f" | docker load
}

case "${1:-}" in
  export) shift; cmd_export "$@";;
  import) shift; cmd_import "$@";;
  images) shift; cmd_images "$@";;
  load)   shift; cmd_load "$@";;
  *) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 1;;
esac
