# Phase 9B.2 Hardware Audio Noise Investigation

Date: 2026-10-21, Asia/Jerusalem.

## Outcome

**A concrete board-level regression was identified: the noisy build automatically assigned graphics-debug output `BG_RGB[6]` to AG30, the codec DAC word-clock pin.** The approved Phase 9B.1 build left AG30 as a reserved input. This is a real unintended driver on an audio clock net, not an inferred codec defect or a melody-duration bug.

The smallest supported production correction is two QSF virtual-pin assignments for the nine internal graphics-debug outputs. Playback RTL, notes, corrected durations, priority/preemption, volume, codec, gameplay, graphics, PLL, SDC and all intended physical pin assignments remain unchanged. **Production compilation, final board-pin audit, regressions and all constrained timing checks passed.** Physical audio acceptance is still required; no listening test is claimed.

## 1. Protection and baseline

HEAD before investigation: `5dbab1653524f386221d436fbe27f59561ecfd33`.

All **563** original tracked/nonignored files were backed up with their working-tree contents under `db/audio_noise_investigation_baseline/files/`. The previous production outputs/reports are preserved under `db/audio_noise_investigation_baseline/output_files/`. User changes in `Lab1Demo.qsf`, `RTL/VGA/TOP_VGA_DEMO.bdf` and unrelated untracked material are preserved.

| Image | Path | SHA-256 |
|---|---|---|
| Hardware-approved Phase 9B.1 | `db/audio_playback_priority_baseline/output_files/Lab1Demo.sof` | `4D6C6632EE1A60F73C5FC82B308933618F9A11E85618F12AF974C8D3C9B427DF` |
| Identical conveniently named rollback | `db/audio_noise_investigation/PHASE_9B1_APPROVED.sof` | Same approved hash |
| Previous noisy Phase 9B.2, backed up | `db/audio_noise_investigation_baseline/output_files/Lab1Demo.sof` | `C55E6095B64D4624582B6D2E7F47A6A499B6E9F69B6C2395F6D25564FA659743` |

Both older images are 6,690,369 bytes. The approved rollback is never replaced. Do not continue testing the noisy image at high volume.

## 2. Root cause and evidence

The top BDF exposes `BG_RGB[7..0]` and `borderDR` as output ports even though they are internal graphics/debug values, not intended board outputs. They have I/O standards but no physical locations. Quartus warning 169085 identifies nine unlocated ports, and the fitter chooses physical pins for them.

The stale assignment `PIN_AG30 -to AUDIN[3]` does not protect that pin: the active top audio bus is only `AUDIN[1..2]`, so `AUDIN[3]` does not exist and its location assignment is ignored.

| Actual fitted item | Approved Phase 9B.1 | Noisy Phase 9B.2 |
|---|---|---|
| `BG_RGB[6]` | AB22, automatically assigned | **AG30, automatically assigned output, 3.3-V LVTTL** |
| AG30 | `RESERVED_INPUT_WITH_WEAK_PULLUP` | **Driven by `BG_RGB[6]`** |
| Other internal debug outputs | Nine unconstrained physical outputs, a latent hazard | Nine unconstrained physical outputs, locations changed |

