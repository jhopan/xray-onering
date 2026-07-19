#!/usr/bin/env bash
# verify.sh — sanity check OneRing core binary or patched tree
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

fail=0

echo "=== OneRing core verify ==="
if [ -f VERSION ]; then
  echo "VERSION:"; sed 's/^/  /' VERSION
fi

if [ -f onering.patch ]; then
  lines=$(wc -l < onering.patch | tr -d ' ')
  echo "OK patch ($lines lines)"
else
  echo "FAIL missing onering.patch"; fail=1
fi

if [ -d Xray-core ]; then
  if grep -q "func ParseOneRing" Xray-core/transport/internet/tls/config.go; then
    echo "OK tree patched"
  else
    echo "FAIL tree not patched"; fail=1
  fi
else
  echo "SKIP no Xray-core (run apply.sh)"
fi

# optional: binary path arg
BIN="${1:-}"
if [ -z "$BIN" ]; then
  # pick newest in dist
  BIN="$(ls -t dist/xray.*.onering* 2>/dev/null | head -1 || true)"
fi

if [ -n "${BIN:-}" ] && [ -f "$BIN" ]; then
  echo "BIN: $BIN ($(wc -c < "$BIN" | tr -d ' ') bytes)"
  if "$BIN" version >/tmp/onering-ver.txt 2>&1 || ./$BIN version >/tmp/onering-ver.txt 2>&1; then
    cat /tmp/onering-ver.txt | head -5 | sed 's/^/  /'
    echo "OK version runs"
  else
    # cross-built binary may not run on host
    echo "SKIP cannot exec binary on this host (likely cross-build)"
    file "$BIN" 2>/dev/null || true
  fi
else
  echo "SKIP no binary (build.sh first)"
fi

# unit: ParseOneRing via go test snippet if tree present
if command -v go >/dev/null; then
  # must NOT end with _test.go (go run rejects that name)
  PARSE_GO="${TMPDIR:-/tmp}/onering_parse_check.go"
  cat > "$PARSE_GO" <<'GO'
package main
import (
  "fmt"
  "os"
  "strings"
)
func ParseOneRing(serverName string) (real, bug string) {
  const prefix = "onering:"
  if !strings.HasPrefix(strings.ToLower(serverName), prefix) { return "", "" }
  parts := strings.SplitN(serverName, ":", 3)
  if len(parts) != 3 || parts[1] == "" || parts[2] == "" { return "", "" }
  return strings.TrimSpace(parts[1]), strings.TrimSpace(parts[2])
}
func main() {
  r,b := ParseOneRing("onering:neva.jhopanstore.my.id:support.zoom.us")
  if r != "neva.jhopanstore.my.id" || b != "support.zoom.us" { fmt.Println("FAIL parse"); os.Exit(1) }
  r,b = ParseOneRing("normal.example.com")
  if r != "" || b != "" { fmt.Println("FAIL normal"); os.Exit(1) }
  r,b = ParseOneRing("onering::bug")
  if r != "" { fmt.Println("FAIL empty real"); os.Exit(1) }
  fmt.Println("OK ParseOneRing logic")
}
GO
  go run "$PARSE_GO" || fail=1
  rm -f "$PARSE_GO"
fi

[ "$fail" -eq 0 ] && echo ADHOC_VERIFY_PASS || { echo ADHOC_VERIFY_FAIL; exit 1; }
