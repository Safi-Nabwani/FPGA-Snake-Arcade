# Supplied Jungle Temple opening — implementation

Date:2026-10-17, Asia/Jerusalem. Baseline:59beeed, verified90-point game, `db/win90_build/source/output_files/`.

**PASS** — supplied-only asset conversion, all focused tests and the single Quartus compilation succeed. All reported constrained setup/hold margins remain positive. Actual memory use is **319/553M10Ks(58%)**, down from515(93%), with the original sidebar rendered unchanged. No push or FPGA programming.

## Supplied assets only

Source ZIP:`C:/Users/USER/Downloads/Opening_Screen_Assets_For_Codex.zip`. Its three PNGs and README are extracted byte-for-byte under `assets/jungle/supplied_opening/`. Archive entries were checked against path traversal before extraction. README content was treated as supplied asset documentation, not an authority to execute instructions.

| Supplied file | Role / exact dimensions | SHA256 |
| --- | --- | --- |
| user_reference_background_126x120.png |126×120RGBA composition reference; not used to replace the sidebar|aa2c1e1dde1f6affb07d8950bf2481c4196e663e5b573c19d5d88912db3189da|
| overgrown_temple_torchlit_frame.png |1275×1234RGB frame/backdrop source|3a0ade6ac9bc4c82cc958c1e0fb90715b226b2f0392ee14f04c24217c6636936|
| snake_arcade_temple_menu.png |1275×1234RGBA main layout, title, keys, relics, explanations, goal90 and start prompt|8520589e981263c08c0962132745548f0d24bc054b0e95afa457935bce1e0787|

No image-generation tool, new texture, redrawn lettering, substituted gem or earlier AI preview art is used. The main concept already contains correct relic effects and NUMPAD8/4/6/2. Its true RGBA alpha is composited over the supplied frame, preserving opaque black. Both assets are resized to the matching496×480right-area aspect using nearest-neighbor sampling, with no content crop. Only standard RGB332 conversion, scaling and exact rectangular source crops are performed.

## Current architecture and preserved sidebar

The old opening stored all640×480pixels in one307200×8RGB332 ROM inside `End_Message_Display.sv`. It masked the entire display, including an obsolete static opening-specific sidebar. The verified baseline allocates300M10K blocks to that ROM and515/553(93.13%) to the project. Other baseline resources are4165312memory bits,6676ALMs,5314registers; worst setup+7.734ns, hold+0.166ns. These are measured successful reports, not the rejected Phase3C.1trial.

The implemented gameplay HUD renderer owns the whole sidebar **X[0,144),Y[0,480)**, with visible carved panel bounds approximatelyX[8,136),Y[8,472). Its32×18score/high-score fields begin(57,116)/(56,182); three48×18relic fields beginX64,Y273/317/362. This phase does not change its RTL, font, atlas, coordinates or counters.

The new MENU drawing request covers **only X[144,640),Y[0,480)**. At every left-side pixel it deasserts, allowing the existing `NumbersBitMap`/score/high-score path through the unchanged compositor. Consequently the actual HUD, including its live values, appears in the opening; there is no copied sidebar bitmap or second HUD renderer in production. The preview's left69120pixels match the existing approved zero-value HUD byte-for-byte. Menu mode initializes actual counters to zero as before; local restarts preserve high score and go directly into play. Normal gameplay HUD behavior is unchanged.

## Memory strategy and alternatives

The chosen implementation is **one multi-resolution RGB332 atlas/read port**:

1. A124×120background(14880pixels) expands4× to cover exactly496×480. The geometry comes from the actual available width;126×4=504would overrun it, so the small reference is not blindly pasted.
2. Eleven source crops retain native-resolution title, three headings, keycaps, control caption, three relic rows, the goal text and start prompt. Together they hold89596pixels. All text/art in these patches comes from the supplied concept, not a newly generated font.
3. Background and details are concatenated in `RTL/mifs/opening_supplied_atlas.mif`: **104476×8bits**,17-bit addresses,835808logical bits. Native detail rectangles are disjoint. Their bounds/offsets are in `opening_supplied_layout.svh` and `verification.json`.

For a right-local pixel `(x,y)`, the default address is `124*(y>>2)+(x>>2)`. A native rectangle replaces that address with its atlas offset plus row stride/local X.124=128−4; generated constant row strides use sized shifts/additions. There is no divide-by-five, palette lookup, decompressor, extra pixel-buffer RAM or dependent second-ROM read. Both tiers share the single existing two-stage menu pipeline: stage1registers the chosen address/visibility/mode, stage2is the vendor registered ROM address with matching metadata; the original mux adds its existing further register.

| Method | Estimated opening M10K | Readability/style and decision |
| --- | ---: | --- |
| Entire right area496×480native8-bit image |233at baseline density|Sharp but much larger than necessary|
| Low-resolution124×120only |15|Small tutorial text is unreadable; rejected|
| Low-resolution plus full-color native source crops in one atlas |103|Selected: preserves supplied illustrated letters, icons and details where needed|
| Global2/3/4-bit palette |Not lossless here|Combined atlas has182RGB332colors and needs8-bit exact global indices; no recoloring allowed|
| Tile/chunk dictionary or RLE |Not fitted|More address/decode logic and pipeline risk; no justified benefit over the simple103-block estimate for this task|
| Procedural/replacement font |Potentially smaller|Would replace the supplied illustrated lettering; unnecessary visual compromise|

