# From project root: python scripts/implement_v4_graphics.py --fixtures
onerror {quit -code 1 -f}
vlib simulation/jungle_implementation_work
vlog -sv -work simulation/jungle_implementation_work simulation/jungle_rom_model.sv RTL/VGA/square_object.sv RTL/VGA/headBitMap.sv RTL/VGA/jungle_head_draw.sv RTL/VGA/AppleBitMap.sv RTL/VGA/snake_body.sv RTL/VGA/back_ground_draw.sv RTL/VGA/objects_mux.sv RTL/VGA/game_controller.sv RTL/VGA/appleCounter.sv db/jungle_implementation_fixture/legacy_headBitMap.sv db/jungle_implementation_fixture/legacy_AppleBitMap.sv db/jungle_implementation_fixture/legacy_snake_body.sv simulation/jungle_implementation_tb.sv
vsim -voptargs=+acc simulation/jungle_implementation_work.jungle_implementation_tb
onfinish stop
onbreak {}
run -all
if {![string match "*1" [examine -radix binary /jungle_implementation_tb/testPassed]]} {quit -code 1 -f}
quit -code 0 -f
