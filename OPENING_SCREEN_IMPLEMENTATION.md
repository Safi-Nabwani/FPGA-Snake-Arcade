# Phase 3C — Jungle Temple opening screen and visual tutorial

Date: 2026-10-16 (Asia/Jerusalem). Starting HEAD and comparison build: `990199e` (`Finalize Jungle Temple HUD and arena borders`).

Status: **PASS** — supplied-art conversion, all focused functional/rendering regressions and the single Quartus compilation succeed. Every reported internal setup/hold margin is positive. The approved artwork fits without reduction or replacement; RAM headroom and hold margin are limited as documented below. No push or physical FPGA programming/testing.

## Approved artwork and corrected tutorial

Source: supplied `a_detailed_pixel_art_video_game_title_start_screen.png`,1448×1086. An exact copy is retained as `assets/jungle/opening_screen/source_approved.png`, SHA256 `E69F3ADF21123ECF046384719233DF1D2BEAD9F5CB54C3FCE6D35C3156469CF3`.

The image is exactly4:3, so nearest-neighbor resizing to640×480 preserves its whole composition without cropping, stretching its aspect ratio or substituting artwork. Each channel is rounded to its nearest representable RGB332 value. This necessary palette conversion is explicit and reproducible; the PNG source itself is not edited. No image-generation service, unrelated replacement art, new title, serpent, gem, border or jungle texture was used.

Only the authorized tutorial corrections change the converted image. The three relic names/illustrations, title, controls/arrow graphics, goal illustration, jungle/temple decorations, left sidebar and large PRESS5TOSTART prompt remain from the supplied composition.

| Relic | Correct score effect | Correct length effect | Preserved gameplay speed effect, omitted from artwork |
| --- | --- | --- | --- |
| Ruby | +1 | +1 | +3 |
| Sapphire | +3 | −3, minimum1 | −5, minimum80 |
| Cursed | −5, minimum0 | +5, maximum32 | +10, maximum250 |

The goal remains reach20 score to win. Cursed collection at score≤5 still loses; wall, rock and self-collision rules are unchanged. The tutorial summarizes the requested score/length effects, not every exception/speed bound.

Correction text uses the project's existing5×7 pixel-font definitions from `hud_labels.sv`, plus the few missing characters needed for the effects/keypad label. All letters are bitmap pixels, not antialiased system-font output. Each relic has two clearly separated7-pixel-high lines. Three small dark text rectangles are cleared using a text-free4×4 background patch from the same approved panel, without painting over relics, names or trim. Changed pixels are verified to occur only in these rectangles or the added keypad label. No existing font/graphics MIF or RTL is rewritten for this conversion.

Native text positions: Ruby(381,256)/(381,267); Sapphire(381,298)/(381,309); Cursed(381,339)/(381,350). The keypad clarification is at(193,345), inside the controls panel above its bottom trim. The two supplied inaccurate descriptions are not retained. Full-scene native and2× actual-MIF previews were visually inspected for readability.

The opening screen's left numerical zeros belong to the supplied boot-screen artwork. It is shown only on hardware initialization/reset, when the actual scores/counters are zero. It is not used as the gameplay HUD, and local game restarts do not return to this static screen. All existing gameplay HUD values remain dynamic and unchanged.

## Files modified and created

Modified existing files:

- `RTL/VGA/game_controller.sv`: name the initial idle state `s_menu`; qualify all start/restart transitions with a fresh keypad5 edge; allow the existing new-game clear pulse to finish before testing the previous game's score/collision inputs. No changes to active-play score, win/loss, collection priority or speed/collision rules.
- `RTL/VGA/End_Message_Display.sv`: add the full-screen menu ROM and drawing-only boot-menu latch inside the existing highest-priority message entity. No external-port change. Keep the original win/loss state logic, assets, rectangle and behavior after the menu exits.
- `.gitattributes`: add `-text` for the new opening MIF so Git preserves its bytes.
- `simulation/jungle_rom_model.sv`: test-only support for legal MIF address ranges. Original win/loss MIFs already use these ranges; their data is not changed. The existing registered-address timing model is retained.

Created files:

