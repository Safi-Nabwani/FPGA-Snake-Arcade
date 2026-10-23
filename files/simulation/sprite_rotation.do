onerror {quit -code 1 -f}
vlib simulation/sprite_rotation_work
vlog -sv -work simulation/sprite_rotation_work simulation/jungle_rom_model.sv RTL/VGA/jungle_head_draw.sv RTL/VGA/snake_body.sv simulation/sprite_rotation_tb.sv simulation/snake_sprite_variants_tb.sv
foreach test {sprite_rotation_tb snake_emerald_production_tb} {
    vsim -voptargs=+acc simulation/sprite_rotation_work.$test
    onfinish stop
    onbreak {}
    run -all
    if {![string match "*1" [examine -radix binary /$test/testPassed]]} {quit -code 1 -f}
    quit -sim
}
quit -code 0 -f
