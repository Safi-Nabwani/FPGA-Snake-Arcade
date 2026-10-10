# FPGA Snake — Phase 3A.1: Visual Redesign Preview

Date: 2026-10-10. Scope: **approval previews only**, not an FPGA implementation.

Read PROJECT_MAP.md, ARENA_ENLARGEMENT.md, HUD_RELIC_COUNTERS.md, TIMING_REPAIR.md and JUNGLE_GRAPHICS.md. Inspected jungle-temple-reference.png and the current asset sheet. Older geometry in PROJECT_MAP.md is historical; the completed arena/HUD reports take precedence.

## 1. Deliverables and scope

New files are this report and **50 PNGs** under `assets/jungle/previews_v2/`. Existing files are not modified. No active MIF, RTL, BDF, QSF, SDC, collision map, gameplay, font, reference image or older preview is replaced. No Quartus/ModelSim compilation, FPGA programming, Git commit or push is performed.

Main approval image: [full_scene.png](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/assets/jungle/previews_v2/full_scene.png), **640×480**.
[full_scene_2x.png](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/assets/jungle/previews_v2/full_scene_2x.png) is an exact nearest-neighbor enlargement to 1280×960.

Supporting sheets:

- [floor_sheet.png](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/assets/jungle/previews_v2/floor_sheet.png): four floor variants, 896×232.
- [snake_sheet.png](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/assets/jungle/previews_v2/snake_sheet.png): UP/RIGHT/DOWN/LEFT head and body, 1120×232.
- [relic_sheet.png](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/assets/jungle/previews_v2/relic_sheet.png): three relics, 672×232.
- [obstacle_sheet.png](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/assets/jungle/previews_v2/obstacle_sheet.png): block, broken wall and pillar, 672×232.
- [proposed_obstacle_map.png](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/assets/jungle/previews_v2/proposed_obstacle_map.png): 480×432; blocked cells in tan, safe starting region outlined green, starting cell outlined gold.
- `full_scene_rgb332.png`: **diagnostic palette-feasibility preview, NOT the recommended final art or a hardware capture**. See section 7.

Separate native assets are 24×24 RGBA PNGs, each with a 192×192 nearest-neighbor inspection copy. Exact stems are:

```text
floor_base
floor_mossy
floor_cracked
floor_carved
snake_head_up
snake_head_right
snake_head_down
snake_head_left
snake_body
ruby_relic
sapphire_relic
cursed_relic
ruin_block
ruin_wall
ruin_pillar
```

For each stem, filenames are `<stem>_24.png` and `<stem>_8x.png`. Twelve selected high-resolution generated originals are retained as `source/<stem>.png`: the four floors, upward head, body, three relics and three obstacles. The other head directions are exact rotations of the selected upward preview, not separate inconsistent designs.

No dedicated tail sprite is included: the current renderer uses the body bitmap for every trail segment and has no dedicated tail renderer. The mockup retains that approach. Adding a tail is not required for this proposal.

The scene is an **illustrative pose**, not a simulation screenshot or faithful sample of the six-frame trail spacing. It displays score 12, high score 19 and counts 012/000/000; the 16 illustrated snake cells are consistent with initial length four plus twelve Ruby collections. All three relics are shown for comparison; Sapphire is hidden at actual new-game initialization. No end-message overlay is shown.

## 2. Geometry and unchanged HUD structure

Arena: 20 columns ×18 rows, each 24×24, origin (144,24).
Bounds: X [144,624), Y [24,456); extent 480×432.
All illustrated objects are composed inside their cell; no artwork extends outside the arena.

Sidebar remains X [8,128), Y [24,456), with the same two-pixel border and dividers at Y=100/192. This leaves the original 16-pixel gap before the arena. Existing label shapes are read from hud_labels.sv; numeric glyphs are read from the actual numbers_new_font.mif. No label or digit is moved, enlarged or replaced.

