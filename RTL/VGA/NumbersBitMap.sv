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
    parameter logic [7:0] SCORE_COLOR_HIGH = 8'hD9;
    parameter logic [7:0] HIGH_SCORE_COLOR = 8'hF9;
    localparam logic [7:0] PANEL_COLOR = 8'h04, FRAME_COLOR = 8'h8D;
    localparam logic [7:0] RUBY_COLOR = 8'hED, SAPPHIRE_COLOR = 8'h57, CURSED_COLOR = 8'hB3;

    // Stage 1: raw coordinates align with the registered square_object offsets.
    logic [10:0] pixelXD, pixelYD;
    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin pixelXD <= 0; pixelYD <= 0; end
        else begin pixelXD <= pixelX; pixelYD <= pixelY; end
    end

    logic labelBit;
    logic [7:0] labelRGB;
    hud_labels labels(pixelXD, pixelYD, labelBit, labelRGB);
    logic panelHit, digitHit, selectedHighScore;
    logic [7:0] panelRGB, digitRGB;
    logic [3:0] selectedDigit, digitX;
    logic [4:0] digitY;
    logic [5:0] relicOffsetX;
    logic [11:0] selectedRelicBCD;

    always_comb begin
        panelHit = (pixelXD >= 11'd8 && pixelXD < 11'd128 &&
                    pixelYD >= 11'd24 && pixelYD < 11'd456);
        panelRGB = PANEL_COLOR;
        if (pixelXD < 11'd10 || pixelXD >= 11'd126 ||
            pixelYD < 11'd26 || pixelYD >= 11'd454 ||
            pixelYD == 11'd100 || pixelYD == 11'd192)
            panelRGB = FRAME_COLOR;
        digitHit = 1'b0; selectedHighScore = 1'b0;
        selectedDigit = 0; digitX = 0; digitY = 0;
        digitRGB = SCORE_COLOR_LOW;
        relicOffsetX = 0; selectedRelicBCD = 0;
        // Native 16x32 font: two score digits occupy a 32x32 rectangle.
        if (scoreSquare_DR && scoreOffsetX < 11'd32 && scoreOffsetY < 11'd32) begin
            digitHit = 1'b1;
            selectedDigit = scoreOffsetX[4] ? scoreLow : scoreHigh;
            digitX = scoreOffsetX[3:0]; digitY = scoreOffsetY[4:0];
            if (!(scoreHigh == 0 || (scoreHigh == 1 && scoreLow == 0)))
                digitRGB = SCORE_COLOR_HIGH;
        end else if (highScoreSquare_DR && highScoreOffsetX < 11'd32 && highScoreOffsetY < 11'd32) begin
            digitHit = 1'b1; selectedHighScore = 1'b1;
            selectedDigit = highScoreOffsetX[4] ? highScoreLow : highScoreHigh;
            digitX = highScoreOffsetX[3:0]; digitY = highScoreOffsetY[4:0];
            digitRGB = HIGH_SCORE_COLOR;
        end else if (pixelXD >= 11'd40 && pixelXD < 11'd88) begin
            relicOffsetX = pixelXD[5:0] - 6'd40;
            if (pixelYD >= 11'd260 && pixelYD < 11'd292) begin
                digitHit = 1'b1; selectedRelicBCD = rubyCountBCD;
                digitY = pixelYD[4:0] - 5'd4; digitRGB = RUBY_COLOR;
            end else if (pixelYD >= 11'd328 && pixelYD < 11'd360) begin
                digitHit = 1'b1; selectedRelicBCD = sapphireCountBCD;
                digitY = pixelYD[4:0] - 5'd8; digitRGB = SAPPHIRE_COLOR;
            end else if (pixelYD >= 11'd396 && pixelYD < 11'd428) begin
                digitHit = 1'b1; selectedRelicBCD = cursedCountBCD;
                digitY = pixelYD[4:0] - 5'd12; digitRGB = CURSED_COLOR;
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

    // Stage 2: metadata and label pixels follow the SAME edge as the ROM address.
    logic panelD, digitD, highD, labelD;
    logic [7:0] panelColorD, digitColorD, labelColorD;
    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin
            panelD <= 0; digitD <= 0; highD <= 0; labelD <= 0;
            panelColorD <= PANEL_COLOR; digitColorD <= 0; labelColorD <= 0;
        end else begin
            panelD <= panelHit; digitD <= digitHit; highD <= selectedHighScore;
            labelD <= labelBit;
            panelColorD <= panelRGB; digitColorD <= digitRGB; labelColorD <= labelRGB;
        end
    end
    // Keep the original score/high-score layers and mux priority; sidebar is disjoint from arena.
    assign highScore_DR = panelD && highD && digitD && fontBit;
    assign score_DR = panelD && !highScore_DR;
    assign highScore_RGB = digitColorD;
    assign score_RGB = labelD ? labelColorD :
                       (digitD && fontBit ? digitColorD : panelColorD);
endmodule
