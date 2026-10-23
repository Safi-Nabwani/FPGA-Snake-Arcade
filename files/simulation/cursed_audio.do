onerror {quit -code 1 -f}
if {![info exists old]} {set old 0}
vlib simulation/cursed_audio_work
vlog -sv -work simulation/cursed_audio_work simulation/jungle_rom_model.sv RTL/AUDIO/Mili_sec_counter.sv RTL/AUDIO/ToneDecoder.sv RTL/AUDIO/prescaler.sv RTL/AUDIO/addr_counter.sv RTL/AUDIO/SinTable.sv RTL/AUDIO/melody_player_1.sv simulation/cursed_audio_tb.sv
set modes {1}
if {!$old} {set modes {1 0}}
foreach fast $modes {
    vsim -voptargs=+acc -gOLD=$old -gFAST=$fast simulation/cursed_audio_work.cursed_audio_tb
    onfinish stop
    onbreak {}
    run -all
    if {![string match "*1" [examine -radix binary /cursed_audio_tb/testPassed]]} {quit -code 1 -f}
    quit -sim
}
quit -code 0 -f
