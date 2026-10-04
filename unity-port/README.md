# unity-port

Work area for porting the C++ RTS in this repository to a mobile game with a
deterministic C# simulation, a Unity client, and a .NET 8 lockstep server.

The original C++ code and data elsewhere in this repository are the behavioral
reference (the "oracle"). They are never modified. Everything for the port
lives under this directory.

## Status

| Phase | State |
|---|---|
| 0: Discovery and legal gate | Deliverables done. Exit waits on owner decisions D1–D7 and a legal review. |
| 1: Foundations | Not started |
| 2+ | Not started |

Start with [`docs/00-phase-plan.md`](docs/00-phase-plan.md). It lists the
decisions that block Phase 1.

## Documents

| File | Contents |
|---|---|
| [`docs/00-phase-plan.md`](docs/00-phase-plan.md) | Phases, exit criteria, decisions needed |
| [`docs/01-legal-provenance-register.md`](docs/01-legal-provenance-register.md) | What is licensed, what is unknown, what must change before release |
| [`docs/02-oracle-audit.md`](docs/02-oracle-audit.md) | How the C++ simulation, networking, and data pipeline work, with file:line citations |
| [`docs/03-oracle-build.md`](docs/03-oracle-build.md) | Building and booting the C++ oracle on modern Linux |

## Tools

| Script | Purpose |
|---|---|
| `tools/oracle/build-oracle.sh` | Builds the legacy Linux client from unmodified sources into `.cache/oracle/` |
| `tools/oracle/smoke-oracle.sh` | Boots it under Xvfb and fails if no frame renders |

`.cache/` is git-ignored.
