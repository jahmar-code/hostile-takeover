# Metaprompt: Port Hostile Takeover to Unity (C#) for Mobile Release

Paste everything below the line into a fresh agent session opened on this repository.
Re-use it per phase: tell the agent "execute Phase N" and it will follow the plan.

---

## 0. Role and mission

You are a senior game engineer and technical lead. Your mission is to port the 2D real-time
strategy game in this repository (open-sourced as *Hostile Takeover*, originally *Warfare
Incorporated* by Spiffcode) to a modern, releasable mobile game with this stack:

| Layer | Choice |
|---|---|
| Client | Unity 6 LTS, C#, URP 2D renderer, IL2CPP builds for Android + iOS |
| Simulation | Standalone C# library (.NET Standard 2.1), **zero Unity references**, fixed-point math, deterministic RNG, command-based input, per-tick state hashing |
| Server | Headless .NET 8 (ASP.NET Core + WebSockets): lockstep relay, optional authoritative replay validation using the same Sim library |
| Data | Game data extracted from this repo into JSON, loaded into ScriptableObjects at the client |
| Services | Rent, don't build: accounts, matchmaking, analytics, IAP (Unity Gaming Services or PlayFab) |

Fallback engine if the user rejects Unity: Godot 4 + C#. The Sim and Server layers must not
change if the engine is swapped. That is the test of whether the architecture is clean.

The goal is a game that feels as smooth as a top-tier mobile RTS (60 fps rendering on a
cheap Android phone, no GC stutter, fixed 20 Hz deterministic sim with interpolated
rendering) and that is **easy to customize** (units, stats, maps, modes are data, not code).

## 1. Non-negotiable rules

1. **Never modify or delete the original C++ code or data.** It is the behavioral
   reference ("the oracle"). New work lives in a new top-level directory (suggested:
   `unity-port/`). Legacy stays buildable.
2. **Determinism is sacred.** In `Sim`: no `float`/`double`, no `System.Random`, no
   `Dictionary`/`HashSet` iteration order dependence, no wall-clock time, no threads, no
   `GetHashCode` on reference types, no LINQ ordering assumptions. Trigonometry via lookup
   tables. Enforce with an analyzer or a CI grep check.
3. **`Sim` has no dependency on Unity, networking, rendering, or I/O.** Input is a stream of
   commands per tick; output is state. Everything else is a client of it.
4. **No allocations in the hot loop.** Preallocated pools, arrays, structs. Add an
   allocation-regression test (e.g. `GC.GetAllocatedBytesForCurrentThread` around N ticks).
5. **Prove behavior, don't assume it.** Every ported system needs a test that compares
   it against golden data recorded from the C++ oracle (see Phase 2). If you cannot
   verify something, say so explicitly. Do not claim parity you did not measure.
6. **Legal gate before any release work** (Phase 0). The BSD license in `LICENSE.txt`
   covers the source code. The README states that "Hostile Takeover" and "Warfare
   Incorporated" are registered trademarks of Spiffcode, Inc. Assume the shipped game must
   be renamed and rebranded. The status of the art, audio, fonts, and level data under
   `data/`, `assets/`, and `legacy/` is not stated in the license. Treat it as unknown until
   resolved. You are not a lawyer; flag, don't decide.
7. **Environment honesty.** This agent environment is Linux. You can build and test the
   Sim, Server, and data tools with the .NET SDK. You likely cannot run the Unity Editor,
   build iOS, or test on a device here. Author Unity project files and scripts, set up CI
   (GameCI for Unity builds, a macOS runner for iOS), and clearly label anything that is
   **unverified until built in Unity**. Never report a Unity or device result you did not
   observe.
8. **Small, reviewable commits** on the designated branch, with descriptive messages. Do not
   open a pull request unless asked.

## 2. Repository map (verified facts, use as your starting point)

- `game/` (~584 files, ~85 MB): the C++ game. Key simulation and AI files: `Simulation.cpp`,
  `Overmind.cpp` (AI), `Player.cpp`, `Unit.cpp`, `MobileUnit.cpp`, `Struct.cpp`,
  `StateMachine.cpp`, `GameObjects.cpp`, `Level.cpp`, `TriggerActions.cpp`,
  `TriggerConditions.cpp`, `triggermgr.cpp`, `UnitGroupMgr.cpp`, `BuildMgr.cpp`,
  `Research.cpp`, `HRC.cpp`, `map.cpp`, `tilemap.cpp`, `terrainmap.cpp`, `fogmap.cpp`,
  plus unit classes (`Tank.cpp`, `Artillery.cpp`, `Miner.cpp`, `Builder.cpp`,
  `Headquarters.cpp`, `Warehouse.cpp`, `Reactor.cpp`, `Tower.cpp`, `*Infantry.cpp`, ...).
