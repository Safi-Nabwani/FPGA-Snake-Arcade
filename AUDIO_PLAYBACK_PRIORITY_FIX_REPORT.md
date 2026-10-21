# Phase 9B.2 — Audio Playback Priority and Song-ROM Timing

Date: 2026-10-21, Asia/Jerusalem.

Status: **PASS**. Audio verification, all eight existing game suites, the production compilation, positive constrained timing and fitted latch/loop checks passed. The new production SOF is ready for user listening tests. No physical verification of this new build is claimed.

## 1. Baseline and rollback protection

Baseline HEAD: `2f70753b617b382d5e689b54c042fb83a9e71ba3` (`Fix audio timer reset and eliminate unintended latches`). The user explicitly physically tested and approved this production version in the Phase 9B.2 instructions.

The actual current reports match the stated baseline: Cyclone V `5CSXFC6D6F31C6`, Quartus Prime Lite 17.0.0 Build 595, 14,562 ALMs, 9,834 registers, 429/553 M10Ks; worst setup +5.991 ns and hold +0.122 ns. No old audio latches/loops remain.

Before editing, all **559** existing tracked/nonignored file paths were copied to `db/audio_playback_priority_baseline/files/`, preserving uncommitted contents. Production outputs and reports were copied to `db/audio_playback_priority_baseline/output_files/`.

Approved rollback SOF:

- Original: `output_files/Lab1Demo.sof`; preserved: `db/audio_playback_priority_baseline/output_files/Lab1Demo.sof`.
- Generated 2026-10-21 11:00:49 +03:00; 6,690,369 bytes.
- SHA-256: `4D6C6632EE1A60F73C5FC82B308933618F9A11E85618F12AF974C8D3C9B427DF` (both original and backup verified before editing).

Unrelated modified `Lab1Demo.qsf` and `RTL/VGA/TOP_VGA_DEMO.bdf`, the existing untracked audits, previews, sprite variants/configuration, controller backup and experimental scripts/builds must remain untouched and outside the feature commit. Backup directories are ignored build artifacts, not Git content.

## 2. Previous problems

The old selector's simultaneous-event priority was correct, but its registered bank could change while the player was busy. The player accepted starts only in idle. A later key or relic could therefore splice the new bank at the old sequence's index/countdown, including truncating terminal effects.

The song ROM registers its address. At first start and at zero-gap index changes the previous player loaded the duration before the requested word became available. It also decoded pitch/gap directly from the changing ROM output. The result depended on the previous bank and gap history rather than exclusively on the accepted effect's stored words.

## 3. Exact files and scope

Modified production files (no port additions or renames):

1. `RTL/AUDIO/sound_effect_controller.sv`: explicit restart request ID 6, distinct from direction request ID 4; existing registered pulse/bus and simultaneous ordering retained.
2. `RTL/AUDIO/melody_player_1.sv`: active-bank/priority ownership, preemption/restart acceptance, registered-word capture and six-state fetch/playback FSM. The constant-zero asynchronous timer reset remains.

New verification/report files:

3. `simulation/audio_playback_priority_tb.sv`: independent MIF/event/tick oracle, actual selector/player/oscillator/volume modules and real game-controller integration.
4. `simulation/audio_playback_priority.do`: accelerated and production-parameter ModelSim runner; assertion/compilation failures or missing pass flags cause nonzero exit.
5. `scripts/analyze_audio_note_timing.py`: read-only, reproducible intended-versus-old-calculated duration-load audit.
6. `AUDIO_PLAYBACK_PRIORITY_FIX_REPORT.md`.

No QSF, SDC, BDF, symbol, MIF, QXP, image, game RTL, clock/pin assignment or existing report/test was changed. Both audio BDFs retain exactly the same ports, widths, instances and connections; the existing four-bit `melodySelect` bus now transports a request ID rather than a live ROM-bank selector. Request 6 is consumed by the player as a control operation and maps to **bank 4**, never to legacy song bank 6.

## 4. Architecture and exact arbitration policy

```text
registered game/key events
  -> existing selector: request pulse + 4-bit request ID
  -> player: accept/reject atomically; latch active bank and effective priority
  -> present {activeBank,noteIndex}; wait for registered ROM
  -> capture complete note word; count note/gap ticks
  -> unchanged pitch/divider/phase/sine/volume/codec path
```

