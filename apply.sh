#!/usr/bin/env bash
# apply.sh — pilih versi Xray → clone/unduh → apply patch OneRing
# Usage:
#   bash apply.sh                 # default dari VERSION / v26.6.22
#   bash apply.sh v26.7.1         # unduh tag ini + apply
#   bash apply.sh --force v26.6.22
#   XRX_VER=v26.7.1 bash apply.sh
#   bash apply.sh --list          # list tag Xray terbaru (butuh network)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

OUT_DIR="${OUT_DIR:-Xray-core}"
PATCH="${PATCH:-onering.patch}"
MARKER="func ParseOneRing"
FORCE=0
XRX_VER="${XRX_VER:-}"

# default base from VERSION file if present
default_ver() {
  if [ -f VERSION ]; then
    sed -n 's/^base=xray-core //p' VERSION | head -1 | tr -d '\r'
  fi
}

usage() {
  cat <<'EOF'
usage:
  bash apply.sh [options] [version]

options:
  --force, -f     re-clone even if tree already exists
  --list, -l      list recent Xray-core tags from GitHub
  --help, -h      this help

version:
  Xray tag, e.g. v26.6.22  (default: VERSION file or v26.6.22)

env:
  XRX_VER=...     same as version arg
  OUT_DIR=...     tree dir (default Xray-core)
  PATCH=...       patch file (default onering.patch)
EOF
}

list_tags() {
  echo "[*] recent Xray-core tags (GitHub)..."
  if command -v gh >/dev/null 2>&1; then
    gh api repos/XTLS/Xray-core/tags --jq '.[].name' 2>/dev/null | head -20 || true
  fi
  if command -v git >/dev/null 2>&1; then
    git ls-remote --tags --refs https://github.com/XTLS/Xray-core.git 2>/dev/null \
      | awk -F/ '{print $NF}' | sort -V | tail -20
  fi
}

# parse args
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
    *)
      XRX_VER="$1"
      shift
      ;;
  esac
done

if [ -z "$XRX_VER" ]; then
  XRX_VER="$(default_ver)"
fi
XRX_VER="${XRX_VER:-v26.6.22}"
# allow 26.6.22 without leading v
case "$XRX_VER" in
  v*) ;;
  *) XRX_VER="v$XRX_VER" ;;
esac

if [ ! -f "$PATCH" ]; then
  echo "[-] missing $PATCH in $ROOT" >&2
  exit 1
fi

need_clone=0
if [ "$FORCE" -eq 1 ]; then
  need_clone=1
elif [ ! -d "$OUT_DIR/.git" ]; then
  need_clone=1
else
  cur="$(git -C "$OUT_DIR" describe --tags --exact-match 2>/dev/null || true)"
  # also try: origin tag / packed-refs shallow
  if [ -z "$cur" ]; then
    cur="$(git -C "$OUT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  fi
  # stored pin from last apply
  pinned=""
  [ -f "$OUT_DIR/.onering-base" ] && pinned="$(tr -d '\r\n' < "$OUT_DIR/.onering-base")"
  if [ -n "$pinned" ] && [ "$pinned" != "$XRX_VER" ]; then
    echo "[*] base pin $pinned → $XRX_VER (re-clone)"
    need_clone=1
  elif [ -n "$cur" ] && [ "$cur" != "$XRX_VER" ] && [[ "$cur" != onering-* ]] && [[ "$cur" != HEAD ]]; then
    echo "[*] tree tag/branch $cur ≠ $XRX_VER (re-clone)"
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
  echo "[+] OneRing already applied (ParseOneRing found). skip patch."
else
  echo "[*] apply OneRing patch → $PATCH"
  if ! git -C "$OUT_DIR" apply --whitespace=nowarn "$ROOT/$PATCH"; then
    echo "[-] git apply failed for base $XRX_VER" >&2
    echo "    upstream mungkin ubah parseServerName. edit manual / regenerate patch." >&2
    echo "    try: git -C $OUT_DIR apply --reject $ROOT/$PATCH" >&2
    exit 1
  fi
  if ! grep -q "$MARKER" "$CFG"; then
    echo "[-] patch applied but marker missing" >&2
    exit 1
  fi
  echo "[+] OneRing patch applied"
fi

echo "[+] core ready: $ROOT/$OUT_DIR  (base=$XRX_VER)"
echo "[+] next: bash build.sh [target]"
echo "    or:   bash build.sh --ver $XRX_VER all"
