# FPGA Snake — Phase 2B.3: Hold-Timing Regression Repair

Date: 2026-10-10, Asia/Jerusalem.
Workspace: `C:/Users/USER/Documents/Work/FPGA-Snake-Arcade`.
Starting commit: `3c3678a` (`Add vertical HUD and relic collection counters`); working tree initially clean.

Read before changes: `PROJECT_MAP.md`, `PRECHANGE_BASELINE.md`, `ARENA_ENLARGEMENT.md`, `HUD_RELIC_COUNTERS.md`. Their older geometry/build descriptions are historical; the implemented 20×18 arena and vertical HUD are authoritative for this phase.

## 1. Result

**The snake-body hold regression is repaired and verified.** One post-repair Quartus build completes with zero compilation errors. All reported constrained setup/hold/recovery/removal/minimum-pulse-width checks pass at all four analyzed corners; no new analyzed timing violation was introduced. Worst game hold changes from −0.146 ns to **+0.163 ns**, and worst game setup improves from +4.925 ns to **+4.943 ns**. The earlier JTAG/SignalTap hold failures are also cleared by the same native fitter setting (worst JTAG hold now +0.028 ns).

Focused functional tests pass. No RTL, BDF, artwork, PLL or SDC changes were made. Incomplete external timing constraints and unsafe automatic debug pin assignments remain, so this is **not full board-level timing/sign-off or approval to program the FPGA**.

## 2. Exact original failing path

| Item | Phase 2B.2 evidence |
| --- | --- |
| Source register | `Snake_Block:inst13\|snake_body:inst6\|trailX[89][8]` |
| Destination register | `Snake_Block:inst13\|snake_body:inst6\|trailX[90][8]` |
| Launch and latch clock | `inst7\|clk_31p5_inst\|altera_pll_i\|general[0].gpll~PLL_OUTPUT_COUNTER\|divclk` |
| Clock frequency / period | 31.5 MHz / 31.746 ns; same rising-edge game clock |
| Worst corner | Slow, 1100 mV, 0°C |
| Hold slack / game-domain TNS | −0.146 ns / −0.287 ns |
| Data arrival | 6.858 ns |
| Data required | 7.004 ns after clock-pessimism removal |

This is a real shift-register connection: on a running frame update, `trailX[i] <= trailX[i-1]`. These are history positions, not new HUD or relic-count registers.

The original detailed path has:

- Launch clock network delay: 6.502 ns.
- Minimum data path after launch: 0.250 ns interconnect + 0.046 ns cell + 0.060 ns destination input = **0.356 ns**.
- Destination clock network delay: 7.771 ns; clock-pessimism removal: −0.767 ns; required time: **7.004 ns**.
- Effective destination-versus-source clock offset: 7.004 − 6.502 = **0.502 ns**. The 0.356 ns data path is too short by **0.146 ns**.

Lowering clock frequency or applying a multicycle setup allowance would not legitimately repair this same-edge minimum-delay failure.

## 3. Root cause and Phase 2B.1 comparison

`git diff ac9abfa 3c3678a` confirms that `snake_body.sv`, `Snake_Block.bdf`, PLL implementation and both SDC files did not change in the HUD phase. The QSF's HUD changes only added sources; its hold setting stayed OFF. The source still uses the same frame-enable and trail shift behavior.

| Corner | Phase 2B.1 game hold | Phase 2B.2 game hold |
| --- | ---: | ---: |
| Slow 85°C | +0.120 ns | −0.125 ns |
| Slow 0°C | +0.108 ns | −0.146 ns |
| Fast 85°C | +0.109 ns | −0.050 ns |
| Fast 0°C | +0.084 ns | −0.062 ns |

Phase 2B.1 has no reported constrained game-clock hold failures. Its retained report gives the worst game-domain paths, not an individual slack for this exact trail-register pair. The earlier −0.074 ns overall hold failure was in JTAG/debug, not the game domain. The original Phase 2A baseline similarly had JTAG/SignalTap hold failures (worst −0.105 ns).