| Element | Preview position / dimensions |
| --- | --- |
| SCORE label | (16,40), 60×14 character box |
| Current score | (48,64), two 16×32 digits |
| HIGH / SCORE labels | (16,112) / (16,128), 48×14 /60×14 |
| High score | (48,148), two 16×32 digits |
| RELICS | (16,208), 72×14 |
| RUBY / count | (16,240), 48×14 / (40,260), 48×32 |
| SAPPHIRE / count | (16,308), 96×14 / (40,328), 48×32 |
| CURSED / count | (16,376), 72×14 / (40,396), 48×32 |

Only preview colors change: dark green stone panel, restrained antique-gold border, pale readable score text and softer red/cyan/violet labels/counts. No decorative HUD redesign is implemented.

## 3. Recommended palette and hierarchy

Recommended high-color art direction, not final RGB332 codes:

| Role | Color direction |
| --- | --- |
| Exterior / negative space | Almost-black forest, approximately #0C1713 |
| Floor | Charcoal-olive #252C29, #30382F, #3C4438 |
| Moss | Restrained dark forest / olive #3C5030 |
| Obstacles | Warm grey stone #4A4C40–#82816A, near-black edge |
| Snake | Emerald #1C9E50, deep green #0D442C, lime #70D85C |
| Snake accents | Small gold / cream highlights; no all-over gold outline |
| Ruby | Crimson/red with a small warm highlight and dark bezel |
| Sapphire | Saturated blue with cyan highlight |
| Cursed | Obsidian/violet with bright violet fissures |
| HUD | Pale cream #E9DBA3 and muted gold #D8BD72; colored relic labels |

Broad, dark floor surfaces keep the eye on the serpent. Relics have distinct silhouettes as well as colors: Ruby bezel gem, Sapphire diamond, Cursed jagged crystal. Obstacles have solid raised outlines/bevels, while carved floor tiles remain flat and recessed. Floor highlights never compete with the brightest object highlights.

The reference supplies stone/moss, emerald and antique-gold styling only. Its horizontal HUD, large exterior structures and original arena proportions are not copied.

## 4. Floor distribution

Counts below cover the **330 walkable cells**, including those underneath illustrated objects. Obstacle cells have hidden base floor underneath and are not included in these ratios.

| Variant | Cells | Share |
| --- | ---: | ---: |
| Base | 174 | 52.73% |
| Mossy | 75 | 22.73% |
| Cracked | 57 | 17.27% |
| Carved | 24 | 7.27% |

Recommended approach: use a fixed authored variant map, separate from the blocked-cell map. Build connected moss patches toward damp edges and corners; concentrate cracks near ruins; scatter a few recessed accents without mirrored motifs. Do not independently randomize every cell at runtime.

The mockup uses smooth spatial patch weights and exact quotas: moss clusters near (1,2), (18,14), (5,16); cracks near (15,5), (4,10), (12,15). Carved accents use a deterministic irregular selection among remaining cells. Moss orientation follows small regions; crack orientations vary without a checkerboard. Base tiles stay quiet. These rules are only preview assembly, not gameplay logic.

## 5. Recommended obstacle concept/layout

**Proposed 30 blocked cells**, versus the currently implemented 16. This proposal does NOT alter the active renderer or spawn-exclusion map.

Coordinates are zero-based (column,row). Pixel top-left is (144+24×column,24+24×row).

| Formation | Blocked cells |
| --- | --- |
| Northwest broken L-wall, 6 | (2,3),(3,3),(4,3),(5,3),(2,4),(2,5) |
| Northeast broken L-wall, 6 | (14,3),(15,3),(16,3),(17,3),(17,4),(17,5) |
| West broken corner, 3 | (3,9),(3,10),(4,10) |
| Southeast ruin, 5 | (14,11),(15,11),(16,11),(16,12),(16,13) |
| South low wall, 4 | (6,15),(7,15),(8,15),(6,14) |
| Isolated broken pillars, 6 | (11,4),(6,7),(17,8),(11,15),(3,14),(18,14) |

The layout offers walls, low formations and isolated pillars rather than repeating one emblem. Static four-neighbor flood fill from starting cell (10,9) reaches **all 330 walkable cells**. Columns 8–12 and rows 7–11 form a clear **25-cell safe starting region** around pixel start (384,240).