Evidence is directly present in the preserved `.pin` files: Phase 9B.1 lines 162/320 versus noisy Phase 9B.2 line 320. The project's `constraints/pin.tcl:165` labels AG30 `AUD_DACLRCK`. Terasic's manufacturer-authored [DE10-Standard User Manual, Table 3-15, page 31](https://www.mouser.com/datasheet/3/996/1/DE10-Standard_User_manual.pdf#page=32) independently identifies AG30 as Audio CODEC DAC LR Clock.

The exported failing full netlist further confirms an actively enabled push-pull `cyclonev_io_obuf` for `BG_RGB[6]`, driven by `inst4|BG_RGB[6]`, with `.oe(vcc)` and `open_drain_output="false"`. It is not a harmless unused port or a tri-stated observation point. The `.pin` report ties that enabled output buffer to the board's AG30 clock connection.

Consequently the revised synthesis/fitting can place a continuously changing graphics bit onto a codec clock net while the actual audio serializer still uses its intended clock/data connections. Depending on codec mode this corrupts the required external clock or creates output-driver contention. Either is an invalid electrical/functional board connection. It is consistent with nonzero audio becoming persistent noise and digital zero/mute suppressing the symptom. The exact electrical waveform and cessation of the audible symptom still require board testing; they have not been measured here.

This explains why an audio-only source change can cause a hardware regression without a bad note sequence: **unchanged QSF location statements do not imply unchanged automatically fitted pins**. No evidence supports replacing the codec QXP.

### Why simulation and timing passed

The earlier tests modeled internal audio logic, not the PCB connection between two independently driven I/O nodes. Even the new fitted-audio simulation selects the internal AUDIO subtree; it cannot catch a separate top-level graphics output being fitted onto the board's DACLRCK pad. TimeQuest positive internal slack does not know which external chip is connected to an unassigned debug pad. The nine-location warning was incorrectly left as a generic limitation rather than checked for actual board conflicts.

The new regression therefore audits the actual final pin report, not just the source assignments or warning totals.

## 3. Minimal production correction

Only `Lab1Demo.qsf` receives a production change:

```tcl
# Internal graphics debug outputs must never drive auto-selected board pins.
set_instance_assignment -name VIRTUAL_PIN ON -to "BG_RGB[*]"
set_instance_assignment -name VIRTUAL_PIN ON -to borderDR
```

The wildcard was verified by synthesis: **82 physical pins, nine virtual pins**. No debug signal can consume a real package pin after successful final fitting. Their internal graphics connections and top-level debug names remain available; no BDF edit, port removal, gameplay change or rendering change is needed.

This does **not** move an intended audio/VGA/keyboard/display pin or change a clock/timing exception. All six active codec pin/direction assignments must match the previous build exactly:

| Signal | Pin | Direction |
|---|---|---|
| AUDIN[1] | AH29 | Input |
| AUDIN[2] | AF30 | Input |
| AUDOUT[4] | AF29 | Output |
| AUDOUT[5] | AH30 | Output |
| AUDOUT[6] | Y24 | Output |
| AUDOUT[7] | Y23 | Output |

The final safety test additionally compares **all** non-debug physical port names, pins, directions and I/O standards against the previous build, and requires AG30 to be a reserved input.

## 4. Focused tests and findings

### Board-level fault reproduction

`scripts/verify_audio_pin_safety.py` rejects the archived noisy pin report with nonzero exit, specifically identifying `BG_RGB[6]` as an output on AG30 and all nine unconstrained physical debug outputs. It is also intended to reject the older latent auto-debug hazard, not label the older board layout universally safe merely because its audio worked.

`simulation/audio_pin_contention_tb.sv` models a resolved board wire with a codec word-clock driver and the unintended graphics driver. Opposing values reproduce two digital driver conflicts; disconnecting the debug driver (virtual pin) leaves zero conflicts. **PASS: nine assertions.** This reproduces the board wiring fault, not an analog white-noise waveform, and explicitly models the codec-driving case.

### Expanded continuous audio tests

The actual keyboard decoder/game controller, selector, player, divider, phase counter and sine path are tested after asynchronous reset at four sub-cycle release offsets, for keypad2/4/5/6/8, all six effects repeatedly, resets during fetch/note/gap, volume/mute/wrap and 10,000-clock idle tails. Every PCM sample is checked against exact unchanged lookup/volume expansion, −16,257..+16,256 bounds, valid tone/divisor and finite completion.

| Test | Result |
|---|---|
| Continuous keypad/reset/output suite | PASS: 2,524,625 checks, 506,512 clocks, 48 completed effects |
| Existing priority/MIF-duration oracle | PASS: 2,545,307 checks; 861 accepted, 216 rejected; 255 completed |
| Production timing parameters | PASS: 17,010,094 checks; 1,890,011 clocks; two 945,001-cycle intervals |
| Existing failing fitted AUDIO vs RTL | PASS: **10,000,081 checks**, 2,000,036 clocks, complete real-time restart and idle tail; exact reconstructed 16-bit codec-input PCM compared |
| Diagnostic snapshot CDC test | PASS: 150 assertions / 50 coherent snapshots |
| Offline diagnostic-reader mock | PASS: 120 IR writes, 240 DR reads, ack/header/coherence and device closure |

These tests found no nominal ongoing random PCM stream. Nonzero held final samples occurred in 24/48 targeted effects; those are not proof of white-noise PCM and were **not** “fixed” by gap muting or sound polishing. Reset release/metastability and physical codec behavior are still outside ideal functional simulation.

The failing build's fitted AUDIO subtree was exported read-only using Quartus EDA; Intel primitive/M10K libraries and synthesized QXP logic were included. The synthetic BCLK/LRCLK stimulus is an example, not a measured board rate or complete I2S-framing sign-off. Harness-development errors in MIF-path renaming, internal complemented selector-bit translation, and idle-reset/volume bookkeeping were corrected in the tests, not misidentified as production causes. All fatal assertions correctly returned nonzero.

All focused tests were rerun successfully against the unchanged production RTL after the QSF correction, with the same counts above. Logs: `db/audio_noise_repair_build/verification/`; earlier investigation/fitted logs: `db/audio_noise_investigation/`.

## 5. Game regressions

All eight established suites passed during investigation and **passed again after the QSF correction**, without changes to the game tests or fixtures. Every runner returned zero and its explicit pass marker. The combined post-correction runner ended with `ALL_REPAIR_REGRESSIONS_PASS`.

| Suite | Result |
|---|---|
| Initial length14 | 3,289,233 checks |
| Capacity63/history/movement/collision | 2,857,582 checks; 379 history pairs, index378, 1,516 frames |
| Emerald sprites | 83 checks; eight existing testbench-force warnings only |
| Arena/spawning | All 307,200 pixels and 360 cells; four-direction checks |
| Score90/relic effects | 1,056 checks |
| HUD | 3,887,791 render checks plus counter/high-score/saturation/reset |
| Opening/restart | 2,864,698 plus startup race |
| Victory/Defeat | 6,783,546 |

## 6. Build and post-fit verification

An observation-only diagnostic copy was initially started while the root cause was unknown. Its map completed; **its fitter was stopped before assembly** after the physical pin conflict was discovered. **No diagnostic SOF was produced or released.** That copy inherited the unsafe pre-repair auto-pin configuration and must not be programmed. Logs/source remain as investigation evidence, not a candidate repair.

The minimal corrected production map/fit/STA/assembler flow started at **18:06:04** and finished assembly at **18:17:13**. Every stage passed with zero errors. There was no retry of this corrected production compilation, no seed change and no timing relaxation.

| Metric | Noisy Phase 9B.2 | Corrected build |
|---|---:|---:|
| ALMs | 14,570 | **14,565 / 41,910** (−5) |
| Registers | 9,902 | **9,938** (+36) |
| M10Ks | 429 / 553 | **429 / 553**, unchanged |
| Block memory bits | 3,405,308 | **3,405,308**, unchanged |
| Physical / virtual pins | 91 / 0 | **82 / 9**, final fit confirmed |
| Worst setup | +5.101 ns | **+5.757 ns** |
| Worst hold | +0.148 ns | **+0.156 ns** |
| Minimum pulse-width slack | +0.793 ns | **+0.793 ns** |
| Latches / loops | 0 / 0 | **0 / 0**, fitted netlist verified |
| Errors map/fit/STA/assembly | 0/0/0/0 | **0/0/0/0** |
| Warnings map/fit/STA/assembly | 240/90/51/0 | **240/89/51/0** |

Target remains Cyclone V `5CSXFC6D6F31C6`, final timing models, zero DSPs and one PLL. Fitter duplication/packing changes full-design register totals even though production RTL is byte-identical.

| Corner | Setup before → after (ns) | Hold before → after (ns) |
|---|---:|---:|
| Slow 1100 mV / 85 C | +5.101 → **+5.757** | +0.279 → **+0.297** |
| Slow 1100 mV / 0 C | +5.325 → **+5.848** | +0.248 → **+0.280** |
| Fast 1100 mV / 85 C | +15.519 → **+16.219** | +0.171 → **+0.176** |
| Fast 1100 mV / 0 C | +17.125 → **+17.724** | +0.148 → **+0.156** |

All setup/hold TNS values are zero. Worst setup improved 0.656 ns and worst hold improved 0.008 ns. The existing read-only netlist inspection confirms timer bits0–4 as clearable FFs (one fitter replica, six physical FFs), no direct combinational feedback, and `IS_LATCH=0` for every timer register. Whole-design TimeQuest checks report **loops=0, latches=0**.

The final pin-safety check **passed**. AG30 is `RESERVED_INPUT_WITH_WEAK_PULLUP`, every non-debug physical port retains its previous pin/direction/I/O standard, all six active codec pins match, and no physical debug output or unconstrained physical design port remains.

Critical warning **169085 is eliminated**, not suppressed. Actual message comparison found no new map/fit/STA/assembly warnings. Existing stale SDC/ignored-node warnings remain. TimeQuest still lists zero unconstrained clocks, five unconstrained input ports/120 input paths and 56 unconstrained output ports/149 output paths (including virtual outputs); these counts are unchanged and do not constitute external-interface timing sign-off.

No altered melodies, source clocks, PLL settings, false paths, relaxed constraints or warning suppression are used. Known unmatched external constraints remain separate; eliminating a demonstrated pad conflict does not certify external codec timing.

Authoritative reports are `output_files/Lab1Demo.{map,fit,sta,asm}.rpt`, `.fit.summary`, `.sta.summary`, `.pin`. Stage logs, final pin audit and netlist checks are under `db/audio_noise_repair_build/`, including `pin_safety_after.log`, `final_timer_structure.log` and `timing_loop_check.rpt`.

Required final command:

```text
python -B scripts/verify_audio_pin_safety.py output_files/Lab1Demo.pin --compare db/audio_noise_investigation_baseline/output_files/Lab1Demo.pin
```

## 7. Programming file and physical acceptance

Corrected production **`output_files/Lab1Demo.sof`**:

- Generated **2026-10-21 18:17:13 +03:00**, Asia/Jerusalem.
- Size: **6,690,369 bytes**.
- SHA-256: **`547DB724C9E3C028EAAF1F57561322C98166085B8EF670B4B037003BE3EC41E4`**.
- Assembly: zero errors/warnings. The old approved and noisy images remain preserved separately.
- This image has **not been programmed or physically tested by the agent**. The identified pin conflict is removed and verified from its fitted pin report; audible resolution still needs the user's physical test below.

**Safety:** use minimum external speaker gain, no headphones, and mute promptly if noise occurs. KEY0 restores digital volume to level3.

The user, not the agent, should:

1. Program the verified corrected production file identified by its final hash below. Do not program the abandoned diagnostic copy or the archived noisy image.
2. After KEY0, wait two seconds and test keypad2,4,5,6,8 separately. Each direction/start effect should end after its intended short sequence, without persistent noise.
3. Repeat immediately after reset and after a ten-second wait, at least 20 resets/key trials across all five keys. This checks the reported intermittent startup pattern.
4. Try repeated direction requests about 50–200 ms apart; direction presses during Ruby/Sapphire/Cursed and Victory/Defeat; explicit keypad5 restart from terminal states. Verify existing priority protection and clean restart.
5. Check all six familiar effects, volume3→2→1→0→3, ordinary defeat, score90 Victory and normal gameplay. Starting length14, maximum63, graphics/HUD and gameplay must remain unchanged.
6. If noise remains, mute immediately and record exact reset/key timing and the SOF hash. Use the preserved **PHASE_9B1_APPROVED.sof** as rollback. Further interface capture is then warranted; do not infer a QXP defect or alter the approved notes.
7. Only physical testing can confirm the audible regression is resolved. No FPGA programming/listening was performed by the agent.

Optional JTAG probes/reader were developed before discovering the pin fault and remain observation-only sidecar tools, not production sources. Their transport and offline reader were tested, but no board capture was performed. One early no-argument helper invocation listed the attached chain only. If future instrumentation is needed, its generated source must include the virtual-pin correction and be separately verified before programming.

## 8. Files, preservation and Git

Production modification: **`Lab1Demo.qsf` only**, with two virtual-pin assignments and an explanatory comment. Its complete pre-existing working-tree content remains an identical prefix; existing unrelated user edits are excluded from the focused feature commit.

New investigation files (no diagnostic HDL is registered in the production QSF):

- `AUDIO_HARDWARE_NOISE_INVESTIGATION.md`.
- `scripts/verify_audio_pin_safety.py`, `prepare_audio_noise_netlist.py`, `prepare_audio_noise_diagnostic.py`, `read_audio_noise_probe.tcl`.
- `simulation/audio_pin_contention.do`, `audio_pin_contention_tb.sv`.
- `simulation/audio_noise_output.do`, `audio_noise_output_tb.sv`.
- `simulation/audio_noise_netlist.do`, `audio_noise_netlist_tb.sv`.
- `simulation/audio_noise_probe.do`, `audio_noise_probe_tb.sv`, `audio_noise_reader_test.tcl`.
- `simulation/fixtures/audio_noise_jtag_stub.sv`.
- `diagnostics/audio_noise_probe.sv`.

All derived copies, netlists, logs, simulation libraries and programming files are ignored build artifacts. The integrity comparison over all **563** original paths finds only `Lab1Demo.qsf` changed, with no missing paths. All RTL/BDF/MIF/QXP/SDC and unrelated existing contents are byte-identical to the investigation baseline. The QSF change is an append, preserving its old content exactly. Both approved rollback copies retain their original hash.

The focused local commit covers the demonstrated pin correction, its investigation/test helpers and this report, excluding the user's pre-existing QSF/BDF edits and unrelated untracked files. The working tree intentionally remains dirty with those original user changes. No push, cleanup, board programming or physical listening was performed. If noise persists on the exact new hash, retain the rollback and return hardware observations rather than treating simulation as acoustic proof.
