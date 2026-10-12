# Phase 3B.2 — Final Jungle Temple HUD and arena borders

Date: 2026-10-12 (Asia/Jerusalem). Starting HEAD and comparison build: `97c1782` (`Implement Jungle Temple HUD`).

Status: **PASS** — exact approved artwork integration, all focused functional/rendering regressions and the single Quartus compilation succeed. Every reported internal setup/hold margin is positive. No artwork compromise, push or FPGA programming.

## Approved design and exact artwork preservation

The approved reference is `assets/jungle/hud_layout_fix_preview/full_scene_2x.png`. Its native counterpart is exactly640×480; the2× reference is a nearest-neighbor enlargement, not a1280×960 FPGA screen. The empty-window native PNG in the same directory supplies the HUD/frame background. No example number pixels are baked into the ROM.

All approved native pixels already belong to the exact nominal RGB332 palette. Conversion uses a reverse256-color lookup and rejects any incompatible pixel; there is no recoloring, quantization approximation, dithering, stretching, cropping or new image generation. The serpent ornaments, torches, leaves/vines, stonework, gold trim, text and the three gemstone illustrations are preserved exactly. No duplicate icons or labels are overlaid.

The actual-MIF full-scene composition equals the approved native full scene **RGB-byte-for-byte**, including the illustrative values12/19 and012/345/678. The empty-window actual-MIF scene also equals the approved empty-window native image. All207,360 arena pixels are unchanged. This demonstrates exact artwork/placement reproduction for the preview pose, not physical monitor equivalence.

Approved input SHA256:

- Empty windows: `4FA2ED6002A50E30FE460E47DD1FE7B8802C75E4D36D8C83F8D31A1A533542DD`.
- Native full scene: `0E65C4E3BDBEF5BA07846CD1334616CB42268FD73F22BA4CCB0430DE86124A05`.
- Approved2× full scene: `BD2CFCCE58247911D443AFF8B4C14EF50F818B470FED4010011394F4D28744D7`.

## Exact files changed and retained

Modified existing files:

- `RTL/VGA/NumbersBitMap.sv`: packed opaque frame ROM, independently bounded drawing mask, enlarged live fields and full-detail font sampling. External ports, numerical inputs and existing pipeline stages are unchanged.
- `RTL/VGA/jungle_hud_layout.svh`: approved HUD and numeral positions,16×18 digit dimensions.
- `RTL/VGA/Score_Block.bdf`: **only four rendering parameters** change: both score/high-score square widths16→32 and heights9→18. All wires, module ports, counters, score logic, pulse buses and colors remain unchanged.
- `.gitattributes`: add `-text` for the new frame MIF, preserving its exact bytes in Git.
- `simulation/hud_render_tb.sv`: independent approved-raster/font expectations, complete packed-address coverage, enlarged dynamic-digit cases, frame bounds and pipeline/geometry checks.
- `simulation/hud_relics.do`: update fixture-generation instructions for the final approved frame; existing real-MIF ROM adapter remains in use.

New implementation files:

- `RTL/mifs/hud_frame_rgb332.mif`: exact approved boundary artwork, WIDTH8, DEPTH99,840, row-major within each packed region; UNS addresses and HEX data.
- `scripts/implement_final_hud.py`: reproducible exact conversion, identity checks, ignored simulator fixtures, actual-MIF previews, staged-MIF byte verification and read-only build comparison. It does not launch Quartus, generate artwork or operate Git state.
- `assets/jungle/hud_final_implemented/empty_counter_windows_640x480.png`.
- `assets/jungle/hud_final_implemented/full_scene_640x480.png`.
- `assets/jungle/hud_final_implemented/full_scene_2x.png`.
- `assets/jungle/hud_final_implemented/zero_values_640x480.png`.
- `assets/jungle/hud_final_implemented/max_decimal_values_640x480.png`.
- `assets/jungle/hud_final_implemented/verification.json`.
- `HUD_FINAL_IMPLEMENTATION.md` — this report.

Previously untracked approved-preview provenance is retained alongside the implementation: `HUD_LAYOUT_FIX_PREVIEW.md` and the seven files in `assets/jungle/hud_layout_fix_preview/` (`compose_preview.ps1`, the three approved PNGs, `image_edit_concept.png`, `image_edit_prompt.txt`, `verification.json`). These historical preview artifacts are unchanged in this phase; the concept draft is not used as an active FPGA asset.

