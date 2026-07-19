#!/usr/bin/env bash
# apply.sh — fetch Xray-core base + apply OneRing patch (idempotent)
# Core only. No AAR. Result: ./Xray-core ready to build for any GOOS/GOARCH.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

XRX_VER="${XRX_VER:-v26.6.22}"
OUT_DIR="${OUT_DIR:-Xray-core}"
PATCH="${PATCH:-onering.patch}"
MARKER="func ParseOneRing"

if [ ! -f "$PATCH" ]; then
  echo "[-] missing $PATCH in $ROOT" >&2
  exit 1
fi

if [ ! -d "$OUT_DIR/.git" ]; then
  echo "[*] clone Xray-core $XRX_VER → $OUT_DIR"
  rm -rf "$OUT_DIR"
  git clone --depth 1 --branch "$XRX_VER" https://github.com/XTLS/Xray-core.git "$OUT_DIR"
else
  echo "[*] $OUT_DIR exists"
  cur="$(git -C "$OUT_DIR" describe --tags --exact-match 2>/dev/null || true)"
  # onering-v* tags sit ON TOP of base — OK if ParseOneRing present
  if [ -n "$cur" ] && [ "$cur" != "$XRX_VER" ] && [[ "$cur" != onering-* ]]; then
    echo "[!] tree tag=$cur expected=$XRX_VER — re-clone or set XRX_VER" >&2
  fi
fi

CFG="$OUT_DIR/transport/internet/tls/config.go"
if [ ! -f "$CFG" ]; then
  echo "[-] missing $CFG" >&2
  exit 1
fi

if grep -q "$MARKER" "$CFG"; then
  echo "[+] OneRing already applied (ParseOneRing found). skip patch."
else
  echo "[*] apply $PATCH"
  # try from OUT_DIR first (relative), then absolute
  if ! git -C "$OUT_DIR" apply --whitespace=nowarn "$ROOT/$PATCH"; then
    echo "[-] git apply failed. try: git apply --reject $ROOT/$PATCH" >&2
    exit 1
  fi
  if ! grep -q "$MARKER" "$CFG"; then
    echo "[-] patch applied but marker missing" >&2
    exit 1
  fi
  echo "[+] patch applied"
fi

echo "[+] core ready: $ROOT/$OUT_DIR"
echo "[+] next: bash build.sh [target]"
echo "    targets: linux-arm64 | linux-amd64 | windows-amd64 | windows-arm64 | all"
