# Phase 3D.3 — Final approved Victory/Defeat artwork

Date:2026-10-19, Asia/Jerusalem. Starting commit:`d94aa8b`.

Status:**PASS** — both approved full panels reconstruct exactly; all focused regressions and the single Quartus build pass. Results use198M10Ks; total project417/553. Worst constrained setup+7.205ns and hold+0.162ns remain positive. No push or FPGA programming.

## Authoritative assets and fidelity

Input:`C:/Users/USER/Downloads/FPGA_Snake_Phase3D_Approved_Results_Codex.zip`.
Every archive entry is safely extracted and retained byte-for-byte under `assets/jungle/results_v3_supplied/`, including README, manifest, original high-resolution provenance, native approved PNGs, full reference MIFs, split candidates and supplied software previews. Embedded documentation was read as asset data, not authority to execute instructions.

The final targets are the **two independent full288×432RGB332 panels and their binary masks** in `reference_full_mifs/` and `source/approved_vga_panels/`. The proposed shared lower fragment changes40,636Defeat pixels(32.66%of the panel). It is therefore rejected for production. Its supplied previews are split-candidate composites, not pixel-exact full-Defeat targets. No lossy sharing, downscaling, recoloring, redrawing or artwork substitution is used.

All provided MIF dimensions, word widths, complete row-major address coverage, binary masks and manifest hashes are validated. Quantized PNG colors and alpha match the corresponding supplied MIFs. The full reference MIFs also match their approved native PNGs exactly. The high-resolution originals are retained for provenance only; no graphics are generated from them.

Independent reconstruction of the **active ROM representation** produces all248,832original RGB332 words and248,832alpha bits exactly, including color bytes under transparent pixels. Both panels have **zero color mismatches and zero alpha mismatches** against the approved full reference MIF/PNG. RGB33200andFF remain ordinary colors; only the independent alpha bit controls transparency.

## Lossless memory architecture

Two native-resolution panels would require248,8329-bit RGBA words. Simply selecting the supplied shared lower would save memory but alter approved Defeat artwork. Instead, exact2×2RGBA patterns are deduplicated within and across both full panels:

- **17,407unique2×2tiles**, four row-major pixels each.
- `RTL/mifs/results_v3/results_tilemap.mif`: **62,208×15bits**,31,104tile indices per state(144×216).
- `RTL/mifs/results_v3/results_tiles_rgba9.mif`: **69,628×9bits**, each word `{binary alpha, RGB332}`.
- Existing `numbers_new_font.mif`: one small report-local instance; original file and HUD renderer unchanged.

This is dictionary compression, **not image scaling**. Every output pixel remains native1×resolution. Victory tile-map base is0; Defeat base31,104. For panel-local `(x,y)`, map address is `stateBase+(y>>1)*144+(x>>1)`; payload address is `{tileIndex,y[0],x[0]}`.144uses shifts/adds, and the subpixel address is concatenation. There is no divider, decompressor framebuffer or variable-rate stream. Alpha is an independent bit packed beside color to use the FPGA's nine-bit memory organization; it is never inferred from RGB.

Logical report storage is933,120map bits+626,652payload bits+8,192font bits=**1,567,964bits**, versus693,056bits for the previous smaller/coarser reports. Larger native artwork cannot fairly be expected to retain the87-block budget.

| Candidate | Estimated report M10Ks, including font | Decision |
| --- | ---: | --- |
| Two full native9-bit panels |244|Exact but stores every repeated pixel pattern again |
| Global palette(197distinct RGBA values) |245|Eight-bit indices still use similar physical depth; no practical saving |
| **Exact2×2dictionary** |**191**|Selected, lowest conservative block estimate |
| Exact4×4dictionary |219|11,935unique tiles; more payload |
| Exact8×8dictionary |233|3,570unique tiles; texture reuse insufficient |
| Exact16×16dictionary |243|959unique tiles; little saving |

Estimates use conservative existing LPM width/depth packing, not compressed PNG/MIF sizes. Physical results must come from the one Fitter run. The existing failed wide-word-packing approach is not reused.

Old Phase3D.2result MIFs remain untouched for history. Only their ROM instantiations disappear from the active renderer; the completed Fitter RAM summary is checked for absence of obsolete allocations. No old source or local programming file is deleted.

