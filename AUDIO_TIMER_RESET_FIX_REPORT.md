# Phase 9B.1 — Audio Timer Reset Repair

Date: 2026-10-21, Asia/Jerusalem.

Baseline HEAD: `79e1bfb30df4ae655c9ea77c50f55c3d46ec3149` — `Start production snake at 14 body nodes`.

Status: **PASS**. Focused audio tests, existing game regressions, the one planned production compilation, fitted-register inspection and TimeQuest latch/loop checks all passed. A new production SOF was generated. No physical audio verification is claimed.

## A. Root cause and protection

The original `RTL/AUDIO/melody_player_1.sv:90` assigns `noteTimeCounter <= noteDuration` inside `always_ff @(posedge CLOCK_31p5 or negedge resetN)`. `noteDuration` is a changing output of the registered-address song ROM, not a constant reset value. Quartus therefore implements five register/latch-emulation networks rather than an ordinary constant-reset timer.

The current pre-change reports, rather than the older audit's resource figures, are the baseline:

- `output_files/Lab1Demo.fit.summary`: 14,528 ALMs, 9,950 registers, 429/553 M10Ks, Cyclone V `5CSXFC6D6F31C6`.
- `output_files/Lab1Demo.sta.summary`: worst setup +4.422 ns; worst hold +0.145 ns.
- Map warning 13004 and five warning-13310 instances identify timer bits 4–0. The report attributes them to source line 98, whereas the causative reset assignment in the current source is line 90.
- Fitter and STA warning 335093 report five combinational loops analyzed as latches.

Before compilation replaced the old database, read-only atom inspection confirmed the actual structure: five timer FFs with `BOOL_POWER_UP_DONT_CARE=1`, plus five timer `LCELL_COMB` cells whose DATAF input feeds back from their own output. These are the bit-associated feedback cells `noteTimeCounter[4]~1`, `[3]~3`, `[2]~5`, `[1]~7`, `[0]~9`. This is structural evidence of the old problem, not just a warning-count inference.

Baseline structural log: `db/audio_timer_reset_build/baseline_timer_structure.log`.

All 554 tracked/nonignored working-tree paths were backed up under `db/audio_timer_reset_baseline/files/`. The pre-change production SOF and reports are preserved under `db/audio_timer_reset_baseline/output_files/`. Unrelated modified `Lab1Demo.qsf` and `RTL/VGA/TOP_VGA_DEMO.bdf`, untracked audits, previews, sprite variants, experimental builds/scripts and the controller backup remain outside this feature.

Pre-change production SOF:

- `output_files/Lab1Demo.sof`, 6,690,369 bytes, generated 2026-10-20 22:36:29.
- SHA-256 `56B36933873783DF20E901240FC00CC6BD0DB432FA85020CDF68C85163001A68`.
- Preserved copy: `db/audio_timer_reset_baseline/output_files/Lab1Demo.sof`.

## B. Exact modification

There is exactly **one changed production RTL line**:

```systemverilog
// Asynchronous reset branch only:
noteTimeCounter <= 5'd0;
```

The five-bit width, idle reset state, note index, song selector, registered ROM interface, tick generator and both synchronous `noteTimeCounter <= noteDuration` loads remain unchanged. No FSM cleanup or new state was added. Local game restart still uses its original sound request; the audio player's reset wiring is unchanged.

Modified production file:

- `RTL/AUDIO/melody_player_1.sv`.

Created verification/report files:

- `simulation/fixtures/audio_timer_reset_reference.sv`: frozen pre-fix player from baseline HEAD; only the module and compilation-unit identifiers are renamed. It deliberately retains the unsafe reset for comparison and is not listed in the QSF.
- `simulation/audio_timer_reset_tb.sv`: accelerated and real-parameter audio/reset/compatibility tests, including the unchanged selector, pitch divider, phase counter and sine/volume modules.
- `simulation/audio_timer_reset.do`: reproducible ModelSim runner with explicit pass flags and nonzero failure exit status.
- `scripts/verify_audio_timer_netlist.tcl`: read-only fitted atom and optional TimeQuest latch/loop inspection; closes the project without exporting assignments and never writes the atom database.
- `AUDIO_TIMER_RESET_FIX_REPORT.md`.

