# The Temple's Curse

A Jungle Temple-themed Snake arcade game implemented in **SystemVerilog and Quartus block diagrams** on the **Terasic DE10-Standard (Cyclone V)**.

The project was developed as part of Electrical Engineering Lab A1 at the Technion and integrates VGA graphics, keyboard input, audio feedback, scoring, collision detection, and multiple gameplay mechanics.

## Features

- 640×480 VGA graphics; 20×18 arena with 24×24-pixel tiles
- Keyboard-controlled snake movement
- Snake growth and self-collision detection
- Border collision detection
- Score and high-score tracking
- Reach **90 points or more** to win
- Initial length: **14 body nodes + head**; maximum: **63 body nodes + head**
- Three relic types:
  - Ruby: +1 score, +1 body node
  - Sapphire: +3 score, −3 body nodes (minimum length: 1)
  - Cursed: −5 score, +5 body nodes; fatal when collected at a score of 5 or less
- Audio feedback and sound effects
- Variable game speed
- ROM/MIF-based graphics
- Jungle Temple floor, ruins and vertical HUD with independent relic counters
- Optimized Emerald Serpent sprites with pixel-exact rotation-based ROM sharing
- Updated opening title and Enter start/restart instructions, plus Victory/Defeat reports

## Controls

Numpad **8 / 4 / 6 / 5**: Up / Left / Right / Down.
**Enter** (main or Numpad): Start / Restart. Numpad 2 is no longer Down.
The opening guide and result-screen instructions reflect these controls.

## Hardware & Tools

- Terasic DE10-Standard, Cyclone V `5CSXFC6D6F31C6`
- SystemVerilog
- Intel Quartus Prime Lite 17.0.0 Build 595 (verified production toolchain)
- ModelSim
- SignalTap
- VGA display
- PS/2 keyboard
- Audio output

## Project Structure

- `RTL/VGA` — game logic and VGA rendering
- `RTL/AUDIO` — audio controller and sound effects
- `RTL/KEYBOARDX` — keyboard interface
- `RTL/Seg7` — seven-segment display logic
- `RTL/mifs` — graphics ROMs and collision masks; audio notes are in `RTL/AUDIO/songs.mif`
- `Lab1Demo.qpf` / `Lab1Demo.qsf` — active project/revision and board assignments; top-level entity: `TOP_VGA_DEMO`
- `DE10_Standard_Audio.sdc` — active timing constraints; `constraints` contains supporting pin Tcl and a separate historical SDC
- `scripts` / `simulation` — asset/verification tools and ModelSim testbenches
- `assets/jungle` — approved artwork, previews and concept/reference material

## Verification

Existing ModelSim regressions cover gameplay, collisions, relic effects, length limits, controls and rendering. The frozen production Quartus build passed with positive constrained setup/hold margins and the AG30/virtual-debug pin-safety audit. External-I/O constraints remain incomplete.

VGA refresh caveat: although the intended display specification is 640×480 @ 60 Hz, the unchanged 31.5 MHz PLL and legacy raster counters imply approximately **72.58 Hz**, as documented in [PRECHANGE_BASELINE.md](PRECHANGE_BASELINE.md). This is not a verified 60 Hz implementation.

Build/simulation verification is separate from physical FPGA approval: no new board or listening tests are claimed here. See [PRODUCTION_RELEASE_FREEZE_REPORT.md](PRODUCTION_RELEASE_FREEZE_REPORT.md) for the production SOF checksum, release snapshot and reproducibility limitations, and [CURSED_RELIC_AUDIO_FIX_REPORT.md](CURSED_RELIC_AUDIO_FIX_REPORT.md) for the latest audio test status.

Keep required vendor IP, PLL files, MIFs and timing constraints intact. Some historical generators/tests require preserved local fixtures; fresh-checkout reproducibility has not yet been validated.