- `RTL/mifs/opening_screen_rgb332.mif` — native opaque menu ROM.
- `scripts/implement_opening_screen.py` — deterministic supplied-art conversion, bounded tutorial correction, actual-MIF previews, fixture generation and read-only build/staged-asset checks. No Quartus launch, artwork generation or Git mutation.
- `simulation/opening_screen.do` — strict pass/fail driver for both new tests.
- `simulation/opening_screen_tb.sv` — actual-MIF/keyboard/state/motion/counter/result-compatibility test.
- `simulation/opening_startup_tb.sv` — small real-score victory→restart race regression.
- `assets/jungle/opening_screen/source_approved.png` — exact supplied source copy.
- `assets/jungle/opening_screen/opening_screen_640x480.png` — actual active-MIF native preview.
- `assets/jungle/opening_screen/opening_screen_2x.png` — nearest-neighbor inspection copy.
- `assets/jungle/opening_screen/verification.json` — source/MIF identity, dimensions, conversion, text rectangles/positions and preservation checks.
- `OPENING_SCREEN_IMPLEMENTATION.md` — this report.

No BDF, module symbol/port, QSF source-list registration or top-level wiring changes are necessary: both modified entities are already registered and connected to all required clocks, reset/start pulses and pixel coordinates. No new debug pins or clocks.

## Game-state design and keyboard handling

The existing2-bit game FSM already has the four needed states: MENU (`s_menu`, formerly idle), PLAYING (`s_gameStarted`), VICTORY (`s_gameWon`) and DEFEAT (`s_gameLost`). Hardware reset selects MENU, with `gameStarted=0`. The existing snake-head/body logic resets/holds inactive while not running, and the game FSM emits no collection, death, win or score events in MENU, regardless of overlap signals. Free-running spawn counters remain unchanged; they do not cause collection events.

`keyPad_decoder.sv` currently maps **9'h073 to keypad5**, with a held `NumberKey[5]` output. Keypad8/6/4/2 are9'h075/074/06B/072. Their original direction priority and no-reversal logic remain unchanged. The separate extended arrow cluster and top-row5 are not new mappings in this phase; the reference arrow graphics illustrate movement, and the added NUMPAD8/4/6/2 text makes the existing mapping explicit.

One register samples the held5 level. `startPressed = key_5 && !key5HeldD` accepts one start on a fresh press. Repeated PS/2 make/typematic events leave the held level high and cannot create additional start pulses. A held key is also consumed while playing, so it cannot automatically restart a later victory/defeat. Release/break and a fresh make are required. The decoder itself is byte-identical; no arrow/input remapping or new asynchronous clock domain.

MENU→PLAYING uses the original `gameStartPulse`, clearing score, body/trail/length/speed, relic counts, blue-spawn state and old messages through their existing connections. It does not assert hardware reset or clear high score. Terminal-state local restarts also go directly to PLAYING, preserving high score; hardware reset retains its original high-score-clearing behavior.

### Minimal correction discovered by the new tests

The initial integrated test exposed an existing victory-restart race. A small diagnostic reproduced it with the real score accumulator: on restart the controller enters PLAYING with `gameStartPulse=1` while score remains20; on the next edge the accumulator clears to00 but the controller still reads the previous20 and re-enters VICTORY.

The diagnostic trace before correction is state1/run1/start1/score20, followed by state2/run0/start0/score00/won1. After correction it remains state1/run1 while score becomes00, with no new win pulse.

The smallest correction is to skip win/collision/collection evaluation **only while the existing gameStartPulse is high**, allowing all existing clear consumers to finish on that same edge. Rules are evaluated normally from the following cycle. No new clock, reset architecture, scoring threshold, exception, movement delay during active play or gameplay algorithm is introduced. This also prevents stale pre-clear collision inputs from ending a new game during initialization.

The four existing FSM/result pulses leave a direct extension point for later victory/defeat artwork. No new result-screen design is implemented here. The original win/loss ROM displays are retained and compared against a frozen990199e renderer in simulation.

## ROM format, layer priority and pipeline

