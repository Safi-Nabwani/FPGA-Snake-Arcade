# Production Starting Length — 14 Body Nodes

Date: 2026-10-20, Asia/Jerusalem.

Baseline HEAD: `fa394a45ad45b5f88756312494c97b7cb3b420a2`.

Status: implemented and verified in ModelSim and one successful production Quartus map/fit/STA/assembler flow. The updated production SOF has been generated. No physical hardware verification is claimed.

## Changes and scope

The starting length is now **14 body nodes plus the separately rendered head**. Maximum capacity remains **63 body nodes**. The six-bit public length interface, 379 X/Y history pairs, six-frame spacing, 24x24 Emerald artwork, lowest-index rendering selection and existing ROM/visibility pipeline are preserved.

Modified production files:

- `RTL/VGA/snake_body.sv`: default `INITIAL_LENGTH=14`; adds a parameter-sized movement-history validity counter and excludes unfilled seed entries from self-collision.
- `RTL/VGA/Snake_Block.bdf`: changes the body's explicit `INITIAL_LENGTH` override from 4 to 14. `MAX_SEGMENTS=63`, `SEGMENT_SPACING=6` and all ports/wires remain unchanged.

Modified regression files:

- `simulation/arena_geometry_tb.sv`: expects the new production length on reset/restart; retains existing geometry/movement checks.
- `simulation/opening_screen_tb.sv`: updates initial/restart length and the expected lengths after collections; score, speed, HUD and state expectations remain unchanged.
- `simulation/snake_sprite_variants_tb.sv`: updates production growth/shrink expectations from 14, retains all Emerald direction/corner/tail checks, and supplies actual mature history before its forced collision probe.
- `simulation/snake_length_capacity_tb.sv`: explicitly retains initial length 4 for the established 32/63-node reference scenarios; uses an independent valid-history collision oracle during startup and exact legacy collision equivalence once fully mature. Adds explicit real mature-history self-contact.

Created:

- `simulation/snake_initial_length_tb.sv`.
- `simulation/snake_initial_length.do`.
- `SNAKE_INITIAL_LENGTH_14_REPORT.md`.

No QSF, top-level BDF, timing constraint, pin, PLL, audio, score, movement, speed, relic, arena, HUD, results or artwork source was edited for this feature. The user's pre-existing QSF/top-BDF modifications remain preserved rather than reverted or included in this feature.

## Why changing the length alone is unsafe

Both hardware reset and local clear initialize every history coordinate at one head position. With four nodes, none participates in self-collision because the original first-four exclusion skips nodes 0–3. At length 14, nodes 4–13 would immediately test those overlapping artificial seed coordinates and cause defeat.

A fixed grace timer is not the chosen solution: it could suppress a real collision with an already-sampled node, or expire while the player has not selected an initial direction. Counting stationary startup frames alone would also eventually create a false collision.

## Startup collision handling

`validTrailSamples` is nine bits, derived as `$clog2(MAX_TRAIL+1)`. It resets to zero on hardware reset and on the existing new-game clear. It remains zero while the head is at configured spawn `(384,240)`, regardless of how many stationary startup frames pass.

At the first running SOF sampling a head position away from spawn, the count becomes one. It then increments on every running SOF, including stationary samples after movement has begun, saturating at 379. There is no coordinate storage change, skipped trail shift, changed speed or new pipeline stage.

Body node `j` continues to use history index `(j+1)*6`. Its existing collision test is additionally eligible only when that index is less than `validTrailSamples`:

```text
active node AND original node >=4 AND history index < valid sample count
    -> unchanged inset head/body rectangle test
```

Thus node 4, at history index 30, becomes collision-eligible at 31 valid movement-history samples, independently of later nodes. Node 13 uses index 84. Once the count reaches 379, all legal indices through 378 are eligible and collision behavior is exactly the original mature-trail behavior. A return to a real earlier sample is not exempt merely because the rest of the trail is still filling.

The existing six-pixel inset, first-four-node exclusion, active length filtering, tail-vacating behavior and `gameStarted` gating are unchanged. This corrects startup-seed eligibility, not normal collision geometry. Growth exposes real older history when available; otherwise unsampled entries remain non-colliding until valid. Excess growth is still discarded.

## Initial appearance and length arithmetic

The renderer still draws the existing collapsed seed coordinates at startup, with the same lowest-index overlap ownership. It does not invent an extended straight body behind the spawn, change the Emerald artwork, or add render gating. As real head history shifts through the array, the fourteen nodes separate and body/corner/tail artwork follows the existing six-frame sampling. Node count remains a time-history measure, not fourteen distinct 24-pixel grid cells.

Hardware reset and `gameStartPulse` both restore 14. Ruby remains +1, Sapphire −3 with a floor of 1, and Cursed +5 with a cap of 63. Seven-bit intermediate saturation and Cursed > Sapphire > Ruby event priority are untouched. Clear still overrides simultaneous events/frame shift. Score-90 Victory and all score/speed effects are untouched.

