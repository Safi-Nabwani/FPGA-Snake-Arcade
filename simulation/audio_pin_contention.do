onerror {quit -code 1 -f}
vlib simulation/audio_pin_contention_work
vlog -sv -work simulation/audio_pin_contention_work simulation/audio_pin_contention_tb.sv
vsim simulation/audio_pin_contention_work.audio_pin_contention_tb
onfinish stop
onbreak {}
run -all
if {![string match "*1" [examine -radix binary /audio_pin_contention_tb/testPassed]]} {quit -code 1 -f}
quit -code 0 -f
