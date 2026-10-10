# FPGA Snake — Phase 3A.2: Implemented Jungle Temple Assets

Final verification: 2026-10-11 (client date). The single implementation build ran on 2026-10-10 according to the execution host's reports.

Status: **The verified graphics implementation passes compilation, constrained timing and focused functional regression tests.** No additional Quartus compilation was launched when resuming this phase. No FPGA programming or GitHub push was performed.

Important working-copy exception: after the verified build, 67 original SignalTap assignments were removed from the local `Lab1Demo.qsf` (file modification time 2026-10-10 15:52:37). Those later changes are **not part of this implementation, not covered by the reported build, and excluded from the graphics commit**. They are preserved in the working copy. The committed QSF retains the original SignalTap configuration and adds only the new graphics source entry.

Read PROJECT_MAP.md, ARENA_ENLARGEMENT.md, HUD_RELIC_COUNTERS.md, TIMING_REPAIR.md, JUNGLE_GRAPHICS.md, PREVIEW_REDESIGN.md and RELIC_REFINEMENT.md before implementation. Inspected the Jungle Temple reference and approved native floor/snake/ruin/refined relic PNGs.

## 1. Exact implementation files

Modified production files:

- `Lab1Demo.qsf`: register `RTL/VGA/jungle_head_draw.sv` only. No other configuration change belongs to this phase.
- `RTL/VGA/headBitMap.sv`: use the separate frozen head collision ROM; keep the original address rotation, rectangle input and hit-output timing.
- `RTL/VGA/AppleBitMap.sv`: separate legacy hit masks from visual transparency; align visual type/valid metadata with registered ROM addresses.
- `RTL/VGA/snake_body.sv`: only visual output/validity registers changed. Trail, length updates, spacing and self-collision logic are unchanged.
- `RTL/VGA/Snake_Block.bdf`: add the parallel full-size visual head renderer, visual drawing-request output and new RGB wiring.
- `RTL/VGA/TOP_VGA_DEMO.bdf`: extend the Snake_Block symbol and route its new visual request to objects_mux; retain the old request on the game-controller/debug path.
- `RTL/VGA/back_ground_draw.sv`: four floor variants, three ruin variants, fixed map and rotation selection, aligned visual background pipeline.
- `RTL/VGA/apple_position_controller.sv`: use the same shared ruin exclusion map as drawing; retain range checking, overlap checks and reroll behavior.
- `RTL/VGA/NumbersBitMap.sv` and `RTL/VGA/hud_labels.sv`: RGB332 color constants only. All positions, glyphs, digit selection and counter interfaces remain unchanged.

New production files:

- `RTL/VGA/jungle_head_draw.sv`: full 24×24 visual head.
- `RTL/VGA/jungle_map.svh`: generated fixed tile descriptors and obstacle rows, shared by rendering and spawn validation.

Updated MIFs:

```text
RTL/mifs/grass_tile_24.mif       mossy floor
RTL/mifs/stone_tile_24.mif       cracked floor
RTL/mifs/rock_tile_24.mif        ruin block
RTL/mifs/snake_head_24.mif       approved upward-facing head
RTL/mifs/snake_body_24.mif       approved body
RTL/mifs/red_apple_24.mif        Ruby gemstone
RTL/mifs/blue_apple_24.mif       Sapphire crystal
RTL/mifs/black_apple_24.mif      Cursed shard
```

New MIFs:

```text
RTL/mifs/floor_base_24.mif
RTL/mifs/floor_carved_24.mif
RTL/mifs/ruin_wall_24.mif
RTL/mifs/ruin_pillar_24.mif
RTL/mifs/snake_head_collision_24.mif
RTL/mifs/relic_collision_24.mif
```

New conversion/verification files:

- `scripts/implement_jungle_preview.py`
- `scripts/verify_jungle_integration.py`
- `simulation/jungle_implementation_tb.sv`
- `simulation/jungle_implementation.do`

Updated test files: `simulation/arena_geometry_tb.sv` and `simulation/hud_render_tb.sv`. Their obstacle expectations now describe the approved 30-cell layout; HUD expected colors were updated without changing geometry assertions.

New generated-but-versioned art outputs: `assets/jungle/implemented/arena_map.json`, `full_scene_rgb332.png`, and 24×24 plus 192×192 PNG pairs for these exact stems:

