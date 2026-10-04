# Port plan: phases, exit criteria, open decisions

Status: **Phase 0 deliverables done. Phase 0 exits when the owner answers the
decisions below and the legal questions reach counsel.**

The metaprompt that defines this effort was truncated after rule 7, so its phase
list never arrived. The phases below are reconstructed from the rules it does
contain: Phase 0 is the legal gate (rule 6), and Phase 2 records golden data from
the C++ oracle (rule 5). Edit this file if your original phase list differs.

## Decisions needed from the project owner

These block or shape Phase 1. Each has a recommendation; none has been acted on.

| # | Decision | Recommendation | Why |
|---|---|---|---|
| D1 | Sim tick rate. The metaprompt says 20 Hz; the original sim steps every **80 ms (12.5 Hz)** (`game/ht.h:1053`). Unit speeds, cooldowns, and build times are all counted in updates. | **Keep 12.5 Hz** through parity. Revisit only as a deliberate post-parity rebalance. | At 20 Hz no per-update value can match the oracle, so rule 5 (prove parity) can't be met. Rendering interpolates to 60 fps either way, so smoothness does not depend on the tick rate. |
| D2 | Integer width of `fix32` (declared `long`: 32-bit on the original ARM targets, 64-bit on x64 Linux and arm64). | Model it as **32-bit** in C# unless Phase 2 traces show the two widths differ. | Record goldens from both `-m32` and `-m64` oracle builds and diff them. If they agree, the question is moot. |
| D3 | Legal path for assets (see `01-legal-provenance-register.md`). | Get counsel's opinion now. Plan for **replacement art, audio, fonts, and name** by default. | The BSD license names source code only. Asset licensing is unknown, and the name and logo are trademarks. |
| D4 | Engine. | Unity 6 LTS as specified (fallback: Godot 4 + C#). | Nothing found in Phase 0 argues against it. Sim, Data, and Server are engine-agnostic by construction. |
| D5 | Map size. Hard limit of 64×64 tiles (`game/ht.h:798`, `WCoord` is 8.8 in a 16-bit short). | Keep the limit through parity. Widen it later behind a versioned "extended" sim mode. | Widening changes overflow and wrap behavior, which breaks parity. |
| D6 | Legacy multiplayer compatibility. | **Do not** speak the old wire protocol. | The old stack depends on a Python 2.7 / Google App Engine leaderboard for auth and stats (`server/README.txt`), which is end-of-life. A clean protocol is cheaper. |
| D7 | Art resolution baked into sim behavior. Projectile origins and hit timing depend on the tile-size pixel tables and on animation special points (audit, finding 2). | Pin the sim to the **32-px data set** (`htdata832.pdb`) for parity. New art at any resolution maps onto the same sim-side special points. | Otherwise the sim isn't resolution-independent, and two clients with different art would desync. |

## Phases

Each phase ends with evidence (tests, traces, builds). A claim without evidence
doesn't close a phase. Anything Unity- or device-dependent is labeled
**unverified until built in Unity** until a real build confirms it.

### Phase 0: Discovery and legal gate (deliverables done, exit pending)

Deliverables:
- `01-legal-provenance-register.md`: what is licensed, what is unknown, what must change.
- `02-oracle-audit.md`: how the C++ sim, networking, and data pipeline work, with citations.
- `03-oracle-build.md` and `tools/oracle/`: the oracle builds and boots on Linux.
- This plan.

Exit: the owner answers D1–D7, and the legal questions in the register go to counsel.

### Phase 1: Foundations

- `unity-port/` .NET solution: `Sim` (netstandard2.1, no dependencies), `Sim.Tests`,
  `Data` (extractors, net8), `Server` (net8 stub), `Tools.Golden` (trace diffing).
- Determinism guard in CI: a Roslyn analyzer, with a grep fallback, that fails on
  `float`, `double`, `decimal`, `System.Random`, `DateTime`, `Stopwatch`, `Thread`,
  `Task`, `Parallel`, `Dictionary`/`HashSet` enumeration, `GetHashCode`, and LINQ
  `OrderBy` inside `Sim`.
- Allocation-regression test harness (`GC.GetAllocatedBytesForCurrentThread`
  across N ticks must be 0 once warm).
- Bit-exact primitives, each tested against C++ compiled from the original headers:
  - `Fix` (16-bit 11.5) and `Fix32` (5 fractional bits) with the oracle's wrap
    and truncation semantics, including the implicit `short` truncation when
    `mulfx` results are stored back into `fix`.
  - `WCoord` (8.8 in `short`), `TCoord`, and the pixel↔world tables.
  - The RNG (MSVC LCG), `isqrt`, and the direction and distance tables
    (`CalcDir`/`CalcDir16`, `gmpDistFromDxy`, `gawcDiagonalDist`,
    `gaDiv256byNWithRounding`). There is no trig, and `sqrtfx` is declared but
    never defined.
  - Gid registry with the oracle's ordering: head-inserted gob list, FIFO gid
    reuse, per-tile chains.
- GitHub Actions: `dotnet build/test`, determinism guard, oracle build plus smoke test.

Exit: CI green. Every primitive has a C++-vs-C# differential test over ≥10⁶ inputs
(exhaustive where the domain is 16-bit).

### Phase 2: Oracle instrumentation and golden data

- Headless golden recorder: a separate `main` that links the original game sources
  unmodified (as `build-oracle.sh` already does), replaces only the host and
  display layer, loads a level, feeds a scripted command stream, and writes per
  update:
  - a canonical state hash (gobs in list-iteration order, since order decides
    who acts first; positions, health, state-machine state, player credits and
    power, RNG state), and
  - a full JSON snapshot every K updates.
- The existing `TRACKSTATE` frames (`game/stateframe.cpp`, `game/statetracker.cpp`)
  are the starting point. Record the full (tag, value) entries, not the weak
  shipped hash, and add the fields that hash omits (health, ammo, weapon
  timers, animation frame, `UpdateInterval` counters, the gid free list).
- Pin everything that makes the oracle nondeterministic: RNG seed (stress mode
  seeds from the wall clock), game speed, handicap, local-player identity, and
  the trigger-update interleaving. Triggers run from the event loop, not inside
  `Simulation::Update`.
- Prove `DEV_BUILD` and non-dev (`--stamped`) oracle builds produce identical
  traces, or record only from the non-dev build.
- Scenario corpus: each campaign mission for N updates with no input; scripted
  micro-scenarios (move, attack, build, harvest, research, trigger fire); and
  AI-vs-AI skirmishes on every multiplayer map.
- Determinism of the oracle itself: two runs of the same scenario must produce
  identical traces. `-m32` vs `-m64` traces get diffed (D2).

Exit: corpus recorded, the oracle reproduces itself bit-for-bit, and traces are
stored as CI artifacts with checksums.

### Phase 3: Data extraction

- Extractors to versioned JSON with a schema: unit and structure templates
  (plus the tables currently hard-coded in C++: prerequisites, upgrades, sight
  range, sounds), levels (terrain, gobs, triggers, areas, switches), tile sets,
  animations, sound tables, and strings.
- Sim-relevant data (levels, `.anir` delays and special points, templates) is
  decoded from the **compiled `htdata832.pdb`**, because that is what the oracle
  runs (D7). Presentation art comes from the lossless sources.
- Art and audio decoders to PNG atlases and WAV/OGG for **internal development
  only** until D3 is resolved.
- Round-trip checks: every value the oracle reads at runtime matches the JSON
  (verified by dumping the oracle's in-memory templates in the Phase 2 harness).
- Unity side: importers turn JSON into ScriptableObjects (**unverified until built
  in Unity**).

Exit: the full data set extracts, schema validation passes, and the extracted
data matches oracle memory dumps.

### Phase 4: Sim port, system by system

Order (each system gated on golden parity before the next starts): map and terrain,
gob registry and update order, movement and pathfinding, combat and weapons,
economy (mining and processing), building and production, upgrades and research,
triggers and scripted missions, computer AI.

Cross-cutting rules for this phase:
- Sound, alerts, minimap invalidation, and UI calls that the C++ makes from sim
  code become entries in a per-tick event buffer.
- Single-player inputs that bypass the command queue (handicap, local-player
  fog, targeting `Flash()`, UI-state trigger conditions) become explicit match
  settings or commands.
- Quirks are ported as-is and documented: 16-bit path-score wrap, the
  trigger-timer pointer bug, the silent 300-command overflow, `itofx(90)/100`.

Exit: every Phase 2 scenario reproduces the oracle's per-update hash for its full
length. The allocation test reads 0 bytes per tick. A benchmark covers worst-case
maps.

### Phase 5: Unity client vertical slice

URP 2D, sprite atlases, interpolated rendering of sim state, touch input that
produces commands only, camera and minimap, HUD, one playable mission.

Budgets: 60 fps and 0 managed allocations per frame (steady state) on the reference
low-end Android device; ≤ 16 ms frame time at the 99th percentile.

Exit: GameCI Android build in CI, profiler captures from a real device. Until
those exist, everything in this phase is **unverified until built in Unity**.

### Phase 6: Multiplayer

.NET 8 ASP.NET Core WebSocket lockstep relay. Binary command protocol with
per-turn input delay, per-update state-hash exchange and desync reports,
reconnect and catch-up, replay files, and optional server-side replay validation
using the same `Sim` assembly.

Exit: 2–4 player soak tests under simulated latency and loss with zero desyncs
between an x64 server-side validator and ARM64 IL2CPP clients.

### Phase 7: Content and customization

Mod-ready data pipeline (units, stats, maps, and modes as data), map editor
strategy, new brand, and replacement assets as D3 requires.

### Phase 8: Services and release

Accounts, matchmaking, analytics, IAP (Unity Gaming Services or PlayFab), crash
reporting, privacy and store compliance, soft launch.

Release work begins only after the Phase 0 legal gate has a written answer.