The new menu is one307,200×8 ROM,19-bit row-major address `640*y+x`. RGB332 channels are R[7:5],G[4:2],B[1:0]. Logical payload is2,457,600 bits. No alpha/framebuffer RAM, duplicate numeral ROM or replacement gameplay asset is added. Full-screen storage preserves all supplied artwork, including its opening-specific sidebar and border; gameplay's existing frame remains an independent untouched asset.

MIF address coverage is exactly0–307,199 once each; UNS addresses, HEX data. MIF SHA256: `057A41131593CA4D758E09C025B7EAE47E52049911662B85E32550F10E919984`.

The renderer uses shifts/additions for640-pixel stride, not a new DSP. Outside X[0,640),Y[0,480), the address is forced to0 and the drawing request is disabled. Color00 andFF are ordinary **opaque menu colors**; neither is a transparency key or collision mask.

Stage1 registers the menu address and region/mode metadata; stage2 is the existing vendor ROM's registered address and matching metadata. This matches the two-stage gameplay HUD/head path. The existing registered object mux adds its usual further stage. The menu occupies the already highest-priority message layer, covering every competing gameplay/HUD pixel while active. Existing object-mux ports, priorities and VGA/DAC timing are untouched.

A local drawing-only `menuActive` latch in the message renderer mirrors hardware reset→first start pulse and then stays off until hardware reset. It has no outputs into gameplay/reset/collision logic. It avoids enlarging or rewiring BDF interfaces; it does not replace or compete with the authoritative game FSM. There is no later return-to-menu input in this phase. Mode changes travel with the matching pixel metadata; there may be a partially transitioned first raster frame when a start arrives mid-frame, as no new frame-latched game-start delay is introduced.

## Focused verification — PASS

- Deterministic source SHA/dimensions/aspect, nearest-neighbor/native RGB332 conversion, exact active MIF width/depth/address data, and unchanged artwork outside authorized text edits: PASS.
- `simulation/opening_screen.log`: **OPENING_STARTUP_PASS**, real winning score20 followed by a stable fresh game at00, with no stale-score re-win.
- Same log: **OPENING_SCREEN_PASS**, **2,870,886 checks**. All307,200 menu pixels and ROM addresses are covered exactly once; independent expected raster, opaque00/FF, blanking/outside coordinates, aligned menu DR/color and original mux priority/latency all pass. Gameplay overlap inputs and held direction are deliberately asserted throughout MENU: no motion, score/length/speed changes or collection/death events occur.
- Actual decoder make/break and keypad073/held/typematic tests: exactly one initial start, no held-key terminal auto-restart, release/repress restarts, hardware reset returns to MENU, four original movement directions work. Tests verify Ruby8/Sapphire1/Cursed1 score/length/speed effects, new-game clears, high-score preservation, win-at20, and pixel-compatible old victory/defeat panels.
- `simulation/opening_hud_regression.log`: **HUD_COUNTERS_PASS**, all independent000–999 relic totals,1005-event saturation/carries, original score/high-score/new-game rules and modulo-five spawn independence; **HUD_FINAL_RENDER_PASS**,3,887,791 checks, all pixels/boundary addresses, five dynamic16×18 fields, zero/max values and original pipeline/arena bounds.
- `simulation/opening_gameplay_regression.log`: **3,345,662 checks PASS**, full-frame V4 rendering, full24×24 head in all directions, frozen legacy22×24 head collision, original body/relic masks,193-entry trail, length/self-collision/reset/priority and cycle-exact scoring from real overlap events. Ruby8/Sapphire1/Cursed1 and1232 self-contacts remain exercised. The held-key test now records one death instead of121 automatic held-key restarts, the intentional required start-edge change—not a collision-mask change.
- `simulation/opening_arena_regression.log`: **ARENA_GEOMETRY_PASS**, all360 cells/30 obstacles,1024 spawn candidates/counter states per color, correct range/overlap/obstacle rejection, reroll reachability and24-pixel four-direction movement.
- Final simulator compiles/runs have zero errors and zero HDL/runtime warnings, apart from harmless pre-existing reused-library notices. Initial test attempts identified the test adapter's unsupported existing compressed MIF ranges and then the genuine startup race above; both were corrected and the entire suite rerun before Quartus. No failed Quartus attempt or artwork compromise.

