// Visual-only head renderer. The original headBitMap/square remains the hit path.
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
    logic [4:0] x, y, rx, ry;
    logic [9:0] address;
    logic [7:0] color;
    always_comb begin
        dx = $signed({1'b0,pixelX}) - topLeftX;
        dy = $signed({1'b0,pixelY}) - topLeftY;
        valid = dx >= 0 && dx < 24 && dy >= 0 && dy < 24;
        x = valid ? dx[4:0] : 5'd0;
        y = valid ? dy[4:0] : 5'd0;
        rx = x; ry = y;
        case (snakeHeadDir)
        3'd2: begin rx = y; ry = 5'd23-x; end
        3'd3: begin rx = 5'd23-y; ry = x; end
        3'd4: begin rx = 5'd23-x; ry = 5'd23-y; end
        default: begin rx = x; ry = y; end
        endcase
        address = ry*24 + rx;
    end
    lpm_rom #(.LPM_WIDTH(8), .LPM_WIDTHAD(10), .LPM_NUMWORDS(576),
        .LPM_FILE("RTL/mifs/snake_head_24.mif"), .LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"), .LPM_OUTDATA("UNREGISTERED"),
        .AUTO_CARRY_CHAINS("ON"), .AUTO_CASCADE_BUFFERS("ON"),
        .INTENDED_DEVICE_FAMILY("Cyclone V")) visual_rom
        (.address(address), .inclock(clk), .q(color));
    // Stage 1 ROM address + same-pixel validity; stage 2 visual pair.
    // This matches the existing HUD latency before objects_mux's register.
    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin validD <= 0; drawingRequest <= 0; RGBout <= 8'hFF; end
        else begin
            validD <= valid;
            drawingRequest <= validD && color != 8'hFF;
            RGBout <= validD ? color : 8'hFF;
        end
    end
endmodule

