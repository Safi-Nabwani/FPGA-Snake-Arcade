# FPGA Snake — Phase 2B.2: Vertical HUD and Relic Counters

Date: 2026-10-10, Asia/Jerusalem (work continued across midnight).
Workspace: `C:/Users/USER/Documents/Work/FPGA-Snake-Arcade`.
Starting revision: `ac9abfa` (`Expand Snake arena to 20x18 grid`); working tree initially clean.

Read first: `PROJECT_MAP.md`, `PRECHANGE_BASELINE.md`, and `ARENA_ENLARGEMENT.md`. The older geometry in the Phase 1 map is superseded by the Phase 2A specification and Phase 2B.1 implementation.

## 1. Scope and result

Implemented the functional vertical HUD and independent Ruby/Sapphire/Cursed totals, using the existing numeric font. Removed the old horizontal header renderer. No final Jungle Temple artwork or new MIF assets were generated.

The 20×18 arena, 24-pixel tiles, starting position, obstacles, spawn/exclusion map, gameplay, scoring rules, speed, length, audio and controls are preserved. Focused counter, real-font streaming-render and arena-regression tests pass. One Quartus build completes with zero compilation errors and lower memory use, but **timing verification fails: this fit introduces game-domain hold violations on unchanged snake-body registers**. The implementation is functionally tested, not timing-approved or hardware-approved. The requirement of no new timing issues is not satisfied by this build.

No FPGA was programmed. No commit or push was made. PLL, timing constraints, SignalTap and physical pin assignments were not edited.

## 2. Exact authored files

### Modified production files

| File | Change |
| --- | --- |
| `RTL/VGA/ScoreConstants.sv` | Move current score to (48,64), high score to (48,148). |
| `RTL/VGA/Score_Block.bdf` | Resize both digit rectangles to 32×32; extend the numeric-renderer symbol; add three counters and named pulse/BCD connections. External block ports remain unchanged. |
| `RTL/VGA/NumbersBitMap.sv` | Compact native-size score/high-score digits; share the original font ROM across all five numeric fields; add temporary sidebar background and labels with registered, ROM-aligned metadata. Correct score/high-score offset inputs to the existing 11-bit BDF width. |
| `RTL/VGA/back_ground_draw.sv` | Remove the obsolete top-header region, address logic and `top_background_rom`. Arena and wood rendering remain; all arena constants and tile-map rows are unchanged. |
| `Lab1Demo.qsf` | Add only the two new production SystemVerilog source entries below. |

### Created production files

| File | Role |
| --- | --- |
| `RTL/VGA/relic_collection_counters.sv` | Three independent, saturating, three-digit packed-BCD counters. |
| `RTL/VGA/hud_labels.sv` | Small procedural 5×7 uppercase label glyphs, doubled to 10×14 pixels; no image ROM. |

### Created verification/documentation files

| File | Role |
| --- | --- |
| `simulation/hud_font_rom_model.sv` | Test-only LPM ROM adapter loading all 8192 bits of the actual existing digit MIF. Not in QSF. |
| `simulation/hud_counters_tb.sv` | Counter/reset/score/high-score and real game-controller event tests. |
| `simulation/hud_render_tb.sv` | Full-frame streaming HUD, actual numeric font, original object mux and unchanged arena-coordinate checks. |
| `simulation/hud_relics.do` | ModelSim compilation and execution of both HUD testbenches, with success flags and nonzero failure exit. |
| `HUD_RELIC_COUNTERS.md` | This report. |

These are the twelve authored files. Quartus and ModelSim also produce/update build databases, reports, logs, work libraries and programming artifacts. Many such files were already tracked in the starting revision, so Git also shows generated-file changes; they are not additional intentional source/configuration edits. In particular, rerunning the existing arena test updates its log and work library without editing its test sources. Do not blindly revert all dirty files to distinguish authored changes from build output.

## 3. Geometry and appearance

All coordinates below are source-pixel rectangles with exclusive right/bottom bounds.