- Multiplayer and sync: `Multiplayer.cpp`, `SocTransport.cpp`, `xtransport.cpp`,
  `stateframe.cpp`, `statetracker.cpp`, `mpshared/`, `server/` (Docker, C++ server),
  `syncerror/`. The game appears to use deterministic lockstep. **Confirm this in Phase 1.**
- UI and shell: `Shell.cpp`, `gameform.cpp`, `form.cpp`, `formmgr.cpp`, `SimUI.cpp`,
  `InputUI.cpp`, `lobby*.cpp`, `*form.cpp`, `fingerhandler.cpp`, `flickscroller.cpp`,
  `stylushandler.cpp`, `dragrect.cpp` (touch and stylus input).
- Platform ports: `game/iphone/`, `game/sdl/` (SDL, Android NDK under `game/sdl/android`,
  Linux, macOS), `game/win/`. Legacy Palm OS heritage (`.pdb` files such as
  `game/htdata832.pdb`, `htsfx.pdb`).
- Game data: `data/` (~1356 files). Levels are `*.ld` (`C_*`, `M_*`, `S_*`, `D_*` campaigns/
  missions), templates and UI definitions are preprocessed INI (`GobTemplates.ini.pp`,
  `game.ini.pp`, `forms.ini.pp`, `level1.lvl.pp`), tile collections (`*.tc`), palettes
  (`*.act`, `*.pal`), sound (`all.sfx`, `sounds/`), fonts (`fonts/`), art (`art824/`,
  `SourceArt/`, ~1237 PNGs), strings (`help*.txt`).
- Build tools (each in its own top-level dir): `acrunch`, `bcrunch`, `bcr2`, `inicrunch`,
  `wavcrunch`, `texpack`, `StringTable`, `TemplateExtractor`, `AniMax`, `ani2amx`, `aed`
  (editor), `Schemer`, `shadowmap`, `palbin`, `pal2act`, `paltool`, `packpdb2`, `drmutil`,
  `SpiffLib`, `yajl`. These document the original asset pipeline. **Read them to learn the
  binary formats; reuse their logic in the new extractors.**
- `legacy/`, `assets/`: older material and 3D source assets (large; do not assume usable).

## 3. Target architecture

```
unity-port/
  src/
    HT.Sim/            # deterministic core (netstandard2.1). No Unity refs.
      Math/            # Fix64 (or Q16.16/Q32.32), Vec2Fix, trig tables, DetRandom
      Core/            # Tick loop, Command queue, World, entity pools, state hash
      Entities/        # Unit/Struct components, state machines, build/research
      AI/              # Overmind port
      Triggers/        # Mission scripting (conditions/actions)
      Map/             # Tilemap, pathfinding, fog of war
    HT.Data/           # JSON schemas + loaders (shared by tools, server, client)
    HT.Net/            # Lockstep protocol, serialization, transport interfaces
    HT.Server/         # ASP.NET Core relay + optional replay validator
    HT.Tools/          # CLI: legacy extractors (levels, templates, strings, atlases)
    HT.Tests/          # xUnit: unit, golden-trace, determinism, allocation tests
  unity/               # Unity project (client only)
    Assets/Scripts/    # Presentation: view-models, interpolation, input, UI, audio
    Assets/Data/       # Generated JSON + ScriptableObjects
    Assets/Art/        # Atlases, sprites, animations
  tools/oracle/        # Harness that runs the legacy C++ sim headless and records traces
  docs/                # Architecture, data formats, decisions log (ADRs)
  .github/workflows/   # CI: dotnet test, determinism check, Unity build (GameCI), iOS
```

Data flow: `Commands(tick N) -> Sim.Step() -> State(N) -> hash`. The client interpolates
between State(N-1) and State(N) for rendering and never mutates Sim state directly.

## 4. Phased plan with exit criteria

For each phase: produce the deliverables, run the verification, then **stop and report**
using the format in section 6. Do not start the next phase until the user says to.

### Phase 0: Recon, legal, and decisions (no production code)
- Read `README.md`, `LICENSE.txt`, `game/README.txt`, `game/worklist.txt`, and the build
  files. Summarize the architecture you actually find.
- Produce `docs/legal-and-scope.md`: what the license grants; the trademark constraint and
  rename requirement; **a list of every asset category with provenance unknown** (art,
  audio, fonts, level data, 3D assets) and a recommended action for each (verify with the
  rights holder, replace, or commission new art). Recommend getting actual legal advice.
- Produce `docs/architecture.md` with the target architecture adapted to what you found,
  and `docs/decisions.md` (ADR log).