The old `hud_panel_rgb332.mif` and `hud_panel_alpha.mif` remain byte-identical for history but are no longer instantiated. The original `numbers_new_font.mif` remains byte-identical. `ScoreConstants.sv` already includes the shared layout header and needs no edit. No top-level BDF change, module interface change, symbol regeneration or new QSF registration is required.

## Geometry and ROM addressing

VGA remains640×480. Arena remains20×18 cells,24×24 pixels, origin(144,24), X[144,624), Y[24,456). HUD visible bounds are approximatelyX[8,136), Y[8,472):128×464. The left divider, top/bottom/right edging and corner caps reproduce the approved connected frame.

Only non-gameplay pixels are stored, avoiding a full-screen ROM:

| Packed region | Screen range | Size | First address |
| --- | --- | --- | ---: |
| Left/HUD/divider | X[0,144), Y[0,480) | 144×480 | 0 |
| Top, including right corner | X[144,640), Y[0,24) | 496×24 | 69,120 |
| Bottom, including right corner | X[144,640), Y[456,480) | 496×24 | 81,024 |
| Right, excluding corners | X[624,640), Y[24,456) | 16×432 | 92,928 |

Total: **99,840 pixels /798,720 logical ROM bits**,17-bit addressing. Every location appears exactly once; no arena pixel is stored. Constant shifts/additions implement144-,496- and16-pixel row strides. No new multiplier/PLL or address pipeline stage is introduced. Outside the visible frame, the ROM address is forced to0 and its drawing request is disabled.

Frame MIF SHA256: `AFC69C02AC7A5DA96EF8235307BDD81FA9AFC488B5B5F7AB2A6832BA522C66E4`.

The approved new boundary raster is fully opaque, so its **independent geometry drawing mask**, not a color key or gameplay mask, defines visibility. Its28,491 color00 pixels and91 colorFF pixels are valid opaque colors. No black-window holes or missing bright trim pixels arise from sprite transparency conventions. Removing the old alpha-ROM instance does not change snake/relic/obstacle drawing masks or collision masks.

## Dynamic values, font and alignment

| Value | Origin | Exact draw range | Digits | RGB332 |
| --- | --- | --- | ---: | --- |
| Score | (57,116) | X[57,89), Y[116,134) | 2 | F9 |
| High Score | (56,182) | X[56,88), Y[182,200) | 2 | F9 |
| Ruby | (64,273) | X[64,112), Y[273,291) | 3 | ED |
| Sapphire | (64,317) | X[64,112), Y[317,335) | 3 | 57 |
| Cursed | (64,362) | X[64,112), Y[362,380) | 3 | B3 |

All fields fit inside the exact approved empty wells (Score35,108/76×32; High33,175/78×32; Ruby59,268/59×27; Sapphire59,313/59×27; Cursed59,358/59×27), clear of labels, gems and trim. Counter windows have no pre-rendered values.

Reuse the original single8192×1 font ROM. Each digit uses all16 columns and all occupied rows6–23 from its16×32 slot, giving the approved **16×18** design without downsampling or a replacement font. Font SHA256 remains `4C06CDFF1A35FF2908DB2635B4B946AC10F2B52D41F151BB6554E9552EA8B58D`.

Score/high-score remain two digits with unchanged4-bit digit inputs. Rendering tests cover00,99 and the maximum raw nibble patternFF without adding a clamp or changing the accumulator. FF is synthetic interface coverage, not a claimed reachable decimal game score. Original win-at20 gameplay is unchanged. Relic counters retain leading zeros,000–999 saturation and12-bit BCD interfaces.

The unchanged counter/event regression verifies independent collection pulses, decimal carries and999 saturation, score/new-game reset, relic resets, high-score persistence across local restart and hardware-reset clearing, Sapphire/Cursed score effects, original modulo-five blue spawning, lethal Cursed ordering and win-at20 behavior.

Stage1 registers raw coordinates alongside the existing square-object offsets. Stage2 samples the frame/font ROM addresses and the corresponding drawing-region/font/color metadata together. The existing object mux contributes its unchanged third stage. All five fields remain live inputs. High-score glyph pixels retain their existing high-score layer; the remaining frame/number pixels use the score layer, with mutually exclusive drawing requests. Existing rendering priorities and gameplay collision signals remain unchanged.

## Focused verification — PASS

