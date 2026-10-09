# FPGA Snake — Phase 2A Prechange Baseline

Date: 2026-10-09, Asia/Jerusalem. Scope: original-project tool verification and one compilation pass, with no redesign or source/configuration edits.

Workspace: `C:/Users/USER/Documents/Work/FPGA-Snake-Arcade`.
Revision: `Lab1Demo`; top: `TOP_VGA_DEMO`; device: `5CSXFC6D6F31C6` (Cyclone V).
Git baseline: `eabf54636d56b7bec2a31b19b3be52e274e13ef0`.

## 1. Result

**The original project compiles and produces a programming file, but it does not meet all timing requirements and is not fully constrained.**

- Analysis/synthesis, fitting, timing-analysis execution, and assembly all completed with zero design errors.
- The worst constrained hold slack is **−0.105 ns**, in the SignalTap/JTAG clock domain. TimeQuest explicitly reports timing requirements not met.
- Five input ports and 55 output ports lack setup/hold constraints. Positive internal setup slack therefore does not establish full board-level timing closure.
- Nine physical outputs have no explicit location assignment. Do not treat the generated programming file as approved for university hardware.
- Quartus 17.0 runs with this target and sources, including the two QXP partitions and the newer PLL wrapper. ModelSim 10.5b starts normally outside the restricted execution environment; no gameplay simulation was run.
- All **72 pre-existing workspace files** included in the initial SHA-256 snapshot remained byte-for-byte unchanged after compilation. This includes RTL, BDF, MIF, QSF, QPF, SDC, IP manifests, imported partitions, waveforms, the project map, and the existing reference image.

This phase created this report and normal compiler-generated artifacts. No board programming, HDL/configuration repair, graphics generation, module renaming, commit, or push occurred.

## 2. Authoritative future redesign specification

The following specification supersedes the older 18×11/32-pixel proposal in `PROJECT_MAP.md`. It was recorded here but **not implemented**:

| Item | Finalized specification |
| --- | --- |
| Theme | Jungle Temple — Temple of the Serpent |
| VGA image | 640×480 |
| Arena | 20 columns × 18 rows |
| Cell size | 24×24 pixels |
| Arena origin | `(144,24)` |
| Arena extent | 480×432 pixels; half-open bounds X `[144,624)`, Y `[24,456)` |
| HUD | Vertical left HUD: Score, High Score, three independent relic counters |
| Collectibles | Ruby, Sapphire, Cursed relics replacing red, blue, black apples |
| Counter reset | All three relic counters reset on every new game |
| Rules | Preserve original gameplay and scoring behavior |

The compiled baseline is still the original 16×16 arena at `(128,88)`, with the original top HUD and apple artwork. `jungle-temple-reference.png` now exists in the project root (2,522,424 bytes), unlike during Phase 1. It was already present when this phase began and was preserved. `PROJECT_MAP.md` was read, not updated; its old proposed geometry and image-absence statement are historical, not current design instructions.

## 3. Installed tools and compatibility evidence

| Tool / dependency | Finding |
| --- | --- |
| Quartus Prime | **17.0.0 Build 595, 04/25/2017, SJ Lite Edition**. Executables at `C:/intelFPGA_lite/17.0/quartus/bin64`. Version query and actual synthesis/fitter/assembler runs passed. Quartus executables were not found through the initial PATH lookup; explicit installed paths were used. |
| Device support | Cyclone V database is installed under the Quartus 17.0 `common/devinfo/cyclonev` directory. Fitter explicitly selected `5CSXFC6D6F31C6` and completed placement/routing. |
| ModelSim | `C:/intelFPGA_lite/17.0/modelsim_ase/win32aloem/vsim.exe`; version **ModelSim ALTERA STARTER EDITION 10.5b, Simulator 2016.10, Oct 5 2016**. PATH resolves `vsim` and `vlog` into this installation. |
| ModelSim startup | Initial sandboxed `vsim -version` failed before startup with Windows “Illegal System DLL Relocation.” Repeating the version query outside the sandbox succeeded. A console startup/quit test outside the sandbox also returned exit code 0. This is not evidence that ModelSim needs reinstalling. |
| Simulation libraries | Installed `modelsim.ini` maps the waveform-required `cyclonev_ver`, `altera_ver`, `altera_mf_ver`, `220model_ver`, `sgate_ver`, and `altera_lnsim_ver` names to bundled directories. Their corresponding library directories are present. Functional netlist loading and game simulation were not exercised. |
| PLL IP version | Wrapper/QIP metadata records 20.1 while project records 17.0. The 17.0 synthesis run accepted and elaborated the PLL. The mismatch is not an observed synthesis blocker. Simulation remains limited by its missing generated `.vo` model. |
| Imported keyboard/audio partitions | `KBDINTF.qxp` and `audio_codec_controller.QXP` imported/elaborated sufficiently for the original project to synthesize and fit. Their source RTL remains unavailable in this repository. |
| Other installation directory | `C:/intelFPGA/20.1` exists, but the inspected directory contains a transcript rather than a runnable Quartus installation at the expected `quartus/bin64` path. No 20.1 compiler was used. |

