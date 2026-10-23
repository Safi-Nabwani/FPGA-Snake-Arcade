# The Temple's Curse — Production Release Freeze

2026-10-23. Phase 11B complete. No compilation, simulation, hardware/source/asset edits, deletion, move, rename, cleanup or push. Existing files and rollback directories remain intact.

## Frozen release

Local, ignored snapshot directory:

`db/release_freezes/production_20261023_113433_033/`

This is a directory archive, not a ZIP. Its `SHA256_MANIFEST.json` records 702 preserved files; every listed copy was rehashed successfully. Manifest SHA-256:

`39B0698AA611F63A0C0203D398B1D88A5512C64BE57B187FEFA434FDCA402EAB`

| Artifact | Archive-relative location | SHA-256 |
|---|---|---|
| Production SOF | `release/output_files/Lab1Demo.sof` | `C07687847A3F4B4CCAA1075C7F96D83A22CAAC202ACF622CCD89907406ACA8DB` |
| Previous known-good production rollback | `release/db/cursed_audio_baseline/output_files/Lab1Demo.sof` | `198FAFF0D32184327CA0840E23EB281E0093B8F881E3DCAA1084FBF2DDA57C09` |

The live SOF matches the requested checksum and remains unchanged. Both SOFs were copied and checked against their documented checksums. “Known-good” here refers to the prior verified production build; no new physical listening/programming claim is made.

The snapshot also includes:

- Final production `.pin`, map/fit/STA summaries, rollback `.pin`, original audio MIF and existing final pin-audit log.
- Exact tracked and nonignored untracked working files, excluding the separate five-build comparison directory (left intact). Includes required QXP/QIP/PLL/SDC, all working RTL/MIFs, scripts, concepts, reports and relevant uncommitted material.
- Initial HEAD `cc4c733`, detailed Git status, binary working/index patches and source/MIF hashes. Initial index was empty.
- Selected ignored fixtures listed below and Quartus/revision metadata. Source copies are under `working_tree/`, ignored dependencies under `fixtures/`.
- Supplemental `phase11b_integrity.json` and `coverage.json` record this phase's checks; these were added after the original manifest and are identified separately in the final local seal.

Existing summaries identify Quartus Prime Lite **17.0.0 Build 595**, revision **Lab1Demo**, top **TOP_VGA_DEMO**, Cyclone V **5CSXFC6D6F31C6**. Existing release results: 13,403 ALMs, 9,970 registers, 421/553 M10Ks; worst setup +4.506 ns, hold +0.135 ns. These are retained results, not new measurements. External-I/O constraint limitations remain.

## Focused local commits

### `e61a047` — Record approved Enter and numpad keyboard remapping

Approved production change / required tests and release evidence:

- `RTL/KEYBOARDX/keyPad_decoder.sv`
- `RTL/VGA/TOP_VGA_DEMO.bdf`
- `RTL/VGA/game_controller.sv` (existing comment update only)
- `simulation/audio_noise_output_tb.sv`
- `simulation/opening_screen_tb.sv`
- `simulation/results_reports_tb.sv`
- `simulation/keypad_remap.do`, `simulation/keypad_remap_tb.sv`
- `KEYBOARD_REMAP_REPORT.md`

Reviewed existing Enter make/break tracking, keypad-5 Down, BDF Enter/Down wiring and related test changes. BDF block movement, connector relocation and label sizing are preserved exactly, not reformatted. Existing `db/keypad_remap.log` records 142 passing checks; archived, not rerun. Historical release report remains unchanged.

### `3081787` — Record approved Enter control artwork in production ROMs

Approved production artwork / supporting script and reference evidence:

- `RTL/mifs/opening_supplied_atlas.mif`
- `RTL/mifs/results_v3/results_tilemap.mif`
- `RTL/mifs/results_v3/results_tiles_rgba9.mif`
- `scripts/update_control_artwork.py`
- `CONTROL_ARTWORK_UPDATE_REPORT.md`
- `assets/jungle/control_artwork_update/verification.json` and its six existing PNG previews (`opening_640x480`, `opening_2x`, `victory_640x480`, `defeat_640x480`, `victory_panel_288x432`, `defeat_panel_288x432`).

Read-only data comparison against initial HEAD found 4,222 pending opening pixel changes, all in the control guide/keycap regions; the later approved title and start-prompt binaries remain exact. Results decode to 1,259 changed Victory pixels and 1,038 Defeat pixels, confined to restart instruction boxes, with every alpha bit unchanged. ROM dimensions remain 8×104476, 15×62208 and 9×69628. Large textual diffs include existing CRLF and tile-dictionary repacking, not broad artwork changes.