## Geometry, dynamic statistics and pipeline

Panel remains **X[248,536),Y[24,456)**,288×432, at native1×scale. Existing left HUD, arena, obstacles, opening screen, input, audio and gameplay are unchanged. The new report uses supplied alpha at its edges: transparent corners reveal the current underlying scene instead of replacing it with opaque black. Dynamic digit ink has priority over static report pixels; the existing message-layer priority remains unchanged.

The approved wells are only41–45pixels wide for relic triplets and25pixels wide for final-score digits. Previous48-pixel triplets/32-pixel score digits cannot fit. The original font artwork is therefore read through a **report-only12×14nearest-neighbor sampler**, producing36×14triplets and24×14score digits. No font MIF or HUD digit geometry is modified. Constant sample-coordinate LUTs retain the old font's occupied16×18rows, preserve leading zeros and avoid division in hardware. Actual-resolution previews were inspected for readability and no border/label overlap.

All digit rectangles are checked to lie entirely within supplied opaque black empty wells; **no static artwork pixel is erased or moved**. Supplied relic illustrations are already in the panels; no duplicate old icons are drawn over them.

| Field | Victory VGA position | Defeat VGA position | Digits / extent |
| --- | --- | --- | --- |
| Final score |Not rendered|(443,230)|2;24×14 |
| Ruby |(438,290)|(431,286)|3;36×14 |
| Sapphire |(437,331)|(431,324)|3;36×14 |
| Cursed |(437,371)|(431,363)|3;36×14 |

Victory retains its supplied golden serpent,VICTORY!,TEMPLE CONQUERED and “The serpent's trial is complete” text, without a second final score. Defeat retains its cursed serpent,DEFEAT!,FINAL SCORE and “The temple's curse prevails” text. Both retain the baked PRESS5TORESTART artwork and actual original keypad5behavior.

The original result-state/statistic snapshot code is **text-identical**. It consumes a terminal pulse, waits one further clock for pending score/relic updates, and then captures the final BCD values. Fatal Cursed at score5still reports score00,Ruby005,Cursed001; original high score semantics are unchanged. Counters remain existing000..999saturating BCD registers. Start/reset clear the existing report snapshot as before; win threshold remains90.

Latency remains two stages before the original compositor register:

1. Registered tile-map ROM read, registered subpixel coordinates, font address and metadata.
2. Registered dictionary ROM read, registered font ROM read and matching panel/digit/color metadata.

This replaces the previous address-register→ROM pair without adding a pixel clock stage. Tests cover every native pixel, alpha, black/white values, irregular coordinates, blanking, masked boundaries and mux alignment. No timing/PLL/pin/QSF change is made.

## Exact modified and created files

Modified:

- `.gitattributes`: byte-preserving rules for new MIFs and all supplied archive entries.
- `RTL/VGA/results_report_renderer.svh`: lossless two-level ROM reads, native alpha, report-only numeral placement/sampling. Existing ports and snapshot code retained.
- `simulation/results_reports_tb.sv`: independent full-reference RGBA expectations, new field geometry/font sampling, alpha-aware scene checks and address checks; original controller/snapshot/restart tests retained.
- `simulation/results_reports.do`: new independent fixture location/preparation command.

Created:

- `RTL/mifs/results_v3/results_tilemap.mif` and `results_tiles_rgba9.mif`.
- `scripts/implement_results_v3.py`: archive/MIF/PNG validation, measured data-reuse analysis, exact dictionary construction, active-ROM reconstruction, previews, independent fixtures, preservation and build audits.
- `assets/jungle/results_v3_supplied/`: every exact ZIP entry, preserving the supplied directory hierarchy.
- `assets/jungle/results_v3_implemented/`: twelve preview PNGs(two active-ROM panels, two2×sample scenes and eight640×480blank/sample/zero/max scenes), `memory_analysis.json`, `verification.json`, and final `quartus_results.json`.
- This report.

No BDF, parent End_Message_Display, HUD, opening, game controller, movement, score/counter, collision, audio, original MIF, VGA/PLL, pin or constraint file is changed. The preservation audit compares114other hardware/configuration inputs byte-for-byte with the previous successful build, including the user's current QSF and top-BDF edits. Those unrelated changes are neither staged nor reverted.

