onerror {quit -code 1 -f}
transcript file simulation/snake_emerald_production.log
vlib simulation/snake_emerald_production_work
vlog -sv -work simulation/snake_emerald_production_work simulation/jungle_rom_model.sv RTL/VGA/jungle_head_draw.sv RTL/VGA/snake_body.sv simulation/snake_sprite_variants_tb.sv
vsim -voptargs=+acc simulation/snake_emerald_production_work.snake_emerald_production_tb
onfinish stop
onbreak {}
run -all
if {![string match "*1" [examine -radix binary /snake_emerald_production_tb/testPassed]]} {quit -code 1 -f}
quit -code 0 -f