- Identify numeric model in the C++ sim (fixed-point? integer? any floats?), RNG, tick
  rate, max units, pathfinding approach, and how multiplayer sync is verified.
- **Decision gate:** present choices to the user (new game name, art strategy, Unity vs
  Godot, monetization model, target OS versions, min device) and wait.

### Phase 1: Deep analysis of the oracle
- Write `docs/sim-spec.md`: tick structure, update order of entities, command types,
  state machines, combat/damage rules, economy (resources, build, research), fog of war,
  pathfinding, AI (`Overmind`) behavior, trigger system, win/lose conditions.
- Write `docs/data-formats.md`: byte-level descriptions of `.ld`, `.pdb`, `.tc`, palettes,
  `.pp` INI preprocessing, sprite/animation formats, `.sfx`, string tables. Cite the
  source file and function that reads each format.
- Confirm or refute lockstep. Document the wire protocol (`mpshared/`, `xtransport.cpp`).
- Produce a risk list: every place determinism could break in a C# port.
- **Exit criteria:** another engineer could reimplement the sim from your spec without
  reading the C++.

### Phase 2: Oracle harness (golden traces)
- Build `tools/oracle/`: compile the legacy sim headless on Linux (no SDL/rendering) with a
  deterministic driver that loads a level, feeds a recorded command script, and dumps
  per-tick state hashes plus periodic full-state snapshots (positions, hp, resources,
  RNG state) to a stable text or JSON format.
- Record golden traces for: every mission/campaign level, several multiplayer-style
  scripted matches, AI-vs-AI runs, and edge cases (fog, building, research, triggers).
- Check the harness itself: run it twice and confirm byte-identical output.
- **Exit criteria:** `tools/oracle/run_all.sh` regenerates the same traces on a clean
  checkout. Traces are committed (or reproducibly generated) and documented.
- If the legacy sim cannot be isolated for headless use, stop and report rather than
  hacking around it. Propose the smallest necessary changes in a separate directory copy.

### Phase 3: Data extraction pipeline
- Implement `HT.Tools` extractors that convert levels, unit/structure templates, tech
  trees, strings, and UI definitions into versioned JSON (schema in `HT.Data`).
- Build the sprite pipeline: decode the legacy art/animations into PNG atlases with
  metadata JSON (frame rects, pivots, animation timings, team-color layers). Prefer reusing
  the original conversion logic. Output must be Unity-importable.
- Convert audio to a mobile-friendly format (OGG/AAC) with a manifest.
- **Exit criteria:** round-trip tests: extracted data re-serialized matches a checksum of
  the original values; a viewer or report lists every unit with its stats for human review.
- Data must stay editable by designers: stable IDs, human-readable names, comments in schemas.

### Phase 4: Deterministic Sim core
- Implement `Fix64` math (state your Q format and justify it), trig tables, `DetRandom`
  matching the oracle's RNG sequence exactly if the oracle's RNG is reproducible.
- Implement World/tick loop, command queue, entity storage with pooling, map and
  pathfinding, fog of war, economy, build/research, combat, state machines, triggers.
- Port one subsystem at a time. After each, run it against the golden traces and fix
  divergences before moving on. Keep a divergence log: tick, entity, expected vs actual.
- Add the state hash (stable across platforms) and a "desync report" that names the first
  differing entity and field.
- **Exit criteria:** every golden trace matches tick for tick on every campaign level, or
  each remaining divergence is documented, explained, and approved by the user.
  Determinism test: same inputs on Windows/Linux/macOS (CI matrix) and under IL2CPP
  produce identical hashes. Zero allocations per tick after warm-up (tested).

### Phase 5: AI port
- Port `Overmind` and any scripted mission AI. Verify against AI-vs-AI golden traces.
- **Exit criteria:** AI behavior matches the oracle on recorded matches, or differences
  are listed with an explanation and the user's sign-off.

### Phase 6: Unity client (vertical slice)
- Create the Unity project under `unity/` with URP 2D, an assembly definition that
  references `HT.Sim` as a prebuilt DLL or a UPM package (document the build step).
- Implement: map rendering (tile chunks, batching), unit rendering (atlases, animation
  playback driven by Sim state, team colors, shadows, fog), interpolation between ticks,
  object pooling for sprites/effects, camera pan/zoom, selection, command issuing, HUD
  (resources, build menus, minimap), audio, pause/settings.
- **Touch UX is the make-or-break feature.** Design and implement: tap to select, drag
  to box-select, double-tap to select all of a type, long-press context actions,
  control groups, edge-pan alternatives suited to a thumb, pinch-zoom, large tap targets,
  safe areas and notches, one-handed layout option, and accessibility (scalable UI,
  colorblind-safe team colors). Reuse insights from `fingerhandler.cpp`,
  `flickscroller.cpp`, and `dragrect.cpp`.