## Verification before Quartus

Actual-ROM previews are saved under `assets/jungle/results_v3_implemented/`:

- `victory_active_rom_panel_288x432.png`, `defeat_active_rom_panel_288x432.png`: exact full-reference RGBA reconstructions, with blank values.
- `victory_sample_640x480.png`, `defeat_sample_640x480.png`: actual existing HUD/arena plus new native report and dynamic existing-font values.
- Corresponding `_blank_640x480.png`, `_zero_640x480.png`, `_max_640x480.png` and `_2x.png` images.

Static panel reconstruction is compared word-for-word with full approved MIFs, not the known-different split Defeat composite. Every pixel outside the alpha mask and panel bounds is checked unchanged from the current scene. Source-provided software preview surroundings are illustrative, so no claim is made that their reference HUD/background equals the current game.

| Final test log under simulation/ | Result |
| --- | --- |
| `results_v3.log` |**6,783,546checks PASS**: six complete frames, exact native color/alpha, dictionary addresses, all decimal numerals, zero/max counters, two-stage DR/color/font/mux, transparent corners, unchanged exterior/HUD/opening, fatal Cursed settled snapshot, Sapphire89→92victory, wall defeat, keypad5held/typematic/release/restart and hardware reset |
| `results_v3_opening.log` |**2,864,698checks PASS**, OPENING_STARTUP_PASS; all opening/HUD pixels, original controls/gameplay/menu/high-score/reset behavior |
| `results_v3_hud.log` |HUD_COUNTERS_PASS and **3,887,791render checks PASS**; original font/fields, resets, saturation, leading zeros, borders and unchanged arena |
| `results_v3_gameplay.log` |**3,345,662checks PASS**; V4floor/obstacles, head rotations/body/relics, separate original collision masks, trail/movement/self-hit and original collection/scoring events |
| `results_v3_win90.log` |**1,056checks PASS**; scores00..89continue;90/91/92win; effects/collisions/reset unchanged |
| `results_v3_arena.log` |ARENA_GEOMETRY_PASS;360cells/30obstacles,1024spawn candidates per relic, valid bounds/rejection and four24-pixel directions |

Final HDL runs have zero compile/runtime errors or warnings apart from existing work-library reuse notices. An initial testbench escaped-literal typo and a fixture-preparation/audit allowlist issue were corrected before final verification; neither required a Quartus attempt or gameplay RTL change. These are RTL/ROM tests, not post-route or physical board verification.

Zero/max combinations are synthetic rendering-capacity tests, not claims that Victory00or Defeat99are reachable gameplay states. The sample Victory uses the tested92/089/001/000combination; the Defeat sample uses67/034/016/003. Numbers are never baked into the static assets.

## Quartus compilation — PASS

Previous successful build:`db/results_build/source/output_files/`,306/553M10Ks,87for reports,7,287ALMs,5,418registers,2,430,176memory bits,0DSPs,91pins,1PLL. Worst setup+8.772ns, hold+0.162ns; warnings map242,fit91,STA52,asm0.

Exactly one isolated map→fit→STA→assembler flow completed in `db/results_v3_build/source/` on2026-10-19,10:59:34–11:06:37+03:00, using Quartus Prime Lite17.0Build595 and Cyclone V5CSXFC6D6F31C6. All stages returned0. Settings writes were disabled for map/fit. No retry, seed search, relaxed constraint or new timing exception was used. All130checked HDL/MIF/hardware/configuration inputs still match the source snapshot manifest byte-for-byte, including the user's current unrelated QSF/top-BDF edits. The verification utility/report were finalized separately without changing compiled hardware inputs.

Fitter RAM physical locations measure **198distinct report M10Ks**: tile map120, RGBA dictionary77, font1. Previous report allocations are absent. Other project allocations remain219blocks in aggregate;417=219+198. The dictionary/font logical storage is exactly1,567,964bits, as calculated before fitting.

The pre-fit191-block estimate was seven blocks low. The map fits120rather than122estimated blocks, while the9-bit dictionary uses77rather than68. Legacy LPM physical packing is therefore not equivalent to ideal native9-bit packing. Packing alpha beside color avoids a separate logical mask-ROM instance, but **does not imply that the alpha bit costs zero physical memory**. The actual198-block result, not191or87, is the handoff figure. Raw full-panel alternatives were not fitted; their estimated counts are not measured savings claims. No artwork fidelity was sacrificed to reduce utilization.