The existing length-to-decimal and active-low SEG7 modules need no production edit: 14 already decodes as tens 1 / ones 4. Tests include those actual decoder modules, not just a guessed display string. Board display wiring and pin assignments are unchanged.

## Functional verification

| Test | Final result |
|---|---|
| New fourteen-node startup suite | PASS: 3,289,233 checks, 8,408 opaque body pixel samples, five expected controller defeats |
| 32-node reference/capacity regression | PASS: 2,110,103 checks, 193 history pairs, 772 movement frames |
| 63-node reference/capacity regression | PASS: 2,857,582 checks, 379 history pairs, 1,516 movement frames, history index 378 |
| Emerald renderer | PASS: 83 checks; four heads, straight body, four corners, four tails, RGB332/alpha/ROM address/output latency |
| Arena/movement/relic positioning | PASS: 307,200 visible pixels, 360 cells, all four movement directions and existing spawn/exclusion tests |
| Score-90 and relic rules | PASS: 1,056 checks; 00–89 continue, exact/crossing 90, penalties, collision, restart/reset |
| HUD and independent relic counters | PASS: 3,887,791 render checks plus counter, saturation, reset and high-score checks |
| Opening/menu/state/startup | PASS: 2,864,698 checks plus Victory-restart score-clear race test; correct new initial/collection/restart lengths |
| Victory/Defeat screens | PASS: 6,783,546 checks, six full frames; dynamic values, fatal Cursed, Victory, keypad-5 and preserved HUD/opening |
| Approved Emerald assets | PASS: `scripts/verify_snake_variants.py --variant 1`; all 14 sprites and 576 pixels per sprite |

The new suite connects the real motion module, body, game controller, decimal converter and both SEG7 decoders. It verifies:

- Menu/hardware reset length 14 and physical display glyphs 1/4.
- 420 running stationary frames before choosing a direction, exceeding a full history depth, with no self-hit or defeat.
- Initial movement in all four directions at the unchanged production initial speed, with 94 SOFs per direction and complete history-array comparison.
- Local restart after four actual controller wall defeats, followed by another 110 stationary SOFs per restart without false collision.
- Exact +1/−3/+5 arithmetic, cap 63, no overflow/queued growth, minimum 1, and reset after prior mature history.
- A legitimate collision with node 4 while node 13 and later entries are still invalid; the real controller then enters defeat. This rejects a blanket startup-grace implementation.
- Validity count saturation and no wrap after 379 samples.
- Fourteen-node render ownership, sprite kind, local/atlas address, RGB and opacity latency against the frozen independent renderer, with the reference initial length parameter set to 14. The reference's known-bad startup self-hit is not used as the new collision oracle.

The capacity tests compare every legal length and collection-pulse combination, all history values, full visible-pixel rendering and mature collision behavior against the frozen reference. The dedicated initial-length suite tests the production default separately, so retaining initial length 4 in the legacy equivalence suite does not hide the production change.

During test adaptation, the older capacity suite's positive-hit assertion initially failed: its previous hit count had depended on the very reset-seeded overlap now being excluded. Rather than weakening collision coverage, the suite now makes explicit contact with an actually sampled mature node. Final runs pass. No production RTL change was needed in response to that obsolete expectation.

Final new startup/capacity tests compile/simulate with zero HDL errors or warnings. The existing Emerald sprite test retains its eight established ModelSim force warnings. Existing-library notices are test-environment notices, not synthesized latch warnings. The legacy simulator needed execution outside the sandbox; its sandbox startup errors were not design/test failures.

Logs: `db/initial14_verification/` and the test scripts' ignored `simulation/*.log` outputs. No physical board or audible/visual hardware acceptance is claimed.

## Quartus compilation

The production configuration compiled successfully with Quartus Prime Lite 17.0.0 Build 595, revision `Lab1Demo`, top `TOP_VGA_DEMO`, Cyclone V `5CSXFC6D6F31C6`. Exactly one map/fit/STA/assembler flow was run; no compile retry, fitter-seed change, constraint relaxation or capacity reduction was needed. The fitter completed at 22:35:38; STA at 22:36:05; assembly at 22:36:29, Asia/Jerusalem. Logs are in `db/initial14_build/`. Settings-file writes were disabled for map/fit; no constraints or fitter settings were changed.

The synthesized parameter report explicitly confirms `(INITIAL_X,INITIAL_Y)=(384,240)`, `INITIAL_LENGTH=14`, `MAX_SEGMENTS=63`, `BODY_SIZE=24`, `SEGMENT_SPACING=6` (`output_files/Lab1Demo.map.rpt`, body-instance parameter table). This verifies the BDF override, not just the SV default.

### Actual FPGA utilization

