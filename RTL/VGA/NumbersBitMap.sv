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
    logic [4:0] relicOffsetX;
    logic [11:0] selectedRelicBCD;
    logic [6:0] panelOffsetX;
    logic [8:0] panelOffsetY;
    logic [15:0] panelAddress;
    logic [7:0] panelRGB;
    logic panelMask;

    always_comb begin
        panelHit = (pixelXD >= HUD_LEFT && pixelXD < HUD_RIGHT &&
                    pixelYD >= HUD_TOP && pixelYD < HUD_BOTTOM);
        panelOffsetX = pixelXD[6:0] - 7'd8;
        panelOffsetY = pixelYD[8:0] - 9'd24;
        // The native panel is row-major, 120 pixels wide; never sample outside its ROM.
        panelAddress = panelHit ? ({7'b0,panelOffsetY} * 16'd120 + {9'b0,panelOffsetX}) : 16'd0;
        digitHit = 1'b0; selectedHighScore = 1'b0;
        selectedDigit = 0; digitX = 0; digitY = 0;
        digitRGB = SCORE_COLOR_LOW;
        relicOffsetX = 0; selectedRelicBCD = 0;
        // Reuse the unchanged font: sample every second pixel in its occupied rows6..23.
        // Compact 8x9 glyphs fit the supplied windows; there is no panel scaling/cropping.
        if (scoreSquare_DR && scoreOffsetX < 11'd16 && scoreOffsetY < 11'd9) begin
            digitHit = 1'b1;
            selectedDigit = scoreOffsetX[3] ? scoreLow : scoreHigh;
            digitX = {scoreOffsetX[2:0],1'b0}; digitY = 5'd6 + {scoreOffsetY[3:0],1'b0};
            if (!(scoreHigh == 0 || (scoreHigh == 1 && scoreLow == 0)))
                digitRGB = SCORE_COLOR_HIGH;
        end else if (highScoreSquare_DR && highScoreOffsetX < 11'd16 && highScoreOffsetY < 11'd9) begin
            digitHit = 1'b1; selectedHighScore = 1'b1;
            selectedDigit = highScoreOffsetX[3] ? highScoreLow : highScoreHigh;
            digitX = {highScoreOffsetX[2:0],1'b0}; digitY = 5'd6 + {highScoreOffsetY[3:0],1'b0};
            digitRGB = HIGH_SCORE_COLOR;
        end else if (pixelXD >= RELIC_X && pixelXD < RELIC_X+24) begin
            relicOffsetX = pixelXD[4:0] - 5'd6;
            if (pixelYD >= RUBY_Y && pixelYD < RUBY_Y+HUD_DIGIT_HEIGHT) begin
                digitHit = 1'b1; selectedRelicBCD = rubyCountBCD;
                digitY = 5'd6 + ((pixelYD[4:0] - 5'd3) << 1); digitRGB = RUBY_COLOR;
            end else if (pixelYD >= SAPPHIRE_Y && pixelYD < SAPPHIRE_Y+HUD_DIGIT_HEIGHT) begin
                digitHit = 1'b1; selectedRelicBCD = sapphireCountBCD;
                digitY = 5'd6 + ((pixelYD[4:0] - 5'd4) << 1); digitRGB = SAPPHIRE_COLOR;
            end else if (pixelYD >= CURSED_Y && pixelYD < CURSED_Y+HUD_DIGIT_HEIGHT) begin
                digitHit = 1'b1; selectedRelicBCD = cursedCountBCD;
                digitY = 5'd6 + ((pixelYD[4:0] - 5'd5) << 1); digitRGB = CURSED_COLOR;
            end
            if (relicOffsetX < 5'd8) selectedDigit = selectedRelicBCD[11:8];
            else if (relicOffsetX < 5'd16) selectedDigit = selectedRelicBCD[7:4];
            else selectedDigit = selectedRelicBCD[3:0];
            digitX = {relicOffsetX[2:0],1'b0};
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

    // Color00 is NOT a transparency key. Both ROMs use the identical address/edge.
    lpm_rom #(.LPM_WIDTH(8), .LPM_WIDTHAD(16), .LPM_NUMWORDS(51840),
        .LPM_FILE("RTL/mifs/hud_panel_rgb332.mif"), .LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"), .LPM_OUTDATA("UNREGISTERED"),
        .AUTO_CARRY_CHAINS("ON"), .AUTO_CASCADE_BUFFERS("ON"),
        .INTENDED_DEVICE_FAMILY("Cyclone V")) panel_rom
        (.address(panelAddress), .inclock(clk), .q(panelRGB));
    lpm_rom #(.LPM_WIDTH(1), .LPM_WIDTHAD(16), .LPM_NUMWORDS(51840),
        .LPM_FILE("RTL/mifs/hud_panel_alpha.mif"), .LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"), .LPM_OUTDATA("UNREGISTERED"),
        .AUTO_CARRY_CHAINS("ON"), .AUTO_CASCADE_BUFFERS("ON"),
        .INTENDED_DEVICE_FAMILY("Cyclone V")) panel_alpha_rom
        (.address(panelAddress), .inclock(clk), .q(panelMask));

    // Stage 2: field metadata follows the SAME edge as all three ROM addresses.
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
    // Keep the original score/high-score layers and mux priority; sidebar is disjoint from arena.
    assign highScore_DR = panelD && panelMask && highD && digitD && fontBit;
    assign score_DR = panelD && panelMask && !highScore_DR;
    assign highScore_RGB = digitColorD;
    assign score_RGB = digitD && fontBit ? digitColorD : panelRGB;
endmodule
