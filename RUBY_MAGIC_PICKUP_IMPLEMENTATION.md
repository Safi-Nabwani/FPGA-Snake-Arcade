# Phase 9C.1 — Ruby Magic Pickup

Date: 2026-10-22, Asia/Jerusalem.

Status: **PASS — implemented, simulated, compiled and pin-audited; ready for user hardware listening/approval.** No board programming or listening performed by the agent.

## Baseline and preservation

Starting HEAD: `fcde220a9d2fad560c12acf5b9d78ee87e1f91ab`.

All 580 existing tracked/nonignored file paths were backed up under `db/ruby_magic_pickup_baseline/files/`, including existing uncommitted contents. Existing production outputs/reports were copied to `db/ruby_magic_pickup_baseline/output_files/` before compilation.

Hardware-approved rollback SOF: `db/ruby_magic_pickup_baseline/output_files/Lab1Demo.sof`, SHA-256 **547DB724C9E3C028EAAF1F57561322C98166085B8EF670B4B037003BE3EC41E4**, 6,690,369 bytes. Original and backup checksums matched before editing. This rollback is retained unchanged.

Existing modified `Lab1Demo.qsf` and `RTL/VGA/TOP_VGA_DEMO.bdf`, untracked audits, QWS, preview/experimental files and sprite assets are preserved and excluded from the feature commit. No cleanup, push or programming is authorized/performed.

## Exact production modification

Only `RTL/AUDIO/songs.mif` changes production behavior. Bank 5 is replaced; the word layout remains tone[15:12], stored octave[11:10], duration[9:5], gap[4:0]. Decoded octave equals stored octave + 3; the project convention maps the approved G5 to tone 7 / decoded octave 4. Existing `ToneDecoder.sv` is authoritative and unchanged.

| Address | Old word / note / duration | New word / note / duration | New gap |
|---|---|---|---:|
| 500 | 0820 / C6 / 1 | 7440 / G5 / 2 | 0 |
| 501 | 4460 / E5 / 3 | 0860 / C6 / 3 | 0 |
| 502 | 7440 / G5 / 2 | 2840 / D6 / 2 | 0 |
| 503 | 0820 / C6 / 1 | 78A0 / G6 / 5 | 0 |
| 504 | 4460 / E5 / 3 | 0000 / terminator | 0 |
| 505 | 7440 / G5 / 2 | 0000 / cleared | 0 |

Both old and new sequences total 12 ticks nominally (360 ms). Range `[504..5FF]` is explicitly zero; no old tail remains. The only decoded addresses changed are 500–505. The bank comment describes the new sound. File line endings and original end-of-file convention are retained.

Pitch divisors, verified through the actual decoder: G5=156, C6=117, D6=104, G6=78. With 31.5 MHz and 256 sine samples, frequency is `31500000/(256*(divisor+1))`: approximately 783.738, 1042.770, 1171.875 and 1557.555 Hz. No retuning, waveform changes, fades, padding, mixing or volume changes.

The unchanged timer period is 945001 clocks (30.000031746 ms). Its free-running phase means the first note can have a partial first interval; the unchanged ROM fetch introduces clock-scale pauses. Twelve consumed note ticks do not promise a fixed 360 ms trigger-to-idle interval.

Sapphire remains words 4861/7861/0CC2: E6/G6/C7, durations 3/3/6, gaps 1/1/2. All 15 other banks, including unused legacy banks, retain identical raw bytes and decoded words.

## Verification files and results

Created files:

- `simulation/ruby_magic_pickup_tb.sv`: independent hardcoded approved-word/pitch checks, per-note tick counting, exactly four enables, no gap state, one ending pulse, no fifth note and return to idle.
- `simulation/ruby_magic_pickup.do`: nonzero exit on failure and explicit completion flag.
- `scripts/verify_ruby_magic_pickup.py`: all 4096 ROM addresses validated; hardcoded approved Ruby and Sapphire words; complete zero tail; decoded comparison and raw byte preservation outside Ruby bank against the saved baseline.
- This report, `RUBY_MAGIC_PICKUP_IMPLEMENTATION.md`.

