# Relic Refinement — Preview Only

Date: 2026-10-10. Follow-up to the approved Phase 3A.1 art direction.

## Result

Only relic artwork is refined. Ruby is an angular red cut gem with exposed crimson/burgundy facets instead of the round gold bezel. Sapphire is a pointed blue crystal with a strong cyan facet and reduced gold support. Cursed is an asymmetric cluster of broken purple/obsidian shards with bright lilac cutting edges, rather than another diamond-shaped gem.

The three sources were created with the built-in image-generation tool using the imagegen skill; PNG fitting and scene composition are mechanical. No active FPGA asset or project source is edited.

## Updated previews

Folder: `assets/jungle/previews_v3_relics/`. The approved `previews_v2/` folder and PREVIEW_REDESIGN.md are preserved.

- [Refined relic sheet](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/assets/jungle/previews_v3_relics/relic_sheet.png)
- [Before/after comparison](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/assets/jungle/previews_v3_relics/relic_comparison.png): previous above, refined below.
- [Updated full scene](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/assets/jungle/previews_v3_relics/full_scene.png): 640×480.
- [2× full scene](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/assets/jungle/previews_v3_relics/full_scene_2x.png): 1280×960, nearest-neighbor.
- `full_scene_rgb332.png`: diagnostic only; carries the same unfinished palette conversion limitations as Phase 3A.1.

Separate files for each of `ruby_relic`, `sapphire_relic`, `cursed_relic`:

- `<name>_24.png`: native 24×24 RGBA preview.
- `<name>_8x.png`: 192×192 nearest-neighbor enlargement.
- `source/<name>.png`: selected generated original.

Total: 14 new PNGs and this report. No unrelated asset is regenerated into the project. A temporary composition helper remains outside the repository.

## Scale, geometry and verification

All three relics retain a centered **18×20 occupied bounding box inside a 24×24 cell**, X [3,21), Y [2,22). Changes are silhouette/facets/outline/highlights, not size or placement.

Positions remain Ruby (7,3), Sapphire (5,10), Cursed (12,6), in zero-based arena cells. The scene remains 20×18 cells at (144,24), with the approved floor distribution, proposed 30-obstacle layout, snake pose, sidebar structure, font glyphs and displayed values unchanged.

An exact comparison of every visible pixel against previews_v2/full_scene.png finds **753 changed pixels, all inside the three existing relic cells**. Every pixel outside those cells is identical, including HUD, arena floor, ruins, serpent and margins. Inspected the native-size assets, enlarged comparison and full scene.

SHA-256 comparison of all **112 tracked starting files** finds zero changes. Earlier untracked preview/report deliverables are retained. No Quartus or ModelSim run, no board programming, no commit or push.

## Remaining implementation boundaries

These are approval previews, not MIF-ready replacements. RGB332 palette simplification and non-FF highlights still need later verification. Generated sources do not strictly meet the requested seven-color limit; native PNGs are high-color concept previews. The new relic alpha masks differ from production masks, so the collision-preservation strategy documented in PREVIEW_REDESIGN.md still applies. Do not copy these shapes directly into active MIFs without approved collision-mask handling.

No scoring, counters, effects, geometry, navigation or spawn behavior changes were made. The approved art direction does not authorize FPGA implementation in this pass.

## Exact selected-source prompts

Ruby and Sapphire use their previous source PNG as edit target. The first Cursed edit retained too much diamond symmetry; the selected Cursed source is a fresh shard concept with no reference image. All outputs requested actual transparency.

### ruby_relic

Use case: precise-object-edit. Input image 1: EDIT TARGET, existing relic sprite. Refine ONLY this relic, keep Jungle Temple pixel-art palette direction and same isolated centered object role. Ruby: a CUT RED GEMSTONE with an angular clipped-corner hexagonal silhouette, broad flat top facet, pointed lower vertex, 4 sharply divided crimson scarlet and deep burgundy triangular facets. A strong pale pink 2pixel diagonal highlight on upper-left facet, black-maroon outline. Remove the rounded gold bezel entirely; at most two tiny gold support pixels below. No apple silhouette. Create true logical24x24 low-resolution PIXEL ART enlarged with crisp large square blocks. Sprite silhouette must occupy18x20 logical pixels centered inside24x24, unchanged gameplay proportions. Facet boundaries must be broad straight diagonal lines with clearly separate flat light/mid/dark planes surviving nearest-neighbor downsample to24x24. Limit to7 flat colors; 1logicalpixel very dark continuous outline and a small bold 2pixel highlight. Strong angular gem silhouette, NOT rounded fruit, glossy ball or smooth3D. Do not add text, labels, watermark, surroundings, extra objects, background shadow, haze, bloom, smooth gradient or tiny decorative noise. Actual transparent background. Preserve transparency outside sprite. This is PREVIEW ONLY.

### sapphire_relic

Use case: precise-object-edit. Input image 1: EDIT TARGET, existing relic sprite. Refine ONLY this relic, keep Jungle Temple pixel-art palette direction and same isolated centered object role. Sapphire: a FACETED BLUE CRYSTAL, elongated double-pointed diamond silhouette, sharp left/right vertices, prominent icy cyan upper-left triangular facet, cobalt central planar face, navy right face; black-navy outline and one tiny cream-blue specular glint. Remove broad base and pedestal, at most two tiny gold support pixels below. No rounded contour. Create true logical24x24 low-resolution PIXEL ART enlarged with crisp large square blocks. Sprite silhouette must occupy18x20 logical pixels centered inside24x24, unchanged gameplay proportions. Facet boundaries must be broad straight diagonal lines with clearly separate flat light/mid/dark planes surviving nearest-neighbor downsample to24x24. Limit to7 flat colors; 1logicalpixel very dark continuous outline and a small bold 2pixel highlight. Strong angular gem silhouette, NOT rounded fruit, glossy ball or smooth3D. Do not add text, labels, watermark, surroundings, extra objects, background shadow, haze, bloom, smooth gradient or tiny decorative noise. Actual transparent background. Preserve transparency outside sprite. This is PREVIEW ONLY.

### cursed_relic

Use case: stylized-concept. One standalone CURSED RELIC game sprite on genuine transparent background. It is a JAGGED cluster of THREE UPRIGHT BROKEN OBSIDIAN SHARDS joined at a rough FLAT CHIPPED BASE. Tall main shard leans left, tip at upper-left; shorter thin shard at right with a broken diagonal top; stubby fractured shard at lower-left. UNEQUAL heights and irregular sharp outer contour, silhouette is like broken glass rising upward. NOT a diamond, NOT a star, NOT a gemstone symmetrical top/bottom, NOT rounded, NO lower downward point, NO octahedron. Broad dark-purple planar faces, one bright lilac diagonal cutting edge, magenta fracture. Thick continuous very dark purple outline. Low resolution logical24x24 PIXEL ART enlarged crisp squares; whole cluster18x20 pixels centered,3pixels horizontal and2pixels vertical padding. Few BIG contrasting angular facets, maximum7 discrete flat colors. Keep purple/black palette matching Temple of the Serpent and tiny highlights readable on darkfloor. No glow, haze, shadows outside sprite, loose floating chips, gradients, smooth3D, text, gold mount or background. Show ONE isolated sprite only.

## Stop

Relic refinement previews complete. Await approval before FPGA asset implementation.