**Diagnosis:** this regression is a physical minimum-data-delay versus clock-skew failure after the changed whole-design fit, not a changed snake-body algorithm or relaxed/new timing constraint. The HUD phase changed the synthesized resource footprint, including removal of 56 header RAM blocks, so unchanged game registers need not retain their old placement/routing. The detailed path demonstrates the insufficient physical data delay. Which individual HUD edit triggered the new packing/placement was not isolated through alternate builds, and is not required to justify fitter hold repair.

The configuration explicitly disabled the tool's hold repair in both `Lab1Demo.qsf` and the QSF-listed `constraints/pin.tcl`. This allowed the physical hold failure to remain uncorrected. OFF alone was not assumed to guarantee the cause/fix; the post-repair fit and timing results below are the verification.

## 4. Smallest repair and exact authored files

| File | Exact change |
| --- | --- |
| `Lab1Demo.qsf`, line 62 | `OPTIMIZE_HOLD_TIMING OFF` → `OPTIMIZE_HOLD_TIMING "All Paths"`. |
| `constraints/pin.tcl`, line 27 | Same one-line setting correction, so the listed Tcl settings cannot reintroduce OFF in related workflows. |
| `TIMING_REPAIR.md` | New report; no other authored file. |

The installed Quartus 17.0 `C:/intelFPGA_lite/17.0/quartus/bin64/assignment_defaults.qdf`, line 395, specifies **"All Paths" as the Cyclone V default**. This restores the native physical hold optimizer for internal register paths; an I/O-only setting would not address this trail connection.

This is a fitter-optimization setting, not a global timing-model/clock-constraint change. It permits legitimate physical hold repair while the original setup/hold requirements remain in force. The setting also covers existing JTAG paths as a consequence; no separate debug redesign/constraint cleanup was added.

`FAST_FIT`, physical-synthesis options, clock frequencies, SDC files, timing exceptions, pin assignments and SignalTap configuration are unchanged. No false path, artificial minimum delay, relaxed clock, seed search, RTL delay chain, extra register or movement-cycle change was introduced. All gameplay, 20×18 geometry, HUD and counter RTL/BDF/MIF sources are unchanged.

Quartus/ModelSim regenerate tracked reports, databases, work libraries, logs and programming artifacts as normal. Those are tool-generated changes, not additional authored repairs, and are excluded from the intended local source/report commit.

## 5. Functional verification

Reused the existing ModelSim-Altera 10.5b tests without editing them:

- `simulation/hud_relics.do`, 00:31:01–00:31:10: **HUD_COUNTERS_PASS** and **HUD_RENDER_PASS**. HDL compilation and both tests: zero errors, zero warnings; only the existing work-library notice. Covers independent collection counts, BCD carry/saturation through 999, new-game reset, high-score persistence, actual game-controller event ordering, leading-zero displays, all 307,200 streaming visible pixels, real numeric MIF data and HUD/mux alignment.
- `simulation/arena_geometry.do`, 00:31:33–00:31:36: **ARENA_GEOMETRY_PASS**, zero HDL/simulation errors or warnings; existing library notice only. Covers arena/obstacle bounds, all 360 cells, spawn validation/reachability/reroll feedback, head/body reset at (384,240), sprite addresses and four 24-pixel movement directions.

The HUD harness loads the actual numeric font but uses constant background image ROM data; the arena harness is geometry-only. These are focused RTL checks, not a full-system or post-fit gate-level timing simulation. Physical hold closure is established, if successful, by the unchanged-model post-fit TimeQuest analysis, not by zero-delay RTL simulation.

A starting SHA-256 snapshot covers 84 tracked non-generated files. The final post-build comparison finds exactly the two one-line settings changes listed above; every other starting source/configuration/asset/test/report is byte-identical. The two diffs also confirm every physical pin assignment is unchanged inside `constraints/pin.tcl` and the QSF. Whitespace checks pass with existing CRLF line endings recognized. No FPGA/monitor test was performed; no physical hardware functionality is claimed.

## 6. One Quartus build and before/after results

