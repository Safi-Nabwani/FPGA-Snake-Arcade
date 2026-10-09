# FPGA Snake — Phase 2B.1 Arena Enlargement

Date: 2026-10-09. Workspace: `C:/Users/USER/Documents/Work/FPGA-Snake-Arcade`.
Scope: geometry only. Phase 1 and Phase 2A reports were read before implementation. This report supplements those historical reports; their original-geometry descriptions are not the current geometry.

## 1. Geometry and snake start

- Active display remains 640×480; VGA raster/PLL were not changed.
- Grid is 20 columns × 18 rows: 360 cells, each 24×24 pixels.
- Origin (144,24); extent 480×432 pixels; half-open bounds X [144,624), Y [24,456).
- Five-bit grid coordinates: X 0–19, Y 0–17.
- Cell top-left: X = 144 + 24×column; Y = 24 + 24×row.
- Valid top-left ranges: X 144–600, Y 24–432 in 24-pixel steps; final cell (19,17) covers X [600,624), Y [432,456).
- Left 144 pixels remain outside the arena for the future vertical HUD; this phase does not construct that HUD.
- Head/body default parameters and both Snake_Block BDF overrides now start at **(384,240)**, cell **(10,9)**. This is clear of all rocks.
- Motion still uses 64× fixed-point coordinates, speed 130 initially, and 24-pixel movement targets. Per-frame positions interpolate smoothly; body trail segments therefore need not remain cell-aligned between target arrivals. No movement FSM, turn/reversal handling, trail spacing, length rule, score rule, audio or input logic was changed.

## 2. Obstacles, rendering and spawning

The original obstacle pattern is preserved in zero-based grid coordinates, translated by the new origin. Both the displayed tile map and spawn-exclusion mask now cover all 20×18 cells; the extra columns and rows contain grass/stone, not new obstacles.

| Grid columns | Grid rows | Pixel coverage, half-open |
| --- | --- | --- |
| 11–12 | 3–4 | X [408,456), Y [96,144) |
| 3–4 | 9–10 | X [216,264), Y [240,288) |
| 3–6 | 11–12 | X [216,312), Y [288,336) |

There remain 16 rock cells. Background tile rows are now 40 bits (20 two-bit tiles); the row lookup handles 18 rows and uses a six-bit selector starting at bit 39. Both grid-index axes are five bits; local offsets remain five bits and tile ROM addresses remain ten bits (0–575). The arena has priority over the legacy 88-pixel-high top background, so its upper rows are rendered and collided consistently.

Collectible generation uses the existing independent +5/+7/+13 free-running counters, widened from eight to ten bits. Each sampled axis is five bits. Raw X candidates 20–31 subtract 20; raw Y candidates 18–31 subtract 18. Consequently generated coordinates are always X 0–19 / Y 0–17, including reset. All 360 cells are reachable for each color over a complete 1024-state counter cycle. This bounded fold is not a uniform random distribution; counter-based pseudo-random sampling remains timing-dependent.

The existing eight-bit seed parameters and their initial grid positions are preserved by zero-extending each nibble into the new five-bit axes: red (7,3), blue (5,10), black (12,6). Their new pixel top-lefts are (312,96), (264,264), and (432,168).

The validator rejects out-of-range inputs before indexing the obstacle array, flags rocks and pairwise overlaps, and preserves existing feedback rerolls. A red event still samples red and black; blue and black events retain their original triggers. Hidden blue positions still participate in overlap checking. Spawning still does not exclude the snake head/body, as in the original gameplay. All three square-object interfaces remain 24×24 with 11-bit pixel coordinates.

## 3. Exact implementation and verification files

Changed production files (all under `RTL/VGA`):

| File | Change |
| --- | --- |
| `back_ground_draw.sv` | Bounds, five-bit tile axes, 20×18/40-bit tile map, arena-over-legacy-HUD priority. |
| `snake_head.sv` | Initial XY only: (384,240). |
| `snake_body.sv` | Initial XY only: (384,240). |
| `randomCounter.sv` | Five-bit coordinate outputs, ten-bit counters, bounded candidate folding and seed extension. |
| `apple_position_controller.sv` | Five-bit grid ports, 20×18 mask, guarded range checks. |
| `apple_TopLeft_Calc.sv` | Five-bit grid inputs and new origin; 24-pixel scale retained. |
| `Apple_Block.bdf` | 54 grid-coordinate port/wire label occurrences widened from [3..0] to [4..0]; no topology, seed, square-size or top-level interface changes. |
| `Snake_Block.bdf` | Four start-parameter values updated for head and body; no topology/size/interface changes. |

New authored verification/report files:

- `simulation/arena_geometry_tb.sv` — focused self-checking unit test.
- `simulation/arena_geometry.do` — reproducible ModelSim test runner, executed from project root.
- `simulation/arena_rom_stub.sv` — coordinate-only ROM fixture, not added to Quartus sources.
- `ARENA_ENLARGEMENT.md` — this report.

Tool-generated outputs are separate from authored changes: `simulation/arena_geometry.log`, `simulation/arena_geometry_work/`, and refreshed Quartus reports, databases and programming output under `output_files/`, `db/`, and `incremental_db/`, plus existing generated root diagnostics. Pre-existing untracked reports/reference artwork were preserved.

