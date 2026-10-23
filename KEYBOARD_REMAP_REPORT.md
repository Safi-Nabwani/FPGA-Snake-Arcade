# Keyboard-remapping release

Date: 2026-10-22, Asia/Jerusalem. Status: **PASS — production build verified; ready for user hardware testing.**

## Controls and active production configuration

- Numpad 8 / 4 / 6 / 5: Up / Left / Right / Down.
- Main Enter (PS/2 Set-2 5A) and Numpad Enter (E0 5A): Start / Restart.
- Enter held states are independent; typematic makes do not repeatedly restart. Numpad 2 no longer requests movement or its sound.
- Existing graphics, including baked-in control labels, are unchanged. Legacy `key_5` and `key_2` port names remain internal compatibility identifiers, now carrying Enter and keypad-5 Down respectively.

`Lab1Demo.qpf` selects revision `Lab1Demo`. Its QSF selects `TOP_VGA_DEMO`, Cyclone V `5CSXFC6D6F31C6`, and `output_files`. It explicitly registers `RTL/KEYBOARDX/keyPad_decoder.sv`, `RTL/KEYBOARDX/TOP_KBD.bdf` and `RTL/VGA/TOP_VGA_DEMO.bdf`. The keyboard block's Enter output at (184,144) connects through `startEnter` to the game-controller input at (-728,-24); `keyIsPressed[5]` feeds Snake_Block's existing Down input at (-712,840).

Existing focused simulation result reused, not rerun: **KEYPAD_REMAP_PASS, 142 checks, zero errors/warnings** (`db/keypad_remap.log`). Covers four directions, main/extended Enter, key releases, overlapping Enter holds, typematic, defeat/victory restart and unchanged sound request IDs. No unrelated simulations were run for this release.

## Rollback

Previous working SOF preserved before compilation:

`db/keyboard_remap_release_baseline/output_files/Lab1Demo.sof`

SHA-256: `431B1534F8102E560F78ACACF3E2649DD14B538959D70C627EF4FA7444025DBE` (original and backup verified).

Previous resource/timing/pin reports are saved alongside it. This rollback uses the old keypad mapping. No source or unrelated working-tree edits were reverted.

## Build and verification

One production Quartus Prime Lite 17.0.0 Build 595 map/fit/STA/assembler flow; map/fit settings export disabled. No timing, pin-assignment or source changes are made during this release. Baseline: 14,565 ALMs, 9,938 registers, 429/553 M10Ks; worst setup +5.757 ns, hold +0.156 ns; warnings map/fit/STA/assembler 240/89/51/0.

All four stages passed on the first and only build attempt: **zero errors**. Warnings remain map/fit/STA/assembler **240/89/51/0**; detailed map/fit/STA warning-message comparisons found no added or removed messages.

| Resource | Previous | Released build |
|---|---:|---:|
| ALMs / 41,910 | 14,565 | 14,591 (35%; +26) |
| Registers | 9,938 | 9,894 (-44 after fitting/optimization) |
| M10Ks / 553 | 429 | 429 (78%) |
| Block memory bits | 3,405,308 | 3,405,308 |
| Physical / virtual pins | 82 / 9 | 82 / 9 |
| PLL / DSP | 1 / 0 | 1 / 0 |

| Timing corner | Setup slack (ns) | Hold slack (ns) |
|---|---:|---:|
| Slow 1100 mV / 85 C | +5.332 | +0.292 |
| Slow 1100 mV / 0 C | +5.358 | +0.259 |
| Fast 1100 mV / 85 C | +16.202 | +0.177 |
| Fast 1100 mV / 0 C | +17.667 | +0.159 |

Worst constrained setup **+5.332 ns** (previous +5.757); hold **+0.159 ns** (previous +0.156). Minimum pulse width +0.793 ns; all TNS zero. No constraints were relaxed. Existing external-I/O limitations remain: 0 unconstrained clocks, 5 input ports / 120 paths and 56 output ports / 149 paths (including virtual outputs). Internal closure is not complete external-interface timing sign-off.

Mandatory final audit:

```text
python -B scripts/verify_audio_pin_safety.py output_files/Lab1Demo.pin --compare db/keyboard_remap_release_baseline/output_files/Lab1Demo.pin
```

**AUDIO_PIN_SAFETY_PASS**: AG30 remains `RESERVED_INPUT_WITH_WEAK_PULLUP`; all nine graphics-debug outputs remain virtual, with none on physical pins. The audit confirms all six active codec pins and all other non-debug physical pin locations/directions/I/O standards are unchanged, including keyboard pins. The final fit retains 82 physical pins and 9 virtual pins. Pin safety passed; no release blocker was found.

Production SOF: **`output_files/Lab1Demo.sof`**, generated **2026-10-22 17:17:07 +03:00**, **6,690,369 bytes**.

SHA-256: **`7E0B52235D3C28DD15EDC3AE57F0E984D82D8DA42BE61AC4D12663111140F051`**.

The rollback's checksum was reverified after assembly and remains unchanged. The build's before/after integrity check found **585 existing source/working-tree files unchanged**, including unrelated QSF/BDF contents. This release only adds this report and generated build artifacts; no further RTL/BDF edits or simulation runs occurred. No files were staged or committed.

Build logs: `db/keyboard_remap_release_build/`. Authoritative reports: `output_files/Lab1Demo.{map,fit,sta,asm}.rpt`, `.fit.summary`, `.sta.summary`, `.pin`.

## Hardware acceptance

After final verification passes, program the checksum-identified `output_files/Lab1Demo.sof` manually; the agent does not program the board.

1. KEY0 reset; press main Enter to start. Check Numpad 8/4/6/5 move Up/Left/Right/Down. Existing no-reversal and movement behavior must remain intact.
2. Verify releases clear requests and Numpad 2 no longer moves or produces the movement effect. Numpad 5 must not restart the game.
3. After defeat and victory, test main Enter and Numpad Enter separately. Holding/typematic Enter through game end must not auto-restart; release and press again.
4. Hold both Enter keys, release one, and verify no extra restart until both are released and a fresh press occurs.
5. Check start/movement and relic sounds at low speaker gain. If abnormal persistent noise occurs, mute and return to the preserved rollback; record the SOF checksum and actions.

Physical behavior/listening remains unverified until the user's test. No commit, push, cleanup, source redesign or FPGA programming is part of this release.