```text
floor_base_24  grass_tile_24  stone_tile_24  floor_carved_24
rock_tile_24   ruin_wall_24   ruin_pillar_24
snake_head_24 snake_body_24
red_apple_24  blue_apple_24  black_apple_24
```

Each pair is `<stem>.png` and `<stem>_8x.png`. Collision masks are not treated as decorative PNG art.

Previously untracked approval provenance is retained unchanged: `PREVIEW_REDESIGN.md`, `RELIC_REFINEMENT.md`, `assets/jungle/previews_v2/`, and `assets/jungle/previews_v3_relics/`. These supply the reproducible converter's approved inputs, not new art generated during implementation. Original reports, old previews/source art, reference image, font and end-screen MIFs are preserved.

## 2. Geometry and approved fixed ruin/floor maps

Unchanged display: 640×480. Arena: 20×18 cells of 24×24 at (144,24), extent 480×432; X [144,624), Y [24,456). HUD remains X [8,128), Y [24,456), with all prior label/digit positions and dividers. Snake start remains (384,240), cell (10,9), length four. No movement, speed, score, counter, audio or input rules changed.

The obstacle **locations** intentionally adopt the approved richer preview layout; this is not a claim that the previous 16-cell layout remains unchanged. Blocked-cell geometry remains a whole 24×24 rectangle, independent of ruin artwork/alpha, and border/collision rules retain their existing timing.

Zero-based blocked cells:

| Cluster | Cells |
| --- | --- |
| Northwest wall, 6 | (2,3), (3,3), (4,3), (5,3), (2,4), (2,5) |
| Northeast wall, 6 | (14,3), (15,3), (16,3), (17,3), (17,4), (17,5) |
| West ruin, 3 | (3,9), (3,10), (4,10) |
| Southeast wall, 5 | (14,11), (15,11), (16,11), (16,12), (16,13) |
| South wall, 4 | (6,15), (7,15), (8,15), (6,14) |
| Pillars, 6 | (11,4), (6,7), (17,8), (11,15), (3,14), (18,14) |

Total: **30 blocked / 330 walkable cells**. All 330 walkable cells are connected under four-neighbor flood fill. Columns 8–12, rows 7–11 remain an obstacle-free starting region. Initial relic seeds (7,3), (5,10), (12,6) remain valid. No new snake-body spawn exclusion is introduced.

The converter reproduces the approved irregular distribution deterministically, rather than a per-frame random or checkerboard pattern. On the 330 walkable cells: base 174 (52.73%), mossy 75 (22.73%), cracked 57 (17.27%), carved 24 (7.27%). Moss clusters use three broad fixed patches; cracks use separate patches; carved accents fill selected irregular positions. Cracked/mossy tile rotations follow fixed coordinate formulas.

A descriptor uses five bits: [2:0] selects one of seven tile ROMs, [4:3] selects a clockwise quarter-turn. The generated 18-row table stores 20 descriptors per row. The same generator emits the blocked rows; both graphics and spawn-exclusion RTL include the shared `jungle_map.svh`. No independently hand-maintained collision map remains.

## 3. Separate visual and collision masks

The preserved silhouettes come from unchanged `assets/jungle/collision_masks.json`, originally captured from pre-artwork commit `1d8725a`. Previous verified RTL and MIFs from `19ae76c` provide independent regression references.

| Object | Legacy collision-mask opaque pixels | New visual opaque pixels |
| --- | ---: | ---: |
| Head | 216 | 318 |
| Ruby | 341 | 269 |
| Sapphire | 322 | 180 |
| Cursed | 333 | 204 |

The old head square remains **22×24**, including its original clipping and clock behavior. `headBitMap` retains its original RTL except the mask-ROM filename, and its drawingRequest remains the collision signal `snakeHead_DR`. Its no-longer-used color output is not routed to the display.

The new renderer computes a separate **full 24×24** visual rectangle from raw raster coordinates and the same top-left position. The approved head occupies a centered 20×22 silhouette in that cell; eyes/highlights are retained. UP/NONE addresses are (x,y); RIGHT (y,23−x); DOWN (23−x,23−y); LEFT (23−y,x). No movement register or direction encoding was changed.

`Snake_Block` exposes `snakeHeadVisual_DR` internally to the hierarchy. TOP_VGA_DEMO sends it only to objects_mux's head-request input. Game-controller and existing debug connections still use `snakeHead_DR`. No new physical board output/pin is added.

