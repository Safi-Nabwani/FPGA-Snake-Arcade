# Phase 3A.4 — Exact supplied V4 floor and obstacle integration

Date: 2026-10-11. Starting commit: `d6e230f` (Phase 3A.3).

Status: **exact asset integration, focused regressions and the single Quartus build PASS. All 40 reported constrained timing checks are positive.** No artwork generation, PNG-to-MIF conversion, physical FPGA verification/programming or push.

## Exact production changes

Modified:

- `RTL/mifs/ancient_stone_24x24_rgb332.mif`
- `RTL/mifs/mossy_stone_24x24_rgb332.mif`
- `RTL/mifs/cracked_stone_24x24_rgb332.mif`
- `RTL/mifs/engraved_stone_24x24_rgb332.mif`
- `RTL/VGA/back_ground_draw.sv`: only the three obstacle `LPM_FILE` paths change. No other rendering logic, latency, collision output or interface changes.
- `RTL/VGA/jungle_floor_map.svh`: replace the independent fixed floor-selection table with the new seeded distribution.
- `.gitattributes`: add `-text` for the three new obstacle MIF paths; four floor paths already have this protection.

New authoritative obstacle MIFs:

- `RTL/mifs/rock_tile_floor_match_v4_24.mif` — carved stone block, ROM kind 4.
- `RTL/mifs/ruin_wall_floor_match_v4_24.mif` — horizontal wall, ROM kind 5.
- `RTL/mifs/ruin_pillar_floor_match_v4_24.mif` — pillar, ROM kind 6.

All seven installed MIFs match the complete ZIP-entry bytes, not merely decoded pixels. Source archives:

- `C:/Users/USER/Downloads/FPGA_Jungle_Floor_v4_preview_and_MIFs.zip`
- `C:/Users/USER/Downloads/FPGA_Jungle_Obstacles_V4_Floor_Matched (1).zip`

No recoloring, redrawing, substituted pixels or altered alpha/collision masks. The three earlier obstacle MIFs remain untouched as historical assets, but are no longer selected by the active background ROMs. Supplied PNG previews are retained byte-for-byte under `assets/jungle/v4_implemented/`.

Other changed/created files:

- `simulation/jungle_implementation_tb.sv`: three expected-ROM fixture paths use the new obstacle names.
- `simulation/jungle_implementation.do`: fixture preparation instruction names the V4 script.
- `scripts/implement_v4_graphics.py`: reproduces/validates the map, validates fixed SHA256 and ZIP byte equality, copies real ROM/legacy Git data to ignored test fixtures, composes MIF-only previews, and reads existing Quartus reports. It never writes artwork MIFs or launches Quartus.
- This report.
- `assets/jungle/v4_implemented/ancient_stone_24x24_rgb332.png`
- `assets/jungle/v4_implemented/mossy_stone_24x24_rgb332.png`
- `assets/jungle/v4_implemented/cracked_stone_24x24_rgb332.png`
- `assets/jungle/v4_implemented/engraved_stone_24x24_rgb332.png`
- `assets/jungle/v4_implemented/rock_tile_floor_match_v4_24.png`
- `assets/jungle/v4_implemented/ruin_wall_floor_match_v4_24.png`
- `assets/jungle/v4_implemented/ruin_pillar_floor_match_v4_24.png`
- `assets/jungle/v4_implemented/full_scene_640x480.png`
- `assets/jungle/v4_implemented/arena_and_hud_640x480.png`
- `assets/jungle/v4_implemented/supplied_assets_4x.png`
- `assets/jungle/v4_implemented/floor_selection_map.png`
- `assets/jungle/v4_implemented/floor_selection_map.json`
- `assets/jungle/v4_implemented/asset_verification.json`

No QSF registration or BDF interface edits are needed: existing renderer references the seven MIFs directly; the floor table is an existing included header.

## Fixed floor distribution

Unchanged VGA 640×480, arena 20×18 cells, 24×24 pixels, origin (144,24), X [144,624), Y [24,456). The original HUD layout and all gameplay coordinates remain unchanged.

