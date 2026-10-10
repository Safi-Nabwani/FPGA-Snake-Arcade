# FPGA Snake — Phase 3A: Jungle Temple Graphics

Date: 2026-10-10, Asia/Jerusalem. Starting commit: `1d8725a` (Git cleanup).
Read: PROJECT_MAP.md, PRECHANGE_BASELINE.md, ARENA_ENLARGEMENT.md,
HUD_RELIC_COUNTERS.md and TIMING_REPAIR.md; inspected jungle-temple-reference.png.
Earlier geometry descriptions in the first reports are historical, not instructions.

## 1. Scope and artwork

Temple of the Serpent arena, serpent and relic artwork is implemented by replacing
eight existing MIF contents. Production HDL and schematics are not edited.
The arena remains 20×18 cells, 24×24 pixels per cell, at (144,24), with half-open
bounds X [144,624), Y [24,456). Snake start remains (384,240), cell (10,9).
The vertical sidebar, scoring/counters, input/audio, movement/speed/length,
spawn exclusion, obstacle map, game rules and win/loss overlays are unchanged.
PLL, SDCs, pin assignments, SignalTap, fitter settings and QSF are unchanged.

The reference guides mossy stone, emerald scales, antique gold and gem colors;
its geometry and horizontal scoreboard are not copied. No final HUD, end-screen
or exterior-border redesign is performed. Existing exterior wood texture remains.

## 2. Exact modified production files

All are in `RTL/mifs/`, retaining filenames, WIDTH=8, DEPTH=576 and row-major
address=y×24+x. Existing module names and ROM instantiations remain unchanged.

| File | New artwork | Existing consumer |
| --- | --- | --- |
| grass_tile_24.mif | Weathered, mossy ancient stone floor | back_ground_draw |
| stone_tile_24.mif | Cracked, chipped stone floor variant | back_ground_draw |
| rock_tile_24.mif | Raised carved temple obstacle, dark boundary/gold bevel/moss | back_ground_draw |
| snake_head_24.mif | Emerald serpent head, eyes, gold highlights, upward base orientation | headBitMap |
| snake_body_24.mif | Emerald segmented scales with gold accents | snake_body |
| red_apple_24.mif | Ruby jewel in temple-style mount | AppleBitMap |
| blue_apple_24.mif | Sapphire jewel in temple-style mount | AppleBitMap |
| black_apple_24.mif | Obsidian/violet Cursed jewel in tarnished mount | AppleBitMap |

Their combined logical payload remains 36,864 bits. No ROM duplication or larger
depth is added. Original floor numeric identifiers (grass/stone) are intentionally
retained; both now represent walkable stone, not distinct gameplay terrain.

## 3. Exact new files and preview locations

- `scripts/build_jungle_assets.py`: deterministic conversion/verification/preview generator.
- `assets/jungle/collision_masks.json`: original masks extracted once from commit
  1d8725a, with original Git-blob SHA-256 provenance for each asset.
- `assets/jungle/PROMPTS.md`: complete prompts and built-in generator provenance.
- `assets/jungle/source/`: eight retained built-in-generated PNG inputs, named
  black_apple_24.png, blue_apple_24.png, grass_tile_24.png, red_apple_24.png,
  rock_tile_24.png, snake_body_24.png, snake_head_24.png and stone_tile_24.png.
- `assets/jungle/previews/`: eight decoded native 24×24 RGBA PNGs with those same
  filenames, plus asset_sheet.png, head_rotations.png and arena_art_preview.png.
- `simulation/jungle_rom_model.sv`: test-only uppercase-parameter ROM adapter,
  loading actual MIF files with registered-address/unregistered-data behavior.
- `simulation/jungle_graphics_tb.sv`: self-checking actual-asset rendering tests.
- `simulation/jungle_graphics.do`: ModelSim runner with nonzero failure exit.
- `JUNGLE_GRAPHICS.md`: this report.

No other authored files are created or modified. Compiler outputs, logs, work
libraries and generated fixture HEX files are ignored, not committed.

Open the [asset sheet](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/assets/jungle/previews/asset_sheet.png),
[head rotations](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/assets/jungle/previews/head_rotations.png),
and [arena artwork preview](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/assets/jungle/previews/arena_art_preview.png).
The arena preview uses the actual 18 RTL map rows but places an **illustrative**
trail and all relic types for inspection. It is not a simulation screenshot or
hardware capture; Sapphire is initially hidden in the real game. It excludes the
unchanged HUD and exterior. Rotation preview shows the full 24×24 ROM; the actual
head square still has its original 22×24 clipping.

## 4. Reproducibility, RGB332 and collision preservation

Built-in image generation supplied the raster artwork; no external API/CLI was
used. Generation itself is nondeterministic. The selected source PNGs are retained
in this project, so rebuilding the final assets needs no AI call or network.
Conversion was run with Python 3.12.14 and Pillow 12.3.0.

From project root, with Python/Pillow available:

```text
python scripts/build_jungle_assets.py --write
python scripts/build_jungle_assets.py --check
```

