# Oracle audit: how the C++ game works

What a deterministic C# port has to reproduce, and where each fact lives in the
original source. Citations are `path:line` at commit `363c8f7`. Statements marked
**(verified)** were checked by reading the cited lines or running code during
Phase 0. Everything else comes from code reading and should be re-checked when
the relevant system is ported.

## Port-critical findings (read these first)

1. **Tick rate is 80 ms (12.5 Hz)**, not 20 Hz (`game/ht.h:1053`). All timing
   data (move rates, firing rates, build times) is expressed per update
   (decision D1).
2. **The sim depends on art resolution.** Projectile launch points are
   `m_wx + WcFromPc(specialPoint.x)` (`game/Tank.cpp:127-133`, and similarly in
   Tower, Infantry, Artillery, Andy). The special point is a pixel offset from
   the animation data, and the pixel↔world tables are built from the selected
   tile size (`game/game.cpp:618-621,643+`). Projectile step count, and so the
   timing of the hit, follows from that. **(verified)** The C# `Sim` must pin
   one resolution (32-px tiles, `htdata832.pdb`) and embed that table and those
   special points as sim data.
3. **Animation data is sim data.** Frame delays, strip lengths, and special
   points from `.anir` drive gameplay (`game/Animation.cpp:89-106,282-321`,
   `game/GameObjects.cpp:331-340`). Extract them from the **compiled** `.anir`
   in `htdata832.pdb`. The build scales them ×1.333 from the `.amx` sources, so
   the sources are the wrong input.
4. **No float math in game state.** The only float hit is a sprite scale in
   `Draw` (`game/Unit.cpp:505`). Fixed point is plain integer arithmetic with
   16-bit truncation (see Numerics).
5. **Triggers do not run inside `Simulation::Update`.** It only schedules them
   every 6 updates (`game/Simulation.cpp:419-426`) **(verified)**. They run
   later from the event loop (`game/game.cpp:2091-2123`), or from
   `RunUpdatesNow` in multiplayer (`game/SimUI.cpp:619,629`). The C# `Sim` must
   reproduce the exact interleaving.
6. **Single player has non-command inputs.** Difficulty handicap scales damage
   (`game/MobileUnit.cpp:791-794`) **(verified)**. Local-player fog affects
   human miners' search (`game/Miner.cpp:302-303`). UI targeting `Flash()` nudges
   `UpdateInterval` (`game/MobileUnit.cpp:566-567`). Two trigger types read UI
   state (`game/TriggerConditions.cpp:297-300`, `game/TriggerActions.cpp:508-510`).
   In the port each of these becomes an explicit sim input (match settings or a
   command). Multiplayer disables `UpdateInterval` skipping (`game/ht.h:739-793`).
7. **The sim is entangled with UI.** Gob classes have `Draw`, and sim code calls
   sound, alerts, minimap invalidation, and forms directly
   (`game/GameObjects.cpp:266-319`, `game/triggermgr.cpp:517-585`). The C# `Sim`
   should emit **events** (sound, alert, effect) into a per-tick buffer that the
   client consumes.

## Simulation core

### Loop

- `Simulation::Update(CommandQueue*)` (`game/Simulation.cpp:400-603`) advances
  sim time by 8 ticks and increments `m_cUpdates`. `m_cUpdates` starts at -1
  (`game/Simulation.cpp:198`).
- Driven by `SimUIForm::OnTimer` at `gtGameSpeed` ticks (`game/SimUI.cpp:297,729-812`).
  Single player doesn't catch up when behind; the timer resets to now
  (`game/timer.cpp:118-124`). Multiplayer catches up via `RunUpdatesNow`.
- **No render interpolation.** Gobs draw at their current `m_wx/m_wy`. The port
  adds interpolation client-side only.

### Update order within one update

1. Return if paused; service sound (`game/Simulation.cpp:402-407`).
2. Time += 8, `m_cUpdates++` (`:411-412`).
3. Maybe schedule triggers (finding 5).
4. `gplrm.Update`: players 0..4 in index order (`game/Player.cpp:326-333`);
   auto-repair every 6 updates (`game/Player.cpp:913-937`).
5. `UnitGroupMgr::Update` (`game/UnitGroupMgr.cpp:141-152`), then
   `BuildMgr::Update` (`game/BuildMgr.cpp:97`).