Conclusion: the locally available Quartus 17.0 is demonstrably usable for this baseline. The bundled ModelSim launches and has appropriate library mappings, but **end-to-end simulation compatibility is not yet verified** because the existing simulation setup is not reproducible from this checkout alone.

No installation, upgrade, library regeneration, simulator configuration edit, or download was performed.

## 4. Compilation procedure and results

One analysis/synthesis run and one fitter run were performed on the original revision, without disabling SignalTap or changing pin/timing settings. Compiler settings-file exports were explicitly disabled for synthesis, fitting, and assembly.

Commands used, with the executable directory shown above:

```text
quartus_map Lab1Demo -c Lab1Demo --read_settings_files=on --write_settings_files=off
quartus_fit Lab1Demo -c Lab1Demo --read_settings_files=on --write_settings_files=off
quartus_sta Lab1Demo -c Lab1Demo --do_report_timing
quartus_asm Lab1Demo -c Lab1Demo --read_settings_files=on --write_settings_files=off
```

TimeQuest 17.0 does not accept the map/fitter `--read_settings_files` / `--write_settings_files` switches. An initial invocation rejected `--read_settings_files` with command-line error 23024 before timing analysis began. Local help was checked, and the supported invocation above was then used. This was a corrected command invocation, not a second compilation or a source repair. SHA-256 verification confirmed that TimeQuest did not alter project configuration.

| Stage | Result | Errors | Warning messages* | Console elapsed time |
| --- | --- | --- | --- | --- |
| Analysis & synthesis | Successful | 0 | 218 | 1 min 16 sec |
| Fitting | Successful | 0 | 80 | 5 min 5 sec |
| TimeQuest | Execution successful; timing requirements **not met** | 0 | 45 | 15 sec |
| Assembly | Successful | 0 | 0 | 16 sec |

*Quartus console totals include critical warnings. The report census is: synthesis 217 ordinary + 1 critical; fitter 77 ordinary + 3 critical; timing 39 ordinary + 6 critical. Similar constraint warnings appear in more than one stage; summing these totals does not give a count of unique problems.

Compilation ran approximately 17:52:40–18:00:36 local time, including inspection between stages. No repeated fitter/synthesis attempts or alternate-source builds were performed.

Generated [Lab1Demo.sof](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.sof): **6,695,886 bytes**, assembled at 18:00:36. It was **not programmed onto the board**.

## 5. Post-fit FPGA resource baseline

These are actual fitter results for the original source with embedded SignalTap still enabled, not estimates for the new arena or artwork.

| Resource | Used | Device total | Reported utilization |
| --- | ---: | ---: | ---: |
| Logic utilization, ALMs | 6,407 | 41,910 | 15% |
| Registers | 5,625 | — | — |
| I/O pins | 91 | 499 | 18% |
| Block memory bits | 1,392,128 | 5,662,720 | 25% |
| RAM blocks | 176 | 553 | 32% |
| DSP blocks | 1 | 112 | <1% |
| PLLs | 1 | 15 | 7% |
| Virtual pins, HSSI resources, DLLs | 0 | — | 0 used |

Synthesis estimated 6,423 ALMs and 5,394 registers; post-fit figures above are authoritative for this run. Memory-bit utilization and RAM-block utilization differ because block allocation/packing is not equivalent to payload-bit usage.

The existing design has substantial nominal resource headroom, but this does not guarantee the redesigned assets, HUD or counters will fit or meet timing. Preserving 24×24 sprites avoids an automatic sprite-depth increase, whereas new HUD/artwork choices and added counters still require a later resource budget and build.

Source: [Lab1Demo.fit.summary](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.fit.summary), [Lab1Demo.fit.rpt](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.fit.rpt).

## 6. Timing results and limits

### Actual constrained clocks

TimeQuest recognized `CLOCK_50` at 50 MHz, the PLL output at **31.5 MHz / 31.746 ns**, an internal PLL VCO clock at 630 MHz, and `altera_reserved_tck` at **25 MHz / 40 ns**. Automatic PLL derivation worked; the stale manual generated-clock declarations did not replace it with a valid alternative.

