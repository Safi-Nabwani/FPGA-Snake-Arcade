onerror {quit -code 1 -f}
vlib simulation/readme_images_work
vlog -sv -work simulation/readme_images_work simulation/jungle_rom_model.sv RTL/VGA/game_controller.sv RTL/VGA/appleCounter.sv RTL/VGA/highscoreComp.sv RTL/VGA/relic_collection_counters.sv RTL/VGA/speed_controller.sv RTL/VGA/snake_head.sv RTL/VGA/snake_body.sv RTL/VGA/jungle_head_draw.sv RTL/VGA/back_ground_draw.sv RTL/VGA/square_object.sv RTL/VGA/NumbersBitMap.sv RTL/VGA/blue_apple_controller.sv RTL/VGA/randomCounter.sv RTL/VGA/apple_position_controller.sv RTL/VGA/apple_TopLeft_Calc.sv RTL/VGA/AppleBitMap.sv RTL/VGA/End_Message_Display.sv RTL/VGA/objects_mux.sv simulation/readme_images_tb.sv
vsim -voptargs=+acc simulation/readme_images_work.readme_images_tb
onfinish stop
onbreak {}
run -all
if {![string match "*1" [examine -radix binary /readme_images_tb/capturePassed]]} {quit -code 1 -f}
quit -code 0 -f