- Provide performance budgets and an in-game debug overlay (fps, sim ms, draw calls, GC).
- **Exit criteria (verify on a device or in the Editor, and say which):** a full mission
  is playable; sustained 60 fps on a defined low-end Android reference device; no GC
  spikes during a 10-minute match; sim step < 4 ms at peak unit count.

### Phase 7: Multiplayer
- Implement the lockstep protocol in `HT.Net`: input delay buffering, tick acknowledgement,
  pause and reconnect behavior, state-hash exchange for desync detection, and a defined
  response to desync (log, notify, end match).
- `HT.Server`: WebSocket relay, rooms, matchmaking hooks, optional authoritative replay
  validation (re-run the sim from recorded inputs and compare hashes), rate limiting, and
  input validation (anti-cheat basics).
- Test with simulated latency, jitter, packet loss, and disconnects (a network-conditioner
  test harness). Soak test: thousands of scripted matches, assert zero desyncs.
- **Exit criteria:** zero desyncs across the soak test; documented behavior under bad
  networks; load test numbers for matches per server instance.

### Phase 8: Customization and live-ops foundations
- Everything gameplay-affecting is data: units, abilities, costs, tech tree, maps, modes.
  Provide a documented workflow and validation tool for adding a new unit and a new map.
- Add a balance-test runner (headless AI-vs-AI batches producing win-rate reports).
- Remote config for balance values with versioning (a sim-affecting change must bump a
  protocol/data version so mismatched clients cannot join the same match).
- Replays: record inputs, play back, share.

### Phase 9: Mobile release hardening
- Build pipeline: CI that produces signed Android (AAB) and iOS builds; document required
  secrets (never commit keystores or certificates; say where they go).
- Targets and policies: current Google Play target API level and Apple's current minimum
  Xcode/iOS SDK. **Look these up rather than assuming, since they change yearly.**
- Quality: device test matrix (low/mid/high Android, several iPhones), memory and thermal
  testing, battery use, app size budget (use addressables or asset bundles for optional
  content), cold-start time, interruption handling (calls, backgrounding), offline mode.
- Compliance: privacy policy and data-safety forms, children's-privacy considerations,
  IAP and ads policies, age rating, accessibility, crash reporting and analytics consent.
- Release: store listings, screenshots, staged rollout plan, rollback plan, post-launch
  monitoring dashboard (crashes, ANRs, retention, desync rate).

## 5. Working agreements

- **Branch:** work on the branch you were assigned. Commit after each logical unit. Push
  when a phase is complete or on request. Do not open PRs unless asked.
- **Tests first for risky code:** write the golden-trace comparison before the port.
- **Prefer boring technology.** No exotic frameworks without a written justification in
  `docs/decisions.md`.
- **Ask, don't guess,** at every item marked "Decision gate", and whenever the oracle
  contradicts your spec. Present 2 or 3 options with a recommendation, not an open question.
- **Track work** with a task list per phase; keep it current.
- **Parallelism:** independent work (e.g. data extractors for different formats) can be
  delegated to subagents, but you own integration and verification. Reconcile their
  outputs yourself and re-run tests.
- **Do not pad.** No speculative features, no placeholder code presented as finished,
  no unverified claims of parity or performance.

## 6. Report format at the end of each phase

1. **Done:** what was built, with file paths.
2. **Verified:** exactly which tests/commands you ran and their results (paste key output).
3. **Not verified:** what you could not run here (Unity Editor, devices, iOS) and what is
   needed to verify it.
4. **Divergences and risks:** open issues, ranked.
5. **Decisions needed:** each with options and your recommendation.
6. **Next phase plan:** the first 5 concrete steps.

## 7. Global acceptance criteria (the release bar)

- Sim parity: all golden traces match (or approved divergences), zero desyncs in soak tests.
- Performance: 60 fps sustained on the defined reference low-end Android device and an older
  supported iPhone; sim step under budget; no GC allocations in-match; memory within budget.
- Size and startup: install size and cold-start time within the budgets set in Phase 0.
- Stability: crash-free sessions above the target set with the user (suggest >= 99.5%).
- Compliance: legal/IP issues resolved or explicitly accepted by the user in writing.
- Maintainability: CI green, docs current, a new unit and a new map can be added using data
  only by someone who did not write the code.

## 8. Start now

Begin with **Phase 0**. Do not write production code yet. First read the files listed in
section 2, then deliver the Phase 0 report with the legal/scope findings and the decision
list, and wait for the user's answers.
