# FPGA Snake Arcade — Phase 1 Project Map

Inspection date: 2026-10-09. Scope: static inspection only.

Workspace: `C:/Users/USER/Documents/Work/FPGA-Snake-Arcade`.
Baseline commit: `eabf54636d56b7bec2a31b19b3be52e274e13ef0` (`Create README.md`, 2026-09-11).
The Git working tree was clean before this inspection. This document is the only file created or changed during Phase 1. No graphics were generated, no HDL or configuration was edited, and no compilation, simulation, FPGA programming, commit, or push was performed.

This map describes the files currently present, not earlier experimental versions from the conversation. Build success, timing closure, resource utilization, and hardware behavior have not been revalidated. Later enhancement phases remain unapproved.

## 1. Executive overview

The design is a schematic-led SystemVerilog game. `TOP_VGA_DEMO.bdf` connects the game logic, VGA raster generator, layered ROM graphics, PS/2 keyboard, audio, and seven-segment display. There is no software CPU, operating system, or full-screen framebuffer in the inspected source hierarchy. Pixels are produced as the VGA raster scans the screen.

The existing arena is **16 columns × 16 rows of 24-pixel cells**, positioned at `(128,88)`, with a 384×384-pixel playable rectangle. The proposed 18×11, 32-pixel-cell layout in the enhancement brief is not implemented. Both `VGA_BG_new_playground.mif` and `jungle-temple-reference.png` are absent from this workspace.

All direct source/configuration paths listed in the QSF exist. All 14 referenced MIF files exist and their declared address spaces are populated. Important problems are concentrated in simulation/debug references and timing assumptions, rather than missing main gameplay source files.

## 2. Quartus project, target, and dependencies

| File | Role / current finding |
| --- | --- |
| [Lab1Demo.qpf](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/Lab1Demo.qpf) | Quartus project; revision `Lab1Demo`; records Quartus 17.0. |
| [Lab1Demo.qsf](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/Lab1Demo.qsf:40) | Source list, target, I/O standards, partitions, output directory, and embedded SignalTap assignments. Family `Cyclone V`; device `5CSXFC6D6F31C6`; top entity `TOP_VGA_DEMO`. |
| [TOP_VGA_DEMO.bdf](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/RTL/VGA/TOP_VGA_DEMO.bdf) | Actual top-level implementation; not a same-named `.sv` file. |
| [pin.tcl](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/constraints/pin.tcl) | QSF-listed board pin assignments and additional fitter settings. Contains template assignments for several ports no longer in the top level. |
| [DE10_Standard_Audio.sdc](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/DE10_Standard_Audio.sdc) | The timing file actually selected by the QSF. Includes stale VGA/audio/SDRAM port references. |
| [constraints/DE10_Standard_Audio.sdc](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/constraints/DE10_Standard_Audio.sdc) | Different second copy, not selected by the QSF. Editing this copy alone would not change the selected timing constraints. |
| [CLK_31P5.qip](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/CLK_31P5.qip) | Synthesis IP manifest; loads the wrapper, nested PLL implementation, nested QIP, and component declaration. Generated with IP tools 20.1 despite project metadata 17.0. |
| [CLK_31P5.v](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/CLK_31P5.v:8) | PLL wrapper entity `CLK_31P5`; instantiates `CLK_31P5_0002` as `clk_31p5_inst`. |
| [CLK_31P5_0002.v](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/CLK_31P5/CLK_31P5_0002.v:17) | Instantiates vendor `altera_pll`; 50 MHz reference, 31.5 MHz output, Cyclone V. |
| [CLK_31P5_0002.qip](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/CLK_31P5/CLK_31P5_0002.qip) | PLL compensation, automatic-reset and bandwidth assignments. |
| [CLK_31P5.cmp](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/CLK_31P5.cmp) | Component declaration, not gameplay source. |
| [CLK_31P5.sip](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/CLK_31P5.sip), [CLK_31P5.spd](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/CLK_31P5.spd) | Simulation package metadata. Both refer to missing `CLK_31P5_sim/CLK_31P5.vo`. |
| [KBDINTF.qxp](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/KBDINTF.qxp) | Imported compiled keyboard design partition, 42,175 bytes. Its RTL internals are not available here. |
| [audio_codec_controller.QXP](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/audio_codec_controller.QXP) | Imported compiled audio-codec design partition, 68,233 bytes. Its RTL internals are not available here. |

External tool/library dependencies: Quartus BDF elaboration, Cyclone V device support, `altera_pll`, `lpm_rom`, and the two imported QXP partitions. The waveform scripts also expect ModelSim OEM and the `cyclonev_ver`, `altera_ver`, `altera_mf_ver`, `220model_ver`, `sgate_ver`, and `altera_lnsim_ver` libraries. These are tool dependencies, not missing repository modules. This inspection did not check which tool versions or simulation libraries are installed.