6. Route every queued command in order, synchronously; disconnects get special
   handling (`game/Simulation.cpp:447-464`) **(verified)**.
7. Snapshot the gids of state-machine gobs **in list order**. Then send
   `kmidReservedUpdate` to each still-resolvable gob whose `UpdateInterval`
   fires (`game/Simulation.cpp:481-521`).
8. `gsmm.DispatchDelayedMessages()`, a FIFO (`game/Simulation.cpp:531`,
   `game/StateMachine.cpp:294-337`).
9. Local-player alerts (presentation only).

### Game objects

- Singly linked list with **head insertion**, so iteration runs newest to oldest
  (`game/GameObjects.cpp:1547-1549`) **(verified)**. Plus a per-tile gid chain,
  also head-inserted, used by spatial queries in row-major tile order
  (`game/GameObjects.cpp:1731-1785,2738-2799`).
- Gid = index into a 768-slot master table (`game/ht.h:5243-5247`)
  **(verified)**. Free list: allocate from the head, free to the tail, so reuse
  is FIFO (`game/GameObjects.cpp:1284-1288,1494-1502,1588-1599`).
  **The C# registry must reproduce this order exactly**, because iteration order
  decides who acts first.
- Class hierarchy: `Gob : StateMachine` (`game/ht.h:5941`), then `UnitGob`,
  then `StructGob`/`MobileUnitGob`, and so on. 23 unit and structure types plus
  projectiles, effects, scenery, and `OvermindGob`. Factory: `CreateGob`
  (`game/GameObjects.cpp:78-182`).
- State machine: macro DSL (`game/ht.h:2092-2130`). `RouteMessage` runs the
  state handler, then the global handler, then processes the state change
  (`game/StateMachine.cpp:175-290`). `SendMsg` is synchronous; `PostMsg` and
  delayed messages are FIFO.

### Numerics (verified)

| Type | Definition | Notes |
|---|---|---|
| `WCoord` | `short`, 8.8 (tile in high byte) | Max map 64×64 tiles (`game/ht.h:795-803`) |
| `TCoord` | `short` | `wc >> 8` |
| `fix` | `short`, 11.5 | `mulfx`/`divfx` widen to `fix32`. Storing the result back into `fix` truncates to 16 bits (`game/ht.h:949-972`). |
| `fix32` | `long`, 5 fractional bits | 32-bit on the original ARM targets, 64-bit on LP64 (decision D2). Upstream `game/makefile.sdl:36` built with `-m32`. |
| `Direction` | `char`, N=0 clockwise | `-fsigned-char` matters (`game/ht.h:1398-1411`) |

- Integer-division quirk to keep: `itofx(90)/100` = 28, i.e. 0.875 rather than
  0.9 (`game/MobileUnit.cpp:793`, `game/Struct.cpp:897`).
- `isqrt` is bitwise (`game/misc.cpp:634-675`). `sqrtfx` is declared but never
  defined. There is no trig. Directions come from tables (`CalcDir`/`CalcDir16`,
  `game/GameObjects.cpp:1167-1278`). Distances come from tables
  (`gmpDistFromDxy[10][10]`, `game/GameObjects.cpp:440-507`; `gawcDiagonalDist`,
  `gaDiv256byNWithRounding`, `game/MobileUnit.cpp:5-46`, generated by
  `game/calcdiagdist.js`). Port the tables verbatim.

### RNG (verified)

- MSVC LCG: `glSeed = glSeed*214013 + 2531011; return (glSeed >> 16) & 0x7fff`
  (`game/misc.cpp:576-603`). Output bits 16–30 depend only on the low 32 bits,
  so C# `uint` arithmetic reproduces it at either `long` width.
- Seeds: single player uses `0x29a` (`game/game.cpp:1497-1505`); multiplayer uses
  the server's clock (`server/game.cpp:380`). `STRESS` mode (only compiled under
  `DEV_BUILD`, `game/ht.h:38-88`) seeds from the wall clock
  (`game/game.cpp:1499`), so the Phase 2 harness must force the seed. A separate `GetAsyncRandom` exists
  for sound and other non-sim picks (`game/misc.cpp:605-615`). No UI code calls
  the sim RNG.
- Cosmetic effects (smoke, scorch) **consume sim RNG and gids**
  (`game/Struct.cpp:919-947,1050-1083`). The port must keep them in the sim even
  though they look like presentation.

### Pathfinding