The 720-bit table contains two bits per cell, packed into 18 constant 40-bit rows. IDs 0/1/2/3 select Ancient/Mossy/Cracked/Engraved. There is no runtime random circuit and no floor-art rotation.

| Variant | All 360 cells | Percentage | 330 visible cells | Under 30 obstacles |
| --- | ---: | ---: | ---: | ---: |
| Ancient | 270 | 75.000% | 248 | 22 |
| Mossy | 43 | 11.944% | 39 | 4 |
| Cracked | 36 | 10.000% | 33 | 3 |
| Engraved | 11 | 3.056% | 10 | 1 |

Integer rounding yields the requested approximate 75/12/10/3 proportions. Seed **20261014**; Python's seeded shuffle followed by quota-preserving swaps. The script verifies no homogeneous 3×3 blocks, no seven-cell horizontal/vertical same-kind stripes, and no six-cell alternating AB pattern with distinct A/B. All rows/columns are distinct; horizontal, vertical and 180-degree symmetry are absent. Short base-stone runs and 2×2 patches remain intentionally natural at 75% base density.

The supplied ZIP's optional selection table was not installed: it contains long ancient-only row runs, including 16 consecutive cells. Only the selection map changed; all supplied artwork bytes remain exact.

## ROM, transparency, collision and pipeline compatibility

All seven supplied MIFs: WIDTH=8, DEPTH=576, ADDRESS_RADIX=UNS, DATA_RADIX=HEX; addresses cover 0–575 exactly once. Pixel ordering is row-major `y*24+x`. PNG pixels agree with nominal RGB332 decoding within one channel level (rounding), with fully opaque 24×24 alpha. No asset uses the reserved `FF` transparent code.

Existing LPM ROMs retain their ten-bit address interface, registered address and unregistered output. Existing selector/region metadata still travels with the ROM address, followed by the unchanged background RGB register and object-mux stage. No new registers, drawing-mask logic, ports or timing exceptions were added.

The V4 obstacle art contains its supplied floor-matched surround. It is safe in the existing opaque, full-cell background path; no transparency synthesis or pixel filling is needed. Wall upper-surface/floor blending is exactly the supplier's artwork, not an integration recolor.

`jungle_map.svh` is unchanged, including all 30 occupied cells, descriptor kinds, rotations and `jungleRockRow` spawn-exclusion bits: 16 wall cells, eight carved-block cells and six pillars. `obstacle_DR` remains the original raw-coordinate full-cell hit expression; `borderDR` is unchanged. Snake/relic visual masks and separate frozen collision masks are unchanged. New texture colors cannot affect collection, border/obstacle/self-hit events or spawn acceptance.

## Verification completed before Quartus

- Fixed SHA256, full archive-byte comparison, MIF header/address coverage, legal pixel values, opaque alpha and PNG/order agreement: **PASS for all seven assets**. Hashes are recorded in `asset_verification.json` and the V4 script.
- Full-scene 640×480 preview uses actual active MIF data, actual HUD glyph/numeric ROM data, and unchanged snake/relic assets. Every arena cell crop equals its chosen MIF data before sprite overlay; all seven asset kinds occur. The preview is an illustrative pose, not a captured simulation framebuffer or board test.
- `simulation/v4_jungle.log`: **3,345,662 focused checks PASS**, including 307,200 streaming pixels, actual ROM data, floor/obstacle edges, visual DR/RGB/mux alignment, 24×24 head rotations and unchanged legacy 22×24 head collision geometry.
- Paired legacy/current collision and controller checks pass cycle-for-cycle: Ruby8, Sapphire1, Cursed1 collection events, 121 death events and 1232 self-contacts; identical scoring, length, 193-entry trail, resets, visibility and collection priority.
- `simulation/v4_arena.log`: **ARENA_GEOMETRY_PASS**; visible bounds, all 360 cells, all 1024 input candidates per relic color, range/overlap/obstacle exclusion, generator reachability and four-direction 24-pixel movement.
- `simulation/v4_hud.log`: **HUD_COUNTERS_PASS / HUD_RENDER_PASS**; independent collection totals, new-game reset, high-score persistence, leading zeros/999 saturation, full-frame real numeric font and no HUD/arena overlap.
- Simulation HDL compile/run: zero errors, zero warnings except harmless reused-library `vlib-34` notices.
- `verify_jungle_integration.py --qsf-index`: PASS for collision BDF wiring, body state, HUD geometry, scoring/movement/input/audio, PLL/SDC/pins preservation.
- Starting tracked-file hashes change only for the nine explicitly modified files above. Every existing obstacle map/MIF, snake/relic/collision asset, gameplay/HUD/audio module, BDF, constraint and pin/PLL file is otherwise byte-identical.
- Working `Lab1Demo.qsf` remains byte-identical: SHA256 `AE56D79E54A6275E550AC525D603CEBB669EA7758AE25EE9D16E2953582DAB8B`. Existing QSF edits, QWS, floor-preview report/folder and Python cache are untouched and excluded from staging.

