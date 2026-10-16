# Winning score changed to90

Date:2026-10-16 (Asia/Jerusalem). Comparison build:929762d / `db/phase3c_build/source/output_files`.

The latest user instruction supersedes the earlier99-point target. Victory now means **score>=90**; equality alone would miss Sapphire jumps. The only production RTL edit is the win comparison and its comment in `RTL/VGA/game_controller.sv`:

```systemverilog
else if (score_High >= 4'd9) begin
```

`score_High` is the decimal tens field, not the full score. Its four-bit width is unchanged, and `appleCounter.sv` continues maintaining decimal ones and carrying into tens. Therefore this implements90 or greater, including91/92 reached by Sapphire. Neither the accumulator nor its +1/+3/-5 arithmetic was changed. The two-position HUD supports all reachable victory values90..92 without a third digit.

## Exact task files

- `RTL/VGA/game_controller.sv`: win condition20→90 and corrected comment.
- `simulation/winning_score_tb.sv`: new focused controller/real-accumulator/high-score/counter regression, using actual relic overlap events rather than forced scores.
- `simulation/winning_score.do`: reproducible ModelSim runner.
- `simulation/opening_startup_tb.sv`: victory/restart expectation updated20→90.
- `simulation/opening_screen_tb.sv`: victory/high-score expectation updated20→90.
- `simulation/hud_counters_tb.sv`: integrated score/relic-counter victory expectation updated20→90.
- `WINNING_SCORE_CHANGE.md`: this report.

No MIF, PNG, artwork, movement/collision/audio RTL, scoring accumulator, arena/HUD layout, timing constraint, PLL, pin, or BDF was edited by this task. Opening/tutorial artwork deliberately retains its existing20-point text as requested. No other active RTL win comparison depends on20. Coordinate, map, sprite and unrelated numeric20 constants remain unchanged.

## Functional verification

ModelSim10.5b, real production RTL and registered-address MIF adapter where rendering is tested:

- `simulation/winning_score.log`: **1056 checks PASS**, zero compile/runtime errors or warnings (existing library reuse notice only). Every score00..89 continues, explicitly including20 and89.89+Ruby→90 wins exactly once.87+Sapphire→90,88+Sapphire→91 and89+Sapphire→92 each win. Terminal state ignores further relic overlaps. High score captures each result and survives local restart; current score/relic counters clear. Hardware reset clears high score. Cursed -5, lethal Cursed at5, and wall/obstacle/self-collision losses at20 remain correct.
- `simulation/win90_opening_regression.log`: **OPENING_STARTUP_PASS**, **OPENING_SCREEN_PASS:2870886 checks**, zero HDL errors/warnings.90-point victory restart survives the old score-clear race. Full menu raster, legacy result panels, keypad controls, held-key suppression, original score/relic/length/speed effects and menu/game transitions pass.
- `simulation/win90_hud_regression.log`: **HUD_COUNTERS_PASS**, **HUD_FINAL_RENDER_PASS:3887791 checks**, zero HDL errors/warnings. Independent counters,000..999 saturation, high-score/reset behavior and full five-field HUD rendering, including00/99 digits and unchanged arena boundaries, pass.

Reproduce from project root with ModelSim using the installed17.0 modelsim.ini:

```text
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/winning_score.do
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/opening_screen.do
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/hud_relics.do
```

The two rendering suites use their existing ignored fixtures from the prior verified build. No artwork regeneration was performed.

## Quartus verification

**PASS** — one complete map→fit→STA→assembler flow under `db/win90_build/source/`, Quartus Prime Lite17.0 Build595, Cyclone V5CSXFC6D6F31C6. Started19:42:59 and completed19:52:53 on2026-10-16, Asia/Jerusalem. Synthesis and fitting each ran once. The first STA command rejected the unsupported `--write_settings_files` option before analysis; the corrected STA command analyzed the existing fit successfully, followed by assembly. No synthesis/fitting rerun, seed change, constraint change or timing exception. The command-line error is retained in `db/win90_build/sta_invocation_error.log`; final reports contain zero errors.

| Stage | Previous warnings | Current warnings | Current errors |
| --- | ---: | ---: | ---: |
| Analysis/synthesis |243|243|0|
| Fitter |91|91|0|
| TimeQuest |52|52|0|
| Assembler |0|0|0|

Warning codes and their counts match the previous build in every stage.

| Corner | Previous setup(ns) | Current setup(ns) | Previous hold(ns) | Current hold(ns) |
| --- | ---: | ---: | ---: | ---: |
| Slow1100mV85C |7.894|8.275|0.152|0.278|
| Slow1100mV0C |7.425|7.734|0.136|0.236|
| Fast1100mV85C |18.127|18.665|0.084|0.177|
| Fast1100mV0C |19.246|19.567|0.062|0.166|

All20 reported timing summaries are positive with TNS0. Worst setup **+7.734ns**, worst hold **+0.166ns**. Minimum pulse width remains+0.793ns. No new timing violation was reported. These are analyzed internal paths: the existing incomplete external-I/O constraints remain (5input ports/120paths;55output ports/141paths, previously148output paths). Existing stale generated-clock references and unassigned debug-pin warnings remain; this is not complete board-level timing signoff.

| Resource | Previous | Current |
| --- | ---: | ---: |
| ALMs |6655|6676/41910(16%)|
| Registers |5341|5314|
| Memory bits |4165312|4165312/5662720(74%)|
| RAM blocks |515|515/553(93%)|
| Pins |91|91/499|
| DSP blocks |1|1/112|
| PLLs |1|1/15|

ALMs increased21 and registers decreased27; memory, pins, DSP and PLL use are unchanged. Physical RAM headroom remains38blocks. Resource/timing comparisons include the pre-existing working-tree configuration described below and should not be attributed exclusively to the threshold edit.

The snapshot copies the current tracked working files byte-for-byte. It includes the user's pre-existing local `Lab1Demo.qsf` and `RTL/VGA/TOP_VGA_DEMO.bdf` edits; these are preserved and excluded from the task commit. Consequently this build verifies that exact working configuration, not a clean checkout with those unrelated edits removed. `db/win90_build/source_manifest.json` records input hashes. The untracked user `Lab1Demo.qws` and controller `.bak` are preserved and excluded from the snapshot/commit.

## Handoff

The verified programming file and reports were copied to the normal ignored `output_files/`. `output_files/Lab1Demo.sof` is the new90-point build (6690369bytes, generated2026-10-16 at19:52:52+03:00), byte-identical to the successful snapshot SOF. SHA256: `BE78659E2F2DC3FABEA14FF159AE0A987FBC77C55905622D64D2693232CC500D`. All304 tracked input hashes still match the snapshot after compilation. The QSF, BDF, QWS and `.bak` hashes match their values at the start of this resumed task.

Local commit message: `Increase Snake winning score to 90`, following the latest target correction. Only the seven task files listed above belong in that commit; user QSF/BDF/QWS/backup changes and generated build/simulation outputs are excluded. No push, FPGA programming or physical hardware verification.
