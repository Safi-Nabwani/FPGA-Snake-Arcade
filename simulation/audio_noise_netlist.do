onerror {quit -code 1 -f}
vlib simulation/audio_noise_netlist_work
vlog -sv -work simulation/audio_noise_netlist_work db/audio_noise_investigation/audio_fitted.vo simulation/jungle_rom_model.sv RTL/AUDIO/Mili_sec_counter.sv RTL/AUDIO/ToneDecoder.sv RTL/AUDIO/prescaler.sv RTL/AUDIO/addr_counter.sv RTL/AUDIO/SinTable.sv RTL/AUDIO/melody_player_1.sv simulation/audio_noise_netlist_tb.sv
vsim -voptargs=+acc -L cyclonev_ver -L altera_ver -L altera_mf_ver -L altera_lnsim_ver simulation/audio_noise_netlist_work.audio_noise_netlist_tb
onfinish stop
onbreak {}
run -all
if {![string match "*1" [examine -radix binary /audio_noise_netlist_tb/testPassed]]} {quit -code 1 -f}
quit -code 0 -f
