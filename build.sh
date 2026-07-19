#!/usr/bin/env bash
# build.sh — build portable OneRing core binary
# Usage:
#   bash build.sh                         # host, tree harus sudah apply
#   bash build.sh linux-arm64
#   bash build.sh all
#   bash build.sh --ver v26.6.22 all      # pilih versi → clone → apply → build
#   bash build.sh -v 26.6.22 windows-amd64
#   bash build.sh --force --ver v26.7.1 all
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

SRC="${SRC:-Xray-core}"
DIST="${DIST:-dist}"
LDFLAGS="${LDFLAGS:--s -w}"
MARKER="func ParseOneRing"
XRX_VER=""
FORCE_APPLY=0
TARGET=""
TARGETS=()

usage() {
  cat <<'EOF'
usage:
  bash build.sh [options] [target]

targets:
  host | linux-arm64 | linux-amd64 | linux-arm
  windows-amd64 | windows-arm64 | all
  custom <goos> <goarch> [extra env...]

options:
  --ver, -v VER   pilih versi Xray → clone/unduh + apply OneRing dulu
  --force, -f     re-clone base (pakai dengan --ver)
  --help, -h

examples:
  bash build.sh --ver v26.6.22 linux-arm64
  bash build.sh -v 26.6.22 all
  bash build.sh --force --ver v26.7.1 windows-amd64
  bash build.sh host
EOF
}

# parse args: options then target
while [ $# -gt 0 ]; do
  case "$1" in
    --ver|-v)
      shift
      XRX_VER="${1:?version required after --ver}"
      shift
      ;;
    --force|-f) FORCE_APPLY=1; shift ;;
    --help|-h) usage; exit 0 ;;
    custom)
      TARGETS=("$@")
      break
      ;;
    -*)
      echo "[-] unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      TARGETS+=("$1")
      shift
      ;;
  esac
done

if [ ${#TARGETS[@]} -eq 0 ]; then
  TARGETS=(host)
fi

# if version requested → apply first
if [ -n "$XRX_VER" ]; then
  apply_args=("$XRX_VER")
  [ "$FORCE_APPLY" -eq 1 ] && apply_args=(--force "$XRX_VER")
  echo "[*] ensure base $XRX_VER + OneRing"
  bash "$ROOT/apply.sh" "${apply_args[@]}"
fi

if [ ! -d "$SRC" ]; then
  echo "[-] $SRC missing. jalankan: bash apply.sh [version]" >&2
  echo "    atau: bash build.sh --ver v26.6.22 all" >&2
  exit 1
fi
if ! grep -q "$MARKER" "$SRC/transport/internet/tls/config.go" 2>/dev/null; then
  echo "[-] OneRing patch belum di $SRC. jalankan: bash apply.sh" >&2
  exit 1
fi

base_pin=""
[ -f "$SRC/.onering-base" ] && base_pin="$(tr -d '\r\n' < "$SRC/.onering-base")"
[ -n "$base_pin" ] && echo "[*] building base=$base_pin"

mkdir -p "$DIST"

build_one() {
  local goos="$1" goarch="$2" out="$3"
  shift 3 || true
  local extra=("$@")
  echo "[*] $out  ($goos/$goarch ${extra[*]:-})"
  (
    cd "$SRC"
    # shellcheck disable=SC2086
    env CGO_ENABLED=0 GOOS="$goos" GOARCH="$goarch" ${extra[@]+"${extra[@]}"} \
      go build -trimpath -ldflags="$LDFLAGS" -o "$ROOT/$DIST/$out" ./main
  )
  ls -lh "$DIST/$out"
}

do_target() {
  local target="$1"
  shift || true
  case "$target" in
    host)
      local goos goarch ext=""
      goos="$(go env GOOS)"
      goarch="$(go env GOARCH)"
      [ "$goos" = "windows" ] && ext=".exe"
      build_one "$goos" "$goarch" "xray.${goos}.${goarch}.onering${ext}"
      ;;
    linux-arm64) build_one linux arm64 xray.linux.arm64.onering ;;
    linux-amd64) build_one linux amd64 xray.linux.amd64.onering ;;
    linux-arm)   build_one linux arm xray.linux.armv7.onering GOARM=7 ;;
    windows-amd64) build_one windows amd64 xray.windows.amd64.onering.exe ;;
    windows-arm64) build_one windows arm64 xray.windows.arm64.onering.exe ;;
    all)
      build_one linux arm64 xray.linux.arm64.onering
      build_one linux amd64 xray.linux.amd64.onering
      build_one windows amd64 xray.windows.amd64.onering.exe
      ;;
    custom)
      local goos="${1:?goos}"; shift
      local goarch="${1:?goarch}"; shift
      local ext=""; [ "$goos" = "windows" ] && ext=".exe"
      build_one "$goos" "$goarch" "xray.${goos}.${goarch}.onering${ext}" "$@"
      ;;
    *)
      echo "[-] unknown target: $target" >&2
      usage >&2
      exit 2
      ;;
  esac
}

# TARGETS may be: all | linux-arm64 | custom linux arm GOARM=7
if [ "${TARGETS[0]}" = "custom" ]; then
  do_target "${TARGETS[@]}"
else
  for t in "${TARGETS[@]}"; do
    do_target "$t"
  done
fi

echo "[+] done → $ROOT/$DIST/"
[ -n "$base_pin" ] && echo "[+] base Xray $base_pin + OneRing"
ls -lh "$DIST" | sed -n '1,20p'