All illustrated relic cells (7,3),(5,10),(12,6) are unblocked. Illustrated head/body cells are unblocked. There are 330 geometrically valid unblocked cells before snake/relic exclusions; this is not a promise of 330 simultaneously valid spawn choices. Snake navigation, turn behavior and runtime spawning are not simulated in this phase. Later implementation must update displayed and spawn-exclusion maps together and verify their equality.

## 6. Snake head improvement

The first generated candidate still resembled a narrow ornate mask at actual size and was rejected. The selected candidate uses a broad, simple skull, short snout, two large pale-gold eyes with dark pupils and far fewer decorative details.

The preview head's occupied bounding box is **X [2,22), Y [1,23)** within its 24×24 cell: 20×22, centered at (12,12). The body is 16 pixels wide. A darker outline separates the head from floor; bright emerald cheeks and eyes give it stronger visual importance than a body segment. Neck exits the back, not the snout. Four directions are exact quarter-turns, maintaining centering and padding.

The illustrative head is at existing start cell (10,9), top-left (384,240), center (396,252). This is a visual centering check only. The active 22×24 square-object clipping and its pipeline have NOT been repaired.

## 7. Technical concerns before implementation

1. **RGB332 cannot reproduce the main concept palette exactly.** Blue has only four levels; direct quantization of dark near-neutral stone produces objectionable blue/olive speckling. The diagnostic full_scene_rgb332.png uses an exploratory restricted dark floor palette and conventional RGB332 rounding elsewhere. It still shows collapsed detail, quantization noise and color shifts, especially around occupied-cell backgrounds. It is not a finalized encoding algorithm or recommended production output. A future pass must hand-curate discrete RGB332 ramps, remove sub-pixel gradients/noise, and inspect all tiles at native size before MIF conversion. The high-color main mockup approves hierarchy/material direction, not exact hardware colors.
2. **Collision masks:** the proposed broad head and new relic silhouettes do not preserve the original FF masks. Existing head/relic DRs participate in collection/collision detection. Do not simply replace MIFs and claim gameplay preservation; choose a separately approved collision-versus-visual mask strategy, or fit approved art to the old masks with their known limitations. Keep 0xFF exclusively transparent in sprite ROMs.
3. **Head clipping/alignment:** existing schematic clips a 24×24 head ROM to 22×24. Later work needs a scoped rectangle/pipeline investigation and streaming rotation/alignment tests, not merely a larger source image. Mixed legacy rendering/collision latencies remain.
4. **More floor/obstacle art:** current two-bit tile IDs cannot directly encode four floor variants plus obstacle classes. Plan either wider visual tile indexing or a separate visual variant selector while retaining an independent authoritative blocked-cell map. Four floor +three obstacle 24×24×8 payloads total 32,256 logical bits; physical RAM allocation cannot be inferred from that number.
5. **Obstacle gameplay scope:** adopting 30 instead of16 blocked cells changes navigation/spawn space. Approval of a picture is not permission to silently replace the production map. Update renderer and validator consistently and repeat all-cell range/reachability/spawn checks in a later authorized phase.
6. **Body pose:** this grid-aligned mockup is not a frame-accurate depiction of the original historical-position trail, speed-dependent spacing or corner overlap. Later native streaming tests and actual output inspection are still needed.
7. **No new timing/resources claim:** no compile was run. Previous constrained timing closure remains documented in TIMING_REPAIR.md/JUNGLE_GRAPHICS.md, not reverified for future proposed changes. Their incomplete external timing constraints, unverified debug pins, stale SignalTap probe, VGA quirks and end-screen overlap remain.
8. No new ROM registration, MIF conversion, production asset-generation run, module renaming, tail renderer, decorative HUD or end-screen work occurs here.

## 8. Verification and preservation

- Checked PNG output dimensions and native 24×24 sprite/tile sizes.
- Inspected assembled main scene, head rotation sheet, floor sheet, obstacle sheet and RGB332 feasibility image.
- Static checks assert 30 unique in-range obstacles, connected 330-cell walkable map, 25-cell clear starting region, exact floor quotas and unblocked illustrated snake/relic placement.
- Read actual HUD labels and all 8192 numeric font bits without editing either source.
- SHA-256 comparison of **all 112 starting tracked files** found **zero modifications**, including all active assets, reports and the reference image.
- Starting working tree was clean. New untracked deliverables are this report and the separate previews_v2 folder only.
- No RTL simulations or Quartus builds; no hardware testing or pixel-perfect FPGA output claim.