`--write` overwrites only the eight approved MIFs, reproducible previews and ignored
test fixtures in db/jungle_graphics_fixture/. `--check` changes no files and checks
MIF formatting/coverage/values, conversion reproducibility and decoded preview
round trips. Initial `--capture-masks` used Git history once; it refuses to
overwrite the saved reference, and is unnecessary for normal rebuilds.

Encoding is RGB332: R[7:5], G[4:2], B[1:0]. Quantization excludes 0xFF from every
opaque color candidate; white highlights use the nearest non-FF value. Transparency
comes ONLY from the original per-address mask, never generated alpha. Where source
alpha is empty but the old pixel is opaque, nearest occupied source artwork extends
into the old silhouette. Legacy apple top protrusions therefore become relic-mount
details rather than disappearing. Floors use box reduction and a restrained six-
color stone/moss palette; other assets use nearest-neighbor sampling and the full
non-FF RGB332 palette. All final assets are exactly 24×24 pixels.

| Sprite | Original opaque pixels | New opaque pixels | FF mask differences |
| --- | ---: | ---: | ---: |
| Head | 216 | 216 | 0 |
| Body | 400 | 400 | 0 |
| Ruby/red | 341 | 341 | 0 |
| Sapphire/blue | 322 | 322 | 0 |
| Cursed/black | 333 | 333 | 0 |

All three floor/obstacle ROMs remain opaque at all 576 addresses. Obstacles are
collided by tile type, not artwork; their complete tile rectangles and spawn map
are unchanged. Head/relic drawing requests depend on FF masks, so preserving every
bit plus unchanged RTL preserves their collision semantics even at legacy pipeline
edges. Body self-collision remains its separate inset-rectangle algorithm.

The generated head source has its snout at the bottom; conversion rotates it 180°
before mask application to match the existing upward-facing ROM contract. Runtime
address transforms are unchanged: UP/NONE=(x,y), RIGHT=(y,23−x), DOWN=(23−x,23−y),
LEFT=(23−y,x). Previews use nominal RGB332 channel scaling, not the physical DAC's
legacy unusual low-bit expansion; they are palette previews, not electrical output
measurements. The original reference PNG and all unused/font/end/audio MIFs remain
byte-identical.

## 5. Functional verification

- `JUNGLE_ASSETS_PASS`: all eight MIFs cover exactly 576 unique in-range addresses;
  all values are 8-bit, exact original masks retained, deterministic MIF/PNG round trips.
- `JUNGLE_GRAPHICS_PASS`: actual MIF loading, all 576 head addresses in NONE and
  four directions, real colors/masks, original extra head output stage under
  streaming input, all 576 pixels of each relic/body, priority and hidden Sapphire,
  exclusive body right bound, game-running gating, all 307,200 visible background
  pixels with actual floor ROM addresses/colors and original collision rectangles.
- `ARENA_GEOMETRY_PASS`: unchanged existing all-pixel geometry/map, candidate range,
  all-cell reachability/reroll, reset/alignment and four-direction movement checks.
- `HUD_COUNTERS_PASS` and `HUD_RENDER_PASS`: unchanged existing independent counters,
  saturation/reset/high-score behavior, original game events and real-font HUD stream.

Final ModelSim tests report zero HDL/simulation errors and warnings; existing
work-library reuse produces only the harmless vlib-34 notice. The first new test
run failed in its test-only reader because the unchanged wood ROM uses decimal,
not HEX, addresses. The adapter was corrected; no production file was changed to
fix that harness issue, and the final run passes.

Reproduce the new test from project root after `--write`:

```powershell
& 'C:/intelFPGA_lite/17.0/modelsim_ase/win32aloem/vsim.exe' -c -modelsimini 'C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini' -l simulation/jungle_graphics.log -do simulation/jungle_graphics.do
```

The existing arena_geometry.do and hud_relics.do runners are unchanged. This host
needs ModelSim outside the sandbox due to its previously documented DLL issue.
The adapter is NOT in QSF; Quartus uses vendor ROMs. These are unit/renderer checks,
not a full-system BDF/QXP/PLL or gate-level simulation. No shared pipeline redesign
is attempted and no physical display functionality is claimed.

## 6. Single Quartus build and comparison

Quartus Prime Lite 17.0.0 Build 595; revision Lab1Demo; top TOP_VGA_DEMO;
Cyclone V 5CSXFC6D6F31C6. Exactly one map/fit/STA/assembly sequence ran
11:31:47–11:40:33 local time. Settings writing was disabled for map/fit/assembly;
STA used its supported `--do_report_timing` option. No alternate build or seed,
constraint change, or extra fitter run was used. The SOF is generated, not programmed.

| Stage | Result | Errors | Previous warnings | New warnings (including critical) | Elapsed |
| --- | --- | ---: | ---: | ---: | --- |
| Analysis/synthesis | Successful | 0 | 186 | 186 (185 ordinary + 1 critical) | 1 min 17 sec |
| Fitter | Successful | 0 | 80 | 80 (77 ordinary + 3 critical) | 6 min 37 sec |
| TimeQuest | Successful; all reported constrained checks pass | 0 | 41 | 41 (39 ordinary + 2 critical) | 25 sec |
| Assembler | Successful; SOF NOT programmed | 0 | 0 | 0 | 26 sec |