SHA256 preservation audit: of294 original tracked files, only the four intended existing files listed above differ. The remaining290 are byte-identical, including every existing MIF, gameplay/HUD geometry and renderer, BDF, keyboard decoder, counter/scoring module, speed/movement/body logic, collision/spawn map, audio, VGA, PLL, SDC and pins. Current QSF hash remains `AE56D79E54A6275E550AC525D603CEBB669EA7758AE25EE9D16E2953582DAB8B`. The pre-existing untracked `Lab1Demo.qws` remains unchanged at its **current session** starting hash `5DF036CC2A0174DC89784B61199AD88D48854A0C25176158C6658D7F214CF398` and is excluded from staging.

## Quartus build and comparison — PASS

One map→fit→STA→assembly sequence uses Quartus Prime Lite17.0 Build595, CycloneV5CSXFC6D6F31C6, revisionLab1Demo/topTOP_VGA_DEMO. It started2026-10-16 13:41:00+03:00 in `db/phase3c_build/source/`, an isolated990199e snapshot with the exact active controller/message renderer/new MIF overlaid. The unchanged current QSF is explicitly copied and byte-verified; settings export is disabled. No alternate fitter seed, timing exception/constraint change or repeated compilation.

Final reports: `db/phase3c_build/source/output_files/`; stage logs: `db/phase3c_build/`. Compare with the existing successful990199e reports under `db/phase3b2_build/source/output_files/`, not a newly compiled baseline or older small-HUD build.

Assembly completed2026-10-16 **13:51:22+03:00**. Map, fit, STA and assembly each exited0. The final active-versus-snapshot hash audit matches both RTL entities, the new MIF and untouched QSF. No second Quartus compilation was launched.

| Stage | Previous errors → opening | Previous warnings → opening |
| --- | --- | --- |
| Analysis/synthesis | 0 → 0 | 233 → 243 |
| Fitter | 0 → 0 | 91 → 91 |
| TimeQuest | 0 → 0 | 52 → 52 |
| Assembly | 0 → 0 | 0 → 0 |

No new warning code. The ten additional synthesis messages are the same vendor LPM-ROM conversion diagnostics already present:13049 increases148→156 (the new eight-bit ROM bus),13046 increases5→7 (grouping diagnostics). These convert the template's internal tri-state nodes into wires; they do not create an actual internal tri-state menu bus. Existing42 width-truncation warnings and every other synthesis warning-code count are unchanged. Fitter/STA warning codes and counts exactly match990199e.

The same three fitter critical warnings remain: nine debug outputs without exact pin locations and two unmatched generated-clock targets in `DE10_Standard_Audio.sdc` lines33/38. Historical ignored assignments and stale clock/audio/debug constraints are not suppressed or repaired here.

### Timing

Clock: `inst7|clk_31p5_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk`. Values are ns; TNS is0 for all reported corners.

| Corner | Previous setup | Opening setup | Previous hold | Opening hold |
| --- | ---: | ---: | ---: | ---: |
| Slow1100mV85C | 8.271 | 7.894 | 0.291 | 0.152 |
| Slow1100mV0C | 7.872 | 7.425 | 0.243 | 0.136 |
| Fast1100mV85C | 18.695 | 18.127 | 0.177 | 0.084 |
| Fast1100mV0C | 19.534 | 19.246 | 0.162 | 0.062 |

Worst setup **+7.872→+7.425ns** (−0.447ns); worst hold **+0.162→+0.062ns** (−0.100ns). All analyzed setup/hold requirements still pass, with no new negative slack/TNS, but **62ps hold margin is narrow** and should be rechecked after any future fit. No timing/PLL change or exception hides the reduction.

All20 reported summary checks have positive slack and zero TNS. Minimum pulse-width slack remains+0.793ns. Slow85C/0C Fmax changes42.60/41.89→41.93/41.12MHz. Existing recovery/removal summaries have no reported paths; this is not a new recovery/removal sign-off.

External I/O remains incompletely constrained:0 unconstrained clocks and5 input ports/120 paths, unchanged;55 unconstrained output ports remain, but their path count increases **141→148**. The new rendering logic creates additional paths to existing unconstrained outputs, without new ports or constraint edits. This is an external-I/O coverage limitation, not a reported internal negative-slack violation. Positive internal timing is not complete board-interface timing closure.

