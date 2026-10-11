# Phase 3B — Approved Jungle Temple HUD

Date: 2026-10-11. Starting HEAD: `11dc92d` (`Visual Redesign`); requested comparison build: `7201242`.

Status: **PASS** — exact artwork integration, HUD/arena/gameplay regressions and the single Quartus compilation succeed. All reported internal setup/hold checks are positive. No artwork generation, FPGA programming or push.

## Files changed

Modified production files:

- `RTL/VGA/NumbersBitMap.sv`: native panel RGB/alpha ROMs, compact live numerals and aligned metadata. Module ports and all numeric inputs remain unchanged. The temporary panel/frame/procedural labels are no longer drawn.
- `RTL/VGA/ScoreConstants.sv`: score/high-score origins reference the common layout header.
- `RTL/VGA/Score_Block.bdf`: only seven rendering parameters change: two square-object widths32→16 and heights32→9, and three numeral color overrides→RGB332 `F9`. All ports, counter/scoring instances, wires and pulse/BCD buses are unchanged.
- `.gitattributes`: `-text` for the approved HUD color MIF and new derived alpha MIF, preserving exact file bytes/line endings in Git.

New production files:

- `RTL/VGA/jungle_hud_layout.svh`: panel and live-field geometry constants.
- `RTL/mifs/hud_panel_rgb332.mif`: exact approved color data copied from `C:/Users/USER/Downloads/Jungle_Temple_HUD_Assets_For_Codex (1).zip`.
- `RTL/mifs/hud_panel_alpha.mif`: binary drawing mask derived mechanically from the supplied `hud_panel_rgb332.png` alpha, not its colors.

Other modified/created files:

- `simulation/hud_relics.do`: use the existing real-MIF ROM adapter rather than the older font-only/zero-background stub.
- `simulation/hud_render_tb.sv`: independently decoded panel/alpha/font expectations, compact window positions, full-frame pipeline checks and five updating-value tests.
- `scripts/implement_jungle_hud.py`: exact asset validation, alpha derivation, ignored expected-data fixtures, actual-MIF scene composition and read-only Quartus-report verification. It has no artwork-generation/PNG-to-color-MIF conversion or Quartus-launch path.
- `assets/jungle/hud_implemented/hud_panel_rgb332.png`: exact supplied quantized preview with binary alpha.
- `assets/jungle/hud_implemented/empty_hud_scene_640x480.png`: active panel with empty counter boxes.
- `assets/jungle/hud_implemented/full_scene_640x480.png`: actual-MIF gameplay preview with illustrative live values12/19 and012/345/678.
- `assets/jungle/hud_implemented/live_hud_4x.png`: nearest-neighbor inspection of the same panel/live values, not replacement artwork.
- `assets/jungle/hud_implemented/verification.json`: asset identity, alpha counts and field/window geometry.
- This report.

No active V4 floor/obstacle MIF, map, snake/relic artwork, collision mask, controller/counter, audio/input, VGA, PLL, SDC, physical pin or QSF file is modified. `hud_labels.sv` is retained unchanged as historical source but no longer instantiated by the numeric renderer. No new module/QSF registration or BDF port changes are needed.

## Native artwork and independent alpha

The supplied panel is exactly **120×432**, positioned at **(8,24)**, X [8,128), Y [24,456). Every ornament/border remains within its native box; the arena begins atX144, retaining a16-pixel gap. No stretching, cropping, recoloring, redesign or replacement textures. Internal transparent margins in the source are retained, not trimmed.

Color ROM: WIDTH8, DEPTH51,840, ADDRESS_RADIX=UNS, DATA_RADIX=HEX. All addresses0–51,839 occur exactly once, row-major `localY*120+localX`. Sixteen address bits cover the ROM. Complete supplied MIF SHA256:

`0958234d18a4b736158f181d3b7b225cca530603d0dd720f844111cf8e084305`

Supplied PNG pixels agree with nominal RGB332 decoding within one channel level due to expansion rounding. The MIF is authoritative and unchanged byte-for-byte, including line endings. The active color MIF has no baked numerical examples: dynamic numbers are drawn separately.

The final RGB332 PNG has only alpha0/255: **34,177 opaque pixels**, **17,663 transparent pixels**. Critically, **12,223 opaque pixels have color00**. Treating00 as a color key would punch holes through black stone, shadows and counter windows.

The new51,840×1 alpha ROM stores exactly the supplied binary opacity; color00 remains ordinary opaque black where the mask is1. Neither00 norFF is used as a HUD color key. Transparent pixels reveal the existing background; no forced black rectangle is drawn around the ornaments. Alpha MIF SHA256 at verification:

`0AA12A5110F95CE4FC97C57327CD1929C4BB31D4B0CF0E663807F0F9E66DCE26`

The three gemstone illustrations and all labels already belong to this panel. **No independent HUD icon ROMs, icon overlays or duplicate text were added.** The standalone icons in the ZIP are not installed into the rendering hierarchy. Their resemblance to the in-game relics is as supplied; in-game artwork is untouched.

## Live number placement and unchanged semantics

All ranges are screen pixels with exclusive upper bounds:

| Value | Origin | Draw field | Digits | Color |
| --- | --- | --- | ---: | --- |
| Score | (62,141) | X[62,78), Y[141,150) | 2 | F9 gold |
| High Score | (62,190) | X[62,78), Y[190,199) | 2 | F9 gold |
| Ruby | (70,259) | X[70,94), Y[259,268) | 3 | ED red |
| Sapphire | (70,292) | X[70,94), Y[292,301) | 3 | 57 blue |
| Cursed | (70,325) | X[70,94), Y[325,334) | 3 | B3 lavender |

The supplied blank window interiors, in panel-local coordinates, are conservatively bounded by Score[34,90)×[113,132), High[34,90)×[162,181), Ruby[54,95)×[233,247), Sapphire[54,95)×[266,280), Cursed[54,95)×[299,313). All five numeral fields are completely inside these opaque interiors, clear of frames, labels and gemstones.

The original single8192×1 `numbers_new_font.mif` remains byte-identical. Native16×32 glyphs have occupied rows6–23; all decimal glyph pixels outside those rows are verified blank. The display samples source columns0,2,…14 and rows6,8,…22 to render compact **8×9** numerals. This changes only dynamic-font sampling, not supplied panel art or counter widths. No derived replacement font or duplicated large font ROM was created. All ten decimal glyphs are nonempty/distinct and visually checked in the actual-MIF preview. Score/high-score remain two digits; collection totals retain three digits and leading zeros.

`appleCounter`, `highscoreComp`, `relic_collection_counters` and the event controller are unchanged. Score resets at new game; high score survives local restarts and resets only on hardware reset; independent12-bit BCD relic totals reset at game start and saturate at999. Original score, win/loss, length/speed and blue-spawn behavior remain unchanged.

## Pipeline and BDF integration

Stage1 registers raw coordinates alongside the existing square-object offset registers. Stage2 simultaneously captures font address, panel color address, panel alpha address and corresponding field/region/color metadata. Color and alpha use exactly the same address/clock edge. The original object mux adds its existing third register stage.

Panel addresses outside the native box are forced to0; the region flag prevents drawing there. Tests include blanking/outside coordinates and assert every sampled panel address is legal. High-score glyph pixels retain the high-score layer; all other opaque panel/score/relic pixels use the score layer. Their DRs are mutually exclusive. Original rendering priorities remain message > head > body > score > high-score > relic > background.

Only the display rectangle dimensions and numeral palette parameters change in the schematic. No changes to top-level BDF, source module interfaces, collection pulse wiring or BCD widths. The live counters have no new feedback into gameplay or collisions.

## Focused verification

- Exact supplied ZIP MIF bytes, embedded SHA256, 120×432 dimensions, complete address coverage, pixel ordering, RGB332/PNG agreement and binary alpha: PASS.
- Alpha ROM equals every supplied alpha bit, distinguishing all12,223 opaque-black pixels from17,663 transparent pixels: PASS.
- Actual-MIF 640×480 preview has one native panel, five live fields, no duplicated icons/labels and no arena overlap. Its arena crop is byte-identical to the V4 actual-MIF preview, including unchanged obstacle arrangement, snake and relic pose. The preview is illustrative, not a board capture.
- `simulation/jungle_hud.log`: **HUD_COUNTERS_PASS / HUD_RENDER_PASS**, **2,239,368 renderer checks**, all307,200 visible pixels, independently decoded panel/mask/font pixels, black00/transparent00 behavior, legal addresses, full streaming DR/RGB/mux alignment and no HUD/arena overlap. All five fields update; every decimal glyph0–9, leading zeros and999 are exercised.
- The unchanged counter/event test covers1005 consecutive collection events, independent totals, decimal carries,999 saturation, reset priorities, local restart, high-score persistence/capture, score effects and modulo-five spawn independence.
- `simulation/hud_jungle_gameplay.log`: **3,345,662 checks PASS**, full-frame V4/snake/relic rendering, centered24×24 head directions, frozen legacy22×24 head collision, real-mask Ruby8/Sapphire1/Cursed1 collection events,121 death events,1232 self-contacts, identical scoring/length/trail/reset/priority behavior.
- `simulation/hud_arena.log`: **ARENA_GEOMETRY_PASS**; all360 cells/30 obstacles,1024 spawn candidates per color, range/overlap/obstacle rejection, reroll/reachability and four-direction movement.
- Final simulations: zero HDL/runtime errors or warnings, aside from harmless reused-library notices. An initial HUD test attempt failed because its one-bit expected-data files used two hexadecimal digits; their formatting was corrected and the complete test rerun successfully before Quartus. No production RTL change or artwork compromise was required for that fixture issue.
- Starting tracked-file SHA256 audit finds only the six intended modified files listed above. Existing gameplay/rendering assets, map, all counters/controllers, object mux, VGA, audio, keyboard, masks, constraints/pins/PLL and QSF are byte-identical. The BDF matches its original text after reversing only the seven approved display parameters; the renderer's external interface is identical.