No existing game regression source was modified. No BDF, QSF, SDC, MIF, QXP, graphics, gameplay, volume or pin assignment was changed. In particular the live-bank switching, first-duration/zero-gap ROM latency behavior and existing interruption priority are intentionally **not fixed** here.

## C. Functional verification

### Focused audio tests

Runner, from the project root:

```text
C:/intelFPGA_lite/17.0/modelsim_ase/win32aloem/vsim.exe -c -do simulation/audio_timer_reset.do
```

Both variants use `simulation/jungle_rom_model.sv`, which reads the actual 4096x16 `songs.mif` and registers its address on the clock edge. An additional per-edge check compares the ROM output with the word addressed before that edge. This preserves the real one-clock address latency rather than using an asynchronous-ROM shortcut.

The old and corrected players run side by side. Their common timing, selector, pitch, waveform and volume RTL is unmodified. A separate one-edge oracle checks the corrected timer/FSM sequencing. Comparisons include state, index, note data, tone, octave, enable, completion, pitch divisor, phase-step pulses, sine phase and the 16-bit sample supplied to the codec boundary.

| Audio test | Result |
|---|---|
| Accelerated comprehensive suite | PASS: 199,354 checks; 39,531 clocks |
| All six effects from every settled preceding bank | PASS: 36 bank combinations, plus two final effects; 38 completed sequences |
| Reset injection | PASS: 17 scenarios, including idle, note, gap, note transition and repeated assertion/release |
| ROM changes during reset | PASS: known nonzero durations and deliberately unknown ROM data cannot contaminate the corrected zero-reset timer |
| Synchronous timer compatibility | PASS: 39,166 active comparisons after duration reload; 423 duration loads, 1,831 decrement events |
| Gaps and state progression | PASS: all four FSM states, 242 zero-gap transitions and 129 nonzero-gap transitions |
| Existing request handling | PASS: all 127 nonempty simultaneous input combinations through the actual selector, plus busy-time bank changes and later requests |
| Global volume | PASS: existing 3→2→1→0→3 cycle, including mute/wrap, with old/new digital sample comparison |
| Production timing-parameter run | PASS: 9,450,071 checks; 1,890,015 clocks; two production interval pulses |

The fast suite overrides only the existing **test instance's** `SIMULATION_MODE` to 1, giving its documented 21-clock inclusive interval. It does not edit the production tick RTL or QSF. The second run uses the actual production `SIMULATION_MODE=0`, `mSecPerTick=30`, `PLLClock=315`: consecutive pulses are exactly **945,001 clock cycles** apart, nominally **30.000031746 ms at 31.5 MHz**. It plays the complete movement/restart effect with old/new waveform equivalence. The bench clock is a convenient simulation clock; cycle counts, not its displayed nanoseconds, establish the production interval.

Tests explicitly check asynchronous zero reset before the next rising edge, deterministic idle after release, and known corrected timer values on every checked initialized clock, including when the ROM data becomes unknown while reset is held. Actual counter widths, registered ROM ordering and tick phase are retained.

### Expected differences from the old reset

There were 365 checked idle/reset clocks where the timer differed: the old design loads or retains its ROM-derived nonzero/unknown reset value; the corrected timer is zero. These differences are expected and are not treated as failures or forced away.

On an accepted idle start, both players synchronously reload the same existing ROM duration. From that load until the next reset their timers match exactly. Observable digital audio-path outputs match throughout the tested valid operation; no new note, gap, completion or request policy is introduced. The deliberately injected unknown-ROM case is confined to held reset, and ROM data is settled before playback begins. Loading genuinely unknown ROM data synchronously is not newly prevented by this reset-only repair.

This does not prove analog equivalence or codec CDC timing. The opaque codec QXP is not simulated, and physical listening remains required. Known scheduling/interruption quirks are represented by the frozen player and deliberately preserved.

Both focused variants compile and simulate with zero HDL errors/warnings. The runner rejects missing pass flags, compilation errors and fatal assertions with a nonzero process exit.

Log: `db/audio_timer_reset_verification/audio_timer_reset.log` (also the ignored `simulation/audio_timer_reset.log`).

### Existing game regressions, rerun without modifying them

