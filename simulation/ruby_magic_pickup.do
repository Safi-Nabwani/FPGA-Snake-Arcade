onerror {quit -code 1 -f}
vlib simulation/ruby_magic_pickup_work
vlog -sv -work simulation/ruby_magic_pickup_work simulation/jungle_rom_model.sv RTL/AUDIO/Mili_sec_counter.sv RTL/AUDIO/ToneDecoder.sv RTL/AUDIO/melody_player_1.sv simulation/ruby_magic_pickup_tb.sv
vsim -voptargs=+acc simulation/ruby_magic_pickup_work.ruby_magic_pickup_tb
onfinish stop
onbreak {}
run -all
if {![string match "*1" [examine -radix binary /ruby_magic_pickup_tb/testPassed]]} {quit -code 1 -f}
quit -code 0 -f