The `pin.tcl` template selects fast fitting and disables some physical synthesis options and hold optimization. Its settings matter because it is a project dependency, not merely a reference document. The exact implications require a later authorized timing/build check.

## 3. Actual schematic hierarchy

Names after `:` are BDF instance names. Repeated `square_object` and `SEG7` blocks share the same source. Vendor primitives and imported partitions are explicitly marked.

```text
TOP_VGA_DEMO                         RTL/VGA/TOP_VGA_DEMO.bdf
├── CLK_31P5:inst7                   PLL wrapper
│   └── CLK_31P5_0002:clk_31p5_inst
│       └── altera_pll:altera_pll_i  vendor IP
├── NOT:inst3                       reset polarity conversion
├── TOP_KBD:inst16                   RTL/KEYBOARDX/TOP_KBD.bdf
│   ├── KBDINTF:inst                 imported KBDINTF.qxp
│   └── keyPad_decoder:inst2
├── game_controller:inst22
├── Snake_Block:inst13               RTL/VGA/Snake_Block.bdf
│   ├── speed_controller:inst
│   ├── snake_head:inst3
│   ├── square_object:inst4          head rectangle: 22×24 (!)
│   ├── headBitMap:inst5              24×24 head ROM and rotation
│   └── snake_body:inst6             body trail, ROM, length, self-collision
├── Apple_Block:inst10               RTL/VGA/Apple_Block.bdf
│   ├── randomCounter:inst
│   ├── apple_position_controller:inst5
│   ├── apple_topleft_calc:inst1
│   ├── blue_apple_controller:inst8
│   ├── square_object:inst11         red: 24×24
│   ├── square_object:inst12         blue: 24×24
│   ├── square_object:inst13         black: 24×24
│   └── AppleBitMap:inst3             three color ROMs, one combined pixel layer
├── Score_Block:inst11               RTL/VGA/Score_Block.bdf
│   ├── appleCounter:inst133          actual score accumulator
│   ├── highscoreComp:inst1
│   ├── ScoreConstants:inst2
│   ├── square_object:inst4          score rectangle: 64×64
│   ├── square_object:inst42         high-score rectangle: 64×64
│   └── NumbersBitMap:inst500         shared glyph ROM
├── back_ground_draw:inst4           HUD, arena, wood border, obstacles
├── end_message_display:inst17       win/loss panels
├── objects_mux:inst19               registered layer selection
├── VGA_Controller:inst              raster, coordinates, sync, physical bus
├── Hex_Block:inst5                  RTL/Seg7/Hex_Block.bdf
│   ├── snakeLengthDigits:inst1
│   ├── SEG7:inst34,inst35            two active decimal digits
│   ├── SEG7:inst22,inst23,inst24,inst25  remaining displays blanked
│   └── GND / VCC                    enable constants
└── Audio_Block:inst6                RTL/AUDIO/Audio_Block.bdf
    ├── sound_effect_controller:inst1
    └── AUDIO:inst                   RTL/AUDIO/AUDIO.bdf
        ├── melody_player_1:inst5
        │   ├── lpm_rom:rom_inst      songs.mif
        │   └── Mili_sec_counter:mili_sec_counter_inst
        ├── ToneDecoder:inst4
        ├── prescaler:inst3
        ├── addr_counter:inst9
        ├── sintable:inst1            source filename SinTable.sv
        └── audio_codec_controller:inst  imported QXP
```

`JukeBox1.sv` and `simple_up_counter.sv` are listed in the QSF but are not instantiated in the inspected hierarchy. They are legacy/support alternatives, not the active melody player or keyboard implementation. There is no standalone active `obstacles` module: obstacle rendering and collision output are integrated into `back_ground_draw`.

## 4. Clock, reset, inputs, and physical outputs

### Clock/reset distribution

```text
CLOCK_50 ──> CLK_31P5.refclk ──> outclk_0 ──> named net clk (31.5 MHz)
resetN_pin ──> NOT ──> CLK_31P5.rst
CLK_31P5.locked ──> named net resetN ──> active-low resets throughout design
```

The keyboard block's port is named `CLOCK_50`, but the top schematic connects it to `clk`, the 31.5 MHz PLL output. Audio, game logic, renderers, VGA and HEX blocks also receive `clk`. Do not infer actual frequency solely from a port name. Keyboard QXP internals cannot be checked for frequency assumptions from this repository.

`resetN_pin` maps to board KEY0 (`PIN_AJ4`). Its low level asserts the PLL reset through the inverter. PLL lock is used directly as the internal reset-release signal; no separate visible reset-release synchronizer/debouncer exists in the top-level schematic. `gameStartPulse` is a game-local clear, distinct from hardware reset: it clears score, length/trail, speed, blue visibility, and the end-message state but preserves the previous high score.

### Keyboard handling