| Event | Request ID | Actual ROM bank | Effective rank (larger wins) |
|---|---:|---:|---:|
| Victory | 0 | 0 | 7 |
| Defeat | 1 | 1 | 6 |
| Cursed | 3 | 3 | 5 |
| Sapphire | 2 | 2 | 4 |
| Ruby | 5 | 5 | 3 |
| Explicit game start/restart | 6 | 4 | 2, plus cancellation exception |
| Direction key | 4 | 4 | 1 |

- Same event cycle: Victory > Defeat > Cursed > Sapphire > Ruby > start/restart > direction. Losing requests are discarded, not queued.
- Idle or completed sequence: any valid request is accepted. Unsupported request IDs are rejected.
- Busy (including ROM fetch and final gap): strictly higher rank preempts; equal/lower rank is dropped. Thus Victory can replace Defeat; Defeat cannot replace Victory. Neither can be interrupted by relic/direction requests. Cursed > Sapphire > Ruby preemption works in the same way.
- **Explicit restart is a cancellation exception**: when selected, it always replaces the old sequence, even a terminal or same restart effect. Bank 4 starts at index zero with fresh timing. No old requests are retained.
- Accepted request: bank, priority and index-zero restart update together in the player's one clocked block. Output phase advance is disabled during fetch. There is no independently delayed bank/start handshake and no pending queue.
- Dropped request: active bank, word, duration and state advance normally; none is spliced or restarted.
- `melodyEnded` pulses for one clock when the zero-duration terminator is fetched. Requests during the completed state are accepted; requests coincident with the terminator load still follow the pre-edge busy priority rule and may be discarded. This is intentional, without a queue.

The actual game controller makes game start/restart mutually exclusive with relic/win/lose pulses. Fatal Cursed intentionally asserts Cursed+Defeat together, so Defeat wins. Real-controller tests cover both terminal restarts and the one-cycle score-clear guard. No gameplay modification or artificial overriding of simultaneous game events was needed.

## 5. Registered-ROM and musical timing

FSM: `s_idle`, `s_fetchWait`, `s_loadNote`, `s_playNote`, `s_gap`, `s_ended`.

At acceptance edge E0 the active bank and index zero are latched. At E1 (`fetchWait`) the ROM captures the new address. At E2 (`loadNote`) the player consumes that word. Nonzero duration captures the complete word, pitch/octave and outgoing gap together, loads D and enables the note. Duration zero terminates without briefly enabling an invalid note. The active bank never follows the live request bus.

During a note, each observed free-running tick consumes one of its D intervals; the Dth tick ends the note. A gap of G consumes the next G ticks; zero gap skips the gap state. After note/gap completion, index advances and the same two-clock fetch occurs. No extra musical tick is introduced for fetch. Pitch and gap come from the captured word, not the next ROM address.

The existing tick module and parameters are unchanged: **945,001 clock cycles**, **30.000031746 ms nominally at 31.5 MHz**. It is not restarted on an effect request. Therefore the first interval is the remaining tick phase, not a guaranteed full 30 ms from note onset. A tick occurring while a new request is still fetching is not counted as played time. Two main-clock fetch cycles are about **63.49 ns**; selector registration adds one clock before player acceptance. A zero-gap transition has this short phase-hold interval, not an added 30-ms gap. The same phase counter, sine samples, volume and codec connection remain; held-output/DC-gap clicking is intentionally not repaired.

### Intended values versus old calculated behavior

Below, old loads are **calculated from the previous FSM/ROM ordering**, for an isolated request after settled idle bank 4. They are not recorded analog measurements or guaranteed durations for arbitrary overlapping requests. Nominal totals include stored gaps, treat a tick as 30 ms for readability, and omit first-tick phase and clock-scale state delays. The new note/gap loads and exact consumption are verified in ModelSim against every word in the unchanged `songs.mif`.