- Exact approved native/2× relationship, RGB332 membership, all99,840 packed words/addresses, input/file hashes, full-scene pixel equality and all207,360 preserved arena pixels: PASS.
- `simulation/final_hud_counters.log`: **HUD_COUNTERS_PASS**; unchanged counter/event test including1005 successive collections, all three saturated999 totals, leading zeros, local/hardware resets, high-score persistence and original game-controller events.
- Same log: **HUD_FINAL_RENDER_PASS**, **3,887,791 checks**. Streams all307,200 visible pixels and checks all99,840 frame addresses exactly once, independent approved-raster/font colors, opaque00/FF, five updating16×18 fields,00/99/FF and000/999, every decimal glyph0–9, blanking/boundary exclusion, ROM/DR/RGB alignment and original mux latency.
- `simulation/final_hud_gameplay.log`: **3,345,662 checks PASS**; full-frame V4 rendering, complete24×24 head rotation, frozen legacy22×24 head collision, unchanged body/relic masks,193-entry trail/length/reset/self-hit behavior, real-mask Ruby8/Sapphire1/Cursed1 events,121 deaths and1232 self-contacts, cycle-exact scoring and transition priorities.
- `simulation/final_hud_arena.log`: **ARENA_GEOMETRY_PASS**; all360 cells/30 obstacles,1024 spawn candidates and complete random-counter cycles per color, range/overlap/obstacle rejection, reroll reachability and four-direction24-pixel movement.
- Final simulator compiles/runs have zero errors and zero HDL/runtime warnings. Reused-work-library notices are harmless and pre-existing.
- SHA256 preservation audit: only the six intended original tracked files listed above differ; all other271 tracked files remain byte-identical. The BDF is identical after reversing only its four dimension values; the renderer's external interface is identical.

Approved V4 floor/obstacle MIFs, occupancy/rotation/floor maps, snake/relic artwork, separate masks, controllers, scoring/relic counters, audio/input, VGA/PLL/pins/SDC and object mux are untouched. Current QSF SHA256 remains `AE56D79E54A6275E550AC525D603CEBB669EA7758AE25EE9D16E2953582DAB8B`. The unrelated untracked `Lab1Demo.qws` remains unchanged and is excluded from staging.

Reproduction from the project root:

```text
python scripts/implement_final_hud.py --fixtures --preview
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/hud_relics.do
python scripts/implement_v4_graphics.py --fixtures
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/jungle_implementation.do
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/arena_geometry.do
```

`--install` explicitly reproduces only the exact new frame MIF from the approved empty-window image. Omit it for read-only active-asset verification. Historical preview/image-generation commands are not needed to reproduce this implementation.

## Quartus compilation and comparison — PASS

One map→fit→STA→assembly sequence uses Quartus Prime Lite17.0 Build595, revisionLab1Demo, topTOP_VGA_DEMO, CycloneV5CSXFC6D6F31C6. It started2026-10-12 20:50:00+03:00 in the isolated snapshot `db/phase3b2_build/source/`: startingHEAD plus the four exact production changes (NumbersBitMap, Score_Block, layout header, frame MIF). The unchanged current QSF is explicitly copied and verified, with settings export disabled. Active sources/configuration are not modified by compilation. No repeated build, alternate fitter seed, constraint relaxation, false path or clock edit.

Previous successful comparison reports: `db/phase3b_build/source/output_files/` (97c1782). Final reports are `db/phase3b2_build/source/output_files/`; stage logs are under `db/phase3b2_build/`. Both builds use the same current QSF, unlike the earlier7201242 comparison.

Assembly completed2026-10-12 **20:57:05+03:00**. All four stage processes exited0. The final source/MIF/QSF hash audit confirms the compiled snapshot still equals the active project. No second Quartus compilation was launched.

| Stage | Previous errors → final | Previous warnings → final |
| --- | --- | --- |
| Analysis/synthesis | 0 → 0 | 235 → 233 |
| Fitter | 0 → 0 | 91 → 91 |
| TimeQuest | 0 → 0 | 52 → 52 |
| Assembly | 0 → 0 | 0 → 0 |

No new warning code or increased warning-code count. Synthesis removes one vendor ROM grouping warning (13046:6→5) and one vendor tri-state-to-wire warning (13049:149→148), consistent with removal of the obsolete alpha-ROM instance. The original42 width-truncation warnings and all other synthesis warning counts remain unchanged. Fitter and STA warning codes/counts match the previous build exactly.

Three fitter critical warnings remain unchanged: nine debug pins without exact locations and two stale generated-clock targets at `DE10_Standard_Audio.sdc` lines33/38. Existing unmatched SDC targets, historical audio/reset/loop warnings and ignored assignments are not repaired or suppressed in this phase.

### Timing

Clock: `inst7|clk_31p5_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk`. All values below are ns; TNS is0 at every reported corner.