`KBDINTF` receives PS/2 clock/data and provides a 9-bit scan code plus make/break indications. `keyPad_decoder.sv` maintains held-key bits and decodes 18 keypad/special codes. Game movement uses keypad **8=up, 6=right, 4=left, 2=down**; keypad **5=start/restart**. No WASD mapping is implemented. Extended arrow scan codes are not explicitly mapped as movement keys.

`keyIsValid` is a one-clock make pulse for 2/4/6/8 and drives movement sounds. Movement itself uses held-key bits. Key 5 is a held level, not a dedicated edge pulse; if held when the FSM enters a terminal state, it can immediately restart. The direction priority when multiple movement keys are held is 8, then 6, then 4, then 2.

### Top-level ports

| Direction | Ports | Purpose |
| --- | --- | --- |
| Input | `CLOCK_50` | Board oscillator. |
| Input | `PS2_CLK`, `PS2_DAT` | Keyboard connection. |
| Input | `resetN_pin` | Hardware reset/PLL reset request. |
| Input | `KEY[3]` | Audio volume input; falling edges cycle volume levels in `sintable`. |
| Input | `AUDIN[1..2]` | Audio LR clock / bit clock according to pin template. |
| Output | `OVGA[28..0]` | Pixel clock, blanking, sync signals and three 8-bit DAC channels. |
| Output | `HEX0` through `HEX5`, each `[6..0]` | Seven-segment displays; first two show decimal snake length, remaining four are blanked. |
| Output | `AUDOUT[4..7]` | DAC data, audio master clock, codec I2C clock/data. |
| Output | `BG_RGB[7..0]`, `borderDR` | Background/debug signals exported as physical top-level outputs; no explicit location assignments were found for these ports. |

Template references such as `SW[*]`, `ADC_*`, `AUD_ADCDAT`, `AUDIN[3]`, `AUDOUT[0]`, `redLight`, and `yellowLight` are not equivalent to existing top-level ports. They should be audited before a later hardware build; they were not removed here.

## 5. Gameplay modules and event flow

The VGA raster provides `pixelX`, `pixelY`, and a once-per-frame `startOfFrame`. Renderers expose color and drawing-request signals (`DR`). Head/apple overlap and head/border/rock overlap feed `game_controller`; body self-collision is a separate rectangle-overlap signal. The controller broadcasts one-clock events back to score, motion/length/speed, apple positioning, sound and end-message logic.

```text
PS/2 ──> held movement keys ──> snake_head ──> head position/direction
                                           ├─> head bitmap / head DR
                                           └─> snake_body trail / self-collision
pixel coordinates ──> background border/rock DR + apple DR + head DR
                                  └────────────> game_controller
score digits ──> win/black-apple thresholds ─────> game_controller
game_controller events ──> score, speed, length, apple respawn, sound, messages
all visible pixel layers ──> objects_mux ──> VGA_Controller ──> OVGA
```

| Module / source in `RTL/VGA` | Responsibility and dependencies |
| --- | --- |
| `game_controller.sv` | Four-state idle/running/won/lost FSM. Starts/restarts on key 5. Tests win, wall/rock/self collision, then black, blue, red apple collisions in that order. Generates game start/end/won/over and three apple-hit pulses. Its `appleHitFlag` allows at most one apple event per frame. |
| `snake_head.sv` | Smooth fixed-point motion with multiplier 64. Starts at `(320,280)`, stationary until direction input. Advances on frame events, snaps to 24-pixel target cells, accepts turns at target boundaries, rejects opposite-direction requests relative to current direction. Outputs pixel position and direction for head rotation. Resets position while game is not running. |
| `snake_body.sv` | Stores 193 historical head positions, updated once per running frame. Renders up to 32 segments from trail indices `(segmentIndex+1)*6`. Initial length 4, minimum 1, maximum 32. Updates length on apple pulses. Tests self-collision from zero-based segment index 4 onward, with 6-pixel inset on head/body rectangles. Loads body ROM. |
| `speed_controller.sv` | Fixed-point speed: initial 130, min 80, max 250; red +3, blue −5, black +10. Clears on new-game pulse. Speed is consumed by head motion; it is not a separate clock. |
| `randomCounter.sv` | Three free-running 8-bit counters, increments +5/+7/+13, reset seeds `37/A5/6C`. Samples low nibble X and high nibble Y on triggers or invalid-position feedback. Deterministic timing-sampled counters, not an LFSR or true random source. Red events also reroll black; black events reroll black; blue spawn rerolls blue. |
| `apple_position_controller.sv` | Combinational validation against a 16×16 rock mask and pairwise apple overlap. Sends error feedback to counters until acceptable coordinates occur. Its `FixedX/Y` outputs are direct pass-through, not a separate valid-position register. No snake-head/body exclusion input exists. Hidden blue apples still participate in pairwise position validation. |
| `apple_TopLeft_Calc.sv` | Entity name is `apple_topleft_calc`. Converts 4-bit tile coordinates into pixels: X=`128+24*tileX`, Y=`88+24*tileY`. |
| `blue_apple_controller.sv` | Counts red hits modulo five. Every fifth red hit spawns blue only if blue is not already visible; blue consumption hides it. New game clears counter/visibility. |
| `appleCounter.sv` | Despite its name, this is the score accumulator, not the five-red spawn counter. Maintains decimal ones/tens with carry/borrow and clears on game start. |
| `highscoreComp.sv` | Captures a larger score on `gameEndPulse`. High score survives local restarts but resets on hardware reset; no nonvolatile storage. |
| `ScoreConstants.sv` | Supplies score display origins `(164,12)` and high-score origin `(548,12)`. |