| Effect | Old calculated loaded note ticks | Intended/new note ticks | Old nominal total → intended total |
|---|---|---|---:|
| Victory | 1,3,3,3,5,3,5 | 3,3,3,5,3,5,10 | 720 → 990 ms |
| Defeat | 1,8,8,8,12,12 | 8,8,8,12,12,2 | 1530 → 1560 ms |
| Sapphire | 1,3,6 | 3,3,6 | 420 → 480 ms |
| Cursed | 35-note history-dependent sequence; full list in audit script output | unchanged stored 35 durations and 35 gaps | 5400 → 5370 ms |
| Direction/restart | 1,1 | 1,1 | 60 → 60 ms |
| Ruby | 1,1,3,2,1,3 | 1,3,2,1,3,2 | 330 → 360 ms |

**Audible rhythm is expected to change**, especially Victory, Ruby and previously spliced effects. This is the authorized duration correction, not new musical data. All note codes, octave fields, frequency dividers, wave samples and volume levels are unchanged. Different first tick phases can shift total elapsed duration by nearly one tick; the table is not an exact request-to-completion guarantee.

Reproduce the full read-only comparison with `python -B scripts/analyze_audio_note_timing.py`.

## 6. ModelSim verification

Run from the project root:

```text
C:/intelFPGA_lite/17.0/modelsim_ase/win32aloem/vsim.exe -c -do simulation/audio_playback_priority.do
```

The existing `simulation/jungle_rom_model.sv` provides one registered address stage. A separate testbench parser reads all 4096 words of `songs.mif` into an independent oracle array. Expected bank ownership, remaining durations/gaps, note indices, enable, completion and pitch are predicted from accepted events and clock/tick history, not copied from the player's FSM or obtained from its ROM array. Every-cycle checks also validate the actual registered ROM address ordering.

| Test | Result |
|---|---|
| Final accelerated suite | PASS: **2,545,307 checks**, 274,076 clocks |
| Event acceptance | 861 accepted; 216 rejected; each accepted effect starts at index zero |
| Full and interrupted playback | 255 completed sequences; 3,042 note loads; 1,662 zero-gap and 885 nonzero-gap transitions |
| All six banks after all six preceding banks | PASS: 36 ordered combinations, each preceding effect actually played before its target |
| Free-running tick phases | PASS: all 21 accelerated phases × all six sequences, including fetch near a tick |
| Preemption | PASS: all seven-by-seven ordered request pairs in fetch-wait, load, note, valid nonzero-gap and completion states |
| Simultaneous events | PASS: all 127 nonempty masks, both idle and under Victory protection, through the actual registered selector |
| Reset | PASS: 640 reset scenarios; asynchronous zero before next clock; every FSM phase; no initialized unknown controls/data |
| Closely spaced requests | PASS: Ruby→Sapphire→Cursed→Defeat→Victory, then all lower/equal terminal attempts rejected; restart cancels protection |
| Real game events | PASS: score-90 Victory, keypad-5 restart, fatal Cursed→Defeat, Defeat restart; obsolete event exclusion |
| Waveform/volume | PASS: unchanged phase held through gaps; initialized digital output known; 3→2→1→0→3 volume cycle |
| Production timing parameters | PASS: **17,010,094 checks**, 1,890,011 clocks; both bank-4 notes and two 945,001-cycle ticks |

Both audio variants compile/simulate with zero HDL errors/warnings. Reused-library notices are not HDL warnings. Logs: `db/audio_playback_priority_verification/audio_playback_priority.log`.

The Phase 9B.1 side-by-side test remains unchanged as a historical reset-only/old-scheduling equivalence suite; exact equivalence with its frozen old playback is deliberately **not** claimed or enforced now. Its legacy scheduling assertions are superseded by this new MIF-duration oracle, which also reruns reset/no-unknown checks. No codec-QXP or analog simulation is claimed.

## 7. Existing game regression results

All eight unchanged regression runners passed:

| Existing runner | Result |
|---|---|
| `simulation/snake_initial_length.do` | PASS: 3,289,233 checks; 14-node startup/restart/reset, mature self-collision, length display |
| `simulation/snake_length_capacity.do` with `capacity=63` | PASS: 2,857,582 checks; 379 history pairs/index 378, 1,516 frames, growth/shrink/saturation and collisions |
| `simulation/snake_emerald_production.do` | PASS: 83 orientation/art/ROM checks; eight existing testbench-force warnings only |
| `simulation/arena_geometry.do` | PASS: all 307,200 pixels and 360 cells; four-direction movement and spawn/exclusion checks |
| `simulation/winning_score.do` | PASS: 1,056 checks; 0–89 continue, exact/crossing 90, relic effects and restart |
| `simulation/hud_relics.do` | PASS: 3,887,791 render checks plus independent counters, reset, high-score and saturation tests |
| `simulation/opening_screen.do` | PASS: 2,864,698 checks; opening rendering, keyboard, real game-state/restart and score-clear race |
| `simulation/results_reports.do` | PASS: 6,783,546 checks; six complete frames, terminal snapshots, fatal Cursed and keypad-5 restart |

Each process returned zero and verified its explicit pass flag. Existing fixtures were reused without regenerating graphics or changing the testbenches. Library-reuse notices and the established Emerald force warnings are not new synthesis warnings. Logs are in `db/audio_playback_priority_verification/`.

## 8. Quartus, resources, timing and structural verification

One production map/fit/TimeQuest/assembler flow completed successfully: started at 11:51:37 and assembly finished at **13:40:27** on 2026-10-21. The already-launched build was inspected after it completed; no second compilation was launched. Map/fit disabled settings-file export. No fitter seed, constraint, clock exception, PLL or pin change was made.

| Metric | Approved baseline | New build |
|---|---:|---:|
| ALMs | 14,562 / 41,910 | **14,570 / 41,910** (+8) |
| Registers | 9,834 | **9,902** (+68) |
| M10Ks | 429 / 553 | **429 / 553**, unchanged; 124 free |
| Block memory bits | 3,405,308 | **3,405,308**, unchanged |
| Worst setup | +5.991 ns | **+5.101 ns** |
| Worst hold | +0.122 ns | **+0.148 ns** |
| Minimum pulse-width slack | +0.793 ns | **+0.793 ns** |
| Latches / combinational loops | 0 / 0 | **0 / 0**, actual netlist verified |
| Errors: map / fit / STA / assembly | 0 / 0 / 0 / 0 | **0 / 0 / 0 / 0** |
| Warnings: map / fit / STA / assembly | 241 / 90 / 51 / 0 | **240 / 90 / 51 / 0** |

The target remains `5CSXFC6D6F31C6` with final timing models, 91/499 pins, one PLL and zero DSP blocks. Full-design physical optimization affects register duplication and packing, so whole-device ALM/register deltas are not just a count of newly written RTL registers.

| Constrained corner | Setup before → after (ns) | Hold before → after (ns) |
|---|---:|---:|
| Slow 1100 mV / 85 C | +5.991 → **+5.101** | +0.276 → **+0.279** |
| Slow 1100 mV / 0 C | +6.000 → **+5.325** | +0.248 → **+0.248** |
| Fast 1100 mV / 85 C | +16.605 → **+15.519** | +0.136 → **+0.171** |
| Fast 1100 mV / 0 C | +18.057 → **+17.125** | +0.122 → **+0.148** |

Every constrained setup/hold and minimum-pulse-width result remains positive; every setup/hold TNS is zero. Worst setup decreased 0.890 ns but remains +5.101 ns; worst hold improved 0.026 ns. No timing exceptions or relaxed clocks were added.

### Fitted latch/loop verification

The existing read-only `scripts/verify_audio_timer_netlist.tcl` was reused with `quartus_sta -t scripts/verify_audio_timer_netlist.tcl timing`. This is inspection of the completed database, not another synthesis/fit. It found timer bits 0–4 as ordinary FFs with the existing asynchronous clear connection and zero combinational self-feedback. Two fitter replicas (bits 1 and 3) give seven physical FFs; TimeQuest classifies all seven as `IS_LATCH=0`. Whole-design `check_timing -include {loops latches}` reports **loops=0, latches=0**, including the new control logic.

Logs: `db/audio_playback_priority_build/final_timer_structure.log` and `db/audio_playback_priority_build/timing_loop_check.rpt`. The reused script also writes its conventional ignored `db/audio_timer_reset_build/timing_loop_check.rpt`; its final result was copied into this phase's build directory. No assignments or fitted database contents were exported by inspection.

### Warnings and I/O limitations

