// Approved fixed Jungle Temple map. Collision outputs remain raw-coordinate signals.
module back_ground_draw (
    input logic clk, resetN,
    input logic [10:0] pixelX, pixelY,
    output logic [7:0] BG_RGB,
    output logic borderDR, obstacle_DR
);
    localparam int ARENA_LEFT=144, ARENA_TOP=24, ARENA_RIGHT=624, ARENA_BOTTOM=456;
    localparam int TILE_SIZE=24;
    localparam logic [1:0] REGION_ARENA=1, REGION_WOOD=2;
    `include "RTL/VGA/jungle_map.svh"
    `include "RTL/VGA/jungle_floor_map.svh"
    logic insideArena;
    logic [10:0] arenaLocalX, arenaLocalY;
    logic [4:0] tileX, tileY, tileOffsetX, tileOffsetY;
    logic [4:0] descriptor;
    logic [4:0] rx, ry;
    logic [9:0] tileAddress, address;
    logic [1:0] selectedRegion;
    logic [2:0] kindD;
    logic arenaD;
    logic [7:0] tileRGB [0:6];
    logic [7:0] selectedRGB;
    assign insideArena = pixelX>=ARENA_LEFT && pixelX<ARENA_RIGHT &&
                         pixelY>=ARENA_TOP && pixelY<ARENA_BOTTOM;
    always_comb begin
        arenaLocalX=0; arenaLocalY=0; tileX=0; tileY=0;
        tileOffsetX=0; tileOffsetY=0; selectedRegion=REGION_WOOD;
        if (insideArena) begin
            selectedRegion=REGION_ARENA;
            arenaLocalX=pixelX-ARENA_LEFT; arenaLocalY=pixelY-ARENA_TOP;
            tileX=arenaLocalX/TILE_SIZE; tileY=arenaLocalY/TILE_SIZE;
            tileOffsetX=arenaLocalX-tileX*TILE_SIZE;
            tileOffsetY=arenaLocalY-tileY*TILE_SIZE;
        end
        descriptor=jungleTile(tileX,tileY);
        // Floor selection is independent of the frozen obstacle descriptors.
        // Supplied artwork is sampled unrotated at address y*24+x.
        if (descriptor[2:0] < 3'd4)
            descriptor={2'b00, 1'b0, jungleFloorTile(tileX,tileY)};
        tileAddress=tileOffsetY*TILE_SIZE+tileOffsetX;
        rx=tileOffsetX; ry=tileOffsetY;
        case(descriptor[4:3])
        2'd1: begin rx=tileOffsetY; ry=5'd23-tileOffsetX; end
        2'd2: begin rx=5'd23-tileOffsetX; ry=5'd23-tileOffsetY; end
        2'd3: begin rx=5'd23-tileOffsetY; ry=tileOffsetX; end
        default: begin rx=tileOffsetX; ry=tileOffsetY; end
        endcase
        address=ry*TILE_SIZE+rx;
    end
    lpm_rom #(.LPM_WIDTH(8), .LPM_WIDTHAD(10), .LPM_NUMWORDS(576),
        .LPM_FILE("RTL/mifs/ancient_stone_24x24_rgb332.mif"), .LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"), .LPM_OUTDATA("UNREGISTERED"),
        .AUTO_CARRY_CHAINS("ON"), .AUTO_CASCADE_BUFFERS("ON"),
        .INTENDED_DEVICE_FAMILY("Cyclone V")) tile_rom_0
        (.address(address), .inclock(clk), .q(tileRGB[0]));
    lpm_rom #(.LPM_WIDTH(8), .LPM_WIDTHAD(10), .LPM_NUMWORDS(576),
        .LPM_FILE("RTL/mifs/mossy_stone_24x24_rgb332.mif"), .LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"), .LPM_OUTDATA("UNREGISTERED"),
        .AUTO_CARRY_CHAINS("ON"), .AUTO_CASCADE_BUFFERS("ON"),
        .INTENDED_DEVICE_FAMILY("Cyclone V")) tile_rom_1
        (.address(address), .inclock(clk), .q(tileRGB[1]));
    lpm_rom #(.LPM_WIDTH(8), .LPM_WIDTHAD(10), .LPM_NUMWORDS(576),
        .LPM_FILE("RTL/mifs/cracked_stone_24x24_rgb332.mif"), .LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"), .LPM_OUTDATA("UNREGISTERED"),
        .AUTO_CARRY_CHAINS("ON"), .AUTO_CASCADE_BUFFERS("ON"),
        .INTENDED_DEVICE_FAMILY("Cyclone V")) tile_rom_2
        (.address(address), .inclock(clk), .q(tileRGB[2]));
    lpm_rom #(.LPM_WIDTH(8), .LPM_WIDTHAD(10), .LPM_NUMWORDS(576),
        .LPM_FILE("RTL/mifs/engraved_stone_24x24_rgb332.mif"), .LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"), .LPM_OUTDATA("UNREGISTERED"),
        .AUTO_CARRY_CHAINS("ON"), .AUTO_CASCADE_BUFFERS("ON"),
        .INTENDED_DEVICE_FAMILY("Cyclone V")) tile_rom_3
        (.address(address), .inclock(clk), .q(tileRGB[3]));
    lpm_rom #(.LPM_WIDTH(8), .LPM_WIDTHAD(10), .LPM_NUMWORDS(576),
        .LPM_FILE("RTL/mifs/rock_tile_floor_match_v4_24.mif"), .LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"), .LPM_OUTDATA("UNREGISTERED"),
        .AUTO_CARRY_CHAINS("ON"), .AUTO_CASCADE_BUFFERS("ON"),
        .INTENDED_DEVICE_FAMILY("Cyclone V")) tile_rom_4
        (.address(address), .inclock(clk), .q(tileRGB[4]));
    lpm_rom #(.LPM_WIDTH(8), .LPM_WIDTHAD(10), .LPM_NUMWORDS(576),
        .LPM_FILE("RTL/mifs/ruin_wall_floor_match_v4_24.mif"), .LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"), .LPM_OUTDATA("UNREGISTERED"),
        .AUTO_CARRY_CHAINS("ON"), .AUTO_CASCADE_BUFFERS("ON"),
        .INTENDED_DEVICE_FAMILY("Cyclone V")) tile_rom_5
        (.address(address), .inclock(clk), .q(tileRGB[5]));
    lpm_rom #(.LPM_WIDTH(8), .LPM_WIDTHAD(10), .LPM_NUMWORDS(576),
        .LPM_FILE("RTL/mifs/ruin_pillar_floor_match_v4_24.mif"), .LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"), .LPM_OUTDATA("UNREGISTERED"),
        .AUTO_CARRY_CHAINS("ON"), .AUTO_CASCADE_BUFFERS("ON"),
        .INTENDED_DEVICE_FAMILY("Cyclone V")) tile_rom_6
        (.address(address), .inclock(clk), .q(tileRGB[6]));
    always_comb begin
        selectedRGB=8'h04;
        if(arenaD) begin
            case(kindD)
            3'd0: selectedRGB=tileRGB[0];
            3'd1: selectedRGB=tileRGB[1];
            3'd2: selectedRGB=tileRGB[2];
            3'd3: selectedRGB=tileRGB[3];
            3'd4: selectedRGB=tileRGB[4];
            3'd5: selectedRGB=tileRGB[5];
            3'd6: selectedRGB=tileRGB[6];
            default: selectedRGB=tileRGB[0];
            endcase
        end
    end
    // Stage 1 selector/region travels with the ROM address; stage 2 color
    // matches the visual latency of head/body/HUD/relics before objects_mux.
    always_ff @(posedge clk or negedge resetN) begin
        if(!resetN) begin kindD<=0; arenaD<=0; BG_RGB<=8'h04; end
        else begin kindD<=descriptor[2:0]; arenaD<=insideArena; BG_RGB<=selectedRGB; end
    end
    assign borderDR=!insideArena;
    assign obstacle_DR=insideArena && descriptor[2:0]>=3'd4;
endmodule
