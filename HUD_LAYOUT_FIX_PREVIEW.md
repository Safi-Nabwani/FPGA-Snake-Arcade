# HUD Layout Fix + Arena Boundary Fillers — Preview Only

Date: 2026-10-12 (Asia/Jerusalem). Starting commit: `97c1782`.

**Status: visual proposal only; awaiting approval.** The currently implemented HUD remains unchanged. This preview is not a new FPGA build, live game capture, or hardware verification. No RTL, BDF, MIF, QSF, SDC, PLL, pins, gameplay, scoring, or collision edits; no Quartus run, staging, commit, push, or programming.

## Main previews

- Native **640×480**: [full_scene_640x480.png](assets/jungle/hud_layout_fix_preview/full_scene_640x480.png)
- Exact **2× nearest-neighbor** inspection: [full_scene_2x.png](assets/jungle/hud_layout_fix_preview/full_scene_2x.png)
- Same composition with **empty numerical windows**: [empty_counter_windows_640x480.png](assets/jungle/hud_layout_fix_preview/empty_counter_windows_640x480.png)

The native image is the size/geometry source of truth. The enlarged inspection image does not imply larger VGA or gameplay dimensions.

## Enlarged regions

All screen coordinate ranges below have exclusive upper bounds.

The prior panel is nominally120×432 at(8,24), but its supplied alpha footprint is only113×358: localX[4,117), localY[36,394), screenX[12,125), Y[60,418). This leaves substantial unused space above and below the visible artwork.

The proposed **visible HUD** instead fills approximately **X[8,136), Y[8,472):128×464**. It covers almost the entire available screen height, including the unused left-side top/bottom corners. It stays entirely left of the gameplay arena. The serpent crest, foliage, stone panel, torches, bronze/gold frames, three gemstone illustrations and lower serpent ornament form one connected structure. This is a re-layout in the same art direction, not uniform enlargement of the old transparent panel canvas.

The score/high-score sections and relic section are larger and better separated. The numerical wells are deliberately high-contrast opaque black. Their illustrative values are drawn separately, using the actual current font, rather than becoming part of background artwork.

| Field | Approximate well origin | Well width×height | Number origin | Number field width×height |
| --- | --- | --- | --- | --- |
| Score | (35,108) | 76×32 | (57,116) | 32×18 |
| High Score | (33,175) | 78×32 | (56,182) | 32×18 |
| Ruby | (59,268) | 59×27 | (64,273) | 48×18 |
| Sapphire | (59,313) | 59×27 | (64,317) | 48×18 |
| Cursed | (59,358) | 59×27 | (64,362) | 48×18 |

Score/high-score wells were approximately56×19; relic wells41×14. The larger wells now allow **16×18 digit cells**, compared with the implemented8×9 cells: twice the width and height, with full occupied font detail instead of every-other-pixel sampling. The score/high-score retain two digits and the relic fields retain three digits. Examples12/19 and012/345/678 are preview overlays only. Counter widths, reset, saturation, persistence and scoring behavior have not been changed.

The existing `RTL/mifs/numbers_new_font.mif` supplies every numeral: columns0–15 and occupied rows6–23 of each16×32 slot. Its file is not modified. The three HUD gemstone illustrations appear once each; no second icon is overlaid on a row. In-game relic artwork is independently preserved in the unchanged arena.

Approximate decorative sections: crest/foliageY8–80, scoreY80–150, high scoreY150–215, RELICS headingY225–250, three relic rowsY250–390, lower stone/serpent ornamentY395–472. Final section/window boundaries should be confirmed against the approved preview before any implementation.

## Added boundary fillers

| Non-gameplay region | Exact reserved range | Size | Treatment |
| --- | --- | --- | --- |
| Arena top | X[144,624), Y[0,24) | 480×24 | Dark carved stone strip, restrained bronze grooves, sparse moss |
| Arena bottom | X[144,624), Y[456,480) | 480×24 | Matching stone strip with occasional worn motifs |
| HUD/arena divider | X[136,144), Y[24,456) | 8×432 | Narrow vertical carved trim connecting the two areas |
| Arena right | X[624,640), Y[24,456) | 16×432 | Slim stone/vine border, small spaced accents |
| Frame corners | LeftX[136,144), rightX[624,640), top/bottom24px | Separate corner blocks | Restrained carved caps; no overhang into gameplay |
| Outer HUD edging | X[0,8), Y[0,480); HUD top/bottom8px | Thin outer trim | Completes the connected frame without unused green strips |