Reproduction from the project root:

```text
python scripts/implement_jungle_hud.py --archive "C:/Users/USER/Downloads/Jungle_Temple_HUD_Assets_For_Codex (1).zip" --fixtures --preview
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/hud_relics.do
python scripts/implement_v4_graphics.py --fixtures
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/jungle_implementation.do
```

`--mask` explicitly reproduces only the derived alpha MIF. Without it the script is read-only for active MIFs. `--git-index` verifies the staged authoritative color blob. Historical artwork-generation commands must not be used to regenerate approved active assets.

## Quartus build and comparison — PASS

One map→fit→STA→assembly sequence uses Quartus Prime Lite17.0 Build595, revisionLab1Demo, topTOP_VGA_DEMO, CycloneV `5CSXFC6D6F31C6`. Snapshot `db/phase3b_build/source/` contains currentHEAD plus the six exact production changes (three existing files, layout header, color MIF, alpha MIF); all six were byte-compared with active files before compilation. It uses the unchanged **current QSF**, with settings export disabled, not an old debug configuration. No repeated compilation or alternative fitter seed.

Current/compiled QSF SHA256: `AE56D79E54A6275E550AC525D603CEBB669EA7758AE25EE9D16E2953582DAB8B`. The starting tree was clean: the earlier SignalTap deletions are now committed by the user's `11dc92d`. They are preserved and not authored/staged by this phase.

Comparison baseline: the successful7201242 reports under `db/phase3a4_build/source/output_files/`. That build retained older SignalTap node assignments, QSF hash `D2537A35A81CBEE063B68B8C08A3EBFC13CA0E2BDAE2812ADF9FD6B32FB05E52`. Consequently resource/warning/timing differences can include the intervening user configuration change, not solely HUD artwork. No second baseline compilation is performed to isolate these contributions.

Authoritative new reports: `db/phase3b_build/source/output_files/`; stage logs: `db/phase3b_build/`. Compilation started2026-10-11 19:46:54 and assembly finished19:58:19 (Asia/Jerusalem). Map, fit, STA and assembly all exited0. The fitted design and generated programming file use the exact active production files: a final hash audit matched all six changed production files and the untouched QSF against the snapshot.

| Compilation stage | Errors, baseline → HUD | Warnings, baseline → HUD |
| --- | --- | --- |
| Analysis/synthesis | 0 → 0 | 226 → 235 |
| Fitter | 0 → 0 | 80 → 91 |
| Timing analyzer | 0 → 0 | 41 → 52 |
| Assembler | 0 → 0 | 0 → 0 |

Synthesis adds nine vendor LPM-ROM tri-state-to-wire diagnostics (13049:140→149) and one grouping diagnostic (13046:5→6), matching the eight panel color bits and one alpha bit. This is the same vendor ROM template behavior as existing assets, not an actual tri-state bus. The old missing SignalTap node warning35025 disappears because of the pre-existing user configuration. Existing42 width-truncation warnings and other synthesis warning codes/counts are unchanged.

Fitter/STA increases are configuration-related: absent JTAG debug nodes now make additional unchanged SDC targets unmatched (332174:18→23;332049:21→28), while the former debug-clock warning332043 disappears (1→0). No new warning code, timing exception or constraint edit was introduced by this phase. Three fitter critical warnings remain: nine debug pins lacking exact assignments and the same two stale generated-clock targets. They are not a declaration of complete board-level timing closure.

### Timing

Clock domain: `inst7|clk_31p5_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk`. Values below are ns; TNS is0 at every reported corner.

