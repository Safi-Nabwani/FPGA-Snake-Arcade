# FPGA Snake Arcade Game

A real-time Snake arcade game implemented in **SystemVerilog** on a **Cyclone V FPGA**.

The project was developed as part of Electrical Engineering Lab A1 at the Technion and integrates VGA graphics, keyboard input, audio feedback, scoring, collision detection, and multiple gameplay mechanics.

## Features

- 640×480 VGA graphics
- Keyboard-controlled snake movement
- Snake growth and self-collision detection
- Border collision detection
- Score and high-score tracking
- Multiple apple types:
  - 🔴 Red apple: +1
  - 🔵 Blue apple: -3
  - ⚫ Black apple: +5
- Audio feedback and sound effects
- Variable game speed
- ROM/MIF-based graphics

## Hardware & Tools

- Cyclone V FPGA
- SystemVerilog
- Intel Quartus Prime
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
- `RTL/mifs` — graphics and audio memory files
- `constraints` — FPGA pin and timing constraints

## Verification

The project includes simulation waveforms for gameplay behavior such as:

- Border collision detection
- Red apple consumption