## 9. Artwork generation provenance and prompt set

Used the built-in image-generation tool per the imagegen skill, not an external API/CLI. Selected PNG originals are retained. AI generation is nondeterministic; mechanical native-size fitting, rotation and scene composition used Pillow without touching active assets. A temporary assembly helper was kept outside the project; no project scripts or configuration were changed.

Prompts below are the exact final generation prompts for each selected source. The reference image was a style input for every selected asset except the refined head and carved floor, whose simpler prompts deliberately omitted it. Transparency was requested for snake/relic/obstacle sources; floors are opaque. Sprite alpha is retained for the preview, not forced into historical collision masks.

### floor_base

Use case: stylized-concept. Asset type: Jungle Temple game tile preview. Input image 1 is STYLE REFERENCE ONLY, not geometry. One full-square base stone floor tile, dark charcoal olive weathered stone slab, quiet broad flat shading, only two tiny edge chips, thin dark seam, no moss, no carving. Style: hand-placed LOW resolution pixel art, logical 24x24 pixels enlarged as crisp square blocks, no dithering, no texture noise, NO photographic detail, no antialiasing or gradient. Palette: floor mostly #252c29, #30382f, #3c4438; quiet subdued moss #3c5030. Floor deliberately dark low-contrast so emerald serpent and red/blue/violet gems dominate. Flat orthographic overhead view. Square tile fills complete image without margins; no background scene, text, labels, border frame or watermark.

### floor_mossy

Use case: stylized-concept. Asset type: Jungle Temple game tile preview. Input image 1 is STYLE REFERENCE ONLY, not geometry. One full-square dark charcoal olive stone floor tile, quiet flat center, restrained moss in two connected corner patches occupying about a quarter of tile, low contrast muted forest green, thin dark seam. No speckles. Style: hand-placed LOW resolution pixel art, logical 24x24 pixels enlarged as crisp square blocks, no dithering, no texture noise, NO photographic detail, no antialiasing or gradient. Palette: floor mostly #252c29, #30382f, #3c4438; quiet subdued moss #3c5030. Floor deliberately dark low-contrast so emerald serpent and red/blue/violet gems dominate. Flat orthographic overhead view. Square tile fills complete image without margins; no background scene, text, labels, border frame or watermark.

### floor_cracked

Use case: stylized-concept. Asset type: Jungle Temple game tile preview. Input image 1 is STYLE REFERENCE ONLY, not geometry. One full-square dark charcoal olive stone floor tile, just one branching dark diagonal crack with three short segments, quiet flat broad surface, thin dark seam. No rubble, no speckles. Style: hand-placed LOW resolution pixel art, logical 24x24 pixels enlarged as crisp square blocks, no dithering, no texture noise, NO photographic detail, no antialiasing or gradient. Palette: floor mostly #252c29, #30382f, #3c4438; quiet subdued moss #3c5030. Floor deliberately dark low-contrast so emerald serpent and red/blue/violet gems dominate. Flat orthographic overhead view. Square tile fills complete image without margins; no background scene, text, labels, border frame or watermark.

### floor_carved

Use case: stylized-concept. Asset type: ONE walkable carved STONE FLOOR TILE for 24x24 low-resolution pixel-art game. A single flat dark charcoal-olive slab, entire image filled by ONE square slab, thin one-logical-pixel dark seam around perimeter. Center shows ONE small subtle recessed square-spiral ancient serpent engraving about8x8 logical pixels, lightly lighter or darker than the floor, NOT raised. Floor colors only #252c29 #30382f #3c4438 #424937. Tiny edge chip in one corner, otherwise quiet smooth stone broad flat color clusters, VERY LOW contrast. Show the24x24 logical pixels enlarged with crisp square blocks. Strict top-down orthographic. No bricks, horizontal masonry joints, moss, bevel, gold, pillars, walls, borderframe, foreground objects, text or watermark. This tile must look clearly WALKABLE not an obstacle. No photographic detail, no texture speckles, no gradients, no antialiasing.

