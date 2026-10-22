# The Temple's Curse — approved opening-region art for Codex

This ZIP contains ONLY two ready-to-integrate graphics patches for the EXISTING opening-screen ROM. The complete preview is **reference only**. Do NOT add a second full-screen image, new ROM, runtime overlay or sprite storage.

## Assets
- `title_264x108.png` — native 264x108 RGB332-quantized title patch.
- `start_prompt_296x34.png` — native 296x34 RGB332-quantized start-prompt patch.
- Matching `.rgb332.bin` files — exact one-byte-per-pixel ROM data (not compressed).
- `opening_640x480_preview.png` — appearance after applying just these two regions to the current supplied original screen reference.
- `manifest.json` — ROM addresses, dimensions, SHA256 hashes and verification.

## Apply to the current project
Use `RTL/mifs/opening_supplied_atlas.mif` (8 bits wide, 104476 deep) and the existing render path. Make surgical changes to these TWO contiguous inclusive address ranges only:

| Region | Screen rectangle (x,y,w,h) | ROM byte addresses | Row stride |
| -- | -- | -- | -- |
| Title | 264,58,264,108 | 14880..43391 | 264 |
| Start | 244,414,296,34 | 94412..104475 | 296 |

For a given patch pixel `(x,y)`, the ROM address is `start + y*stride + x`. The corresponding byte is supplied in the `.rgb332.bin` file. The exact address sequence is already row-major.

Preserve all ROM pixels outside these ranges, existing HUD, controls, relics, menu rendering logic, timings and memory dimensions. Do not introduce image scaling or another graphics layer. If a source-generation script will overwrite the slots, update the existing asset pipeline to reapply these patches **after** earlier asset-generation steps.

Verify that (1) both patches are loaded by the ACTIVE production MIF, (2) all non-patch ROM words are unchanged, (3) 8x104476 ROM dimensions are unchanged, (4) rendered preview matches the supplied visual at the two slots. Do not assume historical source PNGs match current active artwork.

For release, follow the established workflow: one quiet Quartus build if hardware-ready release requested, mandatory pin safety (AG30 reserved, nine graphics-debug pins virtual), positive timing; one descriptive LOCAL Git commit after successful verification, NEVER push without approval. Do not commit generated build output unless already tracked by repository convention.

The supplied preview is a visual reference, NOT proof of the current full-screen ROM composition. The patch binaries and verified rectangle addresses are authoritative. Physical hardware colors must be confirmed on board.