Comparing actual warning messages against the preserved baseline found **no added warnings**. The only removed message is synthesis warning 13046 (internal tri-state nodes not directly driving top-level pins); fitter/STA warning sets are unchanged. Its disappearance is not claimed as a codec electrical/CDC repair. No latch-emulation warning or combinational-loop warning returned.

The known stale SDC targets/ignored assignments and nine unlocated debug outputs (`borderDR`, `BG_RGB[7:0]`) remain. Unconstrained clocks=0; input ports=5 with 120 input paths; output ports=56 with **149 output paths**, versus 146 previously. The three-path increase reflects the changed implementation, not new external ports or repaired constraints. External codec/VGA interface timing remains incomplete and is not signed off by positive internal timing.

Authoritative outputs: `output_files/Lab1Demo.{map,fit,sta,asm}.rpt`, `.fit.summary`, `.sta.summary`; native-stage logs are under `db/audio_playback_priority_build/`.

No new unconstrained clock, latch, loop, compilation error or constrained timing violation was introduced. Existing external-I/O limitations are retained explicitly rather than hidden or relaxed.

## 9. Production SOF, Git and preservation

New production programming file:

- **`output_files/Lab1Demo.sof`**.
- Generated **2026-10-21 13:40:27 +03:00** (Asia/Jerusalem).
- Size: **6,690,369 bytes**.
- SHA-256: **`C55E6095B64D4624582B6D2E7F47A6A499B6E9F69B6C2395F6D25564FA659743`**.
- Assembly: zero errors and zero warnings. Actual resources and margins are listed above.
- Not programmed or physically listened to by the agent. The physically approved previous SOF remains preserved with its original checksum in section 1.

The final content-integrity comparison covered all **559** original file paths: only `RTL/AUDIO/melody_player_1.sv` and `RTL/AUDIO/sound_effect_controller.sv` differ; no original path is missing. This confirms that all gameplay/graphics, audio data/pitch/waveform/QXP, BDF interfaces, constraints and unrelated uncommitted contents are preserved.

Selected preserved SHA-256 signatures:

- `songs.mif`: `EB6AB1DA51CAC9E22D0BFC275F326BEB08F3A03E8D6F5D139082312104D24FD1`.
- `SinTable.sv`: `9436BF3F933CD96517946BA22D2FDD5557B599F89BD3F8757C693598BB84F590`.
- `ToneDecoder.sv`: `643834A2F984B37DAAB00678BC977881A18754A489053AB9E26DE275F85E028C`.
- Codec QXP: `FDC4A108ADA560E3DFA614B044E236CAF73421DB16D2CD642ADC9F9F135E9F0F`.
- User-modified QSF: `28C210EA52E112BD51A574157ABFD69BF27F6066B47354A8786E9BB6177768C9`.
- User-modified top BDF: `F17E9AF9AFB072738EBF55EAFF52DBA0589D0DD7AB9823BCBC45ECDEC7286643`.

Focused local Git scope: only the six feature files in section 3, with message `Fix audio playback priority and song ROM timing`. Generated outputs/databases/logs and all unrelated modifications remain excluded. The existing QSF/top-BDF edits and unrelated untracked files intentionally remain uncommitted; the whole working tree is not expected to be clean. No push or FPGA programming is performed.

## 10. Remaining limitations and recommended physical acceptance

- Held waveform sample during gaps/end, click suppression/envelopes and phase-continuous transitions remain unchanged and unpolished.
- Volume-input synchronization, PLL-lock reset-release assurance and codec CDC/format/I2C/external timing remain outside this repair.
- Direction events can still occur outside gameplay, as before. They are suppressed only while a higher-priority effect is active, not by a new game-state gate.
- No queue: dropped requests are deliberately lost, including lower-priority requests coincident with a terminating word before the completed state is visible.
- No background music, new sounds, envelopes, mixing, cleanup or control remapping was added.
- Recommended user listening: all six original effects at fixed volume; compare Victory's restored final sustained note; Ruby/Sapphire/Cursed escalation; direction presses during long relic and terminal sounds; fatal Cursed Defeat; restart during each terminal/relic; repeated direction inputs; hardware reset during playback. Compare against the preserved physically approved SOF if desired.
- This new build requires the user's physical listening and musical acceptance. No board was programmed by the agent.
