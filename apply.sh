#!/usr/bin/env bash
# apply.sh — pilih versi Xray → clone/unduh → apply patch OneRing
# Developer: JhopanStore  |  https://github.com/jhopan/jhopanstore-onering
#
#   bash apply.sh
#   bash apply.sh v26.6.22
#   bash apply.sh --force v26.6.22
#   bash apply.sh --list
#   XRX_VER=v26.6.22 bash apply.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

OUT_DIR="${OUT_DIR:-Xray-core}"
PATCH="${PATCH:-onering.patch}"
MARKER="func ParseOneRing"
DEFAULT_VER="v26.6.22"
FORCE=0
XRX_VER="${XRX_VER:-}"

usage() {
  cat <<'EOF'
usage:
  bash apply.sh [options] [version]

options:
  --force, -f     re-clone even if tree exists
  --list, -l      list recent Xray-core tags
  --help, -h

version:
  Xray tag, e.g. v26.6.22  (default: v26.6.22)

env:
  XRX_VER=...  OUT_DIR=...  PATCH=...
EOF
}

list_tags() {
  echo "[*] recent Xray-core tags..."
  if command -v gh >/dev/null 2>&1; then
    gh api repos/XTLS/Xray-core/tags --jq '.[].name' 2>/dev/null | head -20 || true
  fi
  git ls-remote --tags --refs https://github.com/XTLS/Xray-core.git 2>/dev/null \
    | awk -F/ '{print $NF}' | sort -V | tail -20 || true
}

while [ $# -gt 0 ]; do
  case "$1" in
    --force|-f) FORCE=1; shift ;;
    --list|-l) list_tags; exit 0 ;;
    --help|-h) usage; exit 0 ;;
    -*)
      echo "[-] unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *) XRX_VER="$1"; shift ;;
  esac
done

XRX_VER="${XRX_VER:-$DEFAULT_VER}"
case "$XRX_VER" in
  v*) ;;
  *) XRX_VER="v$XRX_VER" ;;
esac

if [ ! -f "$PATCH" ]; then
  echo "[-] missing $PATCH" >&2
  exit 1
fi

need_clone=0
if [ "$FORCE" -eq 1 ]; then
  need_clone=1
elif [ ! -d "$OUT_DIR/.git" ]; then
  need_clone=1
else
  pinned=""
  [ -f "$OUT_DIR/.onering-base" ] && pinned="$(tr -d '\r\n' < "$OUT_DIR/.onering-base")"
  cur="$(git -C "$OUT_DIR" describe --tags --exact-match 2>/dev/null || true)"
  if [ -n "$pinned" ] && [ "$pinned" != "$XRX_VER" ]; then
    echo "[*] base pin $pinned → $XRX_VER (re-clone)"
    need_clone=1
  elif [ -n "$cur" ] && [ "$cur" != "$XRX_VER" ] && [[ "$cur" != onering-* ]]; then
    echo "[*] tree $cur ≠ $XRX_VER (re-clone)"
    need_clone=1
  fi
fi

if [ "$need_clone" -eq 1 ]; then
  echo "[*] clone Xray-core $XRX_VER → $OUT_DIR"
  rm -rf "$OUT_DIR"
  if ! git clone --depth 1 --branch "$XRX_VER" https://github.com/XTLS/Xray-core.git "$OUT_DIR"; then
    echo "[-] clone gagal. cek tag: bash apply.sh --list" >&2
    exit 1
  fi
else
  echo "[*] $OUT_DIR ada (base $XRX_VER) — skip clone"
fi

echo "$XRX_VER" > "$OUT_DIR/.onering-base"

CFG="$OUT_DIR/transport/internet/tls/config.go"
if [ ! -f "$CFG" ]; then
  echo "[-] missing $CFG" >&2
  exit 1
fi

if grep -q "$MARKER" "$CFG"; then
  echo "[+] OneRing already applied. skip patch."
else
  echo "[*] apply OneRing → $PATCH"
  if ! git -C "$OUT_DIR" apply --whitespace=nowarn "$ROOT/$PATCH"; then
    echo "[-] git apply failed for base $XRX_VER" >&2
    echo "    try: git -C $OUT_DIR apply --reject $ROOT/$PATCH" >&2
    exit 1
  fi
  grep -q "$MARKER" "$CFG" || { echo "[-] marker missing after patch" >&2; exit 1; }
  echo "[+] OneRing patch applied"
fi

echo "[+] core ready: $ROOT/$OUT_DIR  (base=$XRX_VER)"
echo "[+] next: bash build.sh [target]  |  bash build.sh --ver $XRX_VER all"