The atlas preserves all original RGB332 values within native patches. Exterior ornament/background detail is intentionally reduced to4×pixels. The native patches use original source interiors and therefore can show a sharp-to-coarse transition around their edges; no claim of whole-image pixel identity with the high-resolution supplied art is made. This is the requested memory/readability tradeoff, not new artwork.

Estimated opening storage changes2457600→835808bits(−1621792bits); project logical bits4165312→2543520. Estimated physical opening blocks300→103, project515→318(57.50%), freeing197blocks. These figures remain estimates until the final fit is measured. Actual physical packing, ALMs/registers and timing must come from Quartus.

## Exact task files

Modified:

- `RTL/VGA/End_Message_Display.sv`: restrict MENU to the right area; calculate right-local/background coordinates, include the native-crop address table, and read the smaller atlas. Existing menu latch/start pulse handling, result-panel state/ROMs and public ports remain unchanged.
- `.gitattributes`: add byte-preserving rule for the new atlas MIF.
- `simulation/opening_screen_tb.sv`: full new-menu/unchanged-HUD composite comparison, right-only request and atlas bounds; retain all actual keyboard/gameplay/start/reset tests.
- `simulation/opening_screen.do`: register existing HUD/square/origin modules for the integration test and use new expected-scene fixture.

Created:

- `RTL/VGA/opening_supplied_layout.svh` — generated11-rectangle address-selection logic.
- `RTL/mifs/opening_supplied_atlas.mif` — single derived active8-bit ROM.
- `scripts/implement_supplied_opening.py` — reproducible ZIP/source validation, conversion, atlas/layout generation, actual-MIF preview/fixtures and final report inspection.
- `assets/jungle/supplied_opening/README.txt` and the three exact supplied PNGs listed above.
- `assets/jungle/supplied_opening_implemented/background_124x120.png`.
- `assets/jungle/supplied_opening_implemented/right_area_496x480.png`.
- `assets/jungle/supplied_opening_implemented/full_scene_640x480.png`.
- `assets/jungle/supplied_opening_implemented/full_scene_2x.png` — inspection enlargement only.
- `assets/jungle/supplied_opening_implemented/verification.json`.
- `assets/jungle/supplied_opening_implemented/quartus_results.json` — actual before/after resources, warnings, all timing corners and opening allocation.
- This report.

No authored QSF, BDF, clock/PLL, constraints, pin, collision, movement, game-controller, scoring, audio, HUD or existing artwork change. The old full-screen opening MIF/PNGs remain intact for history but the old opening ROM is no longer instantiated. The new include belongs to the existing QSF-listed renderer, so no source-registration or schematic-interface edit is needed. Unrelated uncommitted reports/previews from prior tasks remain excluded from this task commit.

## Focused verification — PASS

- Supplied PNG hashes and ZIP-entry bytes match. All new ROM addresses are fully covered; RGB332 ordering and exact atlas pixel conversion pass. The124×120base and89596native pixels reproduce the displayed right area independently of the RTL address-generation code. Its true00/FFcolors remain opaque. There are24477opaque00words and495opaqueFFwords in the combined atlas; neither is treated as transparency.
- `simulation/supplied_opening.log`: **OPENING_STARTUP_PASS**, **OPENING_SCREEN_PASS:2970726checks**. Every238080right-side pixel matches the actual supplied-MIF expectation. Every69120left-side pixel matches the original HUD through the real unchanged HUD/font/rectangle/mux path. MENU never asserts over the sidebar; blanking/2047bounds and the shared17-bit atlas address remain legal. Pixel colors and requests are aligned with the original latency and highest message priority.
- Same test: actual decoder keypad073starts exactly once per press, typematic/held keys cannot restart a terminal state, release/repress works, four original numpad directions work, hardware reset returnsMENU. Menu blocks gameplay/events even with collision inputs asserted. Real Ruby8/Sapphire1/Cursed1 score/length/speed effects,90-point victory, local reset and high-score retention pass. Existing win/loss panels match frozen59beeed rendering after the menu exits.
- `simulation/supplied_hud_regression.log`: **HUD_COUNTERS_PASS**, **HUD_FINAL_RENDER_PASS:3887791checks**; unchanged five dynamic fields, leading zeros,99/FFdigits,000..999saturation, score/high-score/reset rules and full-frame/arena boundaries.
- `simulation/supplied_gameplay_regression.log`: **3345662checks PASS**, actual V4 floor/obstacle/rotated head/body/relic pixels, separate original hit masks,193-position trail, movement/length/self-collision and cycle-exact collection/death/scoring. Ruby8/Sapphire1/Cursed1,1232self-contacts and1death as before.
- `simulation/supplied_win90_regression.log`: **1056checks PASS**; all scores00..89continue,90wins, Sapphire jumps to91/92win, Cursed penalties and all collision types remain correct.
- `simulation/supplied_arena_regression.log`: **ARENA_GEOMETRY_PASS**,360cells/30obstacles,1024candidate states per color, valid relic extents, overlap/spawn rejection and four24-pixel movement directions.