### Implemented rules, not README shorthand

| Apple | Score | Body length | Speed | Visibility/position behavior |
| --- | --- | --- | --- | --- |
| Red | +1 | +1 | +3 | Consumption rerolls red and black. |
| Blue | +3 | −3, floor 1 | −5, floor 80 | Appears after groups of five red hits when not already visible; hides when eaten. |
| Black | −5, floor 0 | +5, cap 32 | +10 | Consumption rerolls black; score ≤5 causes loss. |

Win condition: score tens digit ≥2, i.e. score ≥20 for valid decimal digits. Loss: head overlaps non-arena border or rock pixels, or rectangle self-collision, or black apple is eaten with score ≤5. Black penalty and game-end pulses can occur together.

The README's blue −3 / black +5 values match **length effects**, not score effects. Avoid describing them as scoring rules in an interview. Also, `SEGMENT_SPACING=6` selects six-frame history intervals; despite its source comment, it is not fixed six-pixel geometric spacing. Body spacing changes with speed and tile-boundary snapping.

## 6. VGA output and graphics generation

### Raster and physical RGB mapping

[VGA_Controller.sv](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/RTL/VGA/VGA_Controller.sv:11) generates coordinates, sync/blanking, a linear `640*PixelY+PixelX` address and `startOfFrame` on the falling VS edge. The address output is present in the top schematic but is not connected to a framebuffer in this hierarchy.

| Timing component | Horizontal | Vertical |
| --- | --- | --- |
| Front porch | 24 | 9 |
| Sync | 40 | 3 |
| Back porch | 128 | 28 |
| Nominal active size | 640 | 480 |
| Source total constant | 832 | 520 |

The counters increment while `< TOTAL` and then wrap, so the source actually counts through the total value: 833 pixel periods per line and 521 line counts per frame. With 31.5 MHz this implies approximately **72.58 Hz**, not 60 Hz. Blanking checks only the lower thresholds, exposing a potential extra active column/row (`PixelX=640`, `PixelY=480`). This is a static source finding, not a measurement of a monitor. Comments and the SDC's 25.18 MHz/60 Hz template do not describe the implemented PLL/raster combination.

The graphics pixel format is **RGB332**: R=`RGBIn[7:5]`, G=`[4:2]`, B=`[1:0]`. Read both HDL and board pin assignments:

| `OVGA` bits | Actual board destination |
| --- | --- |
| `[7:0]` | Red DAC channel, expanded from RGB332 red. |
| `[15:8]` | Green DAC channel. |
| `[23:16]` | Blue DAC channel. |
| `[24]`, `[25]`, `[26]` | HS, VS, SYNC_N respectively; source drives SYNC_N from VS. |
| `[27]`, `[28]` | BLANK_N and inverted pixel clock. |

The HDL comment incorrectly labels the high color byte as red and the low byte as blue. [pin.tcl](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/constraints/pin.tcl:128) assigns the opposite physical channels, yielding the normal RGB332 mapping above. A future screenshot decoder must follow the physical mapping rather than that comment. Expansion repeats the channel's most significant bit in low output bits; it is not exactly conventional full bit replication/scaling.

### Renderers and composition

| Source in `RTL/VGA` | What it draws |
| --- | --- |
| `back_ground_draw.sv` | Full background: 640×88 ROM-based top HUD, 16×16 arena of grass/stone/rock tiles, repeating 32×32 wood outside the arena. Supplies collision signals `borderDR=!insideArena` and `obstacle_DR=insideArena && rockTile`. |
| `square_object.sv` | Registered rectangle test and local X/Y offsets; reused for head, apples and score/high-score rectangles. Default 100×100 is overridden in BDF instances. Its optional solid color is not the main sprite artwork. |
| `headBitMap.sv` | 24×24 upward-facing head texture, rotated by address transforms for up/right/left/down. Drawing request excludes `FF` pixels. |
| `snake_body.sv` | 24×24 body texture over the head-history trail. Drawing request excludes `FF` pixels and is gated by `gameStarted`. |
| `AppleBitMap.sv` | Three 24×24 apple ROMs. Selects black before visible blue before red when rectangles overlap. Provides separate collision DR outputs and combined visual DR/color. |
| `NumbersBitMap.sv` | 16×32 monochrome glyph slots, enlarged 2× to 32×64; two digits occupy a 64×64 rectangle. Current score is white through 10 and yellow/gold above 10; high score is red. |
| `End_Message_Display.sv` | Entity `end_message_display`. Loads separate 560×90 win/loss panels at `(40,190)` and retains selected message until new game or reset. Panel is opaque: it does not treat `FF` as transparent. |
| `objects_mux.sv` | Registered selection priority: message > head > body > score > high score > apple > background. |

