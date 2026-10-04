# Legal and provenance register

**This is an engineering inventory, not legal advice.** It records what the
repository says about licensing and origin, with citations, and flags what is
unknown. Questions of law go to counsel (see the end of this page). Until
counsel answers, anything marked *unknown* is treated as **not licensed** for
release.

Owner decision D3 (accepted): **plan for replacement art, audio, fonts, and
name by default**. Original content may be used for internal development and
parity testing only.

## Summary

| Asset class | Status | Port plan |
|---|---|---|
| Source code (first-party C++/C#/Python) | **BSD 2-clause**, Spiffcode (`LICENSE.txt`) | The C# port is a translation. Keep the BSD notice in the repo and in an in-app licenses screen. |
| Names and logos: "Hostile Takeover", "Warfare Incorporated" | **Registered trademarks** of Spiffcode (`README.md:6`) | Rename and rebrand. |
| Sprites, UI art, cutscenes, tiles | **Unknown.** No license grant found. | Replace. |
| 2008–09 high-res art | Stated as released (`game/README.txt:46-48`), **not found in repo**, no terms | Ask the rights holder (see questions for counsel). Don't plan on it. |
| 3D source scenes (`assets/3d_assets.zip`) | **Unknown, with third-party indicators** | Don't use. |
| Sound effects | **Contains commercial stock library audio** | Replace all. |
| Fonts | **Contains commercially licensed and shareware fonts** | Replace all. |
| Levels, mission text, story, characters | **Unknown.** Authored by credited designers and writers. | Replace for release, or license. Keep for internal parity tests. |
| Bundled third-party code | Mostly permissive, plus **proprietary SDK headers** | The port uses none of it. Never copy `inc/` or `bin/`. |

## 1. Source code

- `LICENSE.txt:1-26`: BSD 2-clause, "Copyright (c) 2003-2014, Spiffcode, Inc".
  `README.md:6` limits the grant explicitly: "The Hostile Takeover **source
  code** is made available under the BSD open source license."
- The copyright years disagree: `README.md:6` says 2004–2014, `LICENSE.txt:1`
  says 2003–2014.
- Almost no first-party file carries a header. Only 4 of 160 files in `game/`
  mention copyright, and none in `mpshared/`, `server/`, or `stats/`.
- Embedded third-party snippets with their own terms:
  - "Portions Copyright (C) Steve Rabin, 2000", no terms
    (`game/StateMachine.cpp:6`, `game/ht.h:1895`). This is the state-machine
    design the port will mirror.
  - Bentley-McIlroy qsort, "Copyright 1993, John Wiley", inside `#if 0`
    (`game/GameObjects.cpp:2637-2642`). Not compiled.
- **Port implication:** BSD clause 2 asks binary redistributions to reproduce the
  notice. Plan an in-app "Licenses" screen that carries the Spiffcode BSD notice
  and the notice of every third-party library actually shipped.

## 2. Trademarks, brand, and identity

- "Hostile Takeover" and "Warfare Incorporated" are registered trademarks of
  Spiffcode (`README.md:6`). The title logo carries a ™ mark (rendered main menu,
  Phase 0 screenshot) and the credits say "Hostile Takeover(TM)"
  (`data/help.txt:451-466`).
- Brand strings occur widely: "Hostile Takeover" 143 times in 55 files,
  "Warfare Inc[orporated]" 28 times in 12 files, and the bundle id
  `com.spiffcode.ht` (Android manifest, Xcode).
- Third-party publisher credit: "HANDMARK PRESENTS" (`data/forms.ini.pp:726`),
  also in the compiled `htdata832.pdb`.
- Story and characters: Andy Whitmore (`data/help.txt:78`), Jana, Fox, Olstrom,
  the ACME and OMNI factions, and Galaxite. They appear throughout the level
  files and art. They're creative expression with no license stated.
- **Port plan:** new title, logo, bundle ids, store listings, and domain. Don't
  use "Warfare", "Hostile Takeover", "Spiffcode", or "Handmark" in any shipped
  string or metadata. Replace the faction and character names unless counsel
  clears them.

## 3. Art

- Sprites and animations: `data/art824/` (36 `.amx` animations, 1,087 PNG frames,
  138 BMPs). Credits: "Art/Animation: Rob Girling, Mark Soderwall"
  (`data/help.txt:491-493`). No license or assignment terms in the repo.
- Title screens: `data/SourceArt/*.psd`, with layer text "Copyright 2003…" and
  "2014 Spiffcode, Inc".
- `game/README.txt:46-48`: "Around 2008-09, we commissioned much higher res 32
  bit artwork… We are releasing this new artwork with the game." The audit did
  not find that artwork in this repository; the `art824` sprites are small
  (about 20×22 px). The sentence states intent but gives no license terms.
- `assets/3d_assets.zip` (1,499 entries, 100 3ds Max scenes):
  - Texture names match id Software *Quake III Arena* conventions
    (`bouncepad01_diamond2c`, `proto_grate4`, `gothic_light2`, …). That
    identification came from the audit and **has not been independently
    confirmed**.
  - Files predate the project (`rock11.jpg` from 1997). Scenes reference stock
    3ds Max maps (`C:\3dsmax4\Maps\Skies\Skysun2.jpg`). Artist paths suggest a
    freelancer (`C:\Xtreme\free_lance\…`).
  - **Don't use this archive.**
- Icons and launch images (`game/iphone/Images.xcassets`, `game/sdl/android/res/`,
  `game/sdl/mac/`): no provenance metadata.

## 4. Audio

- Sources: `data/sounds/soundeffects.zip` (361 WAV). `files.txt` inside it is a
  directory listing of `C:\dl\sfx\alistair0916\Datadrop4\Final` from 2002.
  Compiled form: `game/htsfx.pdb`. There is no music.
- Embedded WAV metadata:
  - **"Copyright 2000, Sounddogs.com"** on 25 distinct sounds (verified). **16
    of them are wired into the shipping sound table** (`data/all.sfx`,
    "checked"): activator on/off, big explosion, big tank and impact,
    replicator build/on/off, rocket fire and impact, door open/close,
    checkbox, money, happy ending.
  - "Vivid Sound Productions" (`softclick.wav`, `splitent.wav`), "Soundrangers"
    (`listselect.wav`), "1995 Microsoft Corporation" (`clickerx.wav`), and an
    engineer credit on `BRIEFING.WAV`.
- Voice casting notes exist (`legacy/docs/voice_assignments.xls`) with no actor
  names or releases. `legacy/docs/Sound and Music.doc` mentions "this contract".
- **Port plan:** replace every sound effect and voice line. Stock-library terms
  typically cover use inside a product, not redistribution in an open
  repository, but that is counsel's call, not ours.

## 5. Fonts

| File | Embedded terms | Plan |
|---|---|---|
| `data/SourceArt/Eurostyle Extended.TTF` | Adobe/Linotype: "may not be reproduced, used, displayed, modified, disclosed or transferred without the express written approval of Adobe" (verified) | Don't ship. Remove from any asset pipeline. |
| `data/SourceArt/Quadtrangle.TTF` | "Ray Larabie 1997 - freeware" | Replace. Check the current Larabie terms only if wanted. |
| `data/SourceArt/SteelWolf.ttf` | "Shareware… Permission Required For Commercial Distribution" | Don't ship. |
| In-game bitmap fonts (`data/art824/*font.bmp`, `data/fonts/*`) | No provenance. PSD layers name "04b09". | Replace with fonts under SIL OFL or a purchased license. |

## 6. Levels, mission text, and story

- 42 levels ship in `htdata832.pdb` (15 story, 5 challenge, 1 demo, 21
  multiplayer maps). The credits name the mission designers and a story
  editor (`data/help.txt:451-497`). Briefings and dialog are inside the level
  triggers.
- `server/README.txt:351-358`: downloadable mission packs were **user
  submissions** from the forums, with rights held by their individual
  authors. None are in this repo; don't seek them out.
- **Port plan:** use the original levels only for internal parity tests.
  Release content means new maps and missions, or a license for the originals.

## 7. Bundled third-party code and binaries

None of this is needed by the port. Sim, Server, and Data are new C# code, and
the client uses Unity's stack.

| Path | What | Terms in repo | Note |
|---|---|---|---|
| `game/sdl/SDL2/`, prebuilt `libSDL2` for iOS/Android/macOS | SDL 2.0.4 | zlib (header text) | Not used by the port |
| `game/sdl/curl/android/*/libcurl.a` | libcurl with **OpenSSL 1.0.1s statically linked** | Neither license text is shipped | Also an end-of-life, vulnerable TLS stack. Never reuse. |
| `yajl/` | yajl 0.4.0 | BSD-3 (`yajl/COPYING`) | — |
| `base/base64.cpp` | UCL/Bellcore | BSD **with advertising clause** (`:19-21`) | — |
| `base/md5c.cpp`, `base/sigslot.h` | Colin Plumb MD5, sigslot | Public domain | — |
| `inc/` Palm, Sony, Tapwave, WIDCOMM, MediaQ headers | Platform SDKs | **"Proprietary and confidential"**, "private and not for public distribution" (verified for WIDCOMM `inc/BtIf*.h:13`) | Not referenced by any build outside `inc/`. **Never copy into the port.** |
| `bin/SharpZipLib.dll` | SharpZipLib 0.31 | None in repo (upstream 0.x: GPL with linking exception) | Tool dependency only |
| `bin/MagicLibrary.dll`, `bin/mappy.exe`, `bin/touch.exe` (Microsoft), and others | Third-party tools | None | Don't redistribute, don't depend on |
| `AniMax/PerPixelAlphaForm.cs` | Rui Godinho Lopes, 2002 | "not sold for profit without the authors expressed written consent" (verified) | Editor tool only. Not used by the port. |
| `Schemer/SerialStream.cs`, `SpiffLib/binarytree.cs`, `m/mediancut.cs`, `SpiffLib/AudioFormats.cs` (CWI ADPCM) | Various | Freeware or none | Tools only |
| `syncerror/simplejson/` | simplejson 2.0.7 | None in repo (upstream MIT) | — |

No GPL or LGPL code is compiled into the game client or the server.

## 8. Other release-relevant findings

- **No secrets committed.** Only `REPLACEME_*` placeholders
  (`server/secrets.cpp`, `stats/config.py:60-65`, `server/docker/config.json:7`).
  No keystores, certificates, or provisioning profiles.
- The legacy stack has privacy and security defects that must not carry over
  (details in `02-oracle-audit.md`): unsalted MD5 passwords, a plaintext
  password stored on failed signup, plaintext passwords in client prefs, and an
  unauthenticated endpoint exposing player IPs and device ids.
- DRM and expiry code (`game/drm.cpp`, `game/misc.cpp:933-960`) is not ported.
- **Provenance gap:** this clone is shallow (50 commits from 2016, boundary
  `d926ef0`). The original 2014 open-source release history isn't available
  locally, so file-level authorship before 2016 can't be traced from here.

## 9. Engineering rules adopted now

1. Release builds contain **zero** original art, audio, fonts, level files, or
   brand strings. In Phase 3 the extractors write original content to a
   `legacy-assets` pack that the Unity project uses only behind a development
   build flag. CI fails a release build that references it.
2. Every shipped asset gets an entry in a provenance manifest (source, author,
   license, proof of license) checked in next to it.
3. An in-app Licenses screen lists the Spiffcode BSD notice and every shipped
   third-party notice.
4. Nothing from `inc/`, `bin/`, or `assets/` is copied into `unity-port/`.

## 10. Questions for counsel

1. Does the BSD grant ("source code", `README.md:6`) extend to anything else
   in the repository: data files, level files, art, audio? If not, what is the
   status of each?
2. Is a C# reimplementation that follows the original algorithms, data layouts,
   and constants a derivative work of the BSD code? We assume yes and plan to
   comply with the BSD notice terms. Is anything more required?
3. Can gameplay rules, unit stats, and balance numbers (taken from
   `GobTemplates.ini` and code) be reused in a renamed game?
4. Do the original level layouts, mission scripts, story, and character and
   faction names need a license? From whom: Spiffcode, the credited designers
   and writers, the artists?
5. Would the rights holder license the 2008–09 high-res art mentioned in
   `game/README.txt:46-48`, the original art and levels, or the trademarks?
   Contact: the README invites contact with Scott Ludwig and Darrin Massena
   (`game/README.txt:16,80`).
6. Is there any exposure from **this public repository already containing**
   stock audio (Sounddogs.com), an Adobe/Linotype font, and proprietary SDK
   headers? Should the fork remove them from history?
7. Is any trademark clearance search needed for the new title and faction names
   in the target markets?
