# Phase 3D.2 — Shared Jungle Temple Victory and Defeat reports

Date: 2026-10-18, Asia/Jerusalem. Starting HEAD: `ddde7c3`.

Status: **PASS** — supplied artwork integration, all focused regressions and the single Quartus compilation succeed. All reported constrained setup/hold margins are positive. New reports use87M10Ks combined; project usage falls319→306/553. No push or FPGA programming.

## Supplied artwork and exact integration

Source: `C:/Users/USER/Downloads/FPGA_Jungle_Temple_Shared_Results_Assets.zip`.
All archive entries are retained byte-for-byte in `assets/jungle/shared_results_supplied/`.
The embedded README/manifest were inspected as asset documentation, not execution authority.
No artwork was generated, redrawn, recolored or replaced.

The 12 supplied MIFs (seven RGB332 images and five independent binary masks) are installed byte-identically in `RTL/mifs/results/`:

- `report_shared_144x216_rgb332.mif` — 144×216 opaque background, enlarged exactly 2×.
- `victory_title_224x32_rgb332.mif`, `defeat_title_224x32_rgb332.mif`, and their `_mask1.mif` files.
- `victory_emblem_160x72_rgb332.mif`, `defeat_emblem_160x72_rgb332.mif`, and their `_mask1.mif` files.
- `victory_plaque_224x32_rgb332.mif` — opaque TEMPLE CONQUERED plaque.
- `defeat_score_label_136x16_rgb332.mif` and its `_mask1.mif`.

All source/manifest SHA256 values, ZIP-entry bytes, declared dimensions, complete address coverage, PNG RGB332 pixels and binary alpha are checked. The verification JSON records individual hashes. Both `00` and `FF` remain valid opaque colors for supplied artwork; transparency depends only on the supplied masks. Existing relic sprites retain their original FF drawing-transparency convention when copied into the report-only atlas; their active artwork and collision masks are untouched.

The shared background is the exact supplied MIF. Six native overlays and the existing three 24×24 relic images are losslessly concatenated into `results_details_rgb332.mif` (48,448×8) with a parallel `results_details_mask1.mif` (48,448×1). Unmasked plaque pixels have mask1. These derived files contain no newly invented pixels. There is one background ROM, one color-detail ROM, one mask ROM and one small font ROM for both states, not two complete panels. Original supplied overlay files are retained for provenance; they are not separately instantiated in addition to the atlas.

## Geometry and dynamic fields

VGA remains 640×480; arena remains 20×18 at (144,24), with 24×24 tiles. Panel bounds are **X[248,536), Y[24,456)**, 288×432. No report drawing request reaches the existing left HUD X[0,144).

| Element | VGA position | Dimensions |
| --- | --- | --- |
| State title | (280,40) | 224×32 |
| State serpent emblem | (312,80) | 160×72 |
| Victory plaque | (280,164) | 224×32 |
| Defeat FINAL SCORE label | (280,172) | 136×16 |
| Defeat score digits | (456,171) | 32×18, two decimal digits |
| Ruby/Sapphire/Cursed icons | X280, Y232/288/344 | 24×24 each |
| Ruby/Sapphire/Cursed digits | X440, Y235/291/347 | 48×18, three decimal digits each |

Existing `numbers_new_font.mif` supplies the same 16×18 visible glyphs (rows6..23 of its 16×32 slots). Leading zeros and original 000..999 saturating counters are preserved. Each report uses a display-only snapshot of the existing BCD values; there are no replacement scoring or collection counters. Victory never enables final-score digits inside the report, and its opaque plaque covers the shared status well. The left HUD continues displaying its original score/high-score/counters.

The supplied preview images use an illustrative simplified HUD and optional darkening. New actual-MIF previews use the project's real unchanged HUD/frame/arena/relic artwork. Optional outside-panel darkening is deliberately omitted so all surrounding scene pixels remain unchanged. This is not a change to supplied panel artwork.

## RTL, BDF and pipeline

