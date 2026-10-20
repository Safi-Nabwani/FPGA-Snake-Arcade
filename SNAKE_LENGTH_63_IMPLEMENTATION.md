# Phase 8B — 63-Node Snake Capacity

Date: 2026-10-20, Asia/Jerusalem.

Baseline HEAD: `4309883b9125ec0b4a9c6bdfba9d88eadfc3a19a`.

Status: implemented and verified in ModelSim and Quartus. Production capacity is 63 body nodes. The new production SOF was generated successfully; no physical board testing was performed in this phase.

## Implementation

Production capacity is 63 body nodes plus the separately rendered head. `SEGMENT_SPACING` remains six history frames. The trail contains 379 X/Y pairs (`63*6+1`), indexed 0–378. X and Y remain 11 bits each, giving 8,338 declared coordinate bits. The public length interface remains six bits.

Files modified:

- `RTL/VGA/snake_body.sv`: maximum 63; parameter-derived selector width and power-of-two balanced selection tree; explicitly widened saturation arithmetic.
- `RTL/VGA/Snake_Block.bdf`: the body instance's explicit `MAX_SEGMENTS` override changes from 32 to 63. No symbol interface or bus width changes are necessary.
- `RTL/Seg7/snakeLengthDigits.sv`: adds the missing decimal 40–49, 50–59 and 60–63 cases; the existing physical HEX layout remains unchanged.
- `simulation/snake_sprite_variants_tb.sv`: highest-node tests now exercise node 62 and history index 378; adds an explicit pass flag.
- `simulation/snake_emerald_production.do`: checks that pass flag and returns a failing process status if the simulation does not pass.

Files created:

- `simulation/fixtures/snake_body_32_reference.sv`: frozen pre-feature production body RTL with the module renamed and trailing whitespace normalized, providing an independent linear renderer/history/collision reference.
- `simulation/snake_length_capacity_tb.sv`: parameterized state, arithmetic, history, rendering, bounds and decimal-display regression.
- `simulation/snake_length_capacity.do`: reliable 32/63-node test runner.
- `SNAKE_LENGTH_63_IMPLEMENTATION.md`: this report.

### Rendering and gameplay preservation

Independent leaf rectangle tests feed a balanced tree whose left child always wins. This preserves the original lowest-index bounding-rectangle ownership, including transparent pixels within the selected rectangle. A padded 64th leaf is permanently invalid at capacity 63 and never accesses the history arrays.

Each leaf uses constant history/neighbor indices, with a generate-time guard on the final node's older neighbor. Tail selection and dominant-axis corner orientation preserve the previous logic. No pipeline registers were added; the ROM address/visibility and RGB/drawing-request timing are unchanged.

The addition function widens both six-bit operands before addition, retaining the carry in a seven-bit sum. For example, `63+5` is evaluated as 68 and saturates to 63. New-game clear still has highest priority; otherwise Cursed (+5), Sapphire (−3, floor 1), and Ruby (+1) retain their previous priority. Excess growth is discarded, with no queue.

Movement, speed, self-collision geometry, frame-history sampling, head collision masks, score-90 victory, spawning, audio, input, HUD, opening and results logic remain unchanged. Nodes are history samples, not arena grid cells. The existing tail-vacating collision rule and absence of snake-aware relic spawn exclusion are preserved.

## Functional verification

The balanced architecture was first tested at the original 32-node capacity against the frozen production reference before raising the production parameter/BDF override.

| Verification | Result |
|---|---|
| 32-node equivalence, final expanded test | PASS: 1,488,853 checks; 193 history pairs; 772 main movement frames |
| 63-node capacity test | PASS: 2,221,651 checks; 379 history pairs; 1,516 main movement frames |
| Emerald production renderer | PASS: 82 checks, all head/straight/corner/tail orientations and pipeline behavior |
| Arena/movement/relic positions | PASS: all 307,200 visible pixels, 360 cells, counter/reroll cycles, all four movement directions |
| Score-90 and relic effects | PASS: 1,056 checks; all scores below 90, exact 90, Sapphire crossing to 90/91/92, loss/restart/reset |
| HUD and independent relic counters | PASS: 3,887,791 rendering checks plus counter/saturation/reset/high-score checks |
| Opening/menu/play/reset | PASS: 2,864,698 checks, existing HUD and movement/state behavior |
| Victory/defeat reports | PASS: 6,783,546 checks across six frames, fatal Cursed, score updates, keypad-5 restart and snapshots |
| Authoritative Emerald data | PASS: `scripts/verify_snake_variants.py --variant 1` |

The capacity suite tests every length from 1 through the selected maximum with every nonempty combination of collection pulses, plus explicit 1/4/31/32/33/39/40/62/63 boundaries where applicable. An independent integer arithmetic oracle checks saturation and event priority. Every history pair is compared to the frozen reference on frame, clear and reset updates; every visible pixel is checked for identical address, selected node, orientation, RGB, opacity and latency.

The highest legal tail is also isolated using live shifts without hierarchical force: node 62 at index 378 selects the correct tail sprite and local address, and disappears after the next oldest sample shifts out. Additional checks cover self-collision, restart overriding simultaneous pulses/frame update, hardware reset, and decimal digits for all 64 six-bit values including 0.

The 32/63 suites compile and simulate with zero HDL errors or warnings. The older focused Emerald test retains eight ModelSim warnings from deliberate testbench `force` statements; these are not synthesized logic warnings. Reused-library notices are harmless.

Logs: `simulation/snake_length_capacity_32.log`, `simulation/snake_length_capacity_63.log`, and `db/length63_verification/`.

## Quartus verification

