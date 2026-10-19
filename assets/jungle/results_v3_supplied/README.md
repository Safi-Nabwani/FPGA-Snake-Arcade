# Phase 3D — Approved Victory & Defeat Results Assets

## What you are receiving

The 640×480 preview images under `previews/` are **software composites reconstructed from the included RGB332 and one-bit-mask MIFs**. They are NOT high-resolution generative mockups and are NOT physical FPGA output. The HUD and arena surroundings are references taken from existing project preview graphics, not a verified current Quartus framebuffer.

This ZIP also includes the approved final high-resolution pictures **solely as artistic references and for provenance** under `source/approved_originals/`. Do not use those in place of the FPGA-ready ROMs.

## Actual split used by the MIF assets

The 288×432 report panel is shown at VGA (X=248..535,Y=24..455):

* `shared_lower_288x180`: panel local Y=252..431. Same relic rows, blank count wells, lower side pillars, and restart banner for both states. Based on the approved Victory lower artwork.
* `victory_upper_288x252`: panel local Y=0..251. Integrated Victory title, gold serpent, TEMPLE CONQUERED, and subtitle.
* `defeat_upper_288x252`: panel local Y=0..251. Integrated Defeat title, cursed serpent, FINAL SCORE plaque and subtitle. The sample numeral has been removed; the number field stays empty for RTL to render.

IMPORTANT: The separately approved originals differ extensively at the pixel level even in their common-looking lower section. The optimized shared-split Defeat VGA preview uses the Victory-style shared lower and is therefore NOT pixel-identical to the approved full Defeat artwork. The independently approved 288x432 full RGB332 panels in `source/approved_vga_panels/` and `reference_full_mifs/` are the FINAL VISUAL TARGET. The split is a proposed memory optimization, not permission to redesign. Codex should compare and prefer exact approved rendering; if a shared implementation has noticeable drift, use the full reference assets or a smarter lossless sharing scheme.

## Memory vs visual fidelity

This split saves ROM space compared with storing two fully separate panels, but it is **not** the earlier 85–95 M10K allocation. We provide full per-state source MIFs as a visual-fidelity fallback, not as the recommended default storage. Colors and mask total are an ideal lower bound only, excluding physical packing and font ROM. See `manifest.json`. The previous compiled result implementation was 87 blocks, project 306/553. There should be enough FPGA memory for the proposed split, but **Codex must fit it**, compare resources, timing and existing warning issues, and must not force lossy downscaling of these approved visuals solely to hit an arbitrary target.

## Technical requirements

- Color: RGB332 (RRRGGGBB), WIDTH=8, row-major, 0..W*H-1.
- Mask: WIDTH=1, 1 opaque, 0 transparent. Never use RGB value FF as transparency for this artwork.
- Overlay pixel priority: dynamic digits > relevant report ROM fragment > underlying current game scene; outside masks and panel bounds unchanged.
- Composition: the shared lower fragment is sampled at (X-248,Y-(24+252)); state upper at (X-248,Y-24). Both run at native 1× VGA scale; these are **not scaled 2×**, and should remain crisp.
- Changing numbers: three BCD relic totals (each rendered as exactly 3 digits with leading zeroes) and Defeat final score (2 digits); none of these sample numbers are stored in the panels.
- Victory does not render a final score inside the report.
- Restart text is common and baked into shared art; it is the existing keypad 5 restart behavior.
- Preserve current correct HUD, score counters, 90-point victory logic, prior terminal-event snapshot sequencing, and the fully optimized opening screen.
- PNG transparency is binary; no anti-aliased semitransparent edges in the final MIFs.

## Acceptance and handoff

1. Verify the MIFs parse, dimensions, alpha masks, and reconstruct independently to exactly the corresponding asset PNGs. The final visual target is the full-panel source; the shared split is an optimization candidate with known lower-section differences.
2. Compare the exact 640×480 previews against approved artwork and have Codex flag any material appearance drift, unexpected overlap, or unreadable text.
3. Reuse existing display-only terminal statistic snapshot logic and preserve the last fatal Cursed pulse sequencing.
4. Package ROM data as an atlas if Quartus infers excess fragmented M10Ks; compare physical usage, timing and logic before choosing.
5. Build only after source/ROM simulations and preview validation. Never push or FPGA-program automatically.
6. Save a persistent project-root Markdown implementation report `RESULTS_SCREEN_V3_IMPLEMENTATION.md` with actual measured before/after usage and any deviations.

`previews/*_BLANK_VALUES.png` are authoritative static rendering checks; `previews/*_SAMPLE_VALUES.png` show illustrative digits that must be rendered using the actual existing project font on hardware.
