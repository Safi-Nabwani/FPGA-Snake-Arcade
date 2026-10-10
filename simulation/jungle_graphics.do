# Run from project root AFTER scripts/build_jungle_assets.py --write.
onerror {quit -code 1 -f}
vlib simulation/jungle_graphics_work
vlog -sv -work simulation/jungle_graphics_work simulation/jungle_rom_model.sv RTL/VGA/headBitMap.sv RTL/VGA/AppleBitMap.sv RTL/VGA/snake_body.sv RTL/VGA/back_ground_draw.sv simulation/jungle_graphics_tb.sv
vsim -voptargs=+acc simulation/jungle_graphics_work.jungle_graphics_tb
onfinish stop
onbreak {}
run -all
if {![string match "*1" [examine -radix binary /jungle_graphics_tb/testPassed]]} {quit -code 1 -f}
quit -code 0 -f