No QSF, QPF, SDC, PLL files, MIF, SignalTap file/assignments, pin assignments, keyboard/audio/score modules, or top-level schematic were edited. No module was renamed. No FPGA programming, commit or push was performed.

## 4. Focused verification

ModelSim-Altera 10.5b: test finishes with `ARENA_GEOMETRY_PASS`, zero HDL compile/simulation errors or warnings in the final run. Reusing its existing work library produces only a harmless `vlib-34` library-already-exists notice.

The test checks:

1. Every one of the 307,200 visible pixels: arena/border half-open bounds, five-bit grid index, 24-pixel local offset, 0–575 tile address, rock collision rectangles, arena priority over the old HUD, and equality of the displayed/exclusion maps across all 360 cells.
2. All 1024 five-bit X/Y combinations separately for each color: range, obstacle and overlap rejection; valid grid-to-pixel coordinates and full-cell extents.
3. Complete 1024-state counter cycles for all three colors: every grid cell reachable, no generated out-of-range coordinate, sample-and-hold behavior, an actual rejected candidate followed by feedback settling to safe distinct cells, and red-triggered black reroll.
4. Head/body reset and local restart at (384,240); body top-left/final-pixel/exclusive-right bounds; all 576 head ROM addresses in each of four orientations; exact 24-pixel first motion targets in all four directions at original initial speed and unchanged initial length.
5. Static preservation checks: head/body behavior is unchanged except XY defaults; Apple BDF changes only grid-width labels; Snake BDF changes only four parameter values. Quartus elaboration checks the actual BDF-to-HDL interfaces, not just this unit harness.

The installed legacy `220model_ver.lpm_rom` has lowercase parameters and rejects the production RTL's existing uppercase overrides (70 elaboration messages on the initial direct-library attempt). Production RTL was not changed to work around this. The standalone unit runner deliberately substitutes a constant-output ROM fixture and tests geometry/addresses, **not MIF loading, image colors, transparency, visual timing, complete game rules or full-system hardware behavior**. Quartus uses the real ROMs/MIFs; the fixture is not in the QSF.

Reproduce the focused test from the project root:

```powershell
& 'C:/intelFPGA_lite/17.0/modelsim_ase/win32aloem/vsim.exe' -c -modelsimini 'C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini' -l simulation/arena_geometry.log -do simulation/arena_geometry.do
```

On this host, ModelSim needs to execute outside the restricted sandbox because of the Windows DLL-relocation problem documented in Phase 2A. No installed simulator settings were edited.

## 5. One Quartus compilation

Quartus Prime Lite 17.0.0 Build 595, revision `Lab1Demo`, top `TOP_VGA_DEMO`, Cyclone V `5CSXFC6D6F31C6`. One analysis/synthesis, fitter, timing and assembly sequence was run, approximately 18:32:53–18:40:14 local time. No alternate-source or repeated Quartus compilation was performed.

| Stage | Result | Errors | Warnings including critical | Elapsed |
| --- | --- | ---: | ---: | --- |
| Analysis & synthesis | Successful | 0 | 218 (217 ordinary + 1 critical) | 48 sec |
| Fitting | Successful | 0 | 80 (77 ordinary + 3 critical) | 5 min 14 sec |
| TimeQuest | Executed successfully; timing NOT met | 0 | 44 (39 ordinary + 5 critical) | 14 sec |
| Assembly | Successful; SOF generated, NOT programmed | 0 | 0 | 9 sec |

Settings-writing was disabled for map/fit/assembly; the timing stage used its supported `--do_report_timing` argument. A final SHA-256 comparison of all 70 tracked starting files confirms exactly the eight production files listed above changed. All other tracked sources/configuration/assets are byte-identical, including QSF, both SDC copies, PLL/IP manifests and implementation, SignalTap sources/assignments, and pin constraints. Whitespace validation passes when Git recognizes the retained CRLF line endings.

### Resources compared with Phase 2A

| Resource | Original baseline | Enlarged arena | Change |
| --- | ---: | ---: | ---: |
| ALMs | 6,407 / 41,910 (15%) | 6,563 / 41,910 (16%) | +156 |
| Registers | 5,625 | 5,665 | +40 |
| I/O pins | 91 / 499 | 91 / 499 | 0 |
| Block memory bits | 1,392,128 / 5,662,720 (25%) | 1,392,128 / 5,662,720 (25%) | 0 |
| RAM blocks | 176 / 553 (32%) | 176 / 553 (32%) | 0 |
| DSP blocks | 1 / 112 | 1 / 112 | 0 |
| PLLs | 1 / 15 | 1 / 15 | 0 |

### Timing, nanoseconds

| Corner | Current game setup | Current game hold | Baseline JTAG hold | Current JTAG hold |
| --- | ---: | ---: | ---: | ---: |
| Slow 85°C | +11.204 | +0.120 | −0.066 | +0.016 |
| Slow 0°C | +11.497 | +0.108 | −0.077 | −0.017 |
| Fast 85°C | +18.838 | +0.109 | −0.090 | −0.060 |
| Fast 0°C | +20.196 | +0.084 | −0.105 | −0.074 |

