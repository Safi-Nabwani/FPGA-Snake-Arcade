onerror {quit -code 1 -f}
transcript file simulation/audio_playback_priority.log
vlib simulation/audio_playback_priority_work
vlog -sv -work simulation/audio_playback_priority_work simulation/jungle_rom_model.sv RTL/AUDIO/Mili_sec_counter.sv RTL/AUDIO/ToneDecoder.sv RTL/AUDIO/prescaler.sv RTL/AUDIO/addr_counter.sv RTL/AUDIO/SinTable.sv RTL/VGA/game_controller.sv RTL/AUDIO/sound_effect_controller.sv RTL/AUDIO/melody_player_1.sv simulation/audio_playback_priority_tb.sv
vsim -voptargs=+acc simulation/audio_playback_priority_work.audio_playback_priority_tb
onfinish stop
onbreak {}
run -all
if {![string match "*1" [examine -radix binary /audio_playback_priority_tb/testPassed]]} {quit -code 1 -f}
quit -sim
vsim -voptargs=+acc simulation/audio_playback_priority_work.audio_playback_real_tb
onfinish stop
onbreak {}
run -all
if {![string match "*1" [examine -radix binary /audio_playback_real_tb/test/testPassed]]} {quit -code 1 -f}
quit -code 0 -f