The relic collision ROM packs three original masks into three bits per address: bit0 Ruby, bit1 Sapphire, bit2 Cursed. It retains the old selected-address, current selected-type, current-square gating and priority, including their boundary-cycle behavior. Visual alpha never feeds collection detection. Priority remains Cursed > visible Sapphire > Ruby. Existing blue-spawn visibility control is unchanged.

Body self-collision uses the original inset rectangles/trail comparisons, not body visual transparency. New body artwork contains 344 visible pixels instead of the previous 400-pixel drawing silhouette; this has no effect on self-collision geometry or length updates.

## 4. Pixel pipeline, encoding and palette

All visual sprite/tile ROMs remain 24×24, 576 words, eight-bit RGB332 with address y×24+x, ten-bit address interface, REGISTERED address and UNREGISTERED q. **FF is reserved for visual transparency**; every opaque converted sprite pixel avoids FF. The head mask uses 00/FF with the original eight-bit interface; packed relic masks use a separate three-bit ROM.

The visual streams now describe the same raw pixel:

1. Head/body/background: registered ROM address plus matching validity/selector metadata.
2. Head/body/background visual output register. HUD retains its existing two-stage pipeline.
3. Relics: existing square_object register, then ROM address plus matching selected-type/inside metadata; no extra display stage.
4. Unchanged objects_mux adds one common register stage.

Thus head, body, relics, background and HUD have **two raw-pixel stages before the mux**, followed by its third stage. Visual request and color match through transparent edges, region/tile transitions and rotated addresses. Controller-side head/relic/border/obstacle latencies are deliberately not retimed. Legacy end-message rendering/sync timing is not redesigned.

Native approved PNGs are converted reproducibly. Floor conversion uses a restrained dark-olive ramp, source-derived cracks/engraving/moss, and limited median/mode filtering to prevent blue/olive quantization speckles. Bright green serpent shades avoid excessive coarse blue-channel cyan; cream eyes/gold accents retain the full palette. Relic facet outlines/highlights use the full legal RGB332 palette, retaining the approved angular silhouettes.

HUD color constants only: panel 04, frame 8D, cream F9, gold D9, Ruby ED, Sapphire 57, Cursed B3. No font duplication, numeric logic or HUD geometry changes.

RGB332 cannot faithfully reproduce all high-color charcoal/stone shades in the approval image; the converted floor is darker olive and small interior details are simplified. Nominal PNG RGB expansion is **not a verified model of the existing unusual board DAC mapping**.

[Converted full-scene art preview](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/assets/jungle/implemented/full_scene_rgb332.png) is an illustrative composition, not a hardware/framebuffer capture or a faithful six-frame-spaced gameplay trail. Individual PNGs exactly preview their MIF pixels; the scene's HUD/pose are approval references, not simulation output.

## 5. Functional and preservation verification

Existing completed logs were inspected on resume; no new simulation or compilation was needed to finish the report. Final HDL compilations and simulations reported **zero errors and zero warnings**, apart from harmless reused-library vlib-34 notices.