The legacy VGA source remains approximately 72.58 frames/s by its counter arithmetic (833×521 periods at 31.5 MHz). Resolution and refresh rate are separate: this compile does not change the VGA counter off-by-one or make the original raster a verified 60 Hz mode.

### Per-corner margins, nanoseconds

| Timing corner | PLL/game clock setup | PLL/game clock hold | JTAG/debug hold |
| --- | ---: | ---: | ---: |
| Slow, 1100 mV, 85°C | +9.913 | +0.199 | **−0.066** |
| Slow, 1100 mV, 0°C | +10.160 | +0.160 | **−0.077** |
| Fast, 1100 mV, 85°C | +18.595 | +0.120 | **−0.090** |
| Fast, 1100 mV, 0°C | +19.907 | +0.097 | **−0.105** |

Design-wide worst setup slack is +9.913 ns; worst hold slack is −0.105 ns, with hold TNS −1.877 ns at the fast 0°C corner. Worst recovery/removal/minimum-pulse-width slacks are +37.753 / +0.140 / +0.793 ns, respectively, on the paths that were analyzed.

The worst hold path is inside `auto_signaltap_0`: from the offload manager's read-pointer counter bit 11 to the SignalTap buffer RAM port-B address register 11. Both launch and latch clocks are `altera_reserved_tck`. This is an observed debug-fabric hold violation, not an observed gameplay setup failure.

Slow 85°C Fmax report: **45.8 MHz** for the PLL/game domain and 54.39 MHz for JTAG. Fmax considers same-clock paths and does not prove hold closure or external I/O timing. Do not substitute Fmax for a complete sign-off.

### Constraint coverage

TimeQuest reports zero unconstrained clocks, but:

- **5 unconstrained input ports**, representing 120 input-port paths: `AUDIN[1]`, `AUDIN[2]`, `KEY[3]`, `PS2_CLK`, `PS2_DAT`.
- **55 unconstrained output ports**, representing 430 output-port paths.
- Design is not fully constrained for either setup or hold requirements.
- Five combinational loops are analyzed as latches, associated with the audio timer's synthesized reset emulation.

Asynchronous buttons/PS2 inputs may need appropriate synchronizer/exception treatment rather than arbitrary synchronous I/O delays; audio and VGA outputs need constraints matching their real interfaces. The correct fixes require an intentional timing model, not blanket exceptions just to remove warnings.

Sources: [Lab1Demo.sta.summary](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.sta.summary), [Lab1Demo.sta.rpt](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.sta.rpt).

## 7. Important errors/warnings and configuration findings

No hard HDL, missing synthesis-source, target-device, fitting-capacity or assembly error was observed. The following issues prevent calling this a clean, reproducible, hardware-ready baseline.

### Debug configuration

Synthesis critical warning **35025** reports only 37 of 40 required debug connections, with three missing sources/connections. The map report identifies:

1. `game_controller:inst22|collision~0` as the post-fit trigger source.
2. The same name as a post-fit data source.
3. `obstacles:inst1|obstacle_DR` as a post-fit data source.

The map connection table marks these missing at synthesis and substitutes GND. The collision references are tied to post-fit naming/netlist selection; the separate `obstacles` hierarchy is absent from the present design. Compilation completion does not prove that all intended debug probes are meaningful. These references must be reviewed/rebound or the obsolete debug configuration intentionally removed in a later approved phase.

**Correction to Phase 1's uncertainty:** `end_message_display:inst17|messageState.MSG_LOST` is recognized by Quartus as an extracted state signal and is marked connected. It was not an observed missing source. No source edit is required merely because that symbolic name initially looked suspicious.

### Board I/O assignments

Fitter critical warning **169085** reports nine of 91 pins without exact locations. The automatically selected physical pins are:

| Exported signal | Automatically fitted pin | I/O standard |
| --- | --- | --- |
| `BG_RGB[0]` | W15 | 3.3-V LVTTL |
| `BG_RGB[1]` | AJ14 | 3.3-V LVTTL |
| `BG_RGB[2]` | AA16 | 3.3-V LVTTL |
| `BG_RGB[3]` | AC18 | 3.3-V LVTTL |
| `BG_RGB[4]` | AG15 | 3.3-V LVTTL |
| `BG_RGB[5]` | AJ12 | 3.3-V LVTTL |
| `BG_RGB[6]` | AK14 | 3.3-V LVTTL |
| `BG_RGB[7]` | Y16 | 3.3-V LVTTL |
| `borderDR` | AG2 | **2.5 V** |

These are top-level debug outputs, not required VGA channels. Their automatic placement is not an acceptable substitute for checking the board schematic and intended ownership of those pins. No claim is made that these locations are safe on the connected university board. No programming was attempted.