- `RTL/VGA/End_Message_Display.sv`: replace only the legacy result state/ROM/drawing branch with the shared child renderer; add display-only score/three-count inputs. Opening address logic, atlas, latch and two-stage metadata path remain unchanged.
- `RTL/VGA/results_report_renderer.svh`: new child module, included after the existing module so the current QSF source registration is sufficient. It has no outputs to gameplay logic.
- `RTL/VGA/Score_Block.bdf`: expose the existing three internal 12-bit BCD buses as outputs. Original accumulator, high score, counter instances and HUD connections remain unchanged.
- `RTL/VGA/TOP_VGA_DEMO.bdf`: extend only the two affected symbols and connect scoreLow/High plus the three count buses to the message renderer. Pre-existing user schematic changes are preserved and excluded from the task commit.

The report observes win/loss pulses without changing the controller. It marks a capture pending on the edge consuming a terminal pulse and captures statistics on the following edge. This lets collection consumers apply their pending pulses first. In particular, fatal Cursed collection at score5 produces report final score00, Ruby005 and Cursed001, while the original high-score semantics remain unchanged. New-game pulse clears report state/snapshot; keypad5 release/repress behavior and hardware reset/menu behavior remain original.

Stage1 registers all bounded background/detail/font addresses and drawing metadata. Stage2 is the existing registered-address/unregistered-output ROM style, with matching panel/native/digit/color metadata. Binary masks read in parallel with color; transparent pixels select the simultaneously read background. Dynamic glyph ink has priority over native overlays, then background. The existing registered objects mux retains its priority and adds its original final stage. Unlike the old raw-bound result request, the new request and all colors are explicitly aligned to the HUD/opening two-stage latency. No VGA, PLL, constraints or global latency changes.

The old `end_message_win.mif` and `end_message_lost.mif` remain on disk for history and old test fixtures. Their active ROM instances/references are removed; later Fitter RAM allocation is checked to prove they consume no memory in the new build. No needed local file was deleted.

## Exact changed/created task files

Modified:

- `.gitattributes` — byte-preservation rules for supplied/result MIFs.
- `RTL/VGA/End_Message_Display.sv`.
- `RTL/VGA/Score_Block.bdf`.
- `RTL/VGA/TOP_VGA_DEMO.bdf` — task-only additions; unrelated existing edits stay unstaged.
- `simulation/opening_screen_tb.sv` — new statistic port connections and shared-result checks replace obsolete banner equality checks; original menu/control/gameplay checks remain.

Created:

- `RTL/VGA/results_report_renderer.svh`.
- `RTL/mifs/results/` — the 12 exact supplied MIFs listed above and two lossless derived detail atlases.
- `scripts/implement_results_reports.py` — source validation, lossless integration, independent actual-MIF previews/fixtures, preservation checks and completed-build audit.
- `simulation/results_reports_tb.sv`, `simulation/results_reports.do`.
- `assets/jungle/shared_results_supplied/` — all exact ZIP entries (source PNGs, MIFs, README, manifest and illustrative supplied previews).
- `assets/jungle/shared_results_implemented/` — eight actual-MIF PNG previews, `verification.json`, and final `quartus_results.json` after compilation.
- This report.

Ignored test fixtures/build snapshots/logs remain under `db/` and `simulation/`. No QSF, SDC, PLL, pin, active HUD/font, arena, obstacle, snake, relic, collision, gameplay, keyboard or audio file is changed. The preservation audit confirms 84 original RTL/MIF/constraint/IP files byte-identical, the user's QSF byte-identical, both BDFs equal their original working copies plus only required display taps, and the opening path text identical.

## Focused verification — PASS

All suites used real active MIF data where applicable. ModelSim required execution outside the sandbox because its legacy 32-bit executable initially failed Windows DLL relocation inside the sandbox; the initial failure did not execute a test or compile.