### snake_head_up

Use case: stylized-concept. Asset type: a single 24x24-pixel snake HEAD sprite, shown enlarged with crisp square pixels on actual transparent background. Primary request: UNMISTAKABLE BROAD emerald green snake head viewed strictly from ABOVE, pointing UP. Very simple rounded RECTANGULAR skull 20 logical pixels wide and20 pixels tall, broad short flat-rounded snout at top, just2pixels of narrow neck at bottom. Fill almost the whole square. TWO unmistakable large CREAM-YELLOW EYES with BLACK vertical pupils at logical coordinates (6,7) and(17,7), symmetrically near upper corners. Tiny two black nostrils at top center. Emerald solid cheeks with lime highlight, deep green shadow at bottom, ONE restrained gold brow pixel per eye. Maximum8 flat colors. Thick 1pixel nearblack outline. NO mask, NO cobra hood, NO diamond shaped face, NO long tapered snout, NO helmet, NO crown, NO decorative chevrons, NO tongue, NO scales smaller than1logicalpixel, no 3D, gradients, antialiasing, text, watermark, body or surroundings. This is a readable retro arcade low-resolution sprite, big broad head larger than16pixel body, centered20x22 silhouette with1pixel vertical padding and2pixel horizontal padding. Show ONLY one isolated head.

### snake_body

Use case: stylized-concept. Asset type: Jungle Temple game sprite preview. Input image 1 is STYLE REFERENCE ONLY. One emerald serpent body segment from directly overhead, no head or eyes, vertical rounded capsule 16pixels wide and22 tall centered in a logical24x24 cell. Emerald green scales with one subtle gold chevron near upper edge, dark green lower shading and near-black outline. Quiet big pixel clusters. Style: true LOW resolution pixel art, logical 24x24 pixels enlarged into crisp square blocks, use few big readable clusters and flat color ramps, NOT high detail illustration. Orthographic overhead game view, centered isolated single sprite, complete silhouette no cropping, transparent background. Snake palette deep green #0d442c, emerald #1c9e50, light green #70d85c, restrained gold #d8b853, outline #071a14. Gem saturated colors. No text, watermark, extra sprites, dirt or background, no smooth 3D rendering.

### ruby_relic

Use case: stylized-concept. Asset type: Jungle Temple game sprite preview. Input image 1 is STYLE REFERENCE ONLY. One Ruby relic icon, centered red faceted hexagonal gem in small antique gold bezel, bright crimson facets with tiny warm highlight, black outline, logical24x24 tile with relic occupying18x20 pixels. No apple, no stem, no crown, no glow beyond tile. Style: true LOW resolution pixel art, logical 24x24 pixels enlarged into crisp square blocks, use few big readable clusters and flat color ramps, NOT high detail illustration. Orthographic overhead game view, centered isolated single sprite, complete silhouette no cropping, transparent background. Snake palette deep green #0d442c, emerald #1c9e50, light green #70d85c, restrained gold #d8b853, outline #071a14. Gem saturated colors. No text, watermark, extra sprites, dirt or background, no smooth 3D rendering.

### sapphire_relic

Use case: stylized-concept. Asset type: Jungle Temple game sprite preview. Input image 1 is STYLE REFERENCE ONLY. One Sapphire relic icon, centered vivid sapphire blue diamond crystal with tiny pale cyan highlight and understated antique gold foot, black outline, logical24x24 tile with relic occupying18x20 pixels. Strong angular diamond silhouette, no apple, no stem, no diffuse glow. Style: true LOW resolution pixel art, logical 24x24 pixels enlarged into crisp square blocks, use few big readable clusters and flat color ramps, NOT high detail illustration. Orthographic overhead game view, centered isolated single sprite, complete silhouette no cropping, transparent background. Snake palette deep green #0d442c, emerald #1c9e50, light green #70d85c, restrained gold #d8b853, outline #071a14. Gem saturated colors. No text, watermark, extra sprites, dirt or background, no smooth 3D rendering.

