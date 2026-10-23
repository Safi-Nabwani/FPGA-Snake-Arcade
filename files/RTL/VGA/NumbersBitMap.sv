module NumbersBitMap (
    input logic clk, resetN,
    // Match the existing square_object/BDF eleven-bit offset interfaces.
    input logic [10:0] scoreOffsetX, scoreOffsetY,
    input logic scoreSquare_DR,
    input logic [3:0] scoreLow, scoreHigh,
    input logic [10:0] highScoreOffsetX, highScoreOffsetY,
    input logic highScoreSquare_DR,
    input logic [3:0] highScoreLow, highScoreHigh,
    input logic [10:0] pixelX, pixelY,
    input logic [11:0] rubyCountBCD, sapphireCountBCD, cursedCountBCD,
    output logic score_DR,
    output logic [7:0] score_RGB,
    output logic highScore_DR,
    output logic [7:0] highScore_RGB
);
    parameter logic [7:0] SCORE_COLOR_LOW = 8'hF9;
    parameter logic [7:0] SCORE_COLOR_HIGH = 8'hF9;
    parameter logic [7:0] HIGH_SCORE_COLOR = 8'hF9;
    `include "RTL/VGA/jungle_hud_layout.svh"
    localparam logic [7:0] RUBY_COLOR = 8'hED, SAPPHIRE_COLOR = 8'h57, CURSED_COLOR = 8'hB3;

    // Stage 1: raw coordinates align with the registered square_object offsets.
    logic [10:0] pixelXD, pixelYD;
    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin pixelXD <= 0; pixelYD <= 0; end
        else begin pixelXD <= pixelX; pixelYD <= pixelY; end
    end

    logic panelHit, digitHit, selectedHighScore;
    logic [7:0] digitRGB;
    logic [3:0] selectedDigit, digitX;
    logic [4:0] digitY;
    logic [5:0] relicOffsetX;
    logic [11:0] selectedRelicBCD;
    logic [16:0] panelAddress;
    logic [7:0] panelRGB;

    always_comb begin
        // All approved boundary pixels are opaque, including RGB33200 and FF.
        // Geometry is the independent drawing mask; it has NO gameplay outputs.
        panelHit = pixelXD < 11'd640 && pixelYD < 11'd480 &&
                   !(pixelXD >= 11'd144 && pixelXD < 11'd624 &&
                     pixelYD >= 11'd24 && pixelYD < 11'd456);
        panelAddress = 0;
        if (panelHit) begin
            // Compact atlas: left144x480, top496x24, bottom496x24, right16x432.
            // No arena pixels are stored. Registered ROM/metadata latency is unchanged.
            if (pixelXD < 11'd144)
                panelAddress = ({8'b0,pixelYD[8:0]} << 7) +
                               ({8'b0,pixelYD[8:0]} << 4) + {9'b0,pixelXD[7:0]};
            else if (pixelYD < 11'd24)
                panelAddress = 17'd69120 + ({8'b0,pixelYD[8:0]} << 9) -
                               ({8'b0,pixelYD[8:0]} << 4) + {7'b0,pixelXD[9:0]} - 17'd144;
            else if (pixelYD >= 11'd456)
                panelAddress = 17'd81024 + (({8'b0,pixelYD[8:0]} - 17'd456) << 9) -
                               (({8'b0,pixelYD[8:0]} - 17'd456) << 4) +
                               {7'b0,pixelXD[9:0]} - 17'd144;
            else
                panelAddress = 17'd92928 + (({8'b0,pixelYD[8:0]} - 17'd24) << 4) +
                               {13'b0,pixelXD[3:0]};
        end
        digitHit = 1'b0; selectedHighScore = 1'b0;
        selectedDigit = 0; digitX = 0; digitY = 0;
        digitRGB = SCORE_COLOR_LOW;
        relicOffsetX = 0; selectedRelicBCD = 0;
        // Full-detail occupied rows6..23 of the unchanged font: 16x18 per digit.
        if (scoreSquare_DR && scoreOffsetX < 11'd32 && scoreOffsetY < 11'd18) begin
            digitHit = 1'b1;
            selectedDigit = scoreOffsetX[4] ? scoreLow : scoreHigh;
            digitX = scoreOffsetX[3:0]; digitY = 5'd6 + scoreOffsetY[4:0];
            if (!(scoreHigh == 0 || (scoreHigh == 1 && scoreLow == 0)))
                digitRGB = SCORE_COLOR_HIGH;
        end else if (highScoreSquare_DR && highScoreOffsetX < 11'd32 && highScoreOffsetY < 11'd18) begin
            digitHit = 1'b1; selectedHighScore = 1'b1;
            selectedDigit = highScoreOffsetX[4] ? highScoreLow : highScoreHigh;
            digitX = highScoreOffsetX[3:0]; digitY = 5'd6 + highScoreOffsetY[4:0];
            digitRGB = HIGH_SCORE_COLOR;
        end else if (pixelXD >= RELIC_X && pixelXD < RELIC_X+48) begin
            relicOffsetX = pixelXD[5:0] - RELIC_X[5:0];
            if (pixelYD >= RUBY_Y && pixelYD < RUBY_Y+HUD_DIGIT_HEIGHT) begin
                digitHit = 1'b1; selectedRelicBCD = rubyCountBCD;
                digitY = 5'd6 + (pixelYD[4:0] - RUBY_Y[4:0]); digitRGB = RUBY_COLOR;
            end else if (pixelYD >= SAPPHIRE_Y && pixelYD < SAPPHIRE_Y+HUD_DIGIT_HEIGHT) begin
                digitHit = 1'b1; selectedRelicBCD = sapphireCountBCD;
                digitY = 5'd6 + (pixelYD[4:0] - SAPPHIRE_Y[4:0]); digitRGB = SAPPHIRE_COLOR;
            end else if (pixelYD >= CURSED_Y && pixelYD < CURSED_Y+HUD_DIGIT_HEIGHT) begin
                digitHit = 1'b1; selectedRelicBCD = cursedCountBCD;
                digitY = 5'd6 + (pixelYD[4:0] - CURSED_Y[4:0]); digitRGB = CURSED_COLOR;
            end
            if (relicOffsetX < 6'd16) selectedDigit = selectedRelicBCD[11:8];
            else if (relicOffsetX < 6'd32) selectedDigit = selectedRelicBCD[7:4];
            else selectedDigit = selectedRelicBCD[3:0];
            digitX = relicOffsetX[3:0];
        end
    end

    // One shared 8192-bit ROM for current score, high score and all nine relic digits.
    logic [12:0] address;
    logic fontBit;
    assign address = {selectedDigit, digitY, digitX};
    lpm_rom #(
        .LPM_WIDTH(1), .LPM_WIDTHAD(13), .LPM_NUMWORDS(8192),
        .LPM_FILE("RTL/mifs/numbers_new_font.mif"), .LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"), .LPM_OUTDATA("UNREGISTERED"),
        .AUTO_CARRY_CHAINS("ON"), .AUTO_CASCADE_BUFFERS("ON"),
        .INTENDED_DEVICE_FAMILY("Cyclone V")
    ) rom_inst (.address(address), .inclock(clk), .q(fontBit));

    // Opaque boundary atlas. Color values never control transparency/collision.
    lpm_rom #(.LPM_WIDTH(8), .LPM_WIDTHAD(17), .LPM_NUMWORDS(99840),
        .LPM_FILE("RTL/mifs/hud_frame_rgb332.mif"), .LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"), .LPM_OUTDATA("UNREGISTERED"),
        .AUTO_CARRY_CHAINS("ON"), .AUTO_CASCADE_BUFFERS("ON"),
        .INTENDED_DEVICE_FAMILY("Cyclone V")) panel_rom
        (.address(panelAddress), .inclock(clk), .q(panelRGB));

    // Stage 2: field metadata follows the SAME edge as both ROM addresses.
    logic panelD, digitD, highD;
    logic [7:0] digitColorD;
    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin
            panelD <= 0; digitD <= 0; highD <= 0;
            digitColorD <= 0;
        end else begin
            panelD <= panelHit; digitD <= digitHit; highD <= selectedHighScore;
            digitColorD <= digitRGB;
        end
    end
    // Original layers/priority. The entire frame is disjoint from playable pixels.
    assign highScore_DR = panelD && highD && digitD && fontBit;
    assign score_DR = panelD && !highScore_DR;
    assign highScore_RGB = digitColorD;
    assign score_RGB = digitD && fontBit ? digitColorD : panelRGB;
endmodule