### Resources and remaining capacity

| Fitted resource | Previous990199e | Opening build | Difference |
| --- | ---: | ---: | ---: |
| ALMs | 6,490 /41,910 (15%) | 6,655 /41,910 (16%) | +165 |
| Registers | 5,294 | 5,341 | +47 |
| Block-memory bits | 1,707,712 /5,662,720 (30%) | 4,165,312 /5,662,720 (74%) | +2,457,600 |
| RAM blocks | 215 /553 (39%) | 515 /553 (93%) | +300 |
| Pins | 91 /499 | 91 /499 | 0 |
| DSP blocks | 1 /112 | 1 /112 | 0 |
| PLLs | 1 /15 | 1 /15 | 0 |

The memory increase exactly equals the native307,200×8 opening image. It fits without clipping, palette reduction beyond the required RGB332 format, replacement artwork, duplicated alpha/font ROMs or gameplay changes. Logical-bit utilization alone understates the physical constraint: **only38 of553 RAM blocks remain**. Later full-screen result artwork will need sharing/replacement/compression or another deliberate memory strategy, not simply two more uncompressed full-screen ROMs. This phase does not implement that future work.

### Programming file and local handoff

The verified new outputs/reports were copied into the normal ignored `output_files/`. **`output_files/Lab1Demo.sof` now contains this opening-screen build**, not the previous gameplay-only build:

- Generated2026-10-16 13:51:22+03:00;6,690,369 bytes.
- SHA256: `FFEBF494F21CFEE29558E7A4136D8FF61F1C63931329E3A1CD21976F6F04A1D7`.
- Its bytes match the successful `db/phase3c_build/source/output_files/Lab1Demo.sof`.
- The old990199e programming file/reports remain under `db/phase3b2_build/source/output_files/`, old SOF SHA256 `9B76503632A1F78D4EA4B3D24C9E4E112BD023630A4C0BF20EA0D902C7694772`.
- Compilation caches, generated reports/programming files and simulator output remain ignored and excluded from Git. The requested local commit contains only this phase's14 source/test/asset/report files, with message `Add Jungle Temple opening screen and tutorial`. Unrelated QSF/SignalTap settings and `Lab1Demo.qws` are not staged or reverted. No push or programming.

Read-only staged-asset/report verification:

```text
python scripts/implement_opening_screen.py --git-index --build-results db/phase3c_build/source/output_files
```

## Reproduction and limitations

From the project root:

```text
python scripts/implement_opening_screen.py --fixtures --preview
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/opening_screen.do
python scripts/implement_final_hud.py --fixtures
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/hud_relics.do
python scripts/implement_v4_graphics.py --fixtures
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/jungle_implementation.do
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/arena_geometry.do
```

`--install` explicitly reproduces only the new menu MIF; omit it for read-only active-asset verification. All conversion input is retained in the repository, so Downloads/attachments are not runtime dependencies. Fixtures, simulator outputs and compiler snapshots remain ignored.

- No physical FPGA, PS/2 cable or monitor test. Decoder-boundary scan-code simulation is not validation of the imported KBDINTF QXP's serial receive internals.
- PNG previews use nominal RGB332 expansion, not the board's unusual existing DAC low-bit expansion. Fine details necessarily reduce at640×480/RGB332; native title, arrows, prompt and corrected tutorial were visually inspected, with no major composition loss.
- Functional tests use real MIFs and a registered-address ROM adapter, not a full vendor post-route simulation; Quartus separately checks the actual vendor ROM/netlist.
- Existing incomplete external-I/O constraints, stale clock/debug references, unassigned debug pins and historical audio/reset warnings are not repaired. Positive reported internal setup/hold does not establish complete board-level timing closure.
- Physical RAM occupancy is93%, with38 blocks free, and minimum hold slack is62ps. Those are explicit constraints for later work, despite this verified build passing all analyzed checks.
- Original result-screen artwork and its possible overlap with the HUD remain unchanged and are not redesigned here. No future result phase, artwork generation, push or FPGA programming is performed.