| Element | X range | Y range | Details |
| --- | --- | --- | --- |
| Temporary sidebar | [8,128) | [24,456) | 120×432; flat RGB332 `0x24` fill, `0x6D` two-pixel border; divider lines at Y=100 and 192. |
| SCORE label | [16,76) | [40,54) | White; character cells include a two-pixel gap. |
| Current score | [48,80) | [64,96) | Two native 16×32 digits; original white/gold score palette behavior. |
| HIGH label | [16,64) | [112,126) | First line of HIGH SCORE. |
| SCORE label | [16,76) | [128,142) | Second line of HIGH SCORE. |
| High score | [48,80) | [148,180) | Two native 16×32 digits; original high-score color. |
| RELICS label | [16,88) | [208,222) | White. |
| RUBY label | [16,64) | [240,254) | Temporary red `0xE0`. |
| Ruby count | [40,88) | [260,292) | Three native 16×32 digits, red; leading zeros. |
| SAPPHIRE label | [16,112) | [308,322) | Temporary blue `0x03`. |
| Sapphire count | [40,88) | [328,360) | Three digits, blue; leading zeros. |
| CURSED label | [16,88) | [376,390) | Temporary purple `0xA3`. |
| Cursed count | [40,88) | [396,428) | Three digits, purple; leading zeros. |
| Unchanged arena | [144,624) | [24,456) | 480×432; 20×18 cells; 24×24 each. |

Label boxes include the trailing character gap; painted glyph pixels occupy slightly less width. The sidebar ends 16 pixels before the arena. No HUD label, number or panel drawing request enters the arena. The current score/high score remain two-digit displays because their original accumulator/interface is preserved; only the new independent collection totals use three digits.

The old score rectangles at (164,12)/(548,12), their 2× enlarged font display and the horizontal top-header image are no longer rendered. `RTL/mifs/top_background_8bit.mif` is retained unchanged but is now unused by this renderer. No asset was deleted or replaced.

## 4. Counters, original score and reset semantics

`relic_collection_counters` contains three 12-bit packed-BCD registers (hundreds/tens/ones), 36 state bits total. Existing collection pulses map directly as follows:

| Existing event | New total | Existing score behavior, unchanged |
| --- | --- | --- |
| `redAppleHitPulse` | Ruby +1 | +1 |
| `blueAppleHitPulse` | Sapphire +1 | +3 |
| `blackAppleHitPulse` | Cursed +1 | −5, with the original zero floor/game-over handling |

- Asynchronous active-low hardware reset clears all three totals to `000`.
- `gameStartPulse` synchronously clears all three totals to `000`, taking priority over a coincident collection event.
- Otherwise, each asserted corresponding pulse increments its own total once. Independent events can update multiple totals on the same edge. Idle totals retain their values.
- Decimal carry is performed directly in BCD; no separate binary-to-decimal divider is needed for the new counters.
- **Overflow policy:** counts saturate at `999`. Further events leave `999` visible until the next new-game or hardware reset; there is no rollover.
- The existing game controller already emits one-clock collection events from overlap detection. No second edge detector was added, so valid adjacent-cycle events are not lost. The test also verifies that a held overlap causes only one collection before the controller's next-frame re-arm.
- There are no connections from these totals back into score, win/loss, snake length/speed or the modulo-five blue-spawn controller.

The original `appleCounter.sv`, `highscoreComp.sv`, `game_controller.sv` and `blue_apple_controller.sv` were not edited. Current score still resets on `gameStartPulse`. High score still updates on `gameEndPulse` only if the original score is greater, survives local restarts and clears only on hardware reset. The existing same-edge ordering on lethal Cursed collection is preserved: the high-score register sees the pre-penalty score at game end. The original win threshold remains 20.

## 5. Module and BDF integration

`TOP_VGA_DEMO.bdf` already routes all three collection pulses, game-start, clock/reset and raster coordinates into `Score_Block`. Its external interface therefore needs no changes. `objects_mux.sv` also needs no edits: the HUD reuses its original score/high-score layers and preserves the original priority (end message, head, body, score, high score, collectible, background).

Inside `Score_Block.bdf`:

1. Original accumulator `appleCounter:inst133` and `highscoreComp:inst1` retain all ports and wiring.
2. Original `ScoreConstants:inst2` supplies the new positions. Both existing `square_object` instances (`inst4`, `inst42`) have width and height changed from 64 to 32: four parameter edits, no square-object RTL edits.
3. `NumbersBitMap:inst500` gains raw `pixelX[10..0]`, `pixelY[10..0]` and the three `*CountBCD[11..0]` inputs. The embedded symbol outline/port list and named bus stubs are updated together. Its score/high-score offsets now have matching 11-bit formal HDL and schematic widths.
4. New `relic_collection_counters:inst600` receives the existing named clock/reset/game-start nets and branches of the same red/blue/black pulse nets feeding the original accumulator. Its three 12-bit outputs connect by identically named buses to `inst500`.
5. Existing `score_DR`, `score_RGB[7..0]`, `highScore_DR`, `highScore_RGB[7..0]` block outputs are reused. Panel/labels/relics are carried in the score layer, while high-score font pixels retain the high-score layer. These drawing requests are mutually exclusive where high-score pixels are present.