Every suite completed with zero HDL compile/runtime errors or warnings, apart from existing library-reuse notices. These are focused RTL/MIF simulations, not post-route or physical board testing.

## Quartus result and final handoff

**Exactly one** map→fit→STA→assembler flow,2026-10-17,21:45:43–21:57:42+03:00, in `db/supplied_opening_build/source/`, Quartus Prime Lite17.0Build595, Cyclone V5CSXFC6D6F31C6. All stages returned0. No retry, seed search, relaxed clock or timing exception. The working-source snapshot includes the user's unchanged current QSF/BDF edits; those remain excluded from the commit. Settings writes were disabled for map/fit. All compiled inputs still match the source-manifest hashes after compilation.

| Metric | Verified before | Measured after | Change |
| --- | ---: | ---: | ---: |
| Opening M10K blocks |300|104|−196(65.3% reduction)|
| Total M10K blocks |515/553|319/553|−196(38.1% fewer)|
| Block utilization |93.13%|57.69%|−35.44percentage points|
| Total memory bits |4165312|2543520|−1621792|
| ALMs |6676(16%)|7063(17%)|+387|
| Registers |5314|5316|+2|
| Pins / DSP / PLL |91/1/1|91/1/1|0|
| Worst setup slack |+7.734ns|+6.850ns|−0.884ns; positive|
| Worst hold slack |+0.166ns|+0.132ns|−0.034ns; positive|

The actual opening allocation is104blocks, one above the simple103-block estimate due to physical mapping/packing. Its Fitter RAM row confirms104476×8bits,835808implementation bits, synchronous ROM,0MLABcells. Deduplicated M10K locations confirm319project blocks. The remaining215blocks are unchanged other image/font/audio allocations; the saving comes from replacing the full-screen300-block menu with the smaller supplied atlas, not removing or shrinking the gameplay HUD.

| Timing corner | Before setup / after setup(ns) | Before hold / after hold(ns) |
| --- | ---: | ---: |
| Slow1100mV85C |8.275 /7.242|0.278 /0.281|
| Slow1100mV0C |7.734 /6.850|0.236 /0.254|
| Fast1100mV85C |18.665 /17.505|0.177 /0.167|
| Fast1100mV0C |19.567 /18.840|0.166 /0.132|

All20reported timing summaries are positive with TNS0. Minimum pulse-width slack remains+0.793ns. Existing missing external-I/O constraints, stale generated-clock/debug references and unassigned debug pins remain; positive internal timing is not complete board-level signoff. Unconstrained inputs remain5ports/120paths; outputs remain55ports, with142paths versus141before. No physical FPGA functionality has been tested.

| Stage | Before warnings | After warnings | After errors |
| --- | ---: | ---: | ---: |
| Synthesis |243|243|0|
| Fitter |91|91|0|
| TimeQuest |52|52|0|
| Assembler |0|0|0|

Warning codes and counts match the prior successful build exactly at every stage; no new warning was introduced. Existing source-width, vendor-template, pin/debug and SDC concerns were preserved rather than suppressed.

Free capacity is now234M10Ks, versus38before. At the same conservative8-bit ROM density this is about239616additional pixel words before mapping overhead, less than a whole extra640×480image. Future result screens should reuse low-resolution scenery/native details or a separately verified compression method; this task does not implement them.

### Programming file and local commit

The successful outputs/reports were copied into normal ignored`output_files/`. `output_files/Lab1Demo.sof` is now the new supplied-opening build,6690369bytes, generated2026-10-17 at21:57:42+03:00; its bytes match the successful snapshot SOF. SHA256:`289D07535D3F6795776C1FA94F5730AD8AD000412E3C9669FCDF546109A4C908`. The old90-point baseline remains available under`db/win90_build/source/output_files/`. Staged source/asset bytes are checked against the verified working inputs before committing.

Local commit message:`Implement supplied Jungle Temple opening screen`. Only this task's18source/test/asset/report files are included. In particular, the pre-existing QSF/BDF/QWS/backup edits, prior uncommitted audit/AI-preview work and all compilation outputs are excluded. No push or FPGA programming.

Reproduce assets/fixtures without writing existing artwork:

```text
python -B scripts/implement_supplied_opening.py --install --fixtures --preview
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/opening_screen.do
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/hud_relics.do
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/jungle_implementation.do
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/winning_score.do
vsim -c -modelsimini C:/intelFPGA_lite/17.0/modelsim_ase/modelsim.ini -do simulation/arena_geometry.do
python -B scripts/implement_supplied_opening.py --build-results db/supplied_opening_build/source/output_files
```

The supplied PNGs are retained locally, so Downloads/ZIP is not a runtime dependency. Optional`--zip PATH` verifies exact ZIP bytes again. Only`--install` writes the new MIF/include; omit it for read-only active-asset verification. No image-generation API is used. No push or FPGA programming.