One initial synthesis attempt stopped at parsing because Quartus 17 rejected inline `genvar` declarations accepted by ModelSim. Moving those declarations outside the generate loops fixed the compatibility issue without changing functionality; the 63-node focused regression passed again afterward. The successful synthesis retry reported zero errors and 247 warnings. The failed parser log is retained at `db/length63_build/map_inline_genvar_failed.log`.

The corrected production design completed one successful map/fit/STA/assembler flow using Quartus Prime Lite 17.0.0 Build 595, revision `Lab1Demo`, top `TOP_VGA_DEMO`, device Cyclone V `5CSXFC6D6F31C6`. No fitter retry, seed change, timing exception, clock relaxation or capacity reduction was required.

| Stage | Baseline warnings | Final warnings | Final errors |
|---|---:|---:|---:|
| Analysis & Synthesis | 252 | 247 | 0 |
| Fitter | 91 | 91 | 0 |
| TimeQuest | 52 | 52 | 0 |
| Assembler | 0 | 0 | 0 |

### Actual resources

| Resource | Previous 32-node production | New 63-node production | Difference |
|---|---:|---:|---:|
| ALMs | 8,367 / 41,910 | 14,328 / 41,910 (34%) | +5,961 |
| Registers | 5,568 | 9,901 | +4,333 |
| M10K blocks | 429 / 553 | 429 / 553 (78%) | 0 |
| Block memory bits | 3,405,308 | 3,405,308 (60%) | 0 |
| Pins | 91 / 499 | 91 / 499 | 0 |
| PLLs | 1 | 1 | 0 |
| DSPs | 0 | 0 | 0 |

History remains register-based; no additional sprite ROM or trail RAM was introduced. The body instance accounts for approximately 11,965.1 ALMs and 8,927 registers in Quartus's hierarchy attribution, including its unchanged nine-M10K Emerald atlas. Whole-device values in the table are the sign-off resource totals.

### Internal timing

| Timing check | Previous 32-node production | New 63-node production |
|---|---:|---:|
| Worst setup slack | +5.151 ns | **+4.785 ns** |
| Worst hold slack | +0.120 ns | **+0.161 ns** |

Final per-corner results for the unchanged 31.5-MHz game/pixel clock:

| Corner | Setup | Hold | Setup/hold TNS |
|---|---:|---:|---:|
| Slow 1100 mV, 85°C | +4.785 ns | +0.296 ns | 0.000 / 0.000 ns |
| Slow 1100 mV, 0°C | +5.049 ns | +0.277 ns | 0.000 / 0.000 ns |
| Fast 1100 mV, 85°C | +15.631 ns | +0.178 ns | 0.000 / 0.000 ns |
| Fast 1100 mV, 0°C | +17.174 ns | +0.161 ns | 0.000 / 0.000 ns |

All reported setup, hold and minimum-pulse-width slacks are positive. No new inferred-latch warnings were introduced. The same five existing audio register/latch-emulation warnings and five audio-related combinational loops analyzed as latches remain; there is no new body-renderer latch or loop reported.

### External-I/O limitations

Internal timing closure does not imply constrained external I/O:

- Unconstrained clocks: 0, unchanged.
- Unconstrained input ports/paths: 5 / 120, unchanged.
- Unconstrained output ports/paths: **56 / 148**, previously 55 / 141.
- The additional output is `HEX1[1]`. The old synthesis report identifies it as stuck at GND. Correct tens-digit rendering through 63 makes it dynamic, exposing that output to the existing absence of external output-delay constraints. Its physical pin assignment is unchanged.
- Nine existing pins remain without exact locations (`borderDR` and `BG_RGB[7:0]`).
- Existing unmatched/ignored audio, DRAM, VGA and JTAG SDC targets, including two ignored generated-clock constraints, remain. Drive-strength/slew and stale-assignment warnings remain outside this feature.

These limitations were neither hidden with exceptions nor represented as resolved. Resources and timing do not block the 63-node target.

## Final production programming file

- Location: `output_files/Lab1Demo.sof`.
- Generated: 2026-10-20 15:18:37, Asia/Jerusalem.
- Size: 6,690,369 bytes.
- SHA-256: `9D6DBAFE2CE13A1A4886F71E63AEA200393271D795C5C6B4D21A2DA194B28EA9`.

The old production SOF remains recoverable from `db/length63_baseline/output_files/Lab1Demo.sof`. The new SOF is a generated deliverable and is excluded from the source commit.

Both snake ROM instances still reference the approved Emerald atlas. Its unchanged SHA-256 is `259581F27E1A4A1B12A2C48DD289D50C4BA7DC7F56380D7280DE319EC4038611`. RGB332 data, binary opacity, ROM addressing and artwork were preserved exactly.

## Production safety and Git

Pre-edit files, production SOF and baseline reports are backed up in `db/length63_baseline/`, with HEAD/status and SHA-256 values in `manifest.json`. Build logs are isolated under `db/length63_build/`.

The pre-existing QSF and top-level BDF changes have been preserved byte-for-byte. No timing constraint, PLL or pin-assignment change was made. Existing experimental assets and unrelated reports/scripts remain on disk and outside this feature's commit scope. The Phase 8A audit remains a separate pre-existing untracked file.

The focused local commit contains only the three production source/BDF files, two existing test updates, three new test/reference files and this report. The uncommitted `Lab1Demo.qsf` and `TOP_VGA_DEMO.bdf` changes remain unstaged and byte-identical to the baseline manifest. Pre-existing untracked files, including the Phase 8A audit and comparison assets/builds, remain outside the commit. Nothing was deleted or discarded.

No board programming, push, cleanup, project rename, audio phase or further gameplay feature was performed. Physical acceptance of the new longer snake remains for the user; simulation/compilation success is not claimed as physical FPGA verification.
