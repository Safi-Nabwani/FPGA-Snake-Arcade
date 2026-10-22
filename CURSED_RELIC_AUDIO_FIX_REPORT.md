# Cursed Relic — short descending effect

2026-10-23, Asia/Jerusalem. Status: **PASS — short effect verified and compiled; user listening approval pending.**

## Finding and production change

Bank 3 (`blackAppleHitPulse`) previously contained a 35-note explosion: 104 note ticks + 75 gap ticks = **5,370 ms nominal**. Focused simulation of the original sequence confirmed finite completion, one ending pulse, idle return and stable phase/PCM afterward (47,585 checks). No playback/termination defect was reproduced. The data explains the excessive duration and chaotic sound; physical acoustic behavior is not established by simulation.

Only production file changed: **`RTL/AUDIO/songs.mif`, bank 3**:

| Address | Note | Duration | Following gap | Word |
|---|---|---|---|---|
| 300 | E5 | 2 ticks / 60 ms | 1 tick / 30 ms | 4441 |
| 301 | E-flat5 | 2 ticks / 60 ms | 1 tick / 30 ms | 3441 |
| 302 | B4 | 2 ticks / 60 ms | 1 tick / 30 ms | B041 |
| 303 | A4 | 2 ticks / 60 ms | None | 9040 |

Total **11 ticks / 330 ms nominal** (about 300–330 ms from request due to the unchanged free-running first-tick phase, plus clock-scale ROM fetch). The semitone opening and downward intervals give a short negative/dissonant gesture. The final note is only 60 ms; `[304..3FF]` is explicitly zero, clearing the old tail and providing a terminator.

All other 15 banks are byte-identical, including Ruby, Sapphire, Start/Direction, Victory and Defeat. Player, oscillator, sine table, volume, codec, priorities, controls, graphics and gameplay are unchanged. This shortens the effect; it does not attenuate the existing master amplitude.

## Focused verification

- `scripts/verify_cursed_audio.py`: exact approved four words, cleared remainder, all 4096 addresses compared, raw-byte preservation outside bank 3.
- `simulation/cursed_audio_tb.sv` / `.do`: original finite-termination test; new accelerated test **40,467 checks**; production 945001-clock/tick test **20,830,027 checks**. Exactly four notes, eight note ticks, three gap ticks, one end pulse, terminator index 4, stable idle and 10,000 post-end clocks without changing phase/PCM. No broad regressions.
- Important silence limitation: the existing oscillator freezes its last phase/sample on disable. Tests verify **no continuing oscillation**, not zero-valued PCM. A held DC sample is existing behavior for all effects; no waveform/codec redesign or forced-zero gate was added. Initial transitions/clicks and actual listening still require hardware approval.

## Release

One quiet Quartus Prime Lite 17.0.0 Build 595 production map/fit/STA/assembler build passed on the first attempt: **zero errors in all four stages**. All four timing corners pass; worst setup **+4.506 ns**, hold **+0.135 ns**, all TNS zero. Existing incomplete external-I/O constraints remain; this is not complete external-interface timing sign-off. Logs under `db/cursed_audio_build/`; no warning investigation or rebuilds.

Mandatory final-fit audio pin audit **passed** against the preserved baseline: AG30 remains reserved input with weak pull-up, all nine graphics-debug outputs remain virtual, and all six active codec pins plus all other non-debug physical pin locations/directions/I/O standards remain unchanged. No physical debug driver or introduced pin conflict. Source-integrity checks found no changes during compilation, and the post-build bank-preservation check passed again.

Production **`output_files/Lab1Demo.sof`**, generated **2026-10-23 00:40:45 +03:00**, **6,690,369 bytes**.

SHA-256: **`C07687847A3F4B4CCAA1075C7F96D83A22CAAC202ACF622CCD89907406ACA8DB`**.

Rollback: `db/cursed_audio_baseline/output_files/Lab1Demo.sof`, SHA-256 **198FAFF0D32184327CA0840E23EB281E0093B8F881E3DCAA1084FBF2DDA57C09**. Previous reports and original songs.mif are preserved; rollback checksum reverified after assembly.

## Hardware test

At low speaker gain (avoid headphones initially), program only the final checksum-identified SOF. Collect a nonfatal Cursed relic: expect a short E5/E-flat5/B4/A4 descent and no sustained tone afterward. Repeat pickups; test higher-priority defeat/victory interruption and Enter restart. Fatal Cursed collection can invoke Defeat instead, by unchanged priorities. Compare Ruby/Sapphire/start/direction effects. Mute promptly if persistent noise recurs and record the SOF hash/action sequence; the rollback remains available. No agent board programming/listening is claimed.

One focused local commit after successful verification, excluding unrelated working-tree files and generated build/rollback artifacts. No push or cleanup.