| Regression | Result |
|---|---|
| Fourteen-node startup, restart, movement, mature self-collision and seven-segment glyphs | PASS: 3,289,233 checks; initial length 14 retained |
| 63-node capacity/history/arithmetic/reference renderer | PASS: 2,857,582 checks; 379 history pairs; index 378; minimum 1 and saturation at 63 |
| Emerald production sprites | PASS: 83 checks, all head/body/corner/tail orientations; existing eight testbench-force warnings only |
| Arena and relic positions | PASS: 307,200 visible pixels, 360 cells and four-direction movement/spawn-exclusion checks |
| Score-90 and relic effects | PASS: 1,056 checks; scores below 90 continue; exact/crossing 90, penalties, collisions and restart |
| HUD and independent relic counters | PASS: 3,887,791 render checks plus counter/saturation/reset/high-score tests |
| Opening/menu/startup race | PASS: 2,864,698 checks plus the Victory-restart score-clear test |
| Victory/Defeat reports | PASS: 6,783,546 checks; dynamic statistics, fatal Cursed, Victory and keypad-5 restart |

Logs: `db/audio_timer_reset_verification/`. Reused compiled-library notices are harmless. The established Emerald test's eight force warnings are not new synthesized warnings. No physical game/audio test was performed.

## D. Quartus and structural verification

One production map/fit/STA/assembler flow completed successfully using Quartus Prime Lite 17.0.0 Build 595 and the existing `Lab1Demo` production configuration, targeting Cyclone V `5CSXFC6D6F31C6`. Map started at 10:49:30; assembly finished at 11:00:49 on 2026-10-21. There was no compilation retry, fitter-seed change, constraint change or warning suppression. Map/fit settings-file export was disabled.

| Metric | Before | After |
|---|---:|---:|
| Audio latch-emulation warnings (13310) | 5 | 0 |
| Associated combinational feedback loops | 5, structurally confirmed | 0, structurally and TimeQuest confirmed |
| ALMs | 14,528 / 41,910 | 14,562 / 41,910 (+34) |
| Registers | 9,950 | 9,834 (−116) |
| M10Ks | 429 / 553 | 429 / 553 (unchanged; 124 free) |
| Block memory bits | 3,405,308 | 3,405,308 (unchanged) |
| Worst setup slack | +4.422 ns | +5.991 ns |
| Worst hold slack | +0.145 ns | +0.122 ns |
| Minimum pulse-width slack | +0.793 ns | +0.793 ns |
| Errors: map / fit / STA / assembly | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 |
| Warnings: map / fit / STA / assembly | 247 / 91 / 52 / 0 | 241 / 90 / 51 / 0 |

There are 91/499 pins, zero DSP blocks and one PLL, unchanged. ALM/register totals include placement and physical-optimization effects across the full design; their deltas are not a count of the five repaired timer bits. Memory usage and all original non-audio source/assets remain unchanged.

All four constrained timing corners passed, with zero setup/hold total negative slack:

| Corner | Setup before → after (ns) | Hold before → after (ns) |
|---|---:|---:|
| Slow 1100 mV / 85 C | +4.422 → +5.991 | +0.292 → +0.276 |
| Slow 1100 mV / 0 C | +4.594 → +6.000 | +0.256 → +0.248 |
| Fast 1100 mV / 85 C | +15.254 → +16.605 | +0.175 → +0.136 |
| Fast 1100 mV / 0 C | +16.874 → +18.057 | +0.145 → +0.122 |

Worst hold margin decreased by 0.023 ns but remains positive; no new constrained timing failure was introduced. This is internal constrained timing closure, **not** complete external-interface sign-off.

Warning comparison against the preserved reports found only the intended removals: five 13310 instances and their parent 13004 in synthesis, and warning 335093 in fitter and STA. No new warning messages were introduced. Existing stale/mismatched SDC targets, ignored assignments, unused assignments and nine unlocated debug outputs (`borderDR`, `BG_RGB[7:0]`) remain. TimeQuest still reports zero unconstrained clocks, five unconstrained input ports/120 input paths and 56 unconstrained output ports/146 output paths (previously 147 output paths). The small path-count reduction does not resolve the underlying external-I/O limitations.

### Actual fitted structure, not just warning counts

`db/audio_timer_reset_build/final_timer_structure.log` confirms coverage of timer bits 0–4 as clocked FF atoms, each with a CLRN input driven by the unchanged PLL-lock/reset path. Fitter optimization replicated bits 4 and 2, giving seven physical FFs for five logical bits. There are **zero timer combinational self-feedback connections**. TimeQuest independently classifies all seven as `IS_LATCH=0`, and its whole-design check reports **loops=0, latches=0** in `db/audio_timer_reset_build/timing_loop_check.rpt`.

