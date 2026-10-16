onerror {quit -code 1 -f}
vlib simulation/winning_score_work
vlog -sv -work simulation/winning_score_work RTL/VGA/game_controller.sv RTL/VGA/appleCounter.sv RTL/VGA/highscoreComp.sv RTL/VGA/relic_collection_counters.sv simulation/winning_score_tb.sv
vsim -voptargs=+acc simulation/winning_score_work.winning_score_tb
onfinish stop
onbreak {}
run -all
if {![string match "*1" [examine -radix binary /winning_score_tb/testPassed]]} {quit -code 1 -f}
quit -code 0 -f