The older control-artwork opening previews/script describe the intermediate control update, not the final title/prompt. The current opening authority remains `assets/jungle/approved_opening/` plus `scripts/integrate_approved_opening.py`. Do not run the older installer over the final approved opening. Its historical report and previews were preserved unchanged.

This freeze report is committed separately as release documentation after staged review.

## Files deliberately left uncommitted

| Files | Classification / reason |
|---|---|
| `Lab1Demo.qsf` | Unrelated user change: one added blank line. Left untouched; exact file archived. Safety assignments already tracked. |
| `README.md` | Mixed documentation: correct remapped controls plus stale assertion that artwork was not updated. Leave unchanged rather than silently publish misleading text or edit beyond this phase. |
| `AUDIO_ARCHITECTURE_AUDIT.md`, `GRAPHICS_MEMORY_OPTIMIZATION.md`, `OPENING_SCREEN_MEMORY_OPTIMIZATION.md`, `OPENING_TITLE_UPDATE_REPORT.md`, `SNAKE_LENGTH_ARCHITECTURE_AUDIT.md`, `REPOSITORY_CLEANUP_AUDIT.md` | Historical/reference documentation; preserved locally and in the snapshot, deferred to the documentation phase. |
| `scripts/update_opening_title.py`, `scripts/preview_opening_memory.py`, `assets/jungle/{memory_optimization,opening_memory_preview}/`, `reference_exports/` | Historical generators/trials/reference exports, not required active production inputs. Archived with existing state; no cleanup. |
| `scripts/build_snake_variants.ps1`, `RTL/VGA/snake_sprite_config.svh`, four non-Emerald MIFs, `assets/jungle/snake_sprite_sets_supplied/`, `snake_comparison_builds/` | Five-design comparison/reference material. No active production dependency found; preserve for later approved organization. Comparison SOFs/ZIP stay in their original folder. |
| `Lab1Demo.qws`, `RTL/VGA/game_controller.sv.bak` | Local workspace/backup, not production inputs. Preserved, not committed or deleted. |

All 11 originally modified tracked files are accounted for: nine committed, QSF and README left unchanged. No unrelated file was staged.

## Reproducibility and readiness for Phase 11C

- All **75 checked explicit QSF and literal RTL resource/include references** exist and are tracked after reconciliation. Imported audio/keyboard QXPs, PLL files, both SDC versions, active MIFs and the pin-safety script remain intact. This limited check is not full elaboration.
- Current working production source/asset content is represented in Git after the two commits, except the QSF's nonsemantic blank line; the archive preserves exact working bytes. The README and experimental/reference material are separate outstanding items. Existing reports connect this state to the verified SOF; no fresh build or independent binary-to-source provenance proof was attempted.
- Preserved required inputs: `db/control_artwork_baseline/mifs/`, `db/approved_opening_baseline/opening_supplied_atlas.mif`, `db/opening_title_baseline/opening_supplied_atlas.mif`, `db/cursed_audio_baseline/songs.mif`, `db/cursed_audio_build/golden.hex`, `db/sprite_opt_build/original.hex`, `db/keypad_remap.log`.
- Preserved fixture directories: `db/{jungle_graphics_fixture,jungle_implementation_fixture,jungle_hud_final_fixture,jungle_hud_fixture,opening_screen_fixture,supplied_opening_fixture,results_fixture,results_v3_fixture}/`. Every specifically selected fixture path existed. Rehydrate these archive-relative paths if running dependent historical/focused tests from a future checkout; generated fixture files are intentionally not committed.
- Historical tools also depend on Git history/index state, old build summaries and diagnostic fitted netlists (for example `db/audio_noise_investigation/audio_fitted.vo`). The snapshot is not a blanket copy of all historical build databases. Those original directories remain intact; diagnostic/historical workflows need a separate inventory if they become release requirements.
- Source snapshot hashes were rechecked after staging/committing; all original working files retain their bytes. Staged lists and diffs were reviewed for each commit. Integrity checks pass with Git's `cr-at-eol` whitespace interpretation; default whitespace checking flags existing CRLF in binary-preserved MIFs. No line-ending cleanup was performed.
- AG30 protection and nine virtual graphics-debug outputs are preserved through unchanged source/resource bytes and copied final `.pin`/existing audit evidence. No new fit or pin audit was required or claimed.

**Ready for a separately approved Phase 11C:** production release is frozen and approved control/artwork changes are now tracked. The working tree is intentionally not clean. Public README corrections, historical organization, optional project rename and clean-checkout rebuild validation remain future work. No fresh-clone reproducibility claim is made.