ROMs use registered addresses and unregistered ROM outputs. Other rectangle/head/mux stages also register signals, while several background/apple/score selection signals are combinational. There is **no single explicit shared latency-alignment pipeline** for all layers/DR/collision signals. Preserve or deliberately align these relationships in later work; static inspection alone does not prove pixel-perfect alignment.

`FF` means transparent for snake/apple textures, but it is also the white color value in RGB332. White is usable for glyphs because the font ROM is a separate 1-bit mask. It cannot be used as opaque white in the current sprite renderers without changing their transparency convention.

### Actual layout and obstacles

All bounds below are half-open pixel rectangles, with origin at upper left.

| Region | Geometry |
| --- | --- |
| Intended visible image | 640×480. |
| HUD | X `[0,640)`, Y `[0,88)`. Labels/art are baked into `top_background_8bit.mif`. |
| Playable arena | X `[128,512)`, Y `[88,472)`; 384×384. |
| Grid | 16×16 cells, each 24×24. X/Y grid indices each 4 bits. |
| Exterior | Repeating wood texture; all pixels outside the arena assert border collision, including HUD. |
| Snake starting cell | `(320,280)` = grid `(8,8)`. |
| Score / high score | 64×64 rectangles at `(164,12)` / `(548,12)`. |
| Terminal message | 560×90 rectangle at `(40,190)`. |

The visible arena map stores two bits per tile in sixteen 32-bit row constants. Column zero occupies bits `[31:30]`. Rock cells are `(column,row)`:

- Rows 3–4: columns 11–12.
- Rows 9–10: columns 3–4.
- Rows 11–12: columns 3–6.

There are 16 rock cells total. These coordinates match the separately maintained bit masks in `apple_position_controller.sv`. The maps currently agree, but there is no shared map definition enforcing consistency.

## 7. Complete MIF / ROM / image asset inventory

All graphics MIFs are in `C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/RTL/mifs`. Entries are row-major unless noted. All listed assets are referenced by active modules; none of these 14 MIFs is an unused redesign alternative.

| MIF filename | Width × depth | Interpretation | Consumer |
| --- | --- | --- | --- |
| `top_background_8bit.mif` | 8 × 56,320 | 640×88 HUD artwork | `back_ground_draw` |
| `grass_tile_24.mif` | 8 × 576 | 24×24 grass tile | `back_ground_draw` |
| `stone_tile_24.mif` | 8 × 576 | 24×24 stone tile | `back_ground_draw` |
| `rock_tile_24.mif` | 8 × 576 | 24×24 obstacle tile | `back_ground_draw` |
| `wood_tile_32.mif` | 8 × 1,024 | 32×32 repeating border tile | `back_ground_draw` |
| `snake_head_24.mif` | 8 × 576 | 24×24 head, upward orientation per consumer | `headBitMap` |
| `snake_body_24.mif` | 8 × 576 | 24×24 body | `snake_body` |
| `red_apple_24.mif` | 8 × 576 | 24×24 red apple | `AppleBitMap` |
| `blue_apple_24.mif` | 8 × 576 | 24×24 blue apple | `AppleBitMap` |
| `black_apple_24.mif` | 8 × 576 | 24×24 black apple | `AppleBitMap` |
| `numbers_new_font.mif` | 1 × 8,192 | 16 slots, each 16×32; 0–9/A–F masks | `NumbersBitMap` |
| `end_message_win.mif` | 8 × 50,400 | 560×90 win panel | `end_message_display` |
| `end_message_lost.mif` | 8 × 50,400 | 560×90 loss panel | `end_message_display` |
| `../AUDIO/songs.mif` | 16 × 4,096 | 16 selectable banks × 256 note entries; audio, not an image | `melody_player_1` |

The final row is physically at `C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/RTL/AUDIO/songs.mif`; its HDL path is `RTL/AUDIO/songs.mif`, not a `../` reference.

Static validation expanded explicit addresses and address ranges in every MIF: each declared address space is covered, with no out-of-range addresses or values beyond the declared width. Headers match the ROM widths/depths in the consumers. This is a format/content-range check, not a Quartus compile or visual-quality check.

Declared logical graphics storage totals **1,310,208 bits (163,776 bytes)**; audio adds 65,536 bits (8,192 bytes). Total declared ROM payload is 1,375,744 bits. Physical FPGA block use may differ due to packing, optimization, debug storage, and block granularity; there are no current reports to establish utilization.