| Suite/log under simulation/ | Result |
| --- | --- |
| `shared_results.log` | **6,958,125 checks PASS**: six complete VGA frames (Victory/Defeat sample, zeros and maxima), every decimal digit in every field, irregular coordinates/blanking, all native masks, exact2× background, font/request/color/mux alignment, unchanged HUD/exterior pixels, full-frame comparison against prior production opening, fatal Cursed settled capture, Sapphire89→92 victory, wall defeat, held/typematic5 suppression, release/repress restart and hardware reset |
| `results_opening_regression.log` | **2,864,698 checks PASS**, plus OPENING_STARTUP_PASS: all238,080 opening pixels and69,120 HUD pixels, four original movement controls, initial/reset menu, original score/relic/length/speed behavior, restart/high-score retention and new terminal snapshots |
| `results_hud_regression.log` | HUD_COUNTERS_PASS and **3,887,791 rendering checks PASS**: original five fields, zero/max digits, leading zeros, saturation, reset/high-score behavior and unchanged arena/borders |
| `results_gameplay_regression.log` | **3,345,662 checks PASS**: V4 floor/30-obstacle layout, rotated head/body/relic pixels, original separate collision masks,193-position trail, movement/length/self-hit and cycle-exact events/scoring |
| `results_win90_regression.log` | **1,056 checks PASS**: every score00..89 continues;90/91/92 win; original penalty/death/collision/reset behavior |
| `results_arena_regression.log` | ARENA_GEOMETRY_PASS:360cells,30obstacles,1024candidate states per relic, extents/overlap/reroll rejection and four24-pixel directions |

Every HDL compilation/test ended with zero errors and zero warnings, apart from existing work-library reuse notices. These are focused RTL/ROM simulations, not physical FPGA or post-route functional tests.

Zero/max report frames are synthetic display-capacity cases, not claims that Victory00 or Defeat99 are reachable in normal gameplay. The sample Victory preview uses an actually tested terminal combination: score92, Ruby089, Sapphire001, Cursed000. The sample Defeat preview uses score67, Ruby034, Sapphire016, Cursed003. Numeric pixels are always overlaid from the actual unchanged font, never baked into the artwork.

Previews:

- `assets/jungle/shared_results_implemented/victory_sample_640x480.png` and `victory_2x.png`.
- `assets/jungle/shared_results_implemented/defeat_sample_640x480.png` and `defeat_2x.png`.
- Matching `victory_zero_640x480.png`, `victory_max_640x480.png`, `defeat_zero_640x480.png`, `defeat_max_640x480.png`.

## Quartus build — PASS

Exactly one map→fit→STA→assembler flow completed on2026-10-18,16:46:39–16:54:10+03:00 in `db/results_build/source/`, with settings writes disabled for map/fit. All four stages returned0. This source snapshot includes the user's preserved current schematic/QSF edits. No retry, seed search, new timing exception or timing relaxation was performed. All116 hardware/configuration inputs checked against the build manifest still match the current working inputs byte-for-byte. The preview utility/report were finalized afterward without changing compiled hardware inputs.

Baseline: October17 successful supplied-opening build, Quartus Prime Lite17.0 Build595, Cyclone V5CSXFC6D6F31C6,319/553M10Ks,2,543,520memory bits,7,063ALMs,5,316registers. Worst setup+6.850ns, hold+0.132ns. Prior obsolete results use100distinct physical M10Ks, with no overlap with the other219blocks.

The new reports store79,5528-bit color pixels plus48,448mask bits and8,192font bits,693,056logical bits including the report-local existing font. Fitter physical locations confirm **87distinct M10Ks**: background32, native details48, mask6, font1. This meets the85–95block target. Neither old end-message MIF appears in the fitted RAM allocations. The other219blocks remain unchanged in aggregate; these reports replace100old blocks, rather than adding87on top of319.