Reproduce asset verification and fixtures from the project root:

```text
python scripts/implement_v4_graphics.py --floor-archive "C:/Users/USER/Downloads/FPGA_Jungle_Floor_v4_preview_and_MIFs.zip" --obstacle-archive "C:/Users/USER/Downloads/FPGA_Jungle_Obstacles_V4_Floor_Matched (1).zip" --fixtures --preview
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/jungle_implementation.do
```

Without archives the script checks the seven embedded authoritative SHA256 hashes and stored manifest. `--header` prints the reproducible table without installing it. `--git-index` additionally checks staged MIF bytes. Historical artwork-generation `--write` commands must not be used; the older V3 floor verifier is historical and expects obsolete V3 hashes.

## Single Quartus build — successful

Quartus Prime Lite17.0 Build595, CycloneV `5CSXFC6D6F31C6`, revision `Lab1Demo`, top `TOP_VGA_DEMO`. Exactly one map→fit→STA→assembly sequence, no reruns or alternate fitter seeds.

Isolated snapshot `db/phase3a4_build/source/` contains HEAD plus the exact nine changed/new production files (renderer, floor header and seven supplied MIFs). All nine were compared byte-for-byte with working sources before compilation. The snapshot retains the committed QSF (SHA256 `D2537A35A81CBEE063B68B8C08A3EBFC13CA0E2BDAE2812ADF9FD6B32FB05E52`) to compare against Phase 3A.3 without including unrelated local SignalTap edits. Settings export is disabled. The preserved local QSF edits are **not covered by this build**.

Authoritative build reports: `db/phase3a4_build/source/output_files/`; stage logs: `db/phase3a4_build/`. Baseline reports: `db/phase3a3_build/source/output_files/`, not the older root reports.

Completed: execution-host timestamps **2026-10-11 17:11:33–17:17:40 +03:00**. Every stage exited zero; no repeat compilation.

| Stage | Errors | Phase 3A.3 warnings | V4 warnings | V4 elapsed |
| --- | ---: | ---: | ---: | --- |
| Analysis/synthesis | 0 | 226 | 226 | 58s |
| Fitter | 0 | 80 | 80 | 4m44s |
| TimeQuest | 0 | 41 | 41 | 14s |
| Assembler | 0 | 0 | 0 | 9s |

All warning-code counts match the preceding build in every stage. No new compilation error, missing ROM, latch, constraint or timing-violation diagnostic was introduced. The existing deliberate 40-bit-to-two-bit masked floor-selection narrowing warning remains (10230); exhaustive map/pixel checks cover its result.

### Post-fit resources

| Resource | Phase 3A.3 | V4 | Change |
| --- | ---: | ---: | ---: |
| ALMs /41,910 | 6,781 (16%) | 6,769 (16%) | −12 |
| Registers | 5,828 | 5,827 | −1 |
| Block-memory bits /5,662,720 | 958,144 (17%) | 958,144 (17%) | 0 |
| RAM blocks /553 | 123 (22%) | 123 (22%) | 0 |
| Pins /499 | 91 | 91 | 0 |
| DSP blocks | 1 | 1 | 0 |
| PLLs | 1 | 1 | 0 |