The initial read-only inspection script incorrectly required `BOOL_POWER_UP_DONT_CARE=0`; it stopped because Quartus leaves configuration power-up unspecified even on these ordinary clearable FFs. That metadata is not the asynchronous reset value and does not establish latch emulation. The verification script was corrected to record it without treating it as a reset failure. No production RTL, settings or constraints were changed, and no synthesis/fitting was repeated. The final script passed using actual clear connectivity, bit coverage, absence of combinational feedback and independent TimeQuest register/latch checks. The RTL simulation establishes deterministic zero on reset assertion; this phase does not add a separate FPGA power-up initialization guarantee.

Authoritative reports: `output_files/Lab1Demo.map.rpt`, `.fit.rpt`, `.fit.summary`, `.sta.rpt`, `.sta.summary`, `.asm.rpt`. Stage logs: `db/audio_timer_reset_build/{map,fit,sta,asm}.log`.

Structural inspection commands, from the project root:

```text
quartus_cdb -t scripts/verify_audio_timer_netlist.tcl
quartus_sta -t scripts/verify_audio_timer_netlist.tcl timing
```

These inspect the existing fitted database; they do not repeat synthesis or fitting. The `baseline` argument records pre-fix cells without asserting that they satisfy the corrected structure. Temporary API discovery scripts/logs are isolated in `db/audio_timer_reset_build/`; they are not production source, compiler retries or commit candidates.

## E. Remaining audio issues — intentionally deferred

- Live song-bank selection can change the active ROM bank during playback.
- Registered-ROM first-duration and zero-gap scheduling errors remain.
- Same-cycle priority exists, but no protected preemption/queue policy is implemented.
- Gaps stop phase advance rather than explicitly zeroing the held output sample.
- Volume-input synchronization and reset-release/interface assurance remain future work.
- Codec sample rate, serial mode, CDC, SDAT behavior and external-I/O timing require separate evidence/approval.
- Ambient background music, envelopes, mixing and artistic changes remain unimplemented.

No timing exceptions, relaxed clocks, synchronization changes or musical fixes were added to conceal or combine these issues with the reset repair.

## F. Production status and preservation

Verified new production programming file:

- `output_files/Lab1Demo.sof`.
- Generated 2026-10-21 **11:00:49 +03:00** (Asia/Jerusalem).
- Size: **6,690,369 bytes**.
- SHA-256: **`4D6C6632EE1A60F73C5FC82B308933618F9A11E85618F12AF974C8D3C9B427DF`**.
- Assembly: zero errors and zero warnings. The previous SOF remains in the baseline backup with its original hash listed above.
- This file has **not** been programmed or physically tested. Physical audio listening/acceptance remains the user's next step.

Preserved signatures:

- Original player: `673A8BD3EAA230C8AFC9B752DEB7C22449E8BAC9A3CE459D71C24CD1671D637F`.
- `songs.mif`: `EB6AB1DA51CAC9E22D0BFC275F326BEB08F3A03E8D6F5D139082312104D24FD1`.
- `SinTable.sv`: `9436BF3F933CD96517946BA22D2FDD5557B599F89BD3F8757C693598BB84F590`.
- User-modified QSF: `28C210EA52E112BD51A574157ABFD69BF27F6066B47354A8786E9BB6177768C9`.
- User-modified top BDF: `F17E9AF9AFB072738EBF55EAFF52DBA0589D0DD7AB9823BCBC45ECDEC7286643`.

An integrity comparison against all 554 baseline paths found only the intended player file changed and no missing files. The existing starting length 14, capacity 63, score-90 logic, approved artwork, audio assets, QXP, other RTL/BDF/configuration files and unrelated working-tree edits remain unchanged.

Git scope is the six files listed in section B: the production reset line, new audio verification files and this report, with the authorized message `Fix audio timer reset and eliminate unintended latches`. Generated databases/logs/SOFs and unrelated user changes are excluded. The pre-existing QSF/top-BDF modifications and untracked audits, previews, variants, controller backup and experimental scripts/builds remain outside the focused commit; the repository is intentionally not globally clean. No push, FPGA programming, cleanup or later audio phase is performed.
