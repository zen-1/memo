#!/usr/bin/env bash
#
# dify-restore.sh — 移行先マシンで実行。設定反映 → イメージビルド → データ復元 を一括。
#
#   ./dify-restore.sh --dify-docker /path/to/dify/docker [options]
#
# options:
#   --dify-docker DIR   dify の docker/ ディレクトリ (必須)
#   --bundle FILE       データバンドル tar.gz (既定: このスクリプト隣の data/ 内の最新)
#   --no-build          dify-sandbox-tshark イメージのビルドをスキップ
#   --no-import         データ復元をスキップ (設定反映とビルドのみ)
#   --force-env         既存の .env を上書きする (既定は温存)
#
# 前提: 移行先に Docker / Docker Compose、Dify 本体 checkout (同一バージョン),
#       Ollama 起動済み + bge-m3 pull 済み。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIFY_DOCKER=""
BUNDLE=""
DO_BUILD=1
DO_IMPORT=1
FORCE_ENV=0
EXPECT_VERSION="1.16.0"
TSHARK_IMAGE="dify-sandbox-tshark:0.2.15"

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo ">> $*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dify-docker) DIFY_DOCKER="${2:?}"; shift 2;;
    --bundle)      BUNDLE="${2:?}"; shift 2;;
    --no-build)    DO_BUILD=0; shift;;
    --no-import)   DO_IMPORT=0; shift;;
    --force-env)   FORCE_ENV=1; shift;;
    -h|--help)     awk 'NR>1 && /^#/{sub(/^# ?/,"");print;next} NR>1{exit}' "$0"; exit 0;;
    *) die "unknown arg: $1";;
  esac
done

[ -n "$DIFY_DOCKER" ] || die "--dify-docker を指定してください"
DIFY_DOCKER="$(cd "$DIFY_DOCKER" && pwd)" || die "ディレクトリが無い: $DIFY_DOCKER"
[ -f "$DIFY_DOCKER/docker-compose.yaml" ] || die "docker-compose.yaml が無い: $DIFY_DOCKER"
[ -d "$SCRIPT_DIR/config" ] || die "config/ が見つからない ($SCRIPT_DIR)"

# ---- バージョン確認 ----
if grep -q "dify-api:${EXPECT_VERSION}" "$DIFY_DOCKER/docker-compose.yaml"; then
  info "Dify バージョン一致: ${EXPECT_VERSION}"
else
  echo "!! docker-compose.yaml の dify-api タグが ${EXPECT_VERSION} ではありません。"
  echo "   移行元と不一致だと DB スキーマ差異で壊れます。続行するなら Enter / 中断は Ctrl-C"
  read -r _
fi

# ---- 1. 設定ファイル反映 ----
info "設定ファイルを $DIFY_DOCKER へコピー"
mkdir -p "$DIFY_DOCKER/sandbox-tshark" \
         "$DIFY_DOCKER/ssrf_proxy" \
         "$DIFY_DOCKER/volumes/sandbox/conf" \
         "$DIFY_DOCKER/volumes/sandbox/dependencies"

cp -v "$SCRIPT_DIR/config/docker-compose.override.yaml"                   "$DIFY_DOCKER/"
cp -v "$SCRIPT_DIR/config/sandbox-tshark/Dockerfile"                      "$DIFY_DOCKER/sandbox-tshark/"
cp -v "$SCRIPT_DIR/config/ssrf_proxy/squid.conf.template"                 "$DIFY_DOCKER/ssrf_proxy/"
cp -v "$SCRIPT_DIR/config/volumes/sandbox/conf/config.yaml"               "$DIFY_DOCKER/volumes/sandbox/conf/"
cp -v "$SCRIPT_DIR/config/volumes/sandbox/dependencies/python-requirements.txt" \
                                                                         "$DIFY_DOCKER/volumes/sandbox/dependencies/"

if [ -f "$DIFY_DOCKER/.env" ] && [ "$FORCE_ENV" -eq 0 ]; then
  info ".env は既存のものを温存 (上書きは --force-env)"
elif [ -f "$SCRIPT_DIR/.env.template" ]; then
  cp -v "$SCRIPT_DIR/.env.template" "$DIFY_DOCKER/.env"
  info ".env.template を .env として配置 (標準値。SECRET_KEY 空も含め移行元と一致必須)"
else
  echo "!! .env.template が無い。dify の .env.example から手動で用意してください"
fi

# ---- 2. カスタム sandbox イメージ ----
if [ "$DO_BUILD" -eq 1 ]; then
  if docker image inspect "$TSHARK_IMAGE" >/dev/null 2>&1; then
    info "$TSHARK_IMAGE は既に存在。ビルドをスキップ"
  else
    info "$TSHARK_IMAGE をビルド"
    docker build -t "$TSHARK_IMAGE" "$DIFY_DOCKER/sandbox-tshark"
  fi
else
  info "ビルドをスキップ (--no-build)。オフラインなら dify-bundle.sh load でイメージ投入を"
fi

# ---- 3. データ復元 ----
if [ "$DO_IMPORT" -eq 1 ]; then
  if [ -z "$BUNDLE" ]; then
    BUNDLE="$(ls -t "$SCRIPT_DIR"/data/dify_bundle*.tar.gz 2>/dev/null | head -1 || true)"
  fi
  [ -n "$BUNDLE" ] && [ -f "$BUNDLE" ] || die "バンドルが見つからない。--bundle で指定してください"
  info "データ復元: $BUNDLE"
  DIFY_DOCKER_DIR="$DIFY_DOCKER" bash "$SCRIPT_DIR/dify-bundle.sh" import "$BUNDLE"
else
  info "データ復元をスキップ (--no-import)"
  info "後で: cd $DIFY_DOCKER && DIFY_DOCKER_DIR=$DIFY_DOCKER ./dify-bundle.sh import <bundle>"
fi

cat <<EOF

=== 完了。確認 ===
  docker compose -f "$DIFY_DOCKER/docker-compose.yaml" ps      # 全て up か

1. Web UI にログイン (移行元のアカウントが引き継がれる)
2. 設定 > モデルプロバイダー > Ollama の Base URL を確認
   同一ホストに Ollama があれば http://host.docker.internal:11434 のまま / 別なら実URLへ
3. 「検証エージェント」を実行しナレッジ検索が retrieval できるか
4. pcap を使う Code ノードがあれば tshark 動作も確認
EOF
