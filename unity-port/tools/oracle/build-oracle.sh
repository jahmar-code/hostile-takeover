#!/usr/bin/env bash
# Build the legacy C++ client (the "oracle") on modern Linux without
# modifying any original source file.
#
# The upstream makefile (game/sdl/linux/makefile) targets gcc-5 and a
# case-insensitive filesystem. This script drives that same makefile with
# out-of-tree output and a few compiler flags that paper over toolchain drift:
#
#   -std=gnu++98        Original code returns `false` from pointer-returning
#                       functions; C++11 and later reject that.
#   -include <hdr>      Modern libstdc++ no longer pulls <stdio.h>/<stdlib.h>/
#                       <string.h> in transitively.
#   -I <shim>           Some sources include "game/Multiplayer.h" while the
#                       file on disk is game/multiplayer.h (macOS hid this).
#                       The shim holds a symlink, nothing more.
#   -DDEV_BUILD         The checked-in htdata832.pdb is not version-stamped;
#                       non-DEV builds refuse to load it (game/game.cpp,
#                       Game::CheckDatabaseVersion). Pass --stamped to omit.
#
# Usage: build-oracle.sh [--out DIR] [--debug] [--stamped] [--jobs N]
#
# Output: $OUT/HostileTakeover (default OUT=unity-port/.cache/oracle)
# Deps (Ubuntu 24.04): build-essential libsdl2-dev libcurl4-openssl-dev
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
OUT="$REPO_ROOT/unity-port/.cache/oracle"
REL=1
DEV=1
JOBS="$(nproc 2>/dev/null || echo 4)"

while [ $# -gt 0 ]; do
    case "$1" in
        --out) OUT="$2"; shift 2 ;;
        --debug) REL=0; shift ;;
        --stamped) DEV=0; shift ;;
        --jobs) JOBS="$2"; shift 2 ;;
        -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

for tool in gcc g++ make pkg-config; do
    command -v "$tool" >/dev/null || { echo "missing tool: $tool" >&2; exit 1; }
done
for lib in sdl2 libcurl; do
    pkg-config --exists "$lib" || {
        echo "missing library: $lib (apt-get install libsdl2-dev libcurl4-openssl-dev)" >&2
        exit 1
    }
done

mkdir -p "$OUT/shim/game"
ln -sf "$REPO_ROOT/game/multiplayer.h" "$OUT/shim/game/Multiplayer.h"

FLAGS="-std=gnu++98 -I$OUT/shim -include stdio.h -include stdlib.h -include string.h"
if [ "$DEV" = 1 ]; then
    FLAGS="$FLAGS -DDEV_BUILD"
fi

# CPPFLAGS goes through the environment (not the make command line) so the
# makefile's own `CPPFLAGS += ...` lines append to it instead of being replaced.
# The debug build enables AddressSanitizer via the upstream makefile.
CPPFLAGS="$FLAGS" make -C "$REPO_ROOT/game/sdl/linux" -j"$JOBS" \
    CC=gcc CXX=g++ LD=g++ REL="$REL" OUTDIR="$OUT/build"

cp "$OUT/build/HostileTakeover" "$OUT/HostileTakeover"
echo "oracle built: $OUT/HostileTakeover"