Quartus Prime Lite 17.0.0 Build 595; revision `Lab1Demo`; top `TOP_VGA_DEMO`; Cyclone V `5CSXFC6D6F31C6`. Exactly one map/fit/STA/assembly sequence was run, 00:30:43–00:44:35 local time. No repeated compilation, alternate seed or additional repair attempt was needed. Settings-writing was disabled for map/fit/assembly; TimeQuest used `--do_report_timing`.

| Stage | Result | Errors | Phase 2B.2 warnings | Repaired warnings including critical | Elapsed |
| --- | --- | ---: | ---: | ---: | --- |
| Analysis/synthesis | Successful | 0 | 186 | 186 (185 ordinary + 1 critical) | 1 min 52 sec |
| Fitter | Successful | 0 | 80 | 80 (77 ordinary + 3 critical) | 10 min 41 sec |
| TimeQuest | Execution successful; analyzed timing passes | 0 | 45 | 41 (39 ordinary + 2 critical) | 25 sec |
| Assembler | Successful; SOF generated, NOT programmed | 0 | 0 | 0 | 13 sec |

The fitter report confirms the **effective Optimize Hold Timing value is All Paths**. Its Estimated Delay Added for Hold Timing Summary records 397.2 ns summed across optimized game-clock paths and 335.9 ns summed across JTAG paths. These are aggregate physical-delay estimates across paths, not single-path delays or added clock cycles. This verifies that real physical hold optimization was performed, not merely a different warning label or an added exception.

### Setup and hold, nanoseconds

| Corner | Game setup before | Game setup after | Game hold before | Game hold after | JTAG hold before | JTAG hold after |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Slow 1100 mV, 85°C | +5.827 | +6.116 | −0.125 | +0.304 | +0.102 | +0.154 |
| Slow 1100 mV, 0°C | +4.925 | +4.943 | −0.146 | +0.287 | +0.075 | +0.140 |
| Fast 1100 mV, 85°C | +18.303 | +18.704 | −0.050 | +0.177 | −0.011 | +0.041 |
| Fast 1100 mV, 0°C | +19.087 | +19.326 | −0.062 | +0.163 | −0.024 | +0.028 |

All game setup margins improve, and no hold TNS remains in either domain (all are 0.000 ns). JTAG setup is unchanged: +10.807 / +10.882 / +12.888 / +13.011 ns at the four listed corners.

The new reported worst game hold path is `snake_body:inst6|trailY[145][4]` → `trailY[146][4]`. At slow 0°C it has arrival 6.888 ns versus required 6.601 ns, slack +0.287 ns; its fast-0°C result is the game minimum +0.163 ns. The old X[89]→X[90] pair is no longer the reported worst path. The default report extracts the single worst path for each domain/corner, not a separate exact post-repair slack for every historical pair; the positive domain minima establish no constrained game-path hold failures under the unchanged timing model.

Worst analyzed recovery/removal/minimum-pulse-width slacks are +37.257 / +0.317 / +0.793 ns, respectively. All setup, hold, recovery, removal and minimum-pulse-width TNS values in the summary are zero. No 332148 failed-timing warning remains; no new warning ID appeared.

Slow-85°C game Fmax improves **38.58→39.02 MHz**; slow-0°C improves **37.28→37.31 MHz**. Actual game clock remains 31.5 MHz; JTAG remains 25 MHz. Clocks and requirements were not relaxed.

### FPGA resources

| Resource | Phase 2B.2 | Repaired | Change |
| --- | ---: | ---: | ---: |
| ALMs | 6,625 / 41,910 (16%) | 6,611 / 41,910 (16%) | −14 |
| Registers | 5,767 | 5,770 | +3 |
| I/O pins | 91 / 499 (18%) | 91 / 499 (18%) | 0 |
| Block memory bits | 941,568 / 5,662,720 (17%) | 941,568 / 5,662,720 (17%) | 0 |
| RAM blocks | 120 / 553 (22%) | 120 / 553 (22%) | 0 |
| DSP blocks | 1 / 112 | 1 / 112 | 0 |
| PLLs | 1 / 15 | 1 / 15 | 0 |