- `simulation/jungle_implementation.log`: **3,345,662 focused checks pass**. Actual active MIFs are loaded through the registered-address LPM test adapter. All 307,200 visible pixels check background selection/rotation and aligned head/body/relic request/color/mux output. Full-size head checks cover all directions, padding and columns22/23.
- Golden head/relic RTL from `19ae76c` receives identical square offsets and controls. Collision outputs match cycle for cycle, including changes of direction, outside rectangles, overlapping relic priority, hidden Sapphire, reset and differing addresses.
- Paired unchanged game controllers and score accumulators receive the old/new real mask streams. Start/end/death/win/collection outputs and score digits match cycle for cycle. Coverage includes **8 Ruby events, 1 Sapphire event, 1 Cursed event, 121 death pulses and 1,232 sampled self-collision contacts**. Coverage totals are test activity, not counts from a hardware playthrough.
- Paired bodies match length, all **193 trail entries**, and self-hit outputs under 800 scripted frame updates with growth/shrink events, resets, local clears and running-state changes.
- `simulation/arena_geometry.log`: ARENA_GEOMETRY_PASS. All visible pixels and 360 map cells; all 1,024 representable coordinate pairs per relic color; safe sprite extents, overlap/out-of-range/obstacle rejection, generator reachability/reroll feedback; original aligned start and all four 24-pixel movement directions.
- `simulation/hud_relics.log`: HUD_COUNTERS_PASS and HUD_RENDER_PASS. Independent collection counters, leading zeros, saturation at999, new-game resets, high-score persistence, original controller score/win/loss event rules, real8192-bit numeric font, full-frame streaming labels/digits/panel/mux and no HUD/arena overlap.
- Converter `--check`: every current MIF and shared map matches deterministic approved-input conversion; 30 obstacles, connected330-cell walkable region, safe start/seed cells and fixed floor quotas pass.
- `verify_jungle_integration.py --qsf-index`: staged/compiled configuration passes. Confirms BDF collision versus visual routing, original head square/bitmap/body symbol interfaces, unchanged body state/self-collision code, palette-only HUD changes, and original score, counters, movement, input, font, PLL, constraints and pin files.
- The default preservation checker correctly detects the later working-QSF SignalTap removals. `--qsf-index` explicitly checks the verified staged QSF instead and prints a notice that the working QSF is different. This is not suppression or verification of the later removals.
- Git whitespace checks use `core.whitespace=cr-at-eol` for existing Windows line endings. The staged check reports only extra blank lines at EOF in the unchanged approval reports PREVIEW_REDESIGN.md / RELIC_REFINEMENT.md and the new jungle_head_draw.sv; these formatting notices do not affect compilation or functionality.

Reproduction from project root, using the installed bundled Python with Pillow:

```powershell
python scripts/implement_jungle_preview.py --check --fixtures
python scripts/verify_jungle_integration.py
# If deliberately preserving later local QSF edits outside the commit:
python scripts/verify_jungle_integration.py --qsf-index

& 'C:/intelFPGA_lite/17.0/modelsim_ase/win32aloem/vsim.exe' -c -modelsimini 'C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini' -l simulation/jungle_implementation.log -do simulation/jungle_implementation.do
# Existing arena_geometry.do and hud_relics.do run the other suites.
```

`--fixtures` reconstructs old reference RTL/MIFs and test hex files only under ignored db. `--write` is the explicit active-asset regeneration option; `--check` alone is read-only. This host requires ModelSim outside the sandbox because of the old simulator's Windows DLL relocation error.

The historical `build_jungle_assets.py --write` and `jungle_graphics.do` remain preserved for Phase3A history; **do not use them to regenerate/test the new separated-mask implementation**. Use the new converter/runner above.

These are focused RTL/renderer checks, not a full BDF/QXP/PLL/audio system or post-fit gate-level simulation. No physical VGA colors, keyboard or hardware gameplay are claimed as tested.

## 6. Single completed Quartus build

Quartus Prime Lite17.0.0 Build595; project/revision Lab1Demo; top TOP_VGA_DEMO; CycloneV5CSXFC6D6F31C6. Exactly **one map→fit→STA→assembly sequence** ran, host report timestamps **2026-10-10 13:58:03–14:05:35**. Settings writing was disabled for map/fit/assembly; STA used `--do_report_timing`. No second build, fitter seed search, constraint adjustment or board programming was performed.

| Stage | Result | Errors | Prior warnings | This build's warnings | Elapsed |
| --- | --- | ---: | ---: | ---: | --- |
| Analysis/synthesis | Successful | 0 | 186 | 225 (224 ordinary +1 critical) | 1m40s |
| Fitter | Successful | 0 | 80 | 80 (77 ordinary +3 critical) | 5m21s |
| TimeQuest | Successful | 0 | 41 | 41 (39 ordinary +2 critical) | 15s |
| Assembler | Successful | 0 | 0 | 0 | 16s |

Local reports: `output_files/Lab1Demo.map.rpt`, `Lab1Demo.fit.rpt`, `Lab1Demo.fit.summary`, `Lab1Demo.sta.rpt`, `Lab1Demo.sta.summary`, `Lab1Demo.asm.rpt`. Previous build snapshots are retained under `db/phase3a2_baseline/`. Compiler outputs and logs remain local/ignored.

### Resource comparison against the previous verified Phase3A build

