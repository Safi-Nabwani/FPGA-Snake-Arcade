transcript file simulation/snake_emerald_production.log
vlib simulation/snake_emerald_production_work
vlog -sv -work simulation/snake_emerald_production_work simulation/jungle_rom_model.sv RTL/VGA/jungle_head_draw.sv RTL/VGA/snake_body.sv simulation/snake_sprite_variants_tb.sv
vsim -voptargs=+acc simulation/snake_emerald_production_work.snake_emerald_production_tb
run -all
quit -f