Quartus elaboration checks these actual BDF/HDL connections. Synthesis retains 36 counter registers and confirms just one 8192-bit numeric font ROM; labels use logic and no block memory.

### Rendering alignment and shared ROM

The original `numbers_new_font.mif` is unchanged. One original 8192×1 ROM services both score fields and all nine relic digits by selecting the appropriate digit for the current raster position. Its 13-bit address is `{digit[3:0], row[4:0], column[3:0]}` (digit×512 + row×16 + column).

Raw coordinates are registered once to align with the existing registered square-object offsets. Field identity, drawing request, label pixels and colors are then registered on the same edge as the font ROM address. This keeps the ROM bit and its metadata together for consecutive streaming pixels. The original object mux adds its existing registered output stage. Full-frame tests check these stage relationships; this is not a claim that all legacy graphic/collision pipelines or VGA sync timing have been reworked or hardware-validated.

## 6. Focused verification

ModelSim-Altera 10.5b completed the final HUD suite successfully, 00:09:53–00:09:59 local time. HDL compilation and both simulations reported **0 errors, 0 warnings**, with `HUD_COUNTERS_PASS` and `HUD_RENDER_PASS`. A work-library-already-exists notice is harmless. Runner setup was adjusted for this legacy simulator's finish/exit behavior so both tests run and failures do not report success.

### Counter and game-event checks

- Independent Ruby/Sapphire/Cursed increments and their distinct score effects; original score zero floor.
- Local-new-game reset, hardware reset, idle holding, reset priority over simultaneous events and high-score persistence/capture.
- 1005 consecutive event edges for all three totals; every value/carry through `999`, saturation above `999`, and valid decimal state.
- Independence from the existing modulo-five blue-spawn state.
- Actual game-controller held-overlap events and next-frame re-arm, Sapphire event, lethal Cursed event with original high-score ordering, local restart and win at score 20.

### Streaming renderer checks

- One new pixel per clock over all **307,200 visible pixels**, not just coordinates held for several cycles.
- Exact sidebar bounds, all five numeric field positions, actual font address/data, digit colors, high-score mask, panel/label metadata alignment, and the original mux register stage.
- Test values 23/19 and 012/345/678 exercise all decimal glyphs 0–9; separate 000/000/999 fields verify leading zeros and the saturation display.
- Nonempty labels/font and unchanged arena border, tile index and rock collision map. Label-pipeline checks sample the label module's own combinational glyph output; they are not an independent artwork/legibility oracle.

The test-only ROM adapter loads all 8192 actual MIF bits and emulates the registered-address/unregistered-data behavior used by the numeric renderer. Other background ROMs return constant data in this harness, so background-image colors and full-system visual timing are not validated. This adapter is necessary because the installed legacy LPM simulation model's lowercase parameter names do not match the production uppercase overrides. It is not registered in the QSF; synthesis uses the real vendor ROMs.

### Arena regression and preservation checks

The unchanged `simulation/arena_geometry.do` regression also passes, 00:10:26–00:10:28, **0 errors/0 warnings**, with `ARENA_GEOMETRY_PASS`: all visible pixel bounds, all 360 obstacle-map cells, 1024 candidate inputs per color, all-cell reachability, rejection/reroll feedback, head/body reset at (384,240), sprite addresses and four 24-pixel movement directions. Its original ROM fixture tests geometry, not image appearance.

A SHA-256 comparison of all 77 tracked starting source/configuration/documentation/asset files (excluding generated build outputs) finds only the five intentionally modified production files listed in section 2. All other starting files remain byte-identical, including both SDC copies, PLL/IP, SignalTap, pin assignments, TOP schematic, object mux, score/controllers, snake/apple geometry, every MIF and existing test sources. Arena bounds and all 18 tile-map rows match their prechange text. QSF differs only by the two new source assignments. Whitespace validation passes with the retained CRLF endings recognized.

To reproduce from the project root:

```powershell
& 'C:/intelFPGA_lite/17.0/modelsim_ase/win32aloem/vsim.exe' -c -modelsimini 'C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini' -l simulation/hud_relics.log -do simulation/hud_relics.do
& 'C:/intelFPGA_lite/17.0/modelsim_ase/win32aloem/vsim.exe' -c -modelsimini 'C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini' -l simulation/arena_geometry.log -do simulation/arena_geometry.do
```

