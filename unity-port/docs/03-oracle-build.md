# Building and running the C++ oracle on Linux

The original C++ game is the behavioral reference for the port. This page
records how to build and boot it on a current Linux toolchain **without
modifying any original file**.

## Verified result (Phase 0)

Environment: Ubuntu 24.04, gcc 13.3, SDL 2.30, x86-64.

| Step | Result |
|---|---|
| `tools/oracle/build-oracle.sh` (client, release opts + `DEV_BUILD`) | Builds clean in about 15 s with `-j`. Output: `.cache/oracle/HostileTakeover`. |
| `tools/oracle/smoke-oracle.sh` (Xvfb, 10 s, screenshot) | **PASS**: the main menu renders (PLAY / LEADERBOARD / LOAD SAVED GAME / …). |
| Negative control (`smoke-oracle.sh --bin /bin/true`) | **FAIL** as expected ("oracle exited during startup"). |
| Legacy game server `server/` (`wis`), out-of-tree build | Builds clean. Starts and listens once its mission-pack dir has `index`, `modlist`, and `badwords` files (see below). |
| Probe program linked against all oracle objects except `sdl/main.o`, calling original `wi::isqrt` | Links and runs (see "Linking original code into test harnesses"). |
| Gameplay, multiplayer, sync checking | **Not exercised.** Driving gameplay headlessly is Phase 2 work. |

## Client

```bash
sudo apt-get install build-essential libsdl2-dev libcurl4-openssl-dev
unity-port/tools/oracle/build-oracle.sh            # release opts + DEV_BUILD
unity-port/tools/oracle/build-oracle.sh --debug    # -O0 + AddressSanitizer (upstream setting)

sudo apt-get install xvfb x11-apps imagemagick
unity-port/tools/oracle/smoke-oracle.sh
```

The script drives the upstream `game/sdl/linux/makefile` with output redirected
to `unity-port/.cache/` (git-ignored). The upstream makefile targets gcc-5 on a
case-insensitive filesystem; four flags bridge the gap:

| Problem on gcc 13 / Linux | Fix (flag only, no source edit) |
|---|---|
| `#include "game/Multiplayer.h"` but the file is `game/multiplayer.h` (macOS hid this) | `-I <shim>`, where the shim holds one symlink |
| `return false;` from pointer-returning functions (`mpshared/packinfomanager.cpp:67`, `game/sdl/sdlpackfile.cpp:26`) is an error in C++11 and later | `-std=gnu++98` |
| `fopen` and friends undeclared: modern libstdc++ no longer includes `<stdio.h>` transitively | `-include stdio.h -include stdlib.h -include string.h` |
| The checked-in `game/htdata832.pdb` isn't version-stamped, so non-dev builds reject it (`game/game.cpp:1347-1380`, `Game::CheckDatabaseVersion`) | `-DDEV_BUILD`. Alternatively stamp the data with `bin/markversion.exe` (Mono) and build with `--stamped`. |

`DEV_BUILD` also turns on developer defines (`game/ht.h:36-88`). Two of them
reach simulation files:

- `STRESS` (`game/Overmind.cpp:142`, `game/Level.cpp:280`, `game/SimUI.cpp:1100`)
  is gated at runtime by `gfStress` and is inert when that flag is off. When on,
  it gives the human player an Overmind AI and aborts the level after a timeout.
  That's a ready-made AI-vs-AI mode for Phase 2 golden recording.
- `DRAW_PATHS` adds `m_wxDst`/`m_wyDst` to `MobileUnit` save and load
  (`game/MobileUnit.cpp:294-297`). Dev and non-dev save games are therefore
  **not interchangeable**. It appears to feed only path drawing, but that is
  unverified.

Before trusting golden data from a `DEV_BUILD` binary, Phase 2 must show that
dev and non-dev (`--stamped`) builds produce identical traces for the same
scenario.

The game finds its data through `getpwuid()`, not `$HOME`
(`game/sdl/linux/hosthelpers.cpp:28-37`). The smoke script therefore copies the
`.pdb` files into `<passwd home>/Games/HostileTakeover/`.

## Linking original code into test harnesses (verified)

Phase 1 differential tests and the Phase 2 golden recorder both need to call
original C++ functions from a program with its own `main`. Linking one object
file alone doesn't work, because even `game/misc.cpp` mixes UI code with the
math (113 unresolved symbols). Linking **every** oracle object except the SDL
entry point does work:

```bash
B=unity-port/.cache/oracle/build
g++ probe.o $(find $B -name '*.o' ! -path '*/sdl/main.o') -o probe -lSDL2 -lcurl -lpthread
```

A probe linked this way called the original `wi::isqrt` over every input in
[0, 2²⁴) in 0.18 s. A differential test can therefore run C++ and C# over the
same inputs and compare. No header extraction or source edits are needed.

## Server

```bash
cd server
make DOCKER=0 REL=1 OUTDIR=/abs/out \
  CPP_FLAGS="-O2 -DRELEASE_LOGGING -Wno-write-strings -I.. -fsigned-char -DLINUX \
             -std=gnu++98 -include stdio.h -include stdlib.h -include string.h -w" \
  /abs/out/wis
mkdir -p /abs/mp/pack && touch /abs/mp/index /abs/mp/modlist /abs/mp/badwords
/abs/out/wis --htdata ../game/htdata832.pdb --listen_address 127.0.0.1 \
  --listen_port 22221 --missionpack_dir /abs/mp
```

Build the `/abs/out/wis` target directly. The default `all` target wraps the
build in Docker, and `d_all` copies the binary into `server/docker/`, which is
inside the repo.

Upstream bug found: `PackManager::WatchIndex` dereferences the result of
`LoadIndex()` without a null check (`mpshared/packmanager.cpp:158`), so a
missing `<missionpack_dir>/index` file is a segfault at startup. Empty stub files
avoid it. Not fixed, because the original code is read-only for this effort.

Running full multiplayer also needs the `stats/` leaderboard (Python 2.7 on
Google App Engine) for login. That runtime is end-of-life and was not attempted.

## Known gaps

- **32-bit oracle.** `fix32` is `long` (`game/ht.h:953`), which is 32-bit on the
  original ARM targets and 64-bit here. A `-m32` build needs `gcc-multilib` and
  `libsdl2-dev:i386`. Not attempted in Phase 0; it is a Phase 2 task (decision D2).
- **CI.** These scripts are not yet wired into GitHub Actions (Phase 1).