Seven existing 576×8 background ROMs are retained; no new memory-bank or hardware interface is added. Table constants/artwork data and resulting synthesis/placement can change resource optimization without any gameplay logic modification.

### Timing comparison, ns

Previous → V4; game clock remains31.5MHz and JTAG25MHz:

| Corner | Game setup | Game hold | JTAG setup | JTAG hold |
| --- | --- | --- | --- | --- |
| Slow85°C | 4.989 →6.354 | 0.290 →0.320 | 9.184 →10.807 | 0.515 →0.281 |
| Slow0°C | 4.667 →5.294 | 0.266 →0.273 | 9.594 →10.882 | 0.492 →0.278 |
| Fast85°C | 16.643 →17.615 | 0.177 →0.178 | 11.539 →12.888 | 0.215 →0.095 |
| Fast0°C | 17.684 →18.590 | 0.161 →0.161 | 11.923 →13.011 | 0.198 →0.081 |

**Worst setup +5.294ns**, improved0.627ns. **Worst game hold +0.161ns**, unchanged. **Worst overall hold +0.081ns** on JTAG at Fast0°C; lower than the previous overall0.161ns but still positive. JTAG's own minimum decreased0.198→0.081ns (−0.117ns); this modest remaining margin is disclosed, not hidden by exceptions.

All40 setup/hold/recovery/removal/minimum-pulse-width summary entries are strictly positive; every TNS is0. Minimum recovery37.093ns, removal0.309ns, minimum-pulse-width0.793ns. Game Fmax Slow85/0°C is39.38/37.80MHz versus37.37/36.93MHz previously, above the unchanged31.5MHz game clock.

No relaxed constraints, false paths, fitter seed tuning, timing repair, PLL or SignalTap changes were made. The single build does not isolate which individual data/table/placement change caused each slack difference.

Read-only report verification:

```text
python scripts/implement_v4_graphics.py --build-results db/phase3a4_build/source/output_files
```

### Standard programming-file location

After all checks passed, generated top-level build outputs/reports were copied to the standard `output_files/` folder. **Use `output_files/Lab1Demo.sof` for this V4 build**, not an older file retained elsewhere. It is byte-identical to `db/phase3a4_build/source/output_files/Lab1Demo.sof`:

- Size: **6,695,885 bytes**.
- Generated: **2026-10-11 17:17:39 +03:00**.
- SHA256: `0E8617158557D8DEA8B63E6FE95BE9548B2C9C2FDBA7EC530FC441AD2126F8CE`.

Root reports now describe the same new build. Earlier Phase 3A.3 outputs remain in their isolated directory. Compiler outputs, databases and simulator logs/libraries remain ignored and are not committed. No FPGA was programmed or tested during this phase.

## Remaining concerns and Git scope

Known warnings remain, unchanged: SignalTap39/40 with a stale obstacle probe, nine physical debug outputs without explicit pin locations, two stale generated-clock target collections, ignored template assignments and existing audio/reset/latch diagnostics. The committed debug configuration is the one tested; the user's preserved local QSF changes constitute a separate unverified configuration.

Constraint coverage is still incomplete: zero unconstrained clocks; five unconstrained input ports/120 paths;55 unconstrained output ports/**143 paths** (previously152). Path-count changes reflect implementation connectivity, not constraint changes. Positive constrained margins do not constitute external VGA/audio/PS2 board-level timing sign-off, or validation of automatically selected debug pins.

Previews use nominal RGB332 expansion; the existing unusual VGA DAC low-bit expansion and monitor color behavior remain unchanged. No physical display appearance or board gameplay was verified.

The successful integration qualifies for the requested local commit:

`Implement approved V4 Jungle Temple floor and obstacles`

Only the27 modified/created source, supplied-artwork, preview and report files listed above belong to this commit. The existing dirty `Lab1Demo.qsf`, `Lab1Demo.qws`, `FLOOR_PREVIEW.md`, `assets/jungle/floor_preview_3a3/` and Python cache must remain unmodified/unstaged. Staged MIF blobs are additionally compared against both original ZIPs before committing. No push or hardware programming. Stop after Phase 3A.4.