| Resource | Before | After | Change |
| --- | ---: | ---: | ---: |
| ALMs /41,910 | 6,611 (16%) | 6,732 (16%) | +121 |
| Registers | 5,770 | 5,809 | +39 |
| Block-memory bits /5,662,720 | 941,568 (17%) | 958,144 (17%) | +16,576 |
| RAM blocks /553 | 120 (22%) | 123 (22%) | +3 |
| Pins /499 | 91 | 91 | 0 |
| DSP blocks | 1 | 1 | 0 |
| PLLs | 1 | 1 | 0 |

The additional art variants, independent mask ROMs and visual metadata consume modest extra logic/memory. No board interface is expanded.

### Setup/hold comparison

Slacks in ns, previous → new; all reported constrained corners pass:

| Corner | Game setup | Game hold | JTAG setup | JTAG hold |
| --- | --- | --- | --- | --- |
| Slow85°C | 6.116 →6.796 | 0.304 →0.301 | 10.807 →10.807 | 0.154 →0.152 |
| Slow0°C | 4.943 →5.701 | 0.287 →0.285 | 10.882 →10.882 | 0.140 →0.139 |
| Fast85°C | 18.704 →18.185 | 0.177 →0.178 | 12.888 →12.888 | 0.041 →0.039 |
| Fast0°C | 19.326 →19.029 | 0.163 →0.162 | 13.011 →13.011 | 0.028 →0.026 |

Worst game setup **+5.701ns**, worst game hold **+0.162ns**. Worst overall hold is JTAG **+0.026ns**, a small positive margin, not a renewed failure. Across all **40 summary checks**, no slack is nonpositive and every TNS is0. Recovery minimum35.525ns; removal minimum0.367ns; pulse-width minimum0.793ns.

Slow85/0°C game Fmax is **40.08/38.40MHz**, previously39.02/37.31MHz. Actual clock remains31.5MHz. Existing All Paths hold optimization remains effective and unchanged. No false path, relaxed clock, added timing exception or PLL change is introduced.

### Warning comparison and remaining timing/I/O limitations

Synthesis warnings increase by39 net:

| Warning | Before | After | Explanation |
| --- | ---: | ---: | --- |
| 10036 | 0 | 2 | Diagnostic tileAddress/selectedRegion used by geometry tests but optimized out in hardware |
| 10230 | 42 | 41 | Narrow-coordinate/descriptor assignments; old background warnings replaced by bounded new address/table operations |
| 10270 | 1 | 0 | Previous incomplete background case removed |
| 13046 | 1 | 5 | Additional vendor LPM-ROM internal tri-state groups |
| 13049 | 105 | 140 | Vendor ROM internal tri-state buffers converted into wires |
| All other synthesis codes | unchanged | unchanged | Includes the existing critical debug warning |

Eight new graphics/table truncation diagnostics are bounded by tests: local coordinates0–479/0–431 fit11bits, cell coordinates0–19/0–17 fit5bits, offsets0–23 fit5bits, sprite/rotated addresses0–575 fit10bits, and the shifted100-bit row intentionally selects a five-bit descriptor. No new latch, timing-critical warning, pin requirement or inferred gameplay-state change is reported. Additional LPM-ROM conversion notices do not represent external tri-state pins.

Known critical issues remain in the **verified** build: partially connected SignalTap39/40 (stale obstacle probe), nine debug pins without exact physical locations, and two stale SDC generated-clock target collections. Existing audio combinational-loop/reset warnings and legacy I/O limitations are not repaired here.

Constraint coverage: zero unconstrained clocks; five input ports/120 paths and55 output ports/**142 paths** remain unconstrained. Previously output paths were336; the changed synthesis/ROM/mux fanout changes path counts, **not constraint coverage**. These positive internal margins do not establish external VGA/audio/PS2 board timing.

## 7. Git scope and stop point

Local commit message:

`Implement Jungle Temple visuals with separate collision masks`

Commit the verified graphics sources, active assets, reproducible conversion/tests, unchanged approval provenance and this report. The QSF commit stages **only the new source registration**, retaining original debug/timing/pin assignments. Preserve the later67-line SignalTap removal unstaged.

Do not include db, incremental_db, output_files, ModelSim work libraries/logs, local Lab1Demo.qws or Python bytecode/cache. The existing .gitignore is unchanged. No source file, MIF, testbench, prior report, reference image or user change is deleted.

Phase3A.2 stops here. Hardware validation, final decorative HUD/end screens, unresolved baseline I/O/debug issues and the later unverified local SignalTap edits require separately authorized work.
