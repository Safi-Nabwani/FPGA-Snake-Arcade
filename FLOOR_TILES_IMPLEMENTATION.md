# Phase 3A.3 — Supplied Jungle Temple Floor Tiles

Date: 2026-10-11. Starting commit: `7fff9be`.

Status: **implementation, focused regressions and the single Quartus build pass. All reported constrained timing margins are positive.** No physical FPGA verification, programming or push was performed.

## Exact changes and installed assets

Modified existing files:

- `RTL/VGA/back_ground_draw.sv`: four floor ROM file references and independent floor-selection override only. Existing obstacle ROMs, descriptors, rotations, raw-coordinate collision outputs and two-stage background pipeline are retained.
- `simulation/jungle_rom_model.sv`: read the supplied UNS address-radix header as decimal instead of assuming hexadecimal. Production synthesis continues to use vendor LPM ROMs.
- `simulation/jungle_implementation_tb.sv`: expected floor data loads use the four supplied asset names.
- `simulation/jungle_implementation.do`: update its fixture preparation instruction.

New production files:

- `RTL/VGA/jungle_floor_map.svh`: 720-bit fixed floor-selection table (18 rows × 40 bits; two bits per cell).
- `RTL/mifs/ancient_stone_24x24_rgb332.mif`
- `RTL/mifs/mossy_stone_24x24_rgb332.mif`
- `RTL/mifs/cracked_stone_24x24_rgb332.mif`
- `RTL/mifs/engraved_stone_24x24_rgb332.mif`

The four MIFs were copied directly from `C:/Users/USER/Downloads/fpga_jungle_floor_tiles_bundle_v3.zip`. **Their complete bytes, including pixel data and line endings, match the ZIP entries.** No artwork was generated, redrawn, modified, quantized, replaced or converted from PNG. Old floor MIFs remain unchanged as historical assets; only the four active floor ROM references change.

Other new files:

- `.gitattributes`: `-text` for these four MIF paths only, preventing Git's automatic line-ending conversion from changing the exact supplied files.
- `scripts/supplied_floor_tiles.py`: verifies fixed SHA256 hashes, optionally checks ZIP byte equality, deterministically reconstructs the floor table, prepares ignored test fixtures, and decodes existing MIF data into the full-scene preview. It has no active artwork/MIF writing or image-generation path.
- `assets/jungle/supplied_floor_tiles/`: the four original supplied PNGs named `<variant>_24x24_rgb332.png`, plus `full_scene_640x480.png`, `floor_selection_map.json`, and `asset_verification.json`.
- This report.

No QSF registration is necessary for MIF files referenced by `LPM_FILE`, or an SV header included by the already-registered renderer. No BDF interface changes are needed.

## Floor map, ROM addressing and pipeline

Unchanged resolution 640×480; arena 20×18 ×24-pixel cells at (144,24), X [144,624), Y [24,456). HUD geometry and snake start (384,240) are unchanged.

Seed **20261011**, independent two-bit floor table. Selection IDs 0/1/2/3 map to Ancient/Mossy/Cracked/Engraved. Whole-map counts are **162/90/72/36**, exactly 45%/25%/20%/10% over all 360 cells. The 330 visible walkable cells contain **149/82/66/33** tiles; 13/8/6/3 choices are covered by the unchanged obstacles.

Seeded shuffle plus quota-preserving swaps removes homogeneous 2×2 blocks, four-cell horizontal/vertical runs and six-cell AB alternation. All rows and columns are distinct; the map is not centrosymmetric. Short adjacent weathered groups remain. This is a fixed compile-time table, not runtime randomness.

All supplied floor tiles display **unrotated**, at exactly address `y*24+x`; only tile selection varies. MIF WIDTH=8, DEPTH=576, ADDRESS_RADIX=UNS, DATA_RADIX=HEX. The ten-bit ROM interface and registered address/unregistered output remain unchanged. Floor data contains no `FF` transparency pixels. RGB332 channel interpretation is unchanged. Supplied PNGs match nominal MIF decoding within one channel level due to rounding; MIF bytes are authoritative.

The original `jungle_map.svh` remains byte-identical. Only when its descriptor kind is below four does rendering select the independent floor kind and zero floor rotation. Obstacle kinds 4–6 and their original rotations bypass this override. Spawn-exclusion continues using the original shared obstacle rows. Border and obstacle outputs retain their existing raw-pixel timing; floor selector/region metadata still accompanies the registered ROM address, followed by the original background RGB output register and unchanged object mux stage.