Focused Ruby and bank-preservation checks pass. The existing playback oracle derives expected sequences independently from the MIF; it required no test weakening or old-note-count changes. Frozen historical timer-equivalence and old synthesized-netlist tests target superseded RTL/ROM contents, so they are not used as current-production oracles.

Current relevant audio results:

| Suite | Result |
|---|---|
| Ruby exact sequence | PASS: 4 notes, 2/3/2/5 ticks, 12 total ticks, no gaps, idle |
| Bank preservation | PASS: six changed addresses in bank 5; all 15 other banks byte-identical |
| Continuous audio output/reset/keypad | PASS: 2,524,641 checks, 506,512 clocks, 48 effects |
| Priority/ROM/game integration | PASS: 2,545,307 checks, 861 accepted / 216 rejected requests, 255 completions, 640 resets |
| Production-period timer | PASS: 17,010,094 checks, 1,890,011 clocks, two real ticks |

The continuous suite covers keypad 2/4/5/6/8 after asynchronous resets at multiple phases, repeated requests, valid pitch/sample monitoring, finite effect completion, idle output and volume/mute behavior. Priority tests cover all ordered requests and FSM phases, simultaneous events, explicit restart cancellation and game-controller terminal events. Held nonzero samples at idle remain existing behavior, not a new envelope or mute implementation.

All eight existing gameplay/graphics suites passed:

| Suite | Result |
|---|---|
| Initial length 14 | 3,289,233 checks; hardware/local reset, startup formation, legitimate collision |
| Emerald production | 83 checks; approved rendering and orientation |
| Arena geometry | Complete 640x480 scan, 360 cells, movement/spawn boundaries |
| Score-90 victory | 1,056 checks; below/exact/overshoot, relic effects and restart |
| HUD/relic counters | 3,887,791 render checks plus counter/reset/saturation tests |
| Opening screen | 2,864,698 checks; gameplay state, restart guard, existing artwork |
| Results reports | 6,783,546 checks; dynamic stats, fatal Cursed update, restart and unchanged HUD |
| Capacity 63 | 2,857,582 checks; 379 history pairs, 1,516 frames, movement/collision/corner/tail/length display |

Logs are under `db/ruby_magic_pickup_build/`. Existing library-reuse warnings and the eight intentional Emerald testbench force warnings remain; no test failure or production source change was required.

## Quartus, timing and pin safety

One production map/fit/STA/assembler flow completed successfully using Quartus Prime Lite 17.0.0 Build 595, Cyclone V `5CSXFC6D6F31C6`, Lab1Demo revision, TOP_VGA_DEMO top. Map/fit settings export was disabled. No clock, PLL, SDC, QSF or board assignment edits are part of this phase. The separate read-only fitted-netlist inspection is not another compilation.

Baseline: 14,565 ALMs / 41,910, 9,938 registers, 429 / 553 M10Ks, 3,405,308 memory bits, 82 physical pins, 9 virtual pins, 1 PLL, 0 DSP. Baseline worst constrained setup +5.757 ns, hold +0.156 ns, minimum pulse +0.793 ns; all TNS zero. Baseline warnings map=240, fit=89, STA=51, assembler=0.

Final utilization is **identical** to baseline: 14,565/41,910 ALMs (35%), 9,938 registers, 429/553 M10Ks (78%), 3,405,308/5,662,720 memory bits (60%), 82 physical pins, 9 virtual pins, 1 PLL and 0 DSP.

| Timing corner | Baseline setup → new (ns) | Baseline hold → new (ns) |
|---|---:|---:|
| Slow 1100 mV / 85 C | +5.757 → +5.757 | +0.297 → +0.297 |
| Slow 1100 mV / 0 C | +5.848 → +5.848 | +0.280 → +0.280 |
| Fast 1100 mV / 85 C | +16.219 → +16.219 | +0.176 → +0.176 |
| Fast 1100 mV / 0 C | +17.724 → +17.724 | +0.156 → +0.156 |

Worst constrained setup **+5.757 ns**, hold **+0.156 ns**, minimum pulse width **+0.793 ns**; all TNS values zero. Timing is unchanged, not relaxed.

All four stages report **zero errors**. Warnings remain map=240, fit=89, STA=51, assembler=0. Actual warning-message comparison against the saved baseline found no additions/removals in map, fit or STA. Existing ignored-node/stale-SDC warnings remain; critical unassigned-debug warning 169085 does not return.