Additional ROM-like content: `RTL/AUDIO/SinTable.sv` contains an inline 256-entry 8-bit sine lookup table. `JukeBox1.sv` contains legacy hard-coded melody tables but is not used by the active audio hierarchy.

No PNG/JPEG/BMP/GIF source artwork, standalone `.hex` asset, image-conversion script, or editable artwork project was found outside Git metadata. MIF comments mention older `red_apple_fixed.mif` / `blue_apple_fixed.mif` source versions; those are absent provenance references, not active ROM dependencies. The two requested later-theme assets (`VGA_BG_new_playground.mif`, `jungle-temple-reference.png`) are also absent. No assets were decoded into new image files or generated during inspection.

## 8. Audio and seven-segment module map

| Source in `RTL/AUDIO` | Responsibility |
| --- | --- |
| `sound_effect_controller.sv` | Event-to-song selection and one-clock start requests. Priority: win > game over > black > blue > red > restart > movement make pulse. Song IDs: 0 win, 1 loss, 2 blue, 3 black, 4 move/restart, 5 red. |
| `melody_player_1.sv` | Idle/play-note/gap/ended FSM. Reads 16-bit packed entries from `songs.mif`; tone `[15:12]`, octave `[11:10]+3`, duration `[9:5]`, gap `[4:0]`. Zero duration terminates a song. No general mid-song retrigger handling is visible in the playing states. |
| `Mili_sec_counter.sv` | Clock-enable pulse generator. Active instance uses simulation mode 0, `mSecPerTick=30`, `PLLClock=315`, giving approximately 30 ms ticks at 31.5 MHz despite old 10 ms/one-hundredth-second comments. |
| `ToneDecoder.sv` | Maps 12 tone indices and octave to a 12-bit prescaler value. Tone input is four bits but lookup has only entries 0–11; future song data must respect this or implement explicit silence/extra-note handling. |
| `prescaler.sv` | Divides time into sample-update enable pulses from a programmable counter; supplies a delayed enable too. |
| `addr_counter.sv` | Enabled 8-bit sine-table index counter. |
| `SinTable.sv` | Entity `sintable`; registered sine lookup and four volume levels, producing 16-bit sample data. Volume button falling edges decrement a two-bit level, wrapping cyclically. |
| `JukeBox1.sv` | QSF-listed but uninstantiated older hard-coded note/length table alternative. |
| `AUDIO.bdf` / `Audio_Block.bdf` | Wire event selector to player, pitch/sample generator, and imported codec controller. |

`RTL/Seg7/snakeLengthDigits.sv` converts the 6-bit length into ones/tens (for current range 1–32). `RTL/Seg7/SEG7.SV` is a combinational active-low 0–F segment decoder with `darkN` enable; its clock/reset ports are compatibility ports and unused internally. `Hex_Block.bdf` wires these into the physical displays. `RTL/KEYBOARDX/simple_up_counter.sv` is an uninstantiated free-running 4-bit counter, not a debounce/reset utility.

## 9. ModelSim, testbench, and SignalTap inventory

### Waveform-based simulations

The only supplied game test artifacts are [redApple_eat.vwf](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/redApple_eat.vwf) and [snake_border_collision.vwf](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/snake_border_collision.vwf), both QSF-listed and each with a 1,000 ns stimulus duration. Their signals/scripts target the `game_controller` unit, not the complete VGA/snake system. The border waveform additionally names internal `collision`.

Both embed functional/timing testbench-generation and netlist commands using the old absolute base:

`C:/intelFPGA/Quartus_Projects/ECE_Lab_A1_Project/Project_July_5/Project_July_5_Dorms/`

They request generated testbench files under that base's `simulation/qsim` and run ModelSim against `work.game_controller_vlg_vec_tst`. Meanwhile the selected project top is `TOP_VGA_DEMO`. Thus merely relocating the project does not make these unit-test commands consistent: paths and simulation top selection need a deliberate later review. The earlier screenshot's missing `.vwf.vt` error is consistent with this path mismatch, but no simulation was rerun here.

No standalone checked-in `.vt`, game `.vo`, self-checking `*_tb.sv`, `.do`, ModelSim project, VCD, or generated simulation output was found in the inspected workspace. The existing `simulation` directory is empty. The PLL simulation package separately references the missing `CLK_31P5_sim/CLK_31P5.vo`.

### Embedded SignalTap configuration

No `.stp` file was found. Nevertheless [Lab1Demo.qsf](C:/Users/USER/Documents/Work/FPGA-Snake-Arcade/Lab1Demo.qsf:176) enables SignalTap and defines `auto_signaltap_0` directly: acquisition clock `clk`, sample depth 8,192, data width six bits, automatic RAM block type, and one trigger bit.

The data/trigger references include game state/pulses, `snakeHead_DR`, `game_controller:inst22|collision~0`, `end_message_display:inst17|messageState.MSG_LOST`, and `obstacles:inst1|obstacle_DR`. The last hierarchy does not exist in the current BDF. `messageState` is a plain two-bit logic register with localparam state values, so the `.MSG_LOST` symbolic node name is also suspect. The `collision~0` reference depends on synthesis-generated naming and cannot be validated without an authorized build. No debug references were changed.

