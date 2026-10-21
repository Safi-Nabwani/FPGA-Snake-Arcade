onerror {quit -code 1 -f}
vlib simulation/audio_noise_probe_work
vlog -sv -work simulation/audio_noise_probe_work diagnostics/audio_noise_probe.sv simulation/audio_noise_probe_tb.sv
vsim simulation/audio_noise_probe_work.audio_noise_probe_tb
onfinish stop
onbreak {}
run -all
if {![string match "*1" [examine -radix binary /audio_noise_probe_tb/testPassed]]} {quit -code 1 -f}
quit -code 0 -f
