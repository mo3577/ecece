#!/usr/bin/env bash
# Expose local PocketBase (:8090) via Cloudflare quick tunnel for remote phone admin.
# Usage: ./scripts/remote-tunnel.sh
set -euo pipefail

PORT="${ECE_PB_PORT:-8090}"
TARGET="http://127.0.0.1:${PORT}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${ROOT}/deps/cloudflared"

if command -v cloudflared >/dev/null 2>&1; then
  CF="$(command -v cloudflared)"
elif [[ -x "$BIN" ]]; then
  CF="$BIN"
else
  mkdir -p "${ROOT}/deps"
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64|amd64) ASSET=cloudflared-linux-amd64 ;;
    aarch64|arm64) ASSET=cloudflared-linux-arm64 ;;
    *) echo "Unsupported arch: $ARCH"; exit 1 ;;
  esac
  URL="https://github.com/cloudflare/cloudflared/releases/latest/download/${ASSET}"
  echo "Downloading cloudflared -> $BIN"
  curl -fsSL "$URL" -o "$BIN"
  chmod +x "$BIN"
  CF="$BIN"
fi

echo "Checking PocketBase at ${TARGET} ..."
if ! curl -fsS --max-time 5 "${TARGET}/api/health" >/dev/null; then
  echo "WARNING: could not reach ${TARGET}/api/health — start ECE-screen first."
fi

echo
echo "Starting Cloudflare tunnel -> ${TARGET}"
echo "Paste the https://….trycloudflare.com URL into ECE Admin on the phone."
echo "Ctrl+C stops the tunnel."
echo
exec "$CF" tunnel --url "$TARGET"
