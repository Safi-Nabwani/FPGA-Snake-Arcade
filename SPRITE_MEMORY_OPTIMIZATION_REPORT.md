# Phase 10 — Emerald sprite memory optimization

2026-10-23, Asia/Jerusalem. Status: **PASS — exact sprites, targeted tests, production build and pin audit verified.**

## Implementation and focused verification

- `jungle_head_draw.sv`: one 576x9 head-up base, inverse coordinate rotations before the existing registered ROM address.
- `snake_body.sv`: 2880x9 ROM with vertical body, horizontal body, top-left corner, top-right corner and up tail. Existing sprite IDs/selection/priority are preserved; only visual address formation and ROM parameters change. Local coordinates come directly from the selected history position, without division/modulo. No pipeline registers added.
- `RTL/mifs/snake_variants/emerald_head_base_rgba9.mif` and `emerald_body_bases_rgba9.mif` contain exact slices of the unchanged original `01_emerald_rgba9.mif`.
- `scripts/build_emerald_bases.py --install` reproducibly extracts those six original sprites. Without `--install`, it checks them. Exhaustive verification: **8064/8064 original nine-bit pixels exact**, including alpha and invisible RGB.
- `simulation/sprite_rotation_tb.sv` / `.do`: **34,681 checks passed**, streaming all body/corner/tail pixels and all head rotations, same-cycle ROM data and original output latency, blanking and reset.
- Existing Emerald selection test: **83 checks passed**. Only its address expectations in `snake_sprite_variants_tb.sv` were adapted to compact ROM addressing. It retains actual connectivity/tail/overlap/game-state checks. Existing testbench force warnings remain.

Raw unique artwork falls from **72,576 to 31,104 bits (57.1%)**. Separate head/body readers are retained; neither duplicates the other's bases. No source artwork, collision-mask ROM, movement/growth/shrink logic, self-collision or audio changes. No broad regressions.

## Production release

One quiet Quartus Prime Lite 17.0.0 Build 595 map/fit/STA/assembler build. Baseline: **14,591 ALMs**, **9,894 registers**, **429 total M10Ks**, **14 visual sprite M10Ks** (head 5, body 9); worst constrained setup **+5.332 ns**, hold **+0.159 ns**.

One build completed with **zero errors in map, fit, STA and assembler**, with no retries. Logs: `db/sprite_opt_build/`.

| Fitted result | Before | After |
|---|---:|---:|
| Visual sprite M10Ks | 14 (5 head + 9 body) | **6 (1 head + 5 body)** |
| Total M10Ks / 553 | 429 | **421**, saving **8** |
| ALMs / 41,910 | 14,591 | **13,403**, saving 1,188 |
| Registers | 9,894 | 9,970 |
| Total block memory bits | 3,405,308 | 3,326,972 |
| Worst setup (ns) | +5.332 | **+4.506** |
| Worst hold (ns) | +0.159 | **+0.135** |

All four timing corners remain positive with zero TNS. Setup decreases 0.826 ns and hold decreases 0.024 ns, but both retain positive closure without relaxed constraints. The fitted register count changes with implementation/optimization; no RTL pipeline stage was added and the cycle-by-cycle tests retain original latency. Fitted sprite implementation bits total exactly **31,104** (5,184 head + 25,920 body); removing duplicated/unused atlas allocation saves **78,336 implementation bits** versus the previous fitted readers, distinct from unique-artwork savings.

Mandatory `scripts/verify_audio_pin_safety.py` comparison against the saved baseline **passed**. AG30 remains reserved input with weak pull-up; all nine graphics-debug outputs remain virtual. Codec, keyboard and all non-debug physical pin locations/directions/I/O standards remain unchanged. Audit log: `db/sprite_opt_build/pin_audit.log`.

Preservation checks confirm the entire self-collision/output-register section and movement/history/length/sprite-selection functions are text-identical to the pre-edit body RTL. The original 14-sprite source atlas and collision assets are untouched. Pre/post-build integrity checks over **617 existing paths** found no compilation-induced changes.

Production **`output_files/Lab1Demo.sof`**, generated **2026-10-23 00:12:26 +03:00**, **6,690,369 bytes**.

SHA-256: **`198FAFF0D32184327CA0840E23EB281E0093B8F881E3DCAA1084FBF2DDA57C09`**.

Rollback: `db/sprite_opt_baseline/output_files/Lab1Demo.sof`, SHA-256 `474A3B5CFD83A1B1DA10B213F1CC909F0CA401C7B8DA91FA0910B8CC7AC218F3`. Previous reports and both pre-edit RTL files are preserved there/in the baseline parent.

## Hardware checklist and scope

Manually program the verified final SOF. Check all four head/tail orientations, both straight bodies, all four corners, overlapping segments and startup; compare art/colors against the rollback. Check ordinary movement, growth/shrink and self-collision. No agent programming or physical verification. Existing external-I/O constraint limitations remain separate from internal timing closure.

A single focused local commit follows successful release checks. Original atlas, unrelated QSF/BDF/control/artwork edits, generated Quartus artifacts and rollback backups are excluded. No push or unrelated cleanup.
