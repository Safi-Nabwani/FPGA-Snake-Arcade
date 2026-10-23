onerror {quit -code 1 -f}
transcript file simulation/snake_initial_length.log
vlib simulation/snake_initial_length_work
vlog -sv -work simulation/snake_initial_length_work simulation/jungle_rom_model.sv RTL/VGA/snake_body.sv RTL/VGA/snake_head.sv RTL/VGA/game_controller.sv RTL/Seg7/snakeLengthDigits.sv RTL/Seg7/SEG7.SV simulation/fixtures/snake_body_32_reference.sv simulation/snake_initial_length_tb.sv
vsim -voptargs=+acc simulation/snake_initial_length_work.snake_initial_length_tb
onfinish stop
onbreak {}
run -all
if {![string match "*1" [examine -radix binary /snake_initial_length_tb/testPassed]]} {quit -code 1 -f}
quit -code 0 -f