The fitted-netlist checker passes: all five timer bits are covered by six clearable physical FFs (one fitter replica), no direct combinational self-feedback, no timer latches. Whole-design TimeQuest checks report **loops=0, latches=0**. Existing unspecified configuration power-up metadata is recorded separately from deterministic asynchronous clear behavior.

The final-fit pin audit **passed**, both immediately after fit and again after assembly. No internal debug port drives a physical pin; all nine debug outputs remain virtual. AG30 remains `RESERVED_INPUT_WITH_WEAK_PULLUP`. All six codec pins match the approved fit: AUDIN[1]=AH29, AUDIN[2]=AF30, AUDOUT[4]=AF29, AUDOUT[5]=AH30, AUDOUT[6]=Y24, AUDOUT[7]=Y23. The comparison also confirms every other non-debug physical port's location, direction and I/O standard, including keyboard ports; no auto-assigned physical design port or conflicting physical assignment is accepted by the audit.

Authoritative current reports: `output_files/Lab1Demo.{map,fit,sta,asm}.rpt`, `.fit.summary`, `.sta.summary`, `.pin`. Stage/simulation logs, `pin_safety_after.log`, `final_timer_structure.log` and `timing_loop_check.rpt` are retained under `db/ruby_magic_pickup_build/`. The map report explicitly identifies the active 4096x16 song ROM with `RTL/AUDIO/songs.mif`.

Required final audit command:

```text
python -B scripts/verify_audio_pin_safety.py output_files/Lab1Demo.pin --compare db/ruby_magic_pickup_baseline/output_files/Lab1Demo.pin
```

Both existing virtual assignments (`BG_RGB[*]`, `borderDR`) must remain unchanged; all nine debug outputs must remain virtual. AG30 must remain a reserved input with weak pull-up. The six active codec pins and every non-debug physical pin, including keyboard ports, must match the approved fit. A pin audit failure blocks release.

Existing external-I/O constraint limitations remain unchanged: zero unconstrained clocks; five unconstrained input ports / 120 input paths; 56 unconstrained output ports / 149 output paths, including virtual outputs. Internal timing closure is **not** complete external codec/keyboard interface timing sign-off or audible verification.

## Production SOF and physical approval

Verified new production **`output_files/Lab1Demo.sof`**:

- Generated **2026-10-22 15:18:05 +03:00**; assembly completed 15:18:06.
- Size **6,690,369 bytes**.
- SHA-256 **431B1534F8102E560F78ACACF3E2649DD14B538959D70C627EF4FA7444025DBE**.
- All software verification/release checks passed. Physical listening is pending user approval.

The post-build integrity comparison over all **580** pre-existing paths finds only `RTL/AUDIO/songs.mif` changed and none missing. The QSF/BDF and all other existing source/assets/working-tree contents remain byte-identical to the saved baseline. The hardware-approved rollback checksum remains unchanged.

The focused local commit contains only the MIF, three verification files and this report. Existing unrelated QSF/BDF modifications and untracked user files intentionally remain outside that commit. Build outputs and backups are ignored, not committed. No push or board programming was performed.

Physical listening is the user's responsibility. Start with low external speaker gain, avoid headphones during initial checks, and mute immediately if abnormal output occurs. KEY0 restores the existing digital volume setting.

1. Program only the final checksum-identified SOF after this report records success. Reset, start with keypad 5, and collect Ruby. Expect four ascending notes G5–C6–D6–G6 with a longer final note, approximately 360 ms nominally, no old six-note continuation.
2. Repeat Ruby pickups and test direction keys during Ruby; lower-priority direction requests must not interrupt it.
3. Check Sapphire, Cursed, Victory/Defeat and keypad-5 restart remain familiar. Higher-priority effects must retain existing preemption behavior.
4. Repeat KEY0 followed by sound-producing keypad keys; no persistent noise should occur. Check existing volume and mute controls.
5. If any regression occurs, mute and use the preserved hardware-approved rollback SOF. Record the exact SOF checksum and sequence of actions.

No physical acoustic or board-functionality claims are made from simulation. No additional sound redesign, music or polishing is included.