- `TerrainMap::FindPath` (`game/terrainmap.cpp:460-644`): best-first search with
  neighbours in N..NW order, step cost `{5,7}`, squared-Euclidean heuristic
  from `ganSquared`, **16-bit scores that can wrap**, LIFO tie-breaking in a
  sorted linked list (`:678-689`), and a 576-node cap that returns the closest
  node found.
- A Bresenham `FindLinePath` is tried first for targets under 20 tiles away
  (`game/MobileUnit.cpp:1702-1707`).
- Port it as written, quirks included. A "better" pathfinder is a post-parity
  gameplay change.

### Commands

- `CommandQueue` holds at most 300 messages, and **overflow is silently dropped**
  (`game/misc.cpp:104-108`) **(verified)**.
- 12 command ids (move, attack, build, abort, self-destruct, repair, upgrade,
  transform, deliver, mine, disconnect; `mpshared/mpht.h:234-273`). Commands
  carry no player id; ownership is implied by the target gob.

### Triggers and AI

- `TriggerMgr::Update` (`game/triggermgr.cpp:198-251`) runs per side in order.
  There's a timer-pointer bug to replicate at `:213-215`. Conditions are ANDed;
  a blocking action resumes on the next pass (`:398-447`).
- `OvermindGob` (`game/Overmind.cpp:108-299`) is the skirmish AI. Every 125
  updates it attacks with the first idle unit in list order; every 375 updates
  it builds at random.
- Built-in stress mode (`-s`, `game/game.cpp:136-140`, `DEV_BUILD` only) runs
  random levels with an Overmind on the human side. That gives a ready AI-vs-AI
  scenario source for golden recording, once the level choice and seed are
  pinned. It uses `GetAsyncRandom` and the wall clock (`game/Shell.cpp:112`,
  `game/game.cpp:1499`).

### Save games are not golden snapshots

`Game::SaveGame` (`game/game.cpp:2284-2353`) leaves out the RNG seed, the
free-list order, and `UpdateInterval` state. It reverses the gob list on load
and skips Overmind and projectiles. Golden data must come from per-update
traces instead (see Desync detection below).

### Size

The 37 sim files total about 27.5k lines (largest: `MobileUnit.cpp` 3.0k,
`GameObjects.cpp` 2.8k), plus about 4–5k lines of declarations in
`game/ht.h`.

## Data pipeline and formats

### What the game actually loads (verified)

Everything ships in two Palm-format `.pdb` containers (type `DATA`, creator
`WARI`):

- `game/htdata832.pdb`: 465 records, 401 files, 240 records compressed with a
  custom LZ scheme. Contents: 151 `.tbm` sprites, 42 levels (each as
  `.lvl` + `.tmap` + `.trmap`), 36 `.anir` animations, tile sets, palettes,
  fonts, 3 INI files, `strings.bin`, `help.txt`.
- `game/htsfx.pdb`: 111 files, almost all `.snd` (8 kHz 8-bit IMA-ADPCM).

Container layout: `mpshared/packfile.h:22-77` (header, record table, 32-byte
directory entries in record 0). Decompressor: `mpshared/decompress.cpp:8-100`.
A Python 2 reader already exists (`utilities/pack.py`).

The build (`data/makefile`) compiles source files with C# tools run under Mono
(`bin/*.exe`, sources in `SpiffLib/`, `acrunch/`, `bcr2/`, `packpdb2/`,
`m/mcl/`, and others) plus `cpp -P` and a native `inicrunch`. The 32-px build
reuses the 24-px art scaled ×1.333 (`data/makefile:75-85`). `htsfx.pdb` comes
from the GUI tool `Schemer/`, not the makefile.

### Source formats