### Existing build/capture directories

`db`, `incremental_db`, `output_files`, `simulation`, and `screenshot_capture` exist but contain **zero files** at this inspection. There is no retained screenshot-capture HDL/tool script or programming file in that directory, and no current `.sof`/fit/timing report available to treat as build evidence. Earlier experiments in the conversation should not be assumed to exist or be part of the active project now.

## 10. Missing references, suspicious configuration, and static risks

These are findings to investigate in a later approved phase, not changes made here. Some are definite file/reference problems; others are risks inferred from code and are not proven runtime failures.

| Finding | Evidence / impact |
| --- | --- |
| Missing PLL simulation model | SIP/SPD refer to `CLK_31P5_sim/CLK_31P5.vo`; file/directory absent. Synthesis wrapper and nested implementation are present. |
| Stale waveform paths | Both VWF headers refer to the old absolute project directory for input vectors, generated testbenches and netlists. Generated `.vt` files are absent here. |
| Unit-test top vs project-top mismatch | Embedded ModelSim scripts expect `game_controller_vlg_vec_tst`, while QSF selects `TOP_VGA_DEMO`. No separate unit-test revision/test harness is provided. |
| Stale SignalTap nodes | Absent `obstacles:inst1` hierarchy, questionable `messageState.MSG_LOST` node and fragile post-fit `collision~0` names. Debug is enabled, so this is more than an unused comment. |
| Selected SDC contains unrelated template clocks | Targets `VGA_CLK`, `AUD_BCLK`, `AUD_XCK`, `DRAM_CLK`, and SDRAM ports/hierarchy absent from current top. It includes literal placeholder `inst7|...|divclk`. Actual outputs use packed `OVGA` / `AUDOUT` names. |
| Duplicate, divergent SDC files | Root and `constraints` copies have different content/hashes; root is the QSF-selected copy. Neither should be mistaken for a clean verified timing model. |
| PLL generated-clock assumptions | Manual `clk_31p5` declaration has no explicit multiplication/division ratio while `derive_pll_clocks` is also used. Check actual clock definitions/targets later rather than assuming this manual name establishes 31.5 MHz. |
| Mixed tool metadata | Project records 17.0; PLL IP records 20.1. Not proof of incompatibility, but a reproducibility concern when selecting Quartus/device libraries and regenerating simulation models. |
| Extra top-level outputs lack pin locations | `BG_RGB[7..0]` and `borderDR` are exported from top. BG has I/O-standard assignments, not explicit location constraints. Automatic pin selection could be undesirable on university hardware; verify before programming any rebuilt design. |
| Unused template pin assignments | Switches, ADC, old LEDs/audio ports remain referenced without corresponding top ports. They may produce ignored-assignment warnings; they are not evidence those features are implemented. |
| VGA counter off-by-one and latency | Actual counter limits differ from nominal active/total sizes; layer metadata and ROM data use differing pipeline depths. Potential out-of-range HUD address at the extra row/column and edge/overlap artifacts need a later focused simulation. |
| Head rectangle is 22×24, bitmap is 24×24 | `Snake_Block.bdf` overrides `square_object.OBJECT_WIDTH_X` to 22. This clips the sampled head rectangle relative to the ROM/body/cell size; it may be intentional hitbox tuning but is not explained. Rotation and redraw must account for it. |
| BDF score-offset port widths are stale | `Score_Block.bdf` symbol/wires name 11-bit offset buses; `NumbersBitMap.sv` inputs are six bits. Current 64×64 rectangles make truncation numerically sufficient, but symbol/interface mismatch should be reviewed before resizing. |
| Gameplay depends on sprite opacity | Apple/wall/rock collision uses drawing requests, not solely grid coordinates. Changing transparent sprite shape can change when collisions happen. Self-collision uses separate inset rectangles. |
| Geometry/map duplication | Arena origin/tile size/grid widths, motion step, sprite dimensions, BDF overrides, and apple rock mask are separate definitions. A bigger theme/layout is not a single-background-file change. |
| Apple spawn excludes neither head nor body | Validator checks rocks and apple overlap only. This is a design limitation, not a missing-file problem. |
| High-score event ordering | On a lethal black hit, score decrement and high-score capture consume the same controller pulses; capture sees the pre-decrement registered score. Clarify intended rule before changing event semantics. |
| Audio trigger behavior | Player handles start in idle but does not visibly queue/preempt one-clock requests during playback; event sounds may be skipped. Tone lookup range and ROM latency also deserve focused verification if audio is redesigned. |
| No verification/resource baseline | No current build reports or comprehensive self-checking gameplay/graphics testbench are present. Static consistency does not establish timing closure, correct physical I/O or available redesign memory budget. |

