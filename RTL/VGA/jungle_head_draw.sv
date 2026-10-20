// Visual-only Emerald head renderer. The original headBitMap/square remains the hit path.

module jungle_head_draw (
    input logic clk, resetN,
    input logic [10:0] pixelX, pixelY,
    input logic signed [10:0] topLeftX, topLeftY,
    input logic [2:0] snakeHeadDir,
    output logic drawingRequest,
    output logic [7:0] RGBout
);
    logic signed [11:0] dx, dy;
    logic valid, validD;
    logic [4:0] x, y;
    logic [3:0] spriteIndex;
    logic [12:0] atlasAddress;
    logic [8:0] spriteWord;

    always_comb begin
        dx = $signed({1'b0,pixelX}) - topLeftX;
        dy = $signed({1'b0,pixelY}) - topLeftY;
        valid = dx >= 0 && dx < 24 && dy >= 0 && dy < 24;
        x = valid ? dx[4:0] : 5'd0;
        y = valid ? dy[4:0] : 5'd0;

        // Approved Emerald atlas order: up, right, down, left.
        case (snakeHeadDir)
            3'd2: spriteIndex = 4'd1;
            3'd4: spriteIndex = 4'd2;
            3'd3: spriteIndex = 4'd3;
            default: spriteIndex = 4'd0;
        endcase
        atlasAddress = (spriteIndex * 13'd576) + (y * 24) + x;
    end

    lpm_rom #(
        .LPM_WIDTH(9), .LPM_WIDTHAD(13), .LPM_NUMWORDS(8064),
        .LPM_FILE("RTL/mifs/snake_variants/01_emerald_rgba9.mif"), .LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"), .LPM_OUTDATA("UNREGISTERED"),
        .AUTO_CARRY_CHAINS("ON"), .AUTO_CASCADE_BUFFERS("ON"),
        .INTENDED_DEVICE_FAMILY("Cyclone V")
    ) visual_rom (
        .address(atlasAddress), .inclock(clk), .q(spriteWord)
    );

    // Stage 1 ROM address + same-pixel validity; stage 2 visual pair.
    // This matches the existing HUD latency before objects_mux's register.
    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin
            validD <= 1'b0;
            drawingRequest <= 1'b0;
            RGBout <= 8'hFF;
        end
        else begin
            validD <= valid;
            drawingRequest <= validD && spriteWord[8];
            RGBout <= validD ? spriteWord[7:0] : 8'hFF;
        end
    end
endmodule

