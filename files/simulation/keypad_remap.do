onerror {quit -code 1 -f}
vlib simulation/keypad_remap_work
vlog -sv -work simulation/keypad_remap_work RTL/KEYBOARDX/keyPad_decoder.sv RTL/VGA/game_controller.sv RTL/VGA/snake_head.sv RTL/AUDIO/sound_effect_controller.sv simulation/keypad_remap_tb.sv
vsim -voptargs=+acc simulation/keypad_remap_work.keypad_remap_tb
onfinish stop
onbreak {}
run -all
if {![string match "*1" [examine -radix binary /keypad_remap_tb/testPassed]]} {quit -code 1 -f}
quit -code 0 -f