Warning **15714** also flags incomplete I/O assignments. Many outputs lack explicit drive-strength/slew-rate choices. Warnings **15705/15706** report ignored location assignments for 35 nodes, and **171167** reports invalid fitter assignments. The template includes switches, ADC, old light/keyboard/audio names, and other nodes not retained in the fitted design.

Source: [Lab1Demo.pin](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files/Lab1Demo.pin) and fitter I/O/ignored-assignment tables.

### Timing configuration

The selected file remains the root `DE10_Standard_Audio.sdc`, not its divergent `constraints` copy.

- Warnings **332174/332049** confirm that audio/VGA/SDRAM template ports and hierarchies do not match the design.
- Critical **332049** occurs at root SDC lines 33 and 38: empty target collections for generated clocks, including the literal `inst7|...|divclk` placeholder.
- Warning **332043** reports the SDC overwriting the JTAG clock generated by embedded vendor constraints; the resulting analyzed JTAG period is 40 ns.
- Critical **332148** is emitted at all four timing corners because hold requirements are not met.
- `OPTIMIZE_HOLD_TIMING OFF` is set both in the QSF and `constraints/pin.tcl`. This is a relevant setting to review when repairing hold timing; it does not alone prove the full cause or guarantee a fix.

### HDL/interface warnings

| Warning | Count in synthesis report | Interpretation |
| --- | ---: | --- |
| 10230 | 46 | Width truncations across coordinates, addresses, constants and digit calculations. Some are intentional under current bounds; each widened geometry/counter path needs review. |
| 12001 | 20 | BDF instantiation of `NumbersBitMap` exposes offset bits 6–10 that do not exist in its six-bit HDL input ports. Four offset buses each have five mismatched upper bits. |
| 10270 | 1 | Background region case lacks an explicit default case item. The assignment before the case supplies a default RGB value; not itself proof of a latch. |
| 13004 + 13310 | 1 + 5 | Five audio `noteTimeCounter` bits are emulated using registers/latches because asynchronous reset loads `noteDuration`, a changing ROM-derived value, rather than a constant. Review reset determinism and latch inference. |
| 13046 + 13049 | 1 + 113 | Vendor `lpm_rom` internal tri-state outputs converted to ordinary wires. These were handled by synthesis, not fatal missing-ROM errors. |
| 13024 + 13410 | 1 + 29 | Constant output pins, largely consistent with blanked/limited-range seven-segment outputs. Confirm intent rather than treating every constant as a failure. |

The 22×24 head rectangle versus 24×24 head ROM, mixed graphics pipeline latencies, raster off-by-one, and absence of snake exclusion during collectible placement remain source-level issues described in `PROJECT_MAP.md`. This compile does not establish whether they are intentional or visually/gameplay-correct.

## 8. Simulation reproducibility blockers

ModelSim startup is available, but the existing project simulation workflow is not yet a reliable test baseline:

1. `CLK_31P5.sip` / `.spd` reference missing `CLK_31P5_sim/CLK_31P5.vo`. Synthesis succeeds without this simulation-only artifact.
2. Both VWF files embed absolute paths to `C:/intelFPGA/Quartus_Projects/ECE_Lab_A1_Project/Project_July_5/Project_July_5_Dorms/`. This old directory, its red-apple VWF and its generated red-apple `.vt` **do exist** outside the current checkout. The problem is therefore not simply a nonexistent old folder: the commands can silently operate on another project copy rather than this baseline.
3. The current checkout's `simulation` directory remains empty. No reproducible local testbench/netlist was generated in this phase.
4. Embedded VWF scripts expect `game_controller_vlg_vec_tst` while the main project top is `TOP_VGA_DEMO`. Unit and full-system simulation need distinct, consistent harness/top selection.
5. Imported QXP partitions lack editable RTL here. Full-system simulation requires suitable exported netlists/models; unit gameplay simulation can be scoped separately in a later approved verification task.

Do not run the existing absolute-path VWF commands assuming they verify this checkout. No VWF script, old external project, or simulator library was modified; no gameplay simulation result is claimed.

## 9. Required work before a trusted redesign baseline

These are recommendations requiring later approval; none was implemented in Phase 2A.

### Baseline repairs / verification first