The divider replaces the former empty gap; it does not move the arena. Decorative pixels are clipped to non-gameplay regions, not allowed to cover the first/last tile or cast artificial shadows over gameplay. No torches, large serpents, text or new obstacles are added to the arena border. The frame is less visually prominent than the HUD or gameplay objects.

## Unchanged arena and preview verification

- VGA remains **640×480**.
- Arena remains **20×18**, with **24×24** tiles, origin **(144,24)**, X[144,624), Y[24,456).
- The complete480×432 arena raster is copied unscaled from `assets/jungle/hud_implemented/full_scene_640x480.png`, the current actual-MIF scene. This preserves the exact V4 floor distribution, all30 obstacle cells/art, snake pose/art and in-game relic positions/art.
- **207,360 arena RGB pixels were compared individually and are identical**. No generated gameplay-area pixels are used in the final preview.
- Arena RGB SHA256: `8186F74794BDEA738390C68DCEA32622FCB0B7D899B9BC4AAC5E0FF30D96A952`.
- All five original-font number fields fit entirely inside their proposed wells, clear of labels, gemstone icons and frames. Native and2× previews were inspected visually.
- Proposed HUD/frame colors are mechanically restricted to RGB332. The original arena raster is not recolored or requantized.
- Final SHA256 audit confirms **all277 existing tracked files are unchanged**. Only the new preview/report artifacts are added locally and remain untracked. The pre-existing untracked `Lab1Demo.qws` and current `output_files/Lab1Demo.sof` also match their starting hashes; no replacement SOF was generated. Git's index is unchanged.
- These are visual/preservation checks, **not functional simulations or new setup/hold/resource results**. No Quartus or ModelSim run was required for this preview-only task.

## Method and new files

The **imagegen skill / built-in image-editing tool** was used with the current full scene as the edit target and supplied quantized HUD panel as the style reference. Its prompt locks the arena and asks only for a fuller-height HUD and simple boundary trim. The complete prompt is retained in [image_edit_prompt.txt](assets/jungle/hud_layout_fix_preview/image_edit_prompt.txt).

The tool's1448×1086 draft is a concept reference, **not the final geometry-verified preview**. Only its UI/frame regions are used. A preview-only composition step fits those regions into the explicit sidebar/border rectangles with nearest-neighbor sampling, limits them to RGB332, clears numerical placeholders inside the new wells, and overlays original-font numeral examples. It then restores and verifies the unaltered arena. This fitting applies to new preview artwork only; the approved active HUD PNG/MIF is never resized or rewritten.

Created files (all preview/report artifacts):

- `HUD_LAYOUT_FIX_PREVIEW.md` — this report.
- `assets/jungle/hud_layout_fix_preview/image_edit_concept.png` — image-editing draft, retained for provenance, not a hardware asset.
- `assets/jungle/hud_layout_fix_preview/image_edit_prompt.txt` — full prompt and invariants.
- `assets/jungle/hud_layout_fix_preview/compose_preview.ps1` — preview composition and pixel-preservation checks; writes only PNGs/JSON in its own folder.
- `assets/jungle/hud_layout_fix_preview/full_scene_640x480.png` — final native proposal.
- `assets/jungle/hud_layout_fix_preview/full_scene_2x.png` — nearest-neighbor inspection copy.
- `assets/jungle/hud_layout_fix_preview/empty_counter_windows_640x480.png` — background/empty-well inspection copy.
- `assets/jungle/hud_layout_fix_preview/verification.json` — coordinates, field geometry and pixel/source hashes.

Reproduce only the preview composition, without another image-generation call:

```powershell
./assets/jungle/hud_layout_fix_preview/compose_preview.ps1
```

## Later implementation concerns — no implementation authorized here

Approval is needed for the complete re-layout before making any new FPGA assets. A later phase must position full-detail glyph sampling, preserve DR/RGB/mask latency, and account for the bigger sidebar/frame ROM requirements. RGB33200 must remain valid opaque black in the numerical wells; any transparency must use an independent mask.

Boundary decoration must remain a rendering-only layer, independent of `borderDR`, obstacle collision and relic spawn-exclusion maps. The existing high-priority win/loss overlay can still obscure part of a HUD after a game ends; it was not redesigned in this proposal. Timing/resource impact is unknown until a separately approved implementation and compilation.

**Stop point: preview complete; await visual approval.**
