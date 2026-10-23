onerror {quit -code 1 -f}
if {![info exists capacity]} {set capacity 32}
transcript file simulation/snake_length_capacity_${capacity}.log
set lib simulation/snake_length_capacity_${capacity}_work
vlib $lib
vlog -sv +define+TEST_CAPACITY=$capacity -work $lib simulation/jungle_rom_model.sv RTL/VGA/snake_body.sv RTL/Seg7/snakeLengthDigits.sv simulation/fixtures/snake_body_32_reference.sv simulation/snake_length_capacity_tb.sv
vsim -voptargs=+acc $lib.snake_length_capacity_tb
onfinish stop
onbreak {}
run -all
if {![string match "*1" [examine -radix binary /snake_length_capacity_tb/testPassed]]} {quit -code 1 -f}
quit -code 0 -f
