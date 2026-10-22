# Approved opening artwork integration

2026-10-22, Asia/Jerusalem. Status: **PASS — approved artwork integrated; production SOF ready for user hardware verification.**

## Assets and pixel accuracy

Supplied ZIP contents retained unchanged under `assets/jungle/approved_opening/`. Authoritative binaries replace only title words **14880–43391** (264x108) and start-prompt words **94412–104475** (296x34) in `RTL/mifs/opening_supplied_atlas.mif`. Supplied SHA-256 values passed. Every other ROM word is identical to the pre-edit ROM; width 8, depth 104476, offsets and strides remain unchanged.

`scripts/integrate_approved_opening.py` installs/verifies the patches and reconstructs `assets/jungle/approved_opening/active_rom_640x480.png`. Its full scene matches the supplied preview in RGB332, including the unchanged HUD and controls. Exact title spelling is THE TEMPLE'S CURSE; prompt is PRESS ENTER TO START. No artwork was generated, redrawn or recolored.

The supplied PNGs use rounded preview channel levels (e.g. 73), whereas the existing preview helper expands some levels downward (72). Both encode to identical RGB332 bytes; the binary data is used verbatim. This is a preview-expansion difference, not a ROM discrepancy.

Historical writers in `implement_supplied_opening.py` and `implement_results_v3.py` now refuse to overwrite the approved opening when this pack is present. This also protects against the previous control/title scripts, which import the latter writer. Use the new integration script as the final authoritative asset stage. No rendering/keyboard/gameplay/audio/timing logic was changed.

## Release

One quiet production Quartus Prime Lite 17.0.0 Build 595 map/fit/STA/assembler build completed with **zero errors in every stage**. No retries, broad simulations or warning investigations. Logs retained in `db/approved_opening_build/`.

Memory is unchanged at **429/553 M10Ks** and **3,405,308 bits**. All four setup/hold corners pass; worst setup **+5.332 ns**, hold **+0.159 ns**, all TNS zero. Existing external-I/O constraint limitations remain; this is constrained internal timing closure, not complete external-interface sign-off.

Mandatory final-fit audio pin audit **PASS**: AG30 remains reserved input with weak pull-up; all nine graphics-debug outputs remain virtual; all codec/keyboard/non-debug physical pin locations, directions and I/O standards match the saved fit. No physical debug driver or introduced pin conflict.

Production **`output_files/Lab1Demo.sof`**, generated **2026-10-22 22:30:20 +03:00**, **6,690,369 bytes**.

SHA-256: **`474A3B5CFD83A1B1DA10B213F1CC909F0CA401C7B8DA91FA0910B8CC7AC218F3`**.

Rollback SOF and reports: `db/approved_opening_baseline/output_files/`. Original SOF SHA-256: `A197DFC6A76BEAEF10FE9A9B7052C23EEB2E3B4A9CFB416D9628C728A7D215D8`. Exact pre-edit ROM retained alongside these outputs.

## Hardware acceptance

Manually program the final checksum-identified `output_files/Lab1Demo.sof`. After KEY0 compare title/prompt to the supplied preview; check Enter start/restart and keypad 8/4/6/5 movement. Existing HUD, relics, results screens and sound should be unchanged. Use low speaker gain for initial checks; rollback is preserved if needed. No board programming or physical verification is performed by the agent.

The focused local commit includes the supplied pack, actual-ROM preview, integration script, two historical-writer guards, only the two approved ROM spans and this report. Index construction preserves HEAD's words outside those spans, excluding the pre-existing uncommitted control-art edits there. The release SOF is built from the current working tree, including the previously approved uncommitted remap; the focused commit alone does not capture those earlier changes. The working tree intentionally retains them and unrelated QSF/BDF/files. Generated Quartus artifacts and rollback backups are excluded. No push or FPGA programming.
