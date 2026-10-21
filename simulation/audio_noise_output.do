onerror {quit -code 1 -f}
if {![info exists sourceRoot]} {set sourceRoot .}
vlib simulation/audio_noise_output_work
vlog -sv -work simulation/audio_noise_output_work simulation/jungle_rom_model.sv simulation/fixtures/audio_noise_jtag_stub.sv diagnostics/audio_noise_probe.sv $sourceRoot/RTL/AUDIO/Mili_sec_counter.sv $sourceRoot/RTL/AUDIO/ToneDecoder.sv $sourceRoot/RTL/AUDIO/prescaler.sv $sourceRoot/RTL/AUDIO/addr_counter.sv $sourceRoot/RTL/AUDIO/SinTable.sv RTL/KEYBOARDX/keyPad_decoder.sv RTL/VGA/game_controller.sv $sourceRoot/RTL/AUDIO/sound_effect_controller.sv $sourceRoot/RTL/AUDIO/melody_player_1.sv simulation/audio_noise_output_tb.sv simulation/audio_playback_priority_tb.sv
foreach test {audio_noise_output_tb audio_playback_priority_tb audio_playback_real_tb} {
    vsim -voptargs=+acc simulation/audio_noise_output_work.$test
    onfinish stop
    onbreak {}
    run -all
    if {$test eq "audio_playback_real_tb"} {set flag /$test/test/testPassed} else {set flag /$test/testPassed}
    if {![string match "*1" [examine -radix binary $flag]]} {quit -code 1 -f}
    quit -sim
}
quit -code 0 -f