On this host the simulator needs execution outside the restricted sandbox because of the previously documented Windows DLL-relocation issue; no installation settings were changed.

## 7. Quartus compilation and Phase 2B.1 comparison

Quartus Prime Lite 17.0.0 Build 595, revision `Lab1Demo`, top `TOP_VGA_DEMO`, Cyclone V `5CSXFC6D6F31C6`. Exactly one analysis/synthesis, fitter, timing-analysis and assembly sequence was run, 00:10:33–00:23:36 local time. No alternate seeds or repeated Quartus compilation attempts were made. Settings-writing was disabled for map/fit/assembly; timing used its supported `--do_report_timing` argument.

| Stage | Result | Errors | Phase 2B.1 warnings | Current warnings including critical | Current elapsed |
| --- | --- | ---: | ---: | ---: | --- |
| Analysis/synthesis | Successful | 0 | 218 | 186 (185 ordinary + 1 critical) | 2 min 41 sec |
| Fitter | Successful | 0 | 80 | 80 (77 ordinary + 3 critical) | 8 min 19 sec |
| TimeQuest | Execution successful; timing NOT met | 0 | 44 | 45 (39 ordinary + 6 critical) | 34 sec |
| Assembler | Successful; SOF generated, NOT programmed | 0 | 0 | 0 | 30 sec |

### Resources

| Resource | Phase 2B.1 | Current HUD/counters | Change |
| --- | ---: | ---: | ---: |
| ALMs | 6,563 / 41,910 (16%) | 6,625 / 41,910 (16%) | +62 |
| Registers | 5,665 | 5,767 | +102 |
| I/O pins | 91 / 499 (18%) | 91 / 499 (18%) | 0 |
| Block memory bits | 1,392,128 / 5,662,720 (25%) | 941,568 / 5,662,720 (17%) | −450,560 |
| RAM blocks | 176 / 553 (32%) | 120 / 553 (22%) | −56 |
| DSP blocks | 1 / 112 | 1 / 112 | 0 |
| PLLs | 1 / 15 | 1 / 15 | 0 |

The memory reduction is exactly the retired 640×88×8-bit horizontal header. Adding three counters and labels does not duplicate the numeric ROM or add physical ports.

### Timing comparison, nanoseconds

| Corner | Phase 2B.1 game setup | Current game setup | Phase 2B.1 game hold | Current game hold | Phase 2B.1 JTAG hold | Current JTAG hold |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Slow 85°C | +11.204 | +5.827 | +0.120 | **−0.125** | +0.016 | +0.102 |
| Slow 0°C | +11.497 | +4.925 | +0.108 | **−0.146** | −0.017 | +0.075 |
| Fast 85°C | +18.838 | +18.303 | +0.109 | **−0.050** | −0.060 | −0.011 |
| Fast 0°C | +20.196 | +19.087 | +0.084 | **−0.062** | −0.074 | −0.024 |

**New findings, not baseline-only warnings:**

- The game clock now has negative hold slack at all four analyzed corners. The reported worst path is `Snake_Block:inst13|snake_body:inst6|trailX[89][8]` → `trailX[90][8]`, clocked by the unchanged 31.5 MHz PLL output. Worst hold is **−0.146 ns**, game-domain TNS **−0.287 ns** at slow 0°C. That path had no game-domain hold failure in Phase 2B.1. The snake-body RTL is byte-identical, but the changed whole-design placement/routing exposes a hold regression; unchanged source does not make it acceptable or a previously documented baseline failure.
- The detailed worst-hold report shows data arrival 6.858 ns versus required 7.004 ns after clock-pessimism removal. This is a short register-to-register path/clock-skew issue, not an arithmetic setup delay in the new counters. It still requires timing repair and re-verification.
- Setup remains positive at all corners, but its margin is lower. The slow-corner critical setup path is now HUD `NumbersBitMap:inst500|pixelXD[7]` → `labelD`. Worst game setup is +4.925 ns. Slow-85°C game Fmax is **38.58 MHz**, versus 48.68 MHz in Phase 2B.1; slow-0°C Fmax is 37.28 MHz. Both exceed the actual unchanged 31.5 MHz clock, but positive setup does not compensate for failed hold timing.
- Timing warning 332148 rises from three to four failing-corner reports; it is not a new warning ID, but its game-domain failure is new. No new hard compilation errors or other new warning categories appeared.

