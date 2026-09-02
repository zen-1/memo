#!/usr/bin/env bash
#
# dify-restore.sh — 移行先マシンで実行。イメージビルド → データ復元 を一括。
#
#   ./dify-restore.sh [options]
#
# このリポジトリに動作可能な docker/ 一式が入っているので、Dify 本体の clone は不要。
#
# options:
#   --docker-dir DIR    使う docker/ ディレクトリ (既定: このスクリプト隣の ./docker)
#   --bundle FILE       データバンドル tar.gz (既定: ./data/ 内の最新)
#   --no-build          dify-sandbox-tshark イメージのビルドをスキップ
#   --no-import         データ復元をスキップ
#   --force-env         .env を .env.example から作り直す (既定: 既存を温存)
#
# 前提: Docker / Docker Compose、Ollama 起動済み + bge-m3 pull 済み(到達可能)。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$SCRIPT_DIR/docker"
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
    --docker-dir) DOCKER_DIR="${2:?}"; shift 2;;
    --bundle)     BUNDLE="${2:?}"; shift 2;;
    --no-build)   DO_BUILD=0; shift;;
    --no-import)  DO_IMPORT=0; shift;;
    --force-env)  FORCE_ENV=1; shift;;
    -h|--help)    awk 'NR>1 && /^#/{sub(/^# ?/,"");print;next} NR>1{exit}' "$0"; exit 0;;
    *) die "unknown arg: $1";;
  esac
done

DOCKER_DIR="$(cd "$DOCKER_DIR" && pwd)" || die "docker ディレクトリが無い"
[ -f "$DOCKER_DIR/docker-compose.yaml" ] || die "docker-compose.yaml が無い: $DOCKER_DIR"

# ---- バージョン確認 ----
if grep -q "dify-api:${EXPECT_VERSION}" "$DOCKER_DIR/docker-compose.yaml"; then
  info "Dify バージョン: ${EXPECT_VERSION}"
else
  echo "!! docker-compose.yaml の dify-api タグが ${EXPECT_VERSION} ではありません。"
  echo "   移行元と不一致だと DB スキーマ差異で壊れます。続行=Enter / 中断=Ctrl-C"
  read -r _
fi

# ---- .env ----
if [ -f "$DOCKER_DIR/.env" ] && [ "$FORCE_ENV" -eq 0 ]; then
  info ".env は既存のものを温存 (作り直しは --force-env)"
else
  [ -f "$DOCKER_DIR/.env.example" ] || die ".env.example が無い"
  cp "$DOCKER_DIR/.env.example" "$DOCKER_DIR/.env"
  info ".env を .env.example から作成 (標準値。SECRET_KEY 空も含め移行元と一致必須 — 変えない)"
fi

# ---- カスタム sandbox イメージ ----
if [ "$DO_BUILD" -eq 1 ]; then
  if docker image inspect "$TSHARK_IMAGE" >/dev/null 2>&1; then
    info "$TSHARK_IMAGE は既に存在。ビルドをスキップ"
  else
    info "$TSHARK_IMAGE をビルド"
    docker build -t "$TSHARK_IMAGE" "$DOCKER_DIR/sandbox-tshark"
  fi
else
  info "ビルドをスキップ (--no-build)。オフラインなら ./docker/dify-bundle.sh load でイメージ投入を"
fi

# ---- データ復元 ----
if [ "$DO_IMPORT" -eq 1 ]; then
  if [ -z "$BUNDLE" ]; then
    BUNDLE="$(ls -t "$SCRIPT_DIR"/data/dify_bundle*.tar.gz 2>/dev/null | head -1 || true)"
  fi
  [ -n "$BUNDLE" ] && [ -f "$BUNDLE" ] || die "バンドルが見つからない。--bundle で指定してください"
  info "データ復元: $BUNDLE"
  DIFY_DOCKER_DIR="$DOCKER_DIR" bash "$DOCKER_DIR/dify-bundle.sh" import "$BUNDLE"
else
  info "データ復元をスキップ (--no-import)"
  info "後で: DIFY_DOCKER_DIR=$DOCKER_DIR $DOCKER_DIR/dify-bundle.sh import <bundle>"
fi

cat <<EOF

=== 完了。確認 ===
  docker compose -f "$DOCKER_DIR/docker-compose.yaml" ps      # 全て up か

1. Web UI にログイン (移行元のアカウントが引き継がれる)
2. 設定 > モデルプロバイダー > Ollama の Base URL を確認
   同一ホストに Ollama があれば http://host.docker.internal:11434 のまま / 別なら実URLへ
3. 「検証エージェント」を実行しナレッジ検索が retrieval できるか
4. pcap を使う Code ノードがあれば tshark 動作も確認
EOF
