# FPGA Snake — Phase 3D Results Screens / SHARED ASSET PACK

Status: Asset pack and software-simulated previews ONLY. Not integrated into SystemVerilog, and not verified by Quartus/hardware.

## Geometry
VGA 640x480. Existing HUD X[0,144) MUST stay unchanged. New report panel X[248,536), Y[24,456), size 288x432.
Shared `report_shared_144x216` is 2x nearest-neighbor enlarged, fully opaque, ONE ROM used by both Victory and Defeat. No example statistics baked into any asset.

## Source PNG + MIFs
Every MIF uses WIDTH=8 RGB332 packed as {R[2:0],G[2:0],B[1:0]}, row-major addresses y*width+x, top left origin. Binary masks are separate WIDTH=1 MIFs, same address ordering. Mask 1=draw, 0=transparent. RGB332 00 and FF may be opaque; never use them as transparency sentinels. For non-masked assets all pixels opaque. Samples are RGB332-quantized PNGs, not full-color references. `manifest.json` includes size/checksums.

Shared opaque ROM: report_shared_144x216 (144x216; render 2x)
State-specific native overlays:
- victory_title 224x32 + 1-bit mask, X280 Y40
- defeat_title 224x32 + 1-bit mask, X280 Y40
- victory_emblem 160x72 + 1-bit mask, X312 Y80
- defeat_emblem 160x72 + 1-bit mask, X312 Y80
- victory_plaque 224x32 opaque, X280 Y164 (over shared status well)
- defeat_score_label 136x16 + 1-bit mask, X280 Y172

## Separate dynamic elements, NOT in asset pack
- Defeat final score digits (existing 16x18, 2 decimal digits) at X456 Y171.
- Ruby/Sapphire/Cursed 24x24 existing game sprite icons at X280 Y232/288/344. Reuse existing assets rather than duplicating their ROM contents blindly.
- 3 decimal digits in 16x18 font at X440 Y235/291/347 (48x18 each). Count examples in PREVIEW files are illustration only and must remain dynamic.
- Existing start/restart pulse `5` and gameplay logic unchanged.
- HUD must remain rendered and unchanged in the x<144 region. The darkening effect in previews applies only to x>=144; can be omitted or implemented with RGB logic, with no additional RAM.

## Verification performed
- 7 PNGs, 7 RGB332 MIFs, 5 binary alpha-mask MIFs.
- Every MIF byte/pixel matches its corresponding quantized PNG.
- Exact geometry + addressing + opacity verified in Python.
- PREVIEW_victory_640x480 and PREVIEW_defeat_640x480 are COMPOSITES using earlier V4 image as an illustrative background, NOT actual RTL/full project rendering.
- Displayed sample numbers are not baked into any shipped ROM.

## Caveats / engineering discretion
The structural shared panel is deliberately 2x pixel-art with reserved native-resolution overlay locations; dynamic text may require minor alignment based on the actual project font metrics. Static shared label text and restart text are baked into the shared base at 2x. Native overlays retain 8-bit RGB332 colors within their own masked shapes. Source art for emblems was cropped from previous illustrative concept screens; reviews should use the actual 640x480 previews instead of the large original illustrations.

The estimated combined 85–95 M10K blocks and potential savings against old 100-block result ROMs are goals from Codex's inspection, NOT measured for these new assets. ROM physical packing and pipeline timing require a real Quartus fit. Avoid allocating one independent full-sized image per result.