| Data | Source in repo | Format | Game reads |
|---|---|---|---|
| Unit/structure stats | `data/GobTemplates.ini.pp` (23 templates) | Text INI through `cpp` (symbols from `game/res.h:96-134`) | `gobtemplates.ini` (crunched binary INI) |
| Levels | `data/*.ld` (47) | **.NET BinaryFormatter** (`m.LevelDoc`) **(verified)** | `.lvl` (INI: General, sides, GameObjects, Galaxite, Areas, Triggers, UnitGroups, Switches), `.tmap`, `.trmap` |
| Tile sets | `data/grassy.tc`, `data/desert.tc` | BinaryFormatter `m.TemplateDoc` with embedded PNGs | `.tset*` (6-byte header + raw 8bpp), `.tsetmini` |
| Animations | `data/art824/*.amx` (36) + 1,087 PNG frames | SOAP XML **(verified)** + 24-bit PNG | `.anir` (strip and frame tables, special points) + `.tbm` (RLE) |
| UI bitmaps, fonts | `data/art824/**/*.bmp` (138), font strips | BMP | `.tbm`, `.rbm`, `.fnt` |
| UI layouts | `data/forms.ini.pp` (67 forms) | Text INI | `forms.ini` |
| Sounds | `data/sounds/soundeffects.zip` (179 WAV) + `data/all.sfx` (184 entries) | WAV + text | `.snd` ADPCM + `SfxEntries` |
| Strings | `game/wistrings.h` (38) | C comments | `strings.bin` |

Mission briefings are trigger actions inside levels (Ecom, objectives,
cutscenes), not separate files. `mcl -exporttext` dumps them
(`m/mcl/OutputTools.cs:624-700`). There is **no localization** support.

### Data hard-coded in C++ (must move to JSON)

- Prerequisites per unit and structure (`umPrerequisites`/`upgmPrerequisites`
  in about 15 files, e.g. `game/HRC.cpp:23`, `game/Tank.cpp:312`).
- Upgrades: names, costs, times, text (`game/Research.cpp:35-75`).
- Sight range constant `ktcSightRangeMax` (`game/Unit.cpp:861`). The
  `SightRange` key described in `GobTemplates.ini.pp` is never read.
- Per-unit sound and strip indices (e.g. `game/Tank.cpp:313-327`).
- Handicap and other tuning constants (`game/ht.h:291-301,6650`).

### Recommended extraction path (Phase 3)

| Data | Path | Reason |
|---|---|---|
| Stats | Parse `GobTemplates.ini.pp` text and the hard-coded C++ tables. Cross-check against the pdb copy. | Trivial format |
| Levels | Decode `.lvl`/`.tmap`/`.trmap` **from the pdb**. Port `utilities/pack.py` and `ini.py` to C#. | It is exactly what the oracle loads, so parity is by construction. `.ld` needs an NRBF parser. |
| Sim-relevant animation data | Decode `.anir` **from the pdb** | Special points and delays must match the oracle (finding 3) |
| Sprite art | `.amx` XML + source PNGs (magic colors: transparent 255,0,255; shadow 156,212,248; 5 team shades, per `SpiffLib/tbitmap.cs:62-68`) | Lossless. Avoids the TBM RLE decoder. Subject to the legal register. |
| Tiles | `.tset` + `.palbin` from the pdb, or PNGs embedded in `.tc` | Simple raw format |
| Audio | WAVs from `data/sounds/soundeffects.zip` mapped through `data/all.sfx` | Better than the 8 kHz ADPCM. Subject to the legal register. |

### Tool binaries without source

`bin/` contains 18 executables and DLLs with no source in the repo (for example
`FormEdit`, `mappy`, `maptool`, `MagicLibrary.dll`, `SharpZipLib.dll`). The port
should not depend on them.

## Multiplayer and server

### Model: server-paced lockstep relay (verified)

- Every client runs the full simulation. The C++ server (`server/`, binary `wis`)
  never simulates. It queues each client's commands, batches them into
  `ScUpdate` messages, compares per-update state hashes, handles lag, and posts
  win stats. Client design notes: `game/SimUI.cpp:288-295`.
- Commands enter the sim only through the per-update command queue. They are
  routed as state-machine messages in order, and player disconnects are
  injected into the same stream (`game/Simulation.cpp:447-463`). **(verified)**
  This is the "commands are the only input" seam the C# `Sim` needs.
- The server does no validation of commands (`server/game.cpp:796`, `// TODO:
  Validation`). **(verified)**
- The random seed for a multiplayer game is the server's millisecond clock,
  broadcast in `ScBeginGame` (`server/game.cpp:380`). **(verified)**

### Timing

- Base tick is 10 ms (`base/tick.cpp:23-27`). The sim steps every `gtGameSpeed`
  ticks. The default is 8 ticks = 80 ms (`game/ht.h:1053-1054`, `game/game.cpp:55`).
  Allowed speeds: `{64,48,32,24,16,12,10,8,7,6,5,4,3,2,1}` ticks
  (`mpshared/netmessage.cpp:10-12`).