| Metric | Previous successful build | New measured build | Change |
| --- | ---: | ---: | ---: |
| Results M10Ks |100|87|−13 |
| Total M10Ks |319/553(57.69%)|306/553(55.33%)|−13;247free |
| Implementation memory bits |2,543,520|2,430,176|−113,344 |
| ALMs |7,063(17%)|7,287(17%)|+224 |
| Registers |5,316|5,418|+102 |
| DSP blocks |1|0|−1 |
| Pins / PLLs |91/1|91/1|unchanged |
| Worst setup |+6.850ns|+8.772ns|+1.922ns |
| Worst hold |+0.132ns|+0.162ns|+0.030ns |

The DSP reduction follows replacement of the old result-address implementation: the previous Fitter DSP detail names `end_message_display:inst17|Mult0~mac`. No audio/gameplay algorithm was changed. M10K counts are measured physical allocations, not PNG/MIF file-size estimates.

| Timing corner | Before setup / after setup(ns) | Before hold / after hold(ns) |
| --- | ---: | ---: |
| Slow1100mV85C |7.242 /9.117|0.281 /0.300 |
| Slow1100mV0C |6.850 /8.772|0.254 /0.283 |
| Fast1100mV85C |17.505 /18.565|0.167 /0.176 |
| Fast1100mV0C |18.840 /19.777|0.132 /0.162 |

All20reported timing summaries are positive with TNS0; minimum pulse-width slack stays+0.793ns. Existing unconstrained external I/O remains5inputports and55outputports. No complete board-interface timing closure is claimed.

| Stage | Before warnings | After warnings | After errors |
| --- | ---: | ---: | ---: |
| Synthesis |243|242|0 |
| Fitter |91|91|0 |
| TimeQuest |52|52|0 |
| Assembler |0|0|0 |

Synthesis removes three10230width-truncation warnings from the replaced legacy path and adds two13049vendor-ROM tri-state-conversion warnings (156→158). No new warning code is introduced. Fitter and TimeQuest warning-code counts are identical to the baseline. Existing source-width/vendor-template, pin/debug and stale-clock warnings remain, without suppression.

Machine-readable measurements and every timing corner are saved in `assets/jungle/shared_results_implemented/quartus_results.json`. Original full reports/logs remain in the ignored build snapshot.

### Programming file

The successful outputs/reports are copied into the normal ignored `output_files/` after verification. `output_files/Lab1Demo.sof` is the new result-screen build,6,690,369bytes, generated2026-10-18 at16:54:09+03:00. SHA256: `CB2AEADBB3FB04842E071D956484FE9F79E4B3CD7ED2D34D6489822CF1CFD9D7`. Its bytes match the verified snapshot SOF. The previous successful supplied-opening build remains recoverable in `db/supplied_opening_build/source/output_files/`. Copying this programming file does not program the board.

## Remaining limitations / Git

Existing external-I/O constraint omissions, stale generated-clock/debug targets and unassigned debug pins are outside scope. Positive constrained internal timing will not establish complete board-level closure. No FPGA programming or physical testing is performed.

Local commit message: `Implement shared Jungle Temple victory and defeat reports`, after successful compilation/timing verification. The user's QSF edits, pre-existing top-BDF edits, QWS/backup and prior uncommitted memory-audit/preview work are preserved and excluded. The top-BDF task additions are staged independently against HEAD, not by staging the whole working schematic. Generated build/simulation artifacts remain ignored. The verified build includes the preserved working QSF/BDF edits; those unrelated edits are intentionally not claimed to be part of the commit.

Reproduce integration/independent fixtures/previews with the retained supplied assets and installed Python/Pillow:

```text
python -B scripts/implement_results_reports.py --install --preview
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/results_reports.do
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/opening_screen.do
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/hud_relics.do
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/jungle_implementation.do
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/winning_score.do
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/arena_geometry.do
python -B scripts/implement_results_reports.py --audit --build-results db/results_build/source/output_files
```

Only `--install` writes the new active result MIFs; it never changes original gameplay art. `--preview` generates preview PNGs and ignored independent fixtures. `--audit` checks the preserved local baseline; `--build-results` reads the completed fit and validates hardware-source hashes. No second build is required to inspect the saved measurements. No push or hardware programming was performed.