| Metric | Previous successful build | Final V3 build | Change |
| --- | ---: | ---: | ---: |
| Report M10Ks |87|198|+111 |
| Total M10Ks |306/553(55.33%)|417/553(75.41%)|+111;136free |
| Implementation memory bits |2,430,176|3,305,084|+874,908 |
| ALMs |7,287(17%)|7,210(17%)|−77 |
| Registers |5,418|5,396|−22 |
| DSP / pins / PLL |0/91/1|0/91/1|unchanged |
| Worst setup slack |+8.772ns|+7.205ns|−1.567ns; positive |
| Worst hold slack |+0.162ns|+0.162ns|unchanged; positive |

The larger memory footprint buys the approved full native artwork and different per-state lower textures. It is not a hidden duplication of the entire old renderer: only the new map/dictionary/font are instantiated for reports. No whole-screen framebuffer is added.

| Timing corner | Before setup / after setup(ns) | Before hold / after hold(ns) |
| --- | ---: | ---: |
| Slow1100mV85C |9.117 /7.508|0.300 /0.294 |
| Slow1100mV0C |8.772 /7.205|0.283 /0.278 |
| Fast1100mV85C |18.565 /18.027|0.176 /0.177 |
| Fast1100mV0C |19.777 /18.990|0.162 /0.162 |

All20reported timing summaries are positive with TNS0. Minimum pulse-width slack remains+0.793ns. Positive internal timing does not close the existing incomplete external-I/O constraints.

| Stage | Previous warnings | V3 warnings | V3 errors |
| --- | ---: | ---: | ---: |
| Synthesis |242|250|0 |
| Fitter |91|91|0 |
| TimeQuest |52|52|0 |
| Assembler |0|0|0 |

The eight additional synthesis messages are pre-existing vendor warning classes:13046tri-state grouping7→8and13049vendor tri-state conversions158→165. No new warning code or new graphics-RTL width/latch warning is introduced. Fitter/TimeQuest warning-code counts match the previous build. Existing pin/debug/SDC stale-target warnings remain unsuppressed. Full measurements, corner values and warning-code counts are in `assets/jungle/results_v3_implemented/quartus_results.json`.

### Programming-file handoff

After verification the successful outputs/reports are copied to normal ignored `output_files/`. `output_files/Lab1Demo.sof` is the new V3build,6,690,369bytes, generated2026-10-19 at11:06:37+03:00. SHA256:`DEF37FCF32B2E81BD085AA2A41EAE6CB740C717B803261AF230AB67C1EA70461`. Its bytes match the verified build snapshot. The prior successful87-block-report SOF remains recoverable under `db/results_build/source/output_files/`. No FPGA is programmed by generating/copying this file.

## Remaining concerns / Git

Existing incomplete external-I/O timing constraints, stale clock/debug references and unassigned debug pins remain outside scope. Positive constrained internal slack is not full board-interface signoff. No FPGA programming or physical testing is performed.

Local commit message:`Finalize Jungle Temple victory and defeat artwork`, after all verification and the single build pass. Only this phase's exact source/assets/tests/report are staged. The user's QSF/top-BDF changes, QWS/backup and earlier uncommitted memory-audit/preview work remain preserved and excluded. No generated compiler/simulator outputs are committed. The verified build includes those preserved working QSF/BDF edits; the commit intentionally does not incorporate them. No push.

Reproducibility (no artwork generation):

```text
python -B scripts/implement_results_v3.py --install --preview
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/results_reports.do
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/opening_screen.do
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/hud_relics.do
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/jungle_implementation.do
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/winning_score.do
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/arena_geometry.do
python -B scripts/implement_results_v3.py --audit --build-results db/results_v3_build/source/output_files
```

`--install` writes only the two derived active V3MIFs. `--preview` validates source data, reconstructs active ROM pixels, writes previews/JSON and independent ignored test fixtures. The original ZIP is optionally checked if still present; the retained source files provide all artwork needed for reproduction. `--audit` checks preserved local baseline inputs and snapshot code; `--build-results` reads the completed compilation, not another build. Physical board testing remains unperformed.
