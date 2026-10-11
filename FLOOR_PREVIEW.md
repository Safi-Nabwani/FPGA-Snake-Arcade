# Phase 3A.3 — Detailed Arena Floor Preview

2026-10-11. **Preview only; awaiting visual approval.** Based on committed Phase 3A.2 (`7fff9be`) and the current working copy. No active asset, RTL, BDF, QSF, collision mask or gameplay changes. No Quartus run, FPGA programming, commit or push.

## Deliverables

All new work is isolated in `assets/jungle/floor_preview_3a3/`:

- `ancient_stone_24.png`, `mossy_stone_24.png`, `cracked_stone_24.png`, `engraved_stone_24.png`: final opaque **24×24 RGB332** preview tiles.
- `tile_comparison_4x.png`: each final tile enlarged to 96×96 using nearest-neighbor, with labels.
- `gameplay_mockup_640x480.png`: exact display/arena proportions and the existing obstacle, snake, relic and HUD art. Illustrative gameplay pose, not a simulation or board capture.
- `floor_distribution_map.png`: numbered variants; gold crossed outlines mark unchanged obstacle cells.
- `floor_selection_map.json`: reproducible fixed 20×18 map and clockwise tile rotations.
- `build_preview.py`, `source/*.png`, `PROMPTS.md`: preview-only regeneration script, retained image-generation drafts, and complete selected prompts. Image-generation skill/built-in mode provided stone artwork; deterministic sampling/palette conversion provided the native previews. Generation drafts are not the approval target.
- `verification.json`: dimensions, exact palette/pixel counts, map checks and active RTL/MIF hashes.

## Tile designs and palette

Ancient Stone uses a single worn slab with uneven chipped edges, mineral highlights and shallow shaded depressions. It is the quieter dominant variant. Mossy Stone adds irregular damp seams and muted olive growth. Cracked Stone has deeper asymmetric branching fractures and broken-chip highlights. Engraved Stone has recessed, eroded angular carvings rather than glowing symbols.

Native pixels—not high-resolution drafts—are the source of truth for any later MIF conversion. The script samples to 24×24 with nearest-neighbor, expands source contrast (2.4× Ancient Stone; 1.2× others), then maps every pixel to the following exact palette without dithering or antialiasing:

| RGB332 code | Nominal RGB preview | Use |
| --- | --- | --- |
| `00` | (0,0,0) | Deep cracks/carvings only |
| `24` | (36,36,0) | Warm crevices |
| `25` | (36,36,85) | Cool charcoal shade |
| `49` | (73,73,85) | Dominant dark-gray stone |
| `6D` | (109,109,85) | Muted stone edges/chips |
| `28` | (36,73,0) | Moss shade |
| `48` | (73,73,0) | Weathered olive |
| `4C` | (73,109,0) | Moss detail |

RGB expansion is R/G = level×255÷7, B = level×255÷3, rounded down. `FF` remains reserved for transparency and is absent from the opaque floor tiles. Stronger bright-yellow highlights were removed after the first native-size inspection. Ancient Stone excludes pure-black pits; Mossy Stone also avoids pure black to reduce visual noise. RGB332 cannot reproduce a smooth neutral dark-gray ramp, so shadows retain a modest blue/olive cast. These are nominal RGB332 previews; the project's existing DAC bit mapping and the physical monitor may affect perceived colors. Neither is changed here.

## Fixed distribution

Seed: **20261011**. Row-major variants: 0 Ancient, 1 Mossy, 2 Cracked, 3 Engraved. The diagram labels them 1–4. Seeded shuffling plus deterministic quota-preserving swaps removes uniform 2×2 patches, horizontal/vertical four-cell runs, and six-cell AB alternation. Short natural adjacent groups remain. Seeded quarter-turn rotations reduce recurring texture orientation using the existing floor rotation concept.

Whole 360-cell map: **162 / 90 / 72 / 36**, exactly **45% / 25% / 20% / 10%**. Of the 330 walkable cells, counts are **149 / 82 / 66 / 33** (45.15% / 24.85% / 20% / 10%). The remaining 30 floor choices are covered by the original opaque obstacle tiles, not new obstacles.

## Verification and later implementation concerns

- Preview builder passed: four native-sized legal-palette tiles, exact quotas, pattern checks and 640×480 scene dimensions.
- All **30 obstacle tile crops** match current MIF pixels and descriptor rotations byte-for-byte. Positions and collision/spawn maps are untouched.
- Snake and relic sprites are decoded directly from active MIFs, with unchanged transparency. The illustrative pose/relics avoid all obstacles and each other.
- HUD uses current RTL label glyphs, actual numeric font MIF, current color constants, label/digit positions and panel/dividers. Arena stays 20×18 at (144,24), cell size 24; HUD stays left of the arena.
- Before/after SHA256 comparison found **every tracked file unchanged**, including the already-modified QSF. Its existing 67 SignalTap assignment deletions, local QWS and existing Python cache remain untouched.
- Four PNGs still imply four 576-byte floor ROMs; rotations/map can fit the existing approach, but no HDL integration, resource or timing claim is made in this preview phase.
- Original obstacle tiles contain their own opaque surrounding floor tones. They remain visible as supplied; matching those surrounding tones more closely would require separate authorization to alter obstacle art, not a silent floor-preview change.

Approve the **native tile comparison and full-scene mockup** before any MIF/map implementation. This phase stops here.