Previous means the verified Phase 2B.3 repaired build, not the earlier failing HUD
fit. The prior local reports were preserved in ignored db/phase3a_baseline/ before
the new build. Warning categories, ordinary/critical counts and per-ID counts
match that baseline exactly in every stage. No new warnings/errors or analyzed
timing violations are introduced. The unchanged remaining critical warnings
concern missing debug connectivity, automatic I/O placement and stale SDC targets,
not failed setup/hold checks.

| Resource | Repaired baseline | Jungle graphics | Change |
| --- | ---: | ---: | ---: |
| ALMs | 6,611 / 41,910 (16%) | 6,611 / 41,910 (16%) | 0 |
| Registers | 5,770 | 5,770 | 0 |
| Block memory bits | 941,568 / 5,662,720 (17%) | 941,568 / 5,662,720 (17%) | 0 |
| RAM blocks | 120 / 553 (22%) | 120 / 553 (22%) | 0 |
| I/O pins | 91 / 499 (18%) | 91 / 499 (18%) | 0 |
| DSP blocks | 1 / 112 | 1 / 112 | 0 |
| PLLs | 1 / 15 | 1 / 15 | 0 |

| Timing corner | Game setup before/after | Game hold before/after | JTAG hold before/after |
| --- | ---: | ---: | ---: |
| Slow 1100 mV, 85°C | +6.116 / +6.116 ns | +0.304 / +0.304 ns | +0.154 / +0.154 ns |
| Slow 1100 mV, 0°C | +4.943 / +4.943 ns | +0.287 / +0.287 ns | +0.140 / +0.140 ns |
| Fast 1100 mV, 85°C | +18.704 / +18.704 ns | +0.177 / +0.177 ns | +0.041 / +0.041 ns |
| Fast 1100 mV, 0°C | +19.326 / +19.326 ns | +0.163 / +0.163 ns | +0.028 / +0.028 ns |

JTAG setup is also unchanged: +10.807 / +10.882 / +12.888 / +13.011 ns in these
corners. Minimum reported recovery/removal/pulse-width margins remain
+37.257 / +0.317 / +0.793 ns; every reported TNS remains zero. Game Fmax at slow
85°C/0°C remains 39.02/37.31 MHz, with the actual clock still 31.5 MHz.
Effective native Optimize Hold Timing remains All Paths. Identical measured
physical resources/timing are consistent with an artwork-content-only change;
this is a fresh compilation, not a reuse of old report timestamps.

Constraint coverage is unchanged: 0 unconstrained clocks, 5 input ports/120 input
paths and 55 output ports/336 output paths. Therefore passing analyzed internal
timing is NOT external-interface timing sign-off or board-programming approval.
SignalTap remains 39/40 connected, with the same missing obstacle hierarchy.

SHA-256 comparison of all 86 starting tracked files finds exactly the eight
approved MIF modifications: all 78 other tracked files are byte-identical.
No production HDL, BDF, configuration/constraints, other assets or previous tests/
reports were changed. Whitespace checks and asset reproducibility checks pass.

Evidence: [map](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.map.rpt),
[fitter](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.fit.rpt),
[resources](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.fit.summary),
[timing summary](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.sta.summary),
[timing details](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.sta.rpt),
[assembly](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.asm.rpt),
[graphics tests](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/simulation/jungle_graphics.log),
[arena tests](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/simulation/arena_geometry.log),
[HUD tests](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/simulation/hud_relics.log).
These generated evidence files are kept locally but deliberately excluded from Git.

## 7. Remaining issues and scope boundary

- Final carved HUD, exterior decoration and win/loss screens remain future work.
- Original 22×24 head clipping, mixed non-HUD drawing/collision latencies, VGA
  refresh/off-by-one behavior and terminal-panel overlap remain; artwork does not
  repair them or claim complete physical pixel/sync alignment.
- Existing incomplete external timing constraints, stale SDC targets, nine unsafe
  automatically assigned debug output pins, missing SignalTap obstacle probe,
  audio loops/latch/reset warnings, missing PLL simulation model and old VWF
  absolute paths remain separately scoped. Do not program this SOF without a
  separately approved board-interface/pin audit.
- Sprite silhouettes cannot be arbitrary jewels/head shapes while exact drawing-
  mask collision semantics remain mandatory. The retained silhouette limits the
  artwork and is intentional, not an untested gameplay change.
- Pre-existing untracked Lab1Demo.qws (Quartus workspace preferences) is preserved,
  not staged, deleted or added to ignore rules in this artwork phase.

No FPGA programming, push, module renaming or later-phase work is performed.

## 8. Git and stop

Functional tests, reproducibility/preservation checks and the single fresh build
pass, satisfying the condition for a local commit with message
`Add Jungle Temple arena and relic graphics`. Only the 34 listed authored files
(eight modified MIFs and 26 new asset/script/test/report files) are included;
ignored compiler outputs stay out of Git. The commit hash is provided in the
session handoff. Pre-existing untracked Lab1Demo.qws remains outside this commit.
No push or FPGA programming. Phase 3A complete; stop and wait for approval.