## Functional and preservation verification

- Exact ZIP byte equality, fixed SHA256, MIF dimensions, complete address coverage and legal RGB332 values pass for all four assets. Palette counts: Ancient12, Mossy17, Cracked12, Engraved18.
- Full-scene preview is 640×480, composed from actual supplied MIF data and the installed table. All arena tile crops match their selected MIF pixels before sprite overlay, including **all 30 original obstacle crops and rotations**. HUD uses current label glyphs, actual numeric font, existing positions and colors. Snake/relic sprites use their unchanged MIFs. The illustrative pose is not a board capture or a physical gameplay test.
- ModelSim `simulation/supplied_floor_jungle.log`: **3,345,662 checks pass**, including all 307,200 visible pixels with consecutive-clock tile boundaries and aligned background/head/body/relic/mux output. Four floor ROMs are exercised using actual UNS-addressed MIFs and independently generated expected data.
- Legacy collision masks match cycle-for-cycle. Paired controllers/score accumulators receive matching real hit streams; test coverage includes Ruby8, Sapphire1, Cursed1, death121 and self-contact1232 events. Full24 head rotations, legacy22 collision width, all193 body history entries, length, resets, visibility and collection priority remain unchanged.
- `simulation/supplied_floor_arena.log`: ARENA_GEOMETRY_PASS; all visible bounds/map cells, 1024 candidates per relic color, overlap/range/obstacle rejection, generator reachability and four-direction 24-pixel movement.
- `simulation/supplied_floor_hud.log`: HUD_COUNTERS_PASS / HUD_RENDER_PASS; original score/high-score semantics, independent totals, reset/leading-zero/999 saturation, full-frame real-font positioning and no HUD/arena overlap.
- HDL compilation/simulation: zero errors/zero warnings, apart from harmless reused-library `vlib-34` notices. `verify_jungle_integration.py --qsf-index` passes original collision routing, body-state, HUD geometry, score/movement/input/audio/PLL/constraint/pin preservation checks.
- Before/after hashes of starting tracked files differ only for the four intentionally modified renderer/test files listed above. Every obstacle MIF, shared map, spawn controller, sprite/collision ROM, HUD/gameplay module, BDF, PLL and pin/SDC file is byte-identical.
- Existing dirty `Lab1Demo.qsf` is preserved byte-for-byte: SHA256 `AE56D79E54A6275E550AC525D603CEBB669EA7758AE25EE9D16E2953582DAB8B`. Its prior67 SignalTap deletions and uppercase hold-setting spelling are neither reverted nor staged. Existing QWS, Python cache and prior uncommitted floor-preview/report files remain outside this change.

Reproduction from project root:

```text
python scripts/supplied_floor_tiles.py --fixtures --preview
python scripts/supplied_floor_tiles.py --archive C:/Users/USER/Downloads/fpga_jungle_floor_tiles_bundle_v3.zip
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/jungle_implementation.do
```

The old `implement_jungle_preview.py --write` regenerates historical artwork and must not be used for these supplied assets. Its fixture helper is used only under ignored db; the new fixture preparation then replaces floor expectations/map with actual supplied data.

## Single Quartus build and comparison

One map→fit→STA→assembly sequence uses Quartus Prime Lite17.0 Build595, CycloneV `5CSXFC6D6F31C6`, top `TOP_VGA_DEMO`, revision `Lab1Demo`.

To preserve unrelated working-QSF edits and verify the configuration destined for Git, the build runs in **`db/phase3a3_build/source/`**: an archive of starting HEAD plus exactly the changed production renderer/header and four supplied MIFs. It retains the original committed SignalTap configuration. No active QSF was swapped or rewritten. Map/fit/assembly settings export is disabled; STA uses `--do_report_timing`. Local edits to the working QSF are deliberately **not covered by this build**.

Reports are under `db/phase3a3_build/source/output_files/`; stage logs under `db/phase3a3_build/`. Previous-build snapshots are under `db/phase3a3_baseline/`. Root `output_files/` continues to hold the previous build and is not evidence for this new floor build. New generated SOF, if assembly succeeds, is in the isolated build output directory and is not programmed or committed.

Completed build: execution-host timestamps 2026-10-11 14:54:28–15:00:53. Exactly one sequence; no retries, alternate fitter seeds or constraint changes.

