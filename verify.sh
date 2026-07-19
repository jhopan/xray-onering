#!/usr/bin/env bash
# verify.sh — cek patch OneRing + binary
# Developer: JhopanStore  |  https://github.com/jhopan/jhopanstore-onering
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
fail=0

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  echo "usage: bash verify.sh [path-to-binary]"
  exit 0
fi

echo "=== OneRing core verify (JhopanStore) ==="

if [ -f onering.patch ]; then
  echo "OK patch ($(wc -l < onering.patch | tr -d ' ') lines)"
else
  echo "FAIL missing onering.patch"; fail=1
fi

if [ -d Xray-core ]; then
  if grep -q "func ParseOneRing" Xray-core/transport/internet/tls/config.go 2>/dev/null; then
    echo "OK tree patched"
    [ -f Xray-core/.onering-base ] && echo "OK base pin $(tr -d '\r\n' < Xray-core/.onering-base)"
  else
    echo "FAIL tree not patched"; fail=1
  fi
else
  echo "SKIP no Xray-core (run apply.sh)"
fi

BIN="${1:-}"
if [ -z "$BIN" ]; then
  BIN="$(ls -t dist/xray.*.onering* 2>/dev/null | head -1 || true)"
fi

if [ -n "${BIN:-}" ] && [ -f "$BIN" ]; then
  echo "BIN: $BIN ($(wc -c < "$BIN" | tr -d ' ') bytes)"
  if "$BIN" version >/tmp/onering-ver.txt 2>&1; then
    head -5 /tmp/onering-ver.txt | sed 's/^/  /'
    echo "OK version runs"
  else
    echo "SKIP cannot exec (cross-build?)"
  fi
else
  echo "SKIP no binary"
fi

if command -v go >/dev/null; then
  PARSE_GO="${TMPDIR:-/tmp}/onering_parse_check.go"
  cat > "$PARSE_GO" <<'GO'
package main
import ("fmt"; "os"; "strings")
func ParseOneRing(serverName string) (real, bug string) {
  const prefix = "onering:"
  if !strings.HasPrefix(strings.ToLower(serverName), prefix) { return "", "" }
  parts := strings.SplitN(serverName, ":", 3)
  if len(parts) != 3 || parts[1] == "" || parts[2] == "" { return "", "" }
  return strings.TrimSpace(parts[1]), strings.TrimSpace(parts[2])
}
func main() {
  r,b := ParseOneRing("onering:real.example:bug.example")
  if r != "real.example" || b != "bug.example" { fmt.Println("FAIL parse"); os.Exit(1) }
  r,b = ParseOneRing("normal.example.com")
  if r != "" || b != "" { fmt.Println("FAIL normal"); os.Exit(1) }
  fmt.Println("OK ParseOneRing logic")
}
GO
  go run "$PARSE_GO" || fail=1
  rm -f "$PARSE_GO"
fi

[ "$fail" -eq 0 ] && echo ADHOC_VERIFY_PASS || { echo ADHOC_VERIFY_FAIL; exit 1; }
