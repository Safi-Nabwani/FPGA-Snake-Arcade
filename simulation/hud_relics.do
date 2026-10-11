# Run from project root after scripts/implement_jungle_hud.py --fixtures.
# All panel/alpha/font/background ROMs are loaded from their actual MIFs.
onerror {quit -code 1 -f}
vlib simulation/hud_relics_work
vlog -sv -work simulation/hud_relics_work simulation/jungle_rom_model.sv RTL/VGA/relic_collection_counters.sv RTL/VGA/hud_labels.sv RTL/VGA/NumbersBitMap.sv RTL/VGA/ScoreConstants.sv RTL/VGA/appleCounter.sv RTL/VGA/highscoreComp.sv RTL/VGA/game_controller.sv RTL/VGA/blue_apple_controller.sv RTL/VGA/square_object.sv RTL/VGA/back_ground_draw.sv RTL/VGA/objects_mux.sv simulation/hud_counters_tb.sv simulation/hud_render_tb.sv
vsim -voptargs=+acc simulation/hud_relics_work.hud_counters_tb
onfinish stop
onbreak {}
run -all
if {![string match "*1" [examine -radix binary /hud_counters_tb/testPassed]]} {quit -code 1 -f}
quit -sim
vsim -voptargs=+acc simulation/hud_relics_work.hud_render_tb
onfinish stop
onbreak {}
run -all
if {![string match "*1" [examine -radix binary /hud_render_tb/testPassed]]} {quit -code 1 -f}
quit -code 0 -f