**Known problems still present:**

- JTAG/debug hold still fails at the fast corners, worst −0.024 ns. The reported path is now SignalTap `ram_data_shift_out|dffs[0]` → `info_data_shift_out|dffs[26]`, not the Phase 2B.1 hub identity path. Different fitted debug results are not a repair or timing sign-off.
- Constraint coverage: 0 unconstrained clocks; 5 input ports / 120 input paths; 55 output ports / 327 output paths. Output-path count falls from 431 because logic changes/optimization remove paths, not because constraints were fixed. External-interface timing remains unproven.
- Missing/ignored SDC targets, JTAG clock overwrite, five audio-related combinational loops, incomplete/stale I/O assignments and invalid fitter assignments remain. Fitter warning IDs/counts match Phase 2B.1 exactly.
- Synthesis warning 12001 drops **20→0** after matching the existing score-offset bus widths; truncation 10230 drops **46→42**; vendor-ROM conversion 13049 drops **113→105** when the header ROM is removed. Other synthesis counts remain: 35025×1 critical; 10270×1, 13004×1, 13024×1, 13046×1, 13310×5 and 13410×29. No warnings reference the new counter/label logic.
- SignalTap remains partially connected, **39/40**, with stale `obstacles:inst1|obstacle_DR` still missing. SignalTap assignments were not changed.
- Nine debug outputs still have automatic, unverified locations. This fit assigns BG_RGB[0] AF24, [1] AC18, [2] AE28, [3] AG25, [4] AE27, [5] AE26, [6] AA24, [7] AA16 and borderDR AC29 (2.5 V). Pin configuration was not edited; automatic fitted locations changed. These are not approved safe university-board assignments.

### Required follow-up before timing approval

The existing configuration explicitly disables hold optimization in **both** `Lab1Demo.qsf` (line 62) and sourced `constraints/pin.tcl` (line 27), and uses `FAST_FIT`. This is a concrete configuration issue to review in a separately approved timing-repair pass. Enabling appropriate hold optimization and reviewing fitter effort is a plausible next step, **not a verified fix**; both sources of the setting must be considered. No such setting was changed here, no geometry workaround was made, and no timing constraint was relaxed to hide the regression. One further fit/STA pass would be necessary after an approved repair. Small procedural-label logic could also be simplified later to recover setup margin without duplicating large image ROMs, but setup currently passes and that optimization was not attempted after this build.

Evidence: [HUD tests](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/simulation/hud_relics.log), [arena regression](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/simulation/arena_geometry.log), [synthesis](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.map.rpt), [fitter summary](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.fit.summary), [fitter report](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.fit.rpt), [timing summary](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.sta.summary), [timing paths](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.sta.rpt), [assembly](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.asm.rpt). The output files now describe this HUD build, not the earlier arena build; the comparisons above preserve the previous reported measurements.

## 8. Remaining issues before Phase 3

- Final Jungle Temple/Temple of the Serpent artwork, stone-carved labels, relic sprite replacement and consistent apple-to-relic internal renaming are deferred. Temporary labels/panel are functional, not final art. Existing MIFs and the reference image were not modified.
- The existing highest-priority win/loss panel remains at X [40,600), Y [190,280). It can obscure the RELICS heading and upper Ruby area after game end. This is a pre-existing end-message overlay, not a HUD-to-arena overlap; changing its placement/priority or artwork was not included. Full end-screen integration belongs to Phase 3.
- **Resolve the new game-domain hold regression before claiming Phase 2B.2 timing verification passed or programming this build.** Review the explicitly disabled hold optimization in a separately approved repair pass, then re-fit/re-analyze; preserve arena geometry and gameplay.
- Existing incomplete I/O/timing constraints, unsafe automatic debug-output locations, JTAG/SignalTap hold problems, missing debug probe, audio loops/reset/latch warnings, missing PLL simulation netlist and stale absolute-path VWF workflow also need separately approved repairs. A generated SOF is not approval to program the university board.
- The original VGA timing/off-by-one assumptions and mixed non-HUD rendering/collision latencies are unchanged. The original head square still clips a 24×24 ROM to 22×24. Focused HUD alignment tests and compilation are not complete display/board validation.
- No physical FPGA/monitor test was performed, and no hardware functionality is claimed.

**Phase 2B.2 implementation and reporting are finished; functional tests pass, but timing approval is blocked by the new hold regression. Stop and wait for approval for the next scoped action. Do not start Phase 3 or program the FPGA automatically.**
