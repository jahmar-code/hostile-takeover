#!/usr/bin/env bash
# Smoke-test the oracle: launch it under a virtual X display, wait, take a
# screenshot, and fail if the frame is blank. Proves the binary boots, loads
# htdata832.pdb, and renders its main menu. It does not exercise gameplay.
#
# Usage: smoke-oracle.sh [--bin PATH] [--shot PATH] [--wait SECONDS]
#
# Side effect: the game resolves its data dir through getpwuid(), not $HOME,
# so the data files are copied to <passwd home>/Games/HostileTakeover.
# Deps (Ubuntu 24.04): xvfb x11-apps imagemagick
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BIN="$REPO_ROOT/unity-port/.cache/oracle/HostileTakeover"
SHOT="$REPO_ROOT/unity-port/.cache/oracle/smoke.png"
WAIT=10

while [ $# -gt 0 ]; do
    case "$1" in
        --bin) BIN="$2"; shift 2 ;;
        --shot) SHOT="$2"; shift 2 ;;
        --wait) WAIT="$2"; shift 2 ;;
        -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

for tool in Xvfb xwd convert; do
    command -v "$tool" >/dev/null || { echo "missing tool: $tool" >&2; exit 1; }
done
[ -x "$BIN" ] || { echo "oracle binary not found: $BIN (run build-oracle.sh)" >&2; exit 1; }

DATA_DIR="$(getent passwd "$(id -u)" | cut -d: -f6)/Games/HostileTakeover"
mkdir -p "$DATA_DIR"
cp "$REPO_ROOT/game/htdata832.pdb" "$REPO_ROOT/game/htsfx.pdb" "$DATA_DIR/"

DISPLAY_NUM=":$((90 + RANDOM % 9))"
Xvfb "$DISPLAY_NUM" -screen 0 1024x768x24 >/dev/null 2>&1 &
XVFB_PID=$!
GAME_PID=""
cleanup() {
    [ -n "$GAME_PID" ] && kill "$GAME_PID" 2>/dev/null || true
    kill "$XVFB_PID" 2>/dev/null || true
}
trap cleanup EXIT
sleep 2

DISPLAY="$DISPLAY_NUM" SDL_AUDIODRIVER=dummy "$BIN" >/dev/null 2>&1 &
GAME_PID=$!
sleep "$WAIT"

if ! kill -0 "$GAME_PID" 2>/dev/null; then
    echo "FAIL: oracle exited during startup" >&2
    exit 1
fi

mkdir -p "$(dirname "$SHOT")"
DISPLAY="$DISPLAY_NUM" xwd -root -silent | convert xwd:- "$SHOT"
COLORS="$(convert "$SHOT" -format '%k' info:)"
if [ "$COLORS" -lt 16 ]; then
    echo "FAIL: screenshot looks blank ($COLORS colors): $SHOT" >&2
    exit 1
fi
echo "PASS: oracle rendered a frame with $COLORS colors: $SHOT"