These are post-fit figures. Synthesis implements the same 12,621 resources as the HUD build; source/state logic is unchanged. The fitter report records router logic/register duplication and different packing, so the fitted count variation is not three added gameplay cycles or new RTL state.

### Warning comparison

- The four 332148 failed-corner critical warnings are removed: timing total **45→41**, critical total **6→2**.
- Map and fitter warning IDs/counts match Phase 2B.2 exactly. Map: 35025×1 critical; 10230×42, 10270×1, 13004×1, 13024×1, 13046×1, 13049×105, 13310×5, 13410×29. Fitter: 169085×1 and 332049×2 critical; 15705×1, 15706×35, 15714×1, 171167×1, 332043×1, 332049×19, 332174×18, 335093×1. Remaining STA: 332049×2 critical; 332043×1, 332049×19, 332174×18, 335093×1.
- The two remaining timing critical warnings are stale generated-clock target collections, **not failed setup/hold checks**. They remain documented limitations and were not suppressed.

Evidence: [functional HUD tests](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/simulation/hud_relics.log), [arena regression](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/simulation/arena_geometry.log), [synthesis](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.map.rpt), [fitter summary](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.fit.summary), [fitter settings and delay estimates](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.fit.rpt), [timing summary](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.sta.summary), [timing paths](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.sta.rpt), [assembly](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.asm.rpt). Current outputs describe this repaired fit; Phase 2B.2 measurements remain in `HUD_RELIC_COUNTERS.md` and starting commit `3c3678a`.

## 7. Remaining concerns and stop point

- **Not fully constrained externally:** 0 unconstrained clocks, 5 input ports / 120 input paths, 55 output ports / 336 output paths. The HUD build had 327 output paths; there are nine more unconstrained paths, but no extra unconstrained ports. This fitted-path-count difference is not a constraints repair and external VGA/audio/PS2 timing remains unproven. Root SDC template warnings and the JTAG clock overwrite remain.
- **Unsafe automatic debug pins remain:** BG_RGB[0] AK12, [1] AK14, [2] AH15, [3] W15, [4] AJ14, [5] Y16, [6] AJ12, [7] AG15 and borderDR C13 (2.5 V) are automatically placed and not verified safe on the university board. Explicit pin assignments were not changed; physical automatic locations vary between fits. Do not program this SOF before a separately approved pin/interface audit.
- SignalTap still connects 39/40 required sources; the stale obstacle probe remains. Stale/ignored pin assignments, five audio-related loops/latch/reset emulation warnings, missing PLL simulation netlist and old absolute-path VWF setup remain unmodified.
- Existing VGA refresh/off-by-one and non-HUD pipeline issues, 22×24 head clipping, and legacy end-message overlap remain outside this timing-repair scope. No Jungle Temple assets or later-phase work was started.
- All analyzed hold violations, including the earlier JTAG ones, are cleared in this fit. Future source/artwork changes still require a fresh timing check; the small +0.028 ns JTAG margin is a measured result, not a guarantee for later fits.

## 8. Local commit and stop

Functional verification and the single compilation/timing pass succeed, meeting the condition for the authorized local commit. Only `Lab1Demo.qsf`, `constraints/pin.tcl` and this report are to be committed with message **`Fix snake-body hold timing regression`**. Tool-generated reports/databases/logs/programming output remain unstaged; they were not deleted or swept into the repair commit. The resulting commit hash is provided in the session handoff.

Initial staging was blocked by an empty `.git/index.lock`, last written at 00:32:05 and still present at 00:47. No Git process was active, and an exclusive read handle confirmed the lock was not open. The empty stale lock was preserved, not deleted, as `.git/index.lock.stale-20261010-0047`; staging then succeeded. This is recoverable local Git metadata housekeeping, not a source change or a file in the repair commit.

No push or FPGA programming is performed. **Phase 2B.3 complete. Stop here and wait for approval for another phase.**