No missing QSF-listed source, QXP, BDF, selected SDC, Tcl, QIP, SIP or VWF file was found. All active `.LPM_FILE` paths resolve relative to the current project root. Nested synthesis QIP paths also resolve. No main-source `../` path problem was found; the definite transitive missing relative file is the PLL simulation `.vo`.

## 11. Specific files implicated by a future graphics redesign

This is a dependency/change-impact map only. No later phase has begun.

### Same geometry, different artwork/colors

- Background/HUD/border: the five background MIFs (`top_background_8bit`, `grass_tile_24`, `stone_tile_24`, `rock_tile_24`, `wood_tile_32`) and, if tile selection/layout changes, `RTL/VGA/back_ground_draw.sv`.
- Snake appearance: `snake_head_24.mif`, `snake_body_24.mif`; `headBitMap.sv` if orientation/transparency conventions change; `snake_body.sv` if body rendering changes.
- Apples: three apple MIFs and `AppleBitMap.sv` if selection/transparency/animation changes.
- Font/HUD palette: `numbers_new_font.mif`, `NumbersBitMap.sv`, `ScoreConstants.sv`; `Score_Block.bdf` if display rectangles move/resize. HUD labels are part of `top_background_8bit.mif`, not drawn as independent text.
- End screens: `end_message_win.mif`, `end_message_lost.mif`, `End_Message_Display.sv` for panel geometry/state behavior.
- Layering/new overlays: `objects_mux.sv` and `TOP_VGA_DEMO.bdf` for added ports/wiring. Simple artwork replacement at unchanged dimensions need not alter game FSM, input or VGA timing.

Preserve the existing dimensions, row-major addressing, RGB332 encoding, sprite `FF` transparency, and rotation convention for a low-impact artwork-only update. Even then, transparency changes can affect gameplay collisions.

### Proposed larger 18×11 grid with 32-pixel cells

The brief's proposed rectangle is X `[32,608)`, Y `[96,448)`, 576×352. It differs from the implemented square arena. At minimum, coordinated review would involve:

| Concern | Specific files |
| --- | --- |
| Arena bounds, tile lookup, grid/address widths | `RTL/VGA/back_ground_draw.sv`; background assets. |
| Random-coordinate ranges | `RTL/VGA/randomCounter.sv`; X needs at least five bits for columns 0–17, with range control rather than unconstrained nibble sampling. Y must be limited to 0–10. |
| Valid positions and obstacle map | `RTL/VGA/apple_position_controller.sv`; duplicated map must track new grid dimensions. |
| Tile-to-pixel mapping | `RTL/VGA/apple_TopLeft_Calc.sv`. |
| Head movement/grid step/start point | `RTL/VGA/snake_head.sv`; parameter overrides in `RTL/VGA/Snake_Block.bdf`. Current `(320,280)` would not be a 32-pixel-grid-aligned origin relative to `(32,96)`. |
| Body size/trail/spacing/self-hitbox | `RTL/VGA/snake_body.sv`, `Snake_Block.bdf`, body MIF. Six-frame spacing is speed dependent; simply changing the bitmap size does not redefine segment distance. |
| Sprite ROM depths and rotations | `RTL/VGA/headBitMap.sv`, `AppleBitMap.sv`, `snake_body.sv`; corresponding MIFs. A 32×32 sprite has 1,024 entries instead of 576. |
| Apple/head rectangle dimensions and widened grid buses | `RTL/VGA/Apple_Block.bdf`, `Snake_Block.bdf`; refresh affected symbol ports/wiring as well as HDL. |
| HUD/score placement and terminal overlays | `ScoreConstants.sv`, `NumbersBitMap.sv`, `Score_Block.bdf`, `End_Message_Display.sv`, HUD/font/end-panel MIFs as desired. |
| Integration, dependencies and verification references | `TOP_VGA_DEMO.bdf`, `Lab1Demo.qsf` if new sources are added, waveform/testbench setup and SignalTap references as needed. |

`VGA_Controller.sv`, PLL files, pin assignments, imported keyboard/audio partitions, and game scoring rules are not intrinsically theme files. A graphics redesign should not casually change them. Existing timing/debug/reference risks still need separately authorized attention before relying on a rebuilt hardware image.

## 12. Reuse guidance and Phase 1 stop point

For future sessions, begin with this document and compare relevant files against the baseline commit. Re-inspect changed files and their callers/BDF symbols; this map is not a substitute for checking a newly changed hierarchy. Do not assume files from earlier screenshot/simulation experiments survive: the corresponding directories are empty now.

The main interview explanation is: a PLL-clocked raster pipeline scans ROM-based layers; frame events drive smooth grid-targeted snake motion; scan-overlap and rectangle collision signals drive a game FSM; FSM pulses update score, length, speed, apple positions, sounds and end messages. The BDFs provide system composition, while SV modules implement behavior.

**Phase 1 complete. Await user approval before any later phase or project repair.**