Design-wide worst setup is +10.807 ns in JTAG; game-domain worst setup is +11.204 ns (baseline +9.913 ns). Game-domain slow-85°C Fmax is 48.68 MHz (baseline 45.80 MHz), with actual game clock still 31.5 MHz. Overall worst hold is **−0.074 ns**, hold TNS −0.121 ns at fast 0°C. Current worst hold path is in the embedded JTAG hub: `identity_contrib_shift_reg[0]` to `sldfabric_ident_writedata[0]`, both clocked by `altera_reserved_tck`. This is a different fitted debug path than the baseline's SignalTap buffer pointer. It remains a debug-domain hold violation, not a new game-domain setup failure. Better numerical results in this fit are not a timing repair or sign-off.

Constraint coverage remains incomplete: 0 unconstrained clocks, 5 input ports / 120 input paths, 55 output ports / 431 output paths. The baseline had 430 output paths: one additional unconstrained path, not an additional unconstrained port. External interface timing therefore remains unproven.

### New findings versus known baseline warnings

- **New hard compilation errors: none. New warning categories: none.** Synthesis/fitter warning IDs and counts match the baseline exactly. Timing warning 332148 drops from four failing corners to three; total timing warnings drop from 45 to 44.
- Width truncation warning 10230 remains at 46 occurrences. Affected background tile axes now truncate arithmetic into five bits, row-bit selector into six, and collectible pixel coordinates into eleven. Focused checks prove these fit the intended valid coordinate domains; no grid-bit loss or new geometry BDF-port warning was observed.
- The original 20 NumbersBitMap upper-offset-port warnings (12001), background case warning (10270), audio latch/reset warnings (13004/13310), vendor ROM conversion warnings (13046/13049), and constant-pin warnings remain. They were not repaired in this phase.
- Debug warning 35025 remains, but this synthesis connects **39/40** inputs rather than baseline 37/40. The two optimized collision probe references now resolve; `obstacles:inst1|obstacle_DR` remains missing. No SignalTap configuration was edited, so do not treat changed optimization/connectivity as a deliberate debug repair.
- Existing incomplete I/O / stale pin assignments (15714, 169085, 15705/15706, 171167), five audio-related combinational loops (335093), ignored/missing SDC targets (332174/332049), and JTAG clock overwrite (332043) remain.
- Nine top-level debug-output locations are still automatically assigned. Their fitted locations changed even though the pin constraints did not: BG_RGB[0] AC18, [1] AK14, [2] AG30, [3] AF24, [4] Y16, [5] AA16, [6] AF28, [7] AJ14, borderDR G15. These are **not verified safe board assignments**; borderDR remains 2.5 V. No FPGA was programmed.
- The legacy ModelSim ROM parameter incompatibility was discovered during focused-test setup and isolated with the test-only fixture. It is not a new geometry synthesis error, and full visual/MIF simulation remains deferred.

Evidence: [synthesis report](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.map.rpt), [fitter summary](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.fit.summary), [fitter report](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.fit.rpt), [timing summary](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.sta.summary), [timing report](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.sta.rpt), [assembly report](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.asm.rpt), [focused test log](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/simulation/arena_geometry.log).

## 6. Remaining work and limits

### Deferred to Phase 2B.2

- Build the final vertical HUD in the left 144-pixel area, relocate score/high score and add the three independent new-game-reset relic counters.
- Replace the old top-HUD artwork. For now, the background arena takes precedence within its bounds, while the old header image remains elsewhere.
- **Temporary overlap:** score rectangle at (164,12) and high-score rectangle at (548,12), each 64×64, overlap the arena in Y [24,76). Their graphics can cover collectibles below them; head/body retain their higher layer priority. This phase intentionally does not relocate them or produce replacement graphics.
- Jungle Temple / Temple of the Serpent artwork, Ruby/Sapphire/Cursed sprite replacements and final sidebar styling were not implemented. Current apples, tiles, font, win/loss panels and palettes remain unchanged.
- End-message panel and other legacy graphics remain in their original locations; final visual integration and complete display/latency validation still need a later phase.

### Existing baseline issues, separately scoped

- Safe pin ownership, valid timing constraints, debug-domain hold closure and stale SignalTap probes still require approved repairs before programming a rebuilt image.
- The head ROM remains 24×24, while the BDF head square clips to the original 22×24 rectangle. This was deliberately preserved so geometry enlargement does not silently change the collision silhouette/gameplay. Coordinate/address alignment is verified; full-width head rendering is not claimed.
- Mixed rendering/collision pipeline latencies, VGA counter off-by-one/refresh assumptions, score BDF width mismatches, audio reset/latch behavior, missing PLL simulation netlist and stale absolute-path VWF workflows remain untouched.
- No snake-aware collectible exclusion, replacement RNG architecture, gameplay-rule change or full-system test was added. Test success and compilation do not establish physical hardware functionality.

**Phase 2B.1 complete. Stop and wait for approval; do not begin Phase 2B.2 or program this SOF.**