| Resource | Previous 4-node start, cap 63 | New 14-node start, cap 63 | Difference |
|---|---:|---:|---:|
| ALMs | 14,328 / 41,910 | 14,528 / 41,910 (35%) | +200 |
| Registers | 9,901 | 9,950 | +49 |
| M10K blocks | 429 / 553 | 429 / 553 (78%) | 0 |
| Block memory bits | 3,405,308 | 3,405,308 | 0 |
| Pins | 91 / 499 | 91 / 499 | 0 |
| DSPs | 0 | 0 | 0 |
| PLLs | 1 | 1 | 0 |

These are whole-design fitted totals, including placement/duplication effects, not a prediction from the nine declared counter bits. The added eligibility logic does not allocate a new artwork/history ROM. All 52 graphics MIFs, including the approved Emerald atlas, remain byte-identical to the pre-change copies. The body visual-selection section is also byte-identical; its ownership, rotation and ROM pixel pipeline are unchanged.

### Actual internal timing

| Corner, unchanged 31.5-MHz domain | Setup slack | Hold slack | Setup/hold TNS |
|---|---:|---:|---:|
| Slow 1100 mV, 85 C | +4.422 ns | +0.292 ns | 0.000 / 0.000 ns |
| Slow 1100 mV, 0 C | +4.594 ns | +0.256 ns | 0.000 / 0.000 ns |
| Fast 1100 mV, 85 C | +15.254 ns | +0.175 ns | 0.000 / 0.000 ns |
| Fast 1100 mV, 0 C | +16.874 ns | +0.145 ns | 0.000 / 0.000 ns |

Worst setup changes from +4.785 to **+4.422 ns** (−0.363 ns); worst hold changes from +0.161 to **+0.145 ns** (−0.016 ns). Both remain positive. All reported minimum-pulse-width slacks are positive as well. No new timing exception, false path, clock change or audio/timing cleanup was applied.

### Warning comparison and outstanding limitations

| Stage | Baseline warnings | New warnings | New errors |
|---|---:|---:|---:|
| Analysis & Synthesis | 247 | 247 | 0 |
| Fitter | 91 | 91 | 0 |
| TimeQuest | 52 | 52 | 0 |
| Assembler | 0 | 0 | 0 |

Warning-message multisets were compared with the backed-up reports after normalizing source-line numbers: no added or removed warning messages were found in map, fit or STA. There are no newly introduced latch/loop warnings. The same five audio register/latch-emulation warnings and five loops analyzed as latches remain; they are outside this feature.

Internal timing closure does **not** certify external I/O constraints. Existing limitations remain:

- Unconstrained clocks: 0.
- Unconstrained input ports/paths: 5 / 120, unchanged.
- Unconstrained output ports: 56, unchanged. Paths are now 147 rather than 148; this does not mean external constraints have been repaired.
- Existing ignored/unmatched audio, VGA, DRAM and JTAG constraints, ignored assignments and nine unlocated debug outputs remain.
- No physical FPGA test was performed. Actual fourteen-node startup, display readability and gameplay acceptance on the board remain for the user.

## Production SOF

The updated production file is **`output_files/Lab1Demo.sof`**, generated directly in the normal production output directory, not an experimental snapshot directory.

- Generated: **2026-10-20 22:36:29**, Asia/Jerusalem.
- Size: **6,690,369 bytes**.
- SHA-256: **`56B36933873783DF20E901240FC00CC6BD0DB432FA85020CDF68C85163001A68`**.
- The new hash differs from the previous production SOF.
- Previous production SOF and reports remain in `db/initial14_baseline/output_files/`.
- The SOF is an ignored generated deliverable, not included in the source commit.

## Production preservation and Git

Before editing, all 551 tracked/nonignored working-tree paths were copied to `db/initial14_baseline/files/`, preserving the user's current content rather than only HEAD. Existing production output files/reports were copied to `db/initial14_baseline/output_files/`.

The original SOF hash is `9D6DBAFE2CE13A1A4886F71E63AEA200393271D795C5C6B4D21A2DA194B28EA9`. The preserved QSF hash is `28C210EA52E112BD51A574157ABFD69BF27F6066B47354A8786E9BB6177768C9`; the preserved top BDF hash is `F17E9AF9AFB072738EBF55EAFF52DBA0589D0DD7AB9823BCBC45ECDEC7286643`.

Both post-edit and final post-compilation preservation checks found exactly the six intended existing source/test files changed among all 551 backed-up paths; no pre-existing file was missing, and every other pre-existing file matched the backup. QSF/top-BDF hashes still match the values above. Generated libraries, logs, compiler databases and programming files remain ignored, not source-commit candidates. Existing untracked audio/graphics audits, previews, comparison assets/builds and scripts remain unrelated to this feature.

The untracked `Lab1Demo.qws` workspace file appeared during this run. It was left untouched and will not be staged; it was not present in the initial baseline listing. It is not a production RTL/configuration edit requested by this feature.

The focused local commit is limited to the two production files, four updated regression files, two new regression files and this report, with message `Start production snake at 14 body nodes`. Unrelated QSF/top-BDF changes, audits, assets, experiments and the workspace file remain outside that commit. No push, board programming, repository cleanup, project rename or subsequent feature phase was performed.
