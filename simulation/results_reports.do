# Prepare: python -B scripts/implement_results_v3.py --preview
onerror {quit -code 1 -f}
vlib simulation/results_reports_work
vlog -sv -work simulation/results_reports_work simulation/jungle_rom_model.sv RTL/KEYBOARDX/keyPad_decoder.sv RTL/VGA/game_controller.sv RTL/VGA/appleCounter.sv RTL/VGA/highscoreComp.sv RTL/VGA/relic_collection_counters.sv RTL/VGA/End_Message_Display.sv RTL/VGA/NumbersBitMap.sv RTL/VGA/ScoreConstants.sv RTL/VGA/square_object.sv RTL/VGA/objects_mux.sv db/results_v3_fixture/previous_end_message_display.sv simulation/results_reports_tb.sv
vsim -voptargs=+acc simulation/results_reports_work.results_reports_tb
onfinish stop
onbreak {}
run -all
if {![string match "*1" [examine -radix binary /results_reports_tb/testPassed]]} {quit -code 1 -f}
quit -code 0 -f