- The server heartbeat is 250 ms (`server/server.cpp:15,42,66-75`). Each send
  advances a block point `cUpdatesBlock = ceil(msClock/cmsUpdate)`
  (`server/game.cpp:714-721`). At 80 ms per step, one server Update covers about
  3 sim steps.
- A client stalls when it reaches the block point without the next Update
  (`game/SimUI.cpp:656-662`). Latency is measured and reported, but nothing acts
  on it: the adaptation code is `#if 0` (`game/SimUI.cpp:688-699`).
- The server pauses everyone if a player falls more than 5 s behind
  (`server/game.cpp:439-442`). A lagging player can be voted out, after which
  they become a computer player (`server/game.cpp:167-176,757-778`).

### Desync detection

- The `TRACKSTATE` define is set in every shipped build
  (`game/sdl/linux/makefile:22`). Each sim step records a frame of (tag, value)
  pairs:
  - RNG seed, message count, and update count (`game/Simulation.cpp:623-646`)
  - per gob: id, wx, wy, next-gid, state, next-state, and flags with UI bits
    masked off (`game/GameObjects.cpp:249-262`) **(verified)**
  - per player: upgrades, side, allies, credits, power, and kill/loss counts
    (`game/Player.cpp:445-463`)
  - every routed message (`game/StateMachine.cpp:180-184,339`)
- The frame hash is `h += tag; h ^= value` over the entries
  (`game/stateframe.cpp:47-56`). Frames are combined with
  `h = (h << (h & 3)) ^ t` back to the last block (`game/statetracker.cpp:128-143`).
  **(verified)**
- **Implication for the port:** that hash is weak (offsetting entries cancel) and
  covers no health, ammo, or weapon state. Golden traces should record the
  **full frame entries**, which the code already serializes to JSON for desync
  uploads, extended with the fields the hash omits. The C# `Sim` should use a
  proper 64-bit hash (for example xxHash64 over a canonical byte layout) for
  runtime desync checks.
- With `--checksync`, the server compares hashes per block
  (`server/playermgr.cpp:376-447`). On a mismatch it broadcasts `ScSyncError` and
  stops. Clients upload a dump to an endpoint that was never implemented
  (`stats/syncerror.py:5-8`). There is no resync. `syncerror/` holds offline
  Python 2 diff tools.

### Wire protocol (for reference; decision D6: do not reimplement)

- Framing: `[u16 length BE][u8 id][payload]`, big-endian ints, length-prefixed
  strings (`mpshared/xmsg.h:15-48`). About 50 envelope message ids
  (`mpshared/constants.h:11-62`). In-game messages (23 types) are wrapped in id
  `0xd4` (`mpshared/netmessage.h:36-59`).
- A command is a 28-byte `Message` struct under `#pragma pack(2)`
  (`mpshared/mpht.h:137-230`), with command ids at `mpshared/mpht.h:234-273`.
  These ids are the starting vocabulary for the C# `Command` type.

### Accounts and stats (stats/)

- Python 2.7 on Google App Engine (`stats/app.yaml`), using the deprecated
  `webapp`/`db` APIs. Endpoints for auth, server list, game stats, leaderboards,
  and accounts (`stats/config.py:24-49`).
- **Security issues worth knowing about (not to port):** unsalted MD5 password
  hashes (`stats/models.py:7-34`); a plaintext password stored when account
  creation fails (`stats/models.py:38-43`); tokens signed as
  `md5(json+secret)` and sent over plain TCP; the client saves the password in
  plaintext in its prefs (`game/game.cpp:2553`); `/api/getgames` is
  unauthenticated and returns player IPs and device ids
  (`stats/getgames.py:24-38`).
- No real secrets are committed. Only `REPLACEME_*` placeholders
  (`stats/config.py:60-65`, `server/secrets.cpp:9-15`).
- Release service URLs are placeholders (`game/serviceurls.cpp:24-29`). There is
  no live infrastructure to stay compatible with.

### Server build status (verified)

Builds on gcc 13 out-of-tree, and starts once stub mission-pack files exist. See
`03-oracle-build.md`. Upstream null-dereference bug at
`mpshared/packmanager.cpp:158`.

### Sizes

`server/` C++ 9.2k lines, `mpshared/` 6.5k, `stats/` 3.2k Python, plus parts of
`base/` (6.4k) and `yajl/` (3.1k).