| Stage | Errors | Previous warnings | New warnings | Elapsed |
| --- | ---: | ---: | ---: | --- |
| Analysis/synthesis | 0 | 225 | 226 | 1m16s |
| Fitter | 0 | 80 | 80 | 4m40s |
| TimeQuest | 0 | 41 | 41 | 13s |
| Assembler | 0 | 0 | 0 | 15s |

Warning totals include existing critical warnings. Synthesis adds only one 10230 diagnostic: `jungle_floor_map.svh` deliberately narrows a masked40-bit row lookup to two bits. The mask bounds the result to0–3, verified by the table and full-frame tests. Its count changes41→42; all other warning-code counts in each stage are unchanged. No new latch, missing asset, pin, or timing-violation warning appears.

### Post-fit resources versus Phase 3A.2

| Resource | Before | After | Change |
| --- | ---: | ---: | ---: |
| ALMs /41,910 | 6,732 (16%) | 6,781 (16%) | +49 |
| Registers | 5,809 | 5,828 | +19 |
| Block-memory bits /5,662,720 | 958,144 (17%) | 958,144 (17%) | 0 |
| RAM blocks /553 | 123 (22%) | 123 (22%) | 0 |
| Pins /499 | 91 | 91 | 0 |
| DSP blocks | 1 | 1 | 0 |
| PLLs | 1 | 1 | 0 |

The four floor ROM dimensions are unchanged. The separate selection logic and resulting implementation account for modest added logic/register utilization; no extra floor ROM or board interface was introduced.

### Constrained timing, ns

Values are previous → new. Both game and JTAG clocks are analyzed at all four corners:

| Corner | Game setup | Game hold | JTAG setup | JTAG hold |
| --- | --- | --- | --- | --- |
| Slow85°C | 6.796 →4.989 | 0.301 →0.290 | 10.807 →9.184 | 0.152 →0.515 |
| Slow0°C | 5.701 →4.667 | 0.285 →0.266 | 10.882 →9.594 | 0.139 →0.492 |
| Fast85°C | 18.185 →16.643 | 0.178 →0.177 | 12.888 →11.539 | 0.039 →0.215 |
| Fast0°C | 19.029 →17.684 | 0.162 →0.161 | 13.011 →11.923 | 0.026 →0.198 |

**Worst setup +4.667ns; worst overall/game hold +0.161ns; worst JTAG hold +0.198ns.** All40 summary checks are strictly positive; every reported TNS is0. Recovery minimum36.472ns, removal0.337ns, minimum-pulse-width0.793ns.

Regression disclosure: worst game setup margin is **1.034ns lower** and game hold margin0.001ns lower, but neither fails. The new slow-corner critical setup path is `VGA_Controller:inst|V_Cont[3]` → floor ROM0 `ram_block1a0~porta_address_reg7`; it is a raster-to-tile-address path, not a change to movement or score logic. Slow85/0°C game Fmax is37.37/36.93MHz, previously40.08/38.40MHz, still above the unchanged31.5MHz clock. Selection logic and whole-design placement/routing changed; the single build does not isolate their individual contributions. No timing exceptions, relaxed constraints, PLL changes or unrelated timing cleanup were applied.

### Remaining limitations

The known critical warnings remain: SignalTap39/40 with its stale obstacle probe, nine physical debug outputs without explicit pin locations, and two stale generated-clock target collections. Existing audio combinational-loop/reset/latch diagnostics and ignored template assignments remain unchanged.

Constraint coverage remains incomplete: zero unconstrained clocks, five unconstrained inputs/120 paths,55 unconstrained outputs/**152 paths** (previously142). The output path-count change reflects altered synthesized/fitted connectivity, not added constraints. Positive internal margins do **not** constitute external VGA/audio/PS2 board-level timing sign-off or authorization to use automatic debug pin locations. The original unusual DAC bit expansion and VGA timing remain unchanged.

## Git scope and final stop point

The verified floor implementation is eligible for the requested local commit:

`Implement supplied Jungle Temple floor tiles`

Only the exact files listed in this report belong to that commit. No QSF, obstacle/spawn/gameplay/HUD/sprite/collision asset, previous preview/report, generated database, compiler output, simulator log/work library, local QWS or Python cache is included. `.gitattributes` permits a staged-blob byte comparison against the original ZIP MIFs; generated artifacts remain ignored.

The working tree intentionally remains dirty with the user's existing QSF edits and pre-existing untracked preview/report/QWS/cache files. The committed SignalTap configuration is the isolated-build configuration; the preserved local QSF edits are a separate, unverified configuration. No push or FPGA programming. Stop after this phase.