### cursed_relic

Use case: stylized-concept. Asset type: Jungle Temple game sprite preview. Input image 1 is STYLE REFERENCE ONLY. One Cursed relic icon, centered jagged violet-black obsidian crystal with two bright violet fissures and tiny lilac highlights, near-black outline, logical24x24 tile with relic occupying18x20 pixels. Broken asymmetric silhouette distinguishes from sapphire. No apple, no stem, no fog. Style: true LOW resolution pixel art, logical 24x24 pixels enlarged into crisp square blocks, few broad readable color clusters, flat shading, NOT high detail illustration. Orthographic overhead game view, centered isolated sprite with complete silhouette, transparent background. Obstacles palette dark warm grey #4a4c40 with mid #686957 and restrained #82816a edges, muted moss #415633 and black #101b16 boundary, floor will be #30382f; obstacles subordinate to bright emerald snake. No text, labels, watermark, extra sprites or scene, no smooth 3D rendering, no noisy dithering.

### ruin_block

Use case: stylized-concept. Asset type: Jungle Temple game sprite preview. Input image 1 is STYLE REFERENCE ONLY. One ruined temple obstacle block directly overhead, square raised dark grey warm stone block filling22x22 of logical24x24 cell, thick black boundary, chipped corners, broad beveled top, restrained moss patch on one edge, one low contrast ancient carved line. Much brighter than floor but dimmer than emerald snake, no gold frame. Style: true LOW resolution pixel art, logical 24x24 pixels enlarged into crisp square blocks, few broad readable color clusters, flat shading, NOT high detail illustration. Orthographic overhead game view, centered isolated sprite with complete silhouette, transparent background. Obstacles palette dark warm grey #4a4c40 with mid #686957 and restrained #82816a edges, muted moss #415633 and black #101b16 boundary, floor will be #30382f; obstacles subordinate to bright emerald snake. No text, labels, watermark, extra sprites or scene, no smooth 3D rendering, no noisy dithering.

### ruin_wall

Use case: stylized-concept. Asset type: Jungle Temple game sprite preview. Input image 1 is STYLE REFERENCE ONLY. One ruined temple short wall unit directly overhead, horizontal chunky rectangular broken stone brick course filling22x20 of logical24x24 cell, thick near-black boundary, broad warm grey beveled top, one horizontal masonry joint, chipped broken end and sparse moss. No symbols, no gold. Style: true LOW resolution pixel art, logical 24x24 pixels enlarged into crisp square blocks, few broad readable color clusters, flat shading, NOT high detail illustration. Orthographic overhead game view, centered isolated sprite with complete silhouette, transparent background. Obstacles palette dark warm grey #4a4c40 with mid #686957 and restrained #82816a edges, muted moss #415633 and black #101b16 boundary, floor will be #30382f; obstacles subordinate to bright emerald snake. No text, labels, watermark, extra sprites or scene, no smooth 3D rendering, no noisy dithering.

### ruin_pillar

Use case: stylized-concept. Asset type: Jungle Temple game sprite preview. Input image 1 is STYLE REFERENCE ONLY. One broken temple pillar directly overhead, round octagonal stone stump inside square low plinth filling22x22 of logical24x24 cell, visible dark central fracture, warm grey beveled rim, slight moss at base, dark outline. Clearly raised obstacle, not ornate bright medallion. Style: true LOW resolution pixel art, logical 24x24 pixels enlarged into crisp square blocks, few broad readable color clusters, flat shading, NOT high detail illustration. Orthographic overhead game view, centered isolated sprite with complete silhouette, transparent background. Obstacles palette dark warm grey #4a4c40 with mid #686957 and restrained #82816a edges, muted moss #415633 and black #101b16 boundary, floor will be #30382f; obstacles subordinate to bright emerald snake. No text, labels, watermark, extra sprites or scene, no smooth 3D rendering, no noisy dithering.

## Stop point

Phase 3A.1 preview deliverables complete. Wait for art-direction approval. Do not convert these previews to active MIFs or start implementation automatically.

