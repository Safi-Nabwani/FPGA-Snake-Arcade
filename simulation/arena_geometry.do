# Run from the project root. ROM fixture intentionally does not model image data.
# This standalone unit test does not use the stale VWF scripts or the PLL/QXP partitions.
onerror {quit -code 1 -f}
vlib simulation/arena_geometry_work
vlog -sv -work simulation/arena_geometry_work simulation/arena_rom_stub.sv RTL/VGA/back_ground_draw.sv RTL/VGA/randomCounter.sv RTL/VGA/apple_position_controller.sv RTL/VGA/apple_TopLeft_Calc.sv RTL/VGA/snake_head.sv RTL/VGA/snake_body.sv RTL/VGA/headBitMap.sv simulation/arena_geometry_tb.sv
vsim -voptargs=+acc simulation/arena_geometry_work.arena_geometry_tb
onbreak {quit -code 1 -f}
run -all
quit -code 0 -f
