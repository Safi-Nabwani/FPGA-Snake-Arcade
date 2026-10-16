# Prepare: python scripts/implement_opening_screen.py --fixtures
onerror {quit -code 1 -f}
vlib simulation/opening_screen_work
vlog -sv -work simulation/opening_screen_work simulation/jungle_rom_model.sv RTL/KEYBOARDX/keyPad_decoder.sv RTL/VGA/game_controller.sv RTL/VGA/End_Message_Display.sv RTL/VGA/snake_head.sv RTL/VGA/snake_body.sv RTL/VGA/speed_controller.sv RTL/VGA/appleCounter.sv RTL/VGA/highscoreComp.sv RTL/VGA/relic_collection_counters.sv RTL/VGA/objects_mux.sv db/opening_screen_fixture/legacy_end_message_display.sv simulation/opening_screen_tb.sv simulation/opening_startup_tb.sv
vsim simulation/opening_screen_work.opening_startup_tb
onfinish stop
onbreak {}
run -all
if {![string match "*1" [examine -radix binary /opening_startup_tb/testPassed]]} {quit -code 1 -f}
quit -sim
vsim -voptargs=+acc simulation/opening_screen_work.opening_screen_tb
onfinish stop
onbreak {}
run -all
if {![string match "*1" [examine -radix binary /opening_screen_tb/testPassed]]} {quit -code 1 -f}
quit -code 0 -f
