#!/usr/bin/env bash
# build.sh — build portable OneRing core binary (any GOOS/GOARCH)
# Usage:
#   bash build.sh                 # default: host
#   bash build.sh linux-arm64
#   bash build.sh linux-amd64
#   bash build.sh windows-amd64
#   bash build.sh windows-arm64
#   bash build.sh all
#   bash build.sh custom linux arm GOARM=7   # advanced
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

SRC="${SRC:-Xray-core}"
DIST="${DIST:-dist}"
LDFLAGS="${LDFLAGS:--s -w}"
MARKER="func ParseOneRing"

if [ ! -d "$SRC" ]; then
  echo "[-] $SRC missing. run: bash apply.sh" >&2
  exit 1
fi
if ! grep -q "$MARKER" "$SRC/transport/internet/tls/config.go" 2>/dev/null; then
  echo "[-] OneRing patch not in $SRC. run: bash apply.sh" >&2
  exit 1
fi

mkdir -p "$DIST"

build_one() {
  local goos="$1" goarch="$2" out="$3"
  shift 3 || true
  # remaining: extra env like GOARM=7
  local extra=("$@")
  echo "[*] $out  ($goos/$goarch ${extra[*]:-})"
  (
    cd "$SRC"
    env CGO_ENABLED=0 GOOS="$goos" GOARCH="$goarch" "${extra[@]}" \
      go build -trimpath -ldflags="$LDFLAGS" -o "$ROOT/$DIST/$out" ./main
  )
  ls -lh "$DIST/$out"
}

target="${1:-host}"

case "$target" in
  host)
    # detect host
    goos="$(go env GOOS)"
    goarch="$(go env GOARCH)"
    ext=""
    [ "$goos" = "windows" ] && ext=".exe"
    build_one "$goos" "$goarch" "xray.${goos}.${goarch}.onering${ext}"
    ;;
  linux-arm64)
    build_one linux arm64 xray.linux.arm64.onering
    ;;
  linux-amd64)
    build_one linux amd64 xray.linux.amd64.onering
    ;;
  linux-arm)
    # 32-bit ARM (e.g. old OpenWrt) — softfloat often safer for routers
    build_one linux arm xray.linux.armv7.onering GOARM=7
    ;;
  windows-amd64)
    build_one windows amd64 xray.windows.amd64.onering.exe
    ;;
  windows-arm64)
    build_one windows arm64 xray.windows.arm64.onering.exe
    ;;
  all)
    build_one linux arm64 xray.linux.arm64.onering
    build_one linux amd64 xray.linux.amd64.onering
    build_one windows amd64 xray.windows.amd64.onering.exe
    ;;
  custom)
    # bash build.sh custom <goos> <goarch> [extra env...]
    shift
    goos="${1:?goos}"; shift
    goarch="${1:?goarch}"; shift
    ext=""; [ "$goos" = "windows" ] && ext=".exe"
    build_one "$goos" "$goarch" "xray.${goos}.${goarch}.onering${ext}" "$@"
    ;;
  *)
    echo "usage: bash build.sh [host|linux-arm64|linux-amd64|linux-arm|windows-amd64|windows-arm64|all|custom ...]" >&2
    exit 2
    ;;
esac

echo "[+] done → $ROOT/$DIST/"
ls -lh "$DIST" | sed -n '1,20p'