| Corner | Previous setup | Final setup | Previous hold | Final hold |
| --- | ---: | ---: | ---: | ---: |
| Slow1100mV85C | 7.895 | 8.271 | 0.247 | 0.291 |
| Slow1100mV0C | 7.524 | 7.872 | 0.226 | 0.243 |
| Fast1100mV85C | 18.715 | 18.695 | 0.150 | 0.177 |
| Fast1100mV0C | 19.532 | 19.534 | 0.134 | 0.162 |

Worst setup improves **+7.524→+7.872ns** (+0.348ns); worst hold improves **+0.134→+0.162ns** (+0.028ns). Fast85C setup decreases0.020ns but remains strongly positive; no new setup/hold violation is introduced. Minimum pulse-width slack remains+0.793ns. Slow85C/0C Fmax improves41.93/41.28→42.60/41.89MHz.

All20 reported summary checks have positive slack and zero TNS. Recovery/removal tables have no reported paths in this unchanged current debug configuration; no new false paths, timing exceptions, constraint relaxation or claim of recovery/removal sign-off. External I/O remains incompletely constrained:0 unconstrained clocks,5 input ports/120 paths,55 output ports/141 paths, unchanged from the comparison build. Passing analyzed internal paths does not establish complete board-interface timing closure.

### Resource comparison

| Fitted resource | Previous97c1782 | Final HUD/frame | Difference |
| --- | ---: | ---: | ---: |
| ALMs | 6,425 /41,910 (15%) | 6,490 /41,910 (15%) | +65 |
| Registers | 5,277 | 5,294 | +17 |
| Block-memory bits | 1,375,552 /5,662,720 (24%) | 1,707,712 /5,662,720 (30%) | +332,160 |
| RAM blocks | 176 /553 (32%) | 215 /553 (39%) | +39 |
| Pins | 91 /499 | 91 /499 | 0 |
| DSP blocks | 1 /112 | 1 /112 | 0 |
| PLLs | 1 /15 | 1 /15 | 0 |

The logical memory increase is exactly798,720 new frame bits minus466,560 old panel+alpha bits. The original font ROM remains single and unchanged. Capacity is sufficient for the full approved artwork with no resolution reduction or architectural/gameplay compromise. Small logic/register changes include address arithmetic and fitter optimization; source gameplay state/counters are unchanged.

### Standard programming file and local handoff

After all checks passed, the verified new programming file and reports were copied into the normal ignored `output_files/` directory. **`output_files/Lab1Demo.sof` is the final enlarged-HUD/frame build**, not the prior small-HUD build:

- Generated2026-10-12 20:57:05+03:00;6,690,369 bytes.
- SHA256: `9B76503632A1F78D4EA4B3D24C9E4E112BD023630A4C0BF20EA0D902C7694772`.
- Its hash equals `db/phase3b2_build/source/output_files/Lab1Demo.sof`.
- The prior97c1782 SOF/reports remain in `db/phase3b_build/source/output_files/`, with SOF hash `B689D3E137D779D6C925D43C75C62861C882F55152B74305B4FDBF0D3137581A`.
- Build caches, simulator logs/libraries, reports and programming files remain ignored, not committed. The requested local commit is `Finalize Jungle Temple HUD and arena borders`; its scope is the23 implementation/test/preview/report files listed above, excluding `Lab1Demo.qws` and all QSF/SignalTap settings. No push or programming.

Read-only active-asset/report and staged-MIF verification:

```text
python scripts/implement_final_hud.py --git-index --build-results db/phase3b2_build/source/output_files
```

## Remaining limitations

- Physical FPGA/monitor behavior is not tested and the board is not programmed. Actual-MIF previews use nominal RGB332 expansion, not a capture of the board's existing DAC/monitor behavior.
- Functional simulation uses the real MIFs with the existing registered-address ROM model, not a full post-route simulation. Quartus checks the real vendor ROM/netlist separately.
- Existing higher-priority win/loss overlay X[40,600), Y[190,280) is unchanged; it can cover portions of the decorative HUD after game end. Redesigning it or changing mux priority is outside this phase.
- Existing stale constraints, historical audio/reset/debug warnings, unassigned debug pins and incompletely constrained external I/O are not repaired. Positive internal setup/hold margins do not imply complete external I/O timing closure.
- Old HUD assets/history are retained; no user file is deleted or reverted. Generated simulator/build outputs stay ignored. Only this approved implementation and its preview provenance are eligible for the requested local commit; no unrelated QSF/SignalTap edits are included.