| Timing corner | Baseline game setup | HUD game setup | Baseline game hold | HUD game hold |
| --- | ---: | ---: | ---: | ---: |
| Slow1100mV85C | 6.354 | 7.895 | 0.320 | 0.247 |
| Slow1100mV0C | 5.294 | 7.524 | 0.273 | 0.226 |
| Fast1100mV85C | 17.615 | 18.715 | 0.178 | 0.150 |
| Fast1100mV0C | 18.590 | 19.532 | 0.161 | 0.134 |

Worst game setup improves5.294→**7.524ns**. Worst game hold decreases0.161→**0.134ns**, a27ps margin reduction, but remains positive: **no new hold/setup violation**. Minimum pulse-width slack remains+0.793ns. Fmax at slow85C/0C is41.93/41.28MHz (baseline39.38/37.80MHz).

All20 reported summary checks have positive slack and zero TNS. The baseline had40 checks, including a JTAG clock with worst hold+0.081ns and debug recovery/removal paths. Those debug paths are absent in the current user configuration, not hidden with new false paths. Baseline overall hold+0.081ns therefore must not be confused with the comparable game-domain hold+0.161ns. Current recovery/removal tables have no reported paths; this is not a new recovery/removal sign-off.

External I/O remains incompletely constrained:0 unconstrained clocks,5 input ports/120 input paths,55 output ports/141 output paths (baseline55/143). These pre-existing omissions limit external-interface claims even though the analyzed internal clocks pass.

### Resources

| Fitted resource | Baseline7201242 | HUD build | Net difference |
| --- | ---: | ---: | ---: |
| ALMs | 6,769 /41,910 (16%) | 6,425 /41,910 (15%) | −344 |
| Registers | 5,827 | 5,277 | −550 |
| Block-memory bits | 958,144 /5,662,720 (17%) | 1,375,552 /5,662,720 (24%) | +417,408 |
| RAM blocks | 123 /553 (22%) | 176 /553 (32%) | +53 |
| Pins | 91 /499 | 91 /499 | 0 |
| DSP blocks | 1 /112 | 1 /112 | 0 |
| PLLs | 1 /15 | 1 /15 | 0 |

The native panel and independent alpha logically require466,560 ROM bits; the numeric font stays a single unchanged8,192-bit ROM. The net resource changes also include the intervening removal of the user-created debug node and elimination of the old procedural HUD labels/frame. They cannot be attributed solely to the new artwork or presented as an isolated HUD optimization. Capacity remains sufficient with no artwork reduction or gameplay compromise.

### Standard programming file and local handoff

The verified new outputs/reports were copied to the normal ignored `output_files/` directory. **`output_files/Lab1Demo.sof` is the new HUD build**, not the previous arena-only programming file:

- Generated2026-10-11 19:58:19+03:00;6,690,369 bytes.
- SHA256:`B689D3E137D779D6C925D43C75C62861C882F55152B74305B4FDBF0D3137581A`.
- Standard-output hash equals the successful snapshot's SOF hash.
- The prior7201242 SOF/reports remain locally in `db/phase3a4_build/source/output_files/`; prior SOF hash:`0E8617158557D8DEA8B63E6FE95BE9548B2C9C2FDBA7EC530FC441AD2126F8CE`.
- Compiler caches, ModelSim outputs and programming files remain ignored and are not committed. The requested local commit contains only this phase's16 source/test/asset/report files, with message `Implement Jungle Temple HUD`. No QSF/debug changes are staged, no push is performed and the FPGA is not programmed.

Read-only report/asset check after compilation:

```text
python scripts/implement_jungle_hud.py --archive "C:/Users/USER/Downloads/Jungle_Temple_HUD_Assets_For_Codex (1).zip" --git-index --build-results db/phase3b_build/source/output_files
```

## Remaining limitations

- The original higher-priority win/loss message is unchanged: its rectangle X[40,600), Y[190,280) can cover the High Score and Ruby fields after a game ends. Normal gameplay displays all five fields without overlap. Altering this existing end-screen geometry or mux priority is outside this phase.
- Simulation uses an actual-MIF registered-address ROM adapter, not a full post-route device simulation. Quartus separately checks the real vendor ROM implementation and timed netlist. No physical FPGA/monitor verification is claimed.
- The PNG preview uses nominal RGB332 expansion. Existing board DAC bit expansion/monitor appearance, unconstrained external I/O and historical audio/reset/debug warnings are not repaired here.
- Original score/high-score widths and two-digit behavior are retained. The three collection totals retain their existing three-digit leading-zero/999 saturation policy. Preview numerical examples are not baked into artwork.
- The supplied panel, including its native ornaments and transparent margins, is preserved exactly. No standalone HUD gemstone overlays were added, and the in-game relics remain unchanged.
