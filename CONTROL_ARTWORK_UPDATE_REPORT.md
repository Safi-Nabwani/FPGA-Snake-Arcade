# Control artwork update

Date: 2026-10-22, Asia/Jerusalem. Status: **PASS — updated production SOF ready for user hardware testing.**

## Changes

- `RTL/mifs/opening_supplied_atlas.mif`: keycap interiors show 8 (top), 4 (left), 6 (right), 5 (bottom). Guide now reads `8 UP  5 DOWN`, `4 LEFT 6 RIGHT`, `ENTER START/RESTART`. Start prompt is `PRESS ENTER TO START`.
- `RTL/mifs/results_v3/results_tilemap.mif` and `results_tiles_rgba9.mif`: Victory and Defeat restart prompts now read `PRESS ENTER TO RESTART`, replacing `PRESS 5 TO RESTART`. The shared lossless tile dictionary is repacked; decoded changes are restricted to the two existing restart text boxes.
- `scripts/update_control_artwork.py`: reproducible native RGB332 instruction edit and actual-ROM verification, reusing the project's 5x7 pixel-font forms. No generated replacement artwork or changes to supplied source PNGs.
- Actual-ROM previews and `verification.json`: `assets/jungle/control_artwork_update/` (opening, Victory, Defeat at 640x480; opening 2x; results panels).
- This report.

No RTL/BDF/QSF, keyboard behavior, gameplay, audio, HUD, sprites, arena or timing settings were modified. Existing unrelated working-tree changes are preserved. No commit, push or FPGA programming.

## Focused verification

`python -B scripts/update_control_artwork.py` passed after installation, checking all active ROM words and reconstructing complete output images. Opening changes: 11,296 pixels; Victory: 1,259; Defeat: 1,038. All changes lie within documented instruction boxes, all results alpha bits are unchanged, and all ROM widths/depths stay unchanged (opening 8x104476; map 15x62208; payload 9x69628). Rendering address layout and pipeline latency are unchanged; no new ROM or drawing stage was introduced.

Active production references are `End_Message_Display.sv` → `opening_supplied_atlas.mif`, and its included `results_report_renderer.svh` → the two `results_v3` MIFs. The completed map report confirms all three edited MIFs were loaded from this workspace. Broad simulations were not run because only ROM pixel data changed. Use `scripts/update_control_artwork.py` for the focused verification; historical supplied-art converters still describe the archived original labels.

## Production build and pin safety

One quiet production map/fit/STA/assembler flow completed successfully, Quartus Prime Lite 17.0.0 Build 595, `Lab1Demo`, Cyclone V `5CSXFC6D6F31C6`. **Zero errors** in all four stages; warnings map/fit/STA/assembler **240/89/51/0**, unchanged counts. Stage logs: `db/control_artwork_build/`.

All four timing corners pass. Worst constrained setup **+5.332 ns**, hold **+0.159 ns**, all TNS zero, unchanged from the keyboard-remap release. Existing incomplete external-I/O constraints remain; this is not full external-interface timing sign-off.

Mandatory audit:

```text
python -B scripts/verify_audio_pin_safety.py output_files/Lab1Demo.pin --compare db/control_artwork_baseline/output_files/Lab1Demo.pin
```

**AUDIO_PIN_SAFETY_PASS**: AG30 remains `RESERVED_INPUT_WITH_WEAK_PULLUP`; all nine graphics-debug outputs remain virtual, with none driving physical pins. All six active codec pins and every other non-debug physical pin location/direction/I/O standard match the saved fit, including keyboard ports. No physical pin conflict was introduced. Audit log: `db/control_artwork_build/pin_safety_after.log`.

The build checked all **594** pre-existing source/working-tree paths against their precompile hashes: none changed during compilation. Approved keyboard RTL/BDF, audio, gameplay and unrelated changes remain untouched.

## SOF and rollback

Updated production **`output_files/Lab1Demo.sof`**, generated **2026-10-22 17:45:14 +03:00**, **6,690,369 bytes**.

SHA-256: **`7E12D49B4BEF204A68B0189167D6DA6EAA85DC55E3D65403CB0516F45E6EE2AB`**.

Previous working SOF retained at `db/control_artwork_baseline/output_files/Lab1Demo.sof`.

Rollback SHA-256: `7E0B52235D3C28DD15EDC3AE57F0E984D82D8DA42BE61AC4D12663111140F051` (verified before editing/building and after assembly). Previous reports and the three pre-edit MIFs are preserved under the same baseline folder.

## User hardware test

1. Program the final checksum-identified `output_files/Lab1Demo.sof` manually. After KEY0, inspect the opening: 8/4/6/5 movement guide, `ENTER START/RESTART`, and `PRESS ENTER TO START`.
2. Start with main Enter; verify Numpad 8/4/6/5 movement and that keypad 5 does not restart. Check Numpad Enter too.
3. On Victory and Defeat, inspect `PRESS ENTER TO RESTART` and test Enter restart. Statistics, artwork outside the changed labels and sounds should remain unchanged.
4. If needed, program the preserved rollback SOF; it retains the approved remapped controls but old baked-in artwork labels.

Physical FPGA display/listening is not verified by the agent.