1. **Resolve physical debug-output pin ownership before any rebuilt-board programming.** Remove unused top-level exports or constrain them to verified safe pins with appropriate electrical standards. Audit stale location assignments against the actual board interface. Do not accept automatic placement.
2. **Repair the active timing constraints and JTAG hold violation.** Remove/replace unrelated template clocks, target actual ports/PLL nodes, establish appropriate interface delays and asynchronous exceptions, review duplicated JTAG definitions and disabled hold optimization, then rerun timing with legitimate constraints. Aim for nonnegative margins and documented coverage rather than warning suppression.
3. **Repair or deliberately retire stale SignalTap connections.** Rebind the real background obstacle signal and use valid collision probes/netlist selection. Preserve/debug-test useful capture behavior if keeping SignalTap.
4. **Make local simulation reproducible.** Use this checkout, choose unit/full-system tops explicitly, provide the required PLL/netlist models and matching library configuration, and establish tests of original rules before changing geometry.
5. **Align BDF interfaces and review reset/width warnings.** Refresh score-renderer symbols/ports; inspect the audio nonconstant asynchronous reset and related latches. Preserve intended game behavior when deciding which legacy quirks to correct.

No capacity or HDL syntax repair is currently required just to make the original source compile: it already did. The necessary work is achieving safe physical I/O, credible timing/debug coverage, and reproducible behavioral verification.

### New-geometry dependency work, after separate approval

- Both tile-coordinate axes need at least **five bits** for X 0–19 and Y 0–17. `randomCounter`, `apple_position_controller`, `apple_topleft_calc`, and their BDF buses currently use four-bit axes. Range limiting must prevent invalid columns/rows; merely widening counters is insufficient.
- `back_ground_draw` needs 20×18 map lookup and new arena/HUD bounds. Its visible rock map and the position validator's duplicated exclusion map must stay consistent.
- The existing snake start `(320,280)` is not cell-aligned relative to `(144,24)`: offsets 176 and 256 are not multiples of 24. Head/body initial-position parameters and BDF overrides must agree on a valid new starting cell.
- Keep 24-pixel movement targets and 24×24 ROM sprite dimensions unless explicitly changing them. Do not carry forward the obsolete 32-pixel-cell plan.
- Move score/high-score rendering and replace the baked top HUD. Add three **independent collection counters**, driven by the corresponding hit pulses and cleared by `gameStartPulse`; they are not the score accumulator or the existing modulo-five blue-spawn counter. Their display widths/overflow policy need definition before implementation.
- Re-theme Ruby/Sapphire/Cursed artwork while preserving the original score/length/speed/visibility/respawn rules. Changing sprite transparency can change pixel-overlap collisions even if FSM code is unchanged.
- Update integration/simulation/debug interfaces coherently if new sources or ports are added. No module renaming is needed simply to establish this baseline.

### Original behavior to preserve

| Future name / current type | Score | Length | Speed | Other behavior |
| --- | --- | --- | --- | --- |
| Ruby / red | +1 | +1 | +3 | Rerolls red and black positions. |
| Sapphire / blue | +3 | −3, floor 1 | −5, floor 80 | Spawns after groups of five red hits if not already visible; hides on collection. |
| Cursed / black | −5, floor 0 | +5, cap 32 | +10 | Collection with score ≤5 loses; rerolls black. |

Win at score ≥20; wall/rock/self collision loses. New-game pulse clears current score, motion-related state and blue visibility; hardware reset also clears high score. High score survives local restarts. Existing simultaneous black-penalty/end-event ordering should be captured by tests before changing it.

## 10. Artifacts, preservation, and stop point

Evidence retained in `C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/output_files`:

- `Lab1Demo.map.rpt` / `.map.summary`: elaboration, synthesis warnings/resources and SignalTap connection table.
- `Lab1Demo.fit.rpt` / `.fit.summary`: final resources, I/O warnings and fitted pin assignments.
- `Lab1Demo.sta.rpt` / `.sta.summary`: four-corner timing, Fmax, clocks and unconstrained paths.
- `Lab1Demo.asm.rpt`, `Lab1Demo.sof`, `Lab1Demo.pin`, `Lab1Demo.flow.rpt`, plus generated `.sld`, `.jdi`, and `.fit.smsg`.

Compiler-generated databases remain in `db` and `incremental_db`. The ModelSim startup log is `db/baseline_modelsim_startup.log`. Quartus also generated root-level `KBDINTF.qarlog`, `audio_codec_controller.qarlog`, and `c5_pin_model_dump.txt`. These are new tool artifacts, not edits to pre-existing project sources. They were retained rather than deleted. No generated output was committed.

Initial pre-existing untracked files were `PROJECT_MAP.md` and `jungle-temple-reference.png`; they remain preserved. Post-build SHA-256 comparison of all 72 initial files reported no changes, and `git diff --name-only` reported no tracked-file modifications.

**Phase 2A complete. Stop here and await approval for repairs or later redesign phases.**
