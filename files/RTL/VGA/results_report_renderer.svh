// Display-only post-game reports. Included by the existing QSF-listed renderer.
// Supplied artwork is never a collision mask. No output feeds game logic.
module results_report_renderer (
    input logic clk, resetN,
    input logic [10:0] pixelX, pixelY,
    input logic gameWonPulse, gameOverPulse, gameStartPulse,
    input logic [3:0] scoreLow, scoreHigh,
    input logic [11:0] rubyCountBCD, sapphireCountBCD, cursedCountBCD,
    output logic report_DR,
    output logic [7:0] report_RGB
);
    localparam logic [1:0] NONE=0, VICTORY=1, DEFEAT=2;
    logic [1:0] resultState;
    logic capturePending, statisticsReady;
    logic [7:0] finalScoreBCD;
    logic [11:0] finalRubyBCD, finalSapphireBCD, finalCursedBCD;
    // Consumers apply collection pulses on the edge that observes the end pulse.
    // Capture ONE edge later: fatal Cursed score/count changes have now settled.
    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin
            resultState<=NONE; capturePending<=0; statisticsReady<=0;
            finalScoreBCD<=0; finalRubyBCD<=0; finalSapphireBCD<=0; finalCursedBCD<=0;
        end else if (gameStartPulse) begin
            resultState<=NONE; capturePending<=0; statisticsReady<=0;
            finalScoreBCD<=0; finalRubyBCD<=0; finalSapphireBCD<=0; finalCursedBCD<=0;
        end else begin
            if (capturePending) begin
                finalScoreBCD<={scoreHigh,scoreLow}; finalRubyBCD<=rubyCountBCD;
                finalSapphireBCD<=sapphireCountBCD; finalCursedBCD<=cursedCountBCD;
                capturePending<=0; statisticsReady<=1;
            end
            if (gameWonPulse || gameOverPulse) begin
                resultState<=gameWonPulse ? VICTORY : DEFEAT;
                capturePending<=1; statisticsReady<=0;
            end
        end
    end

    logic panelHit, digitHit, twoDigits;
    logic [15:0] mapAddress;
    wire [14:0] tileIndex;
    logic [1:0] subpixelD;
    wire [16:0] payloadAddress={tileIndex,subpixelD};
    wire [8:0] rgba;
    logic [12:0] fontAddress,fontAddressD;
    logic [5:0] fieldOffsetX,glyphOffsetX;
    logic [4:0] glyphOffsetY;
    logic [11:0] selectedBCD;
    logic [3:0] selectedDigit;
    logic [7:0] digitColor;
    // Report-only nearest-neighbor sampling of the unchanged16x18 glyphs.
    // The supplied wells fit12x14 glyphs, not the previous48-pixel-wide triplets.
    function automatic logic [3:0] sampleX(input logic [3:0] x);
        case(x)
            4'd0:sampleX=4'd0;
            4'd1:sampleX=4'd2;
            4'd2:sampleX=4'd3;
            4'd3:sampleX=4'd4;
            4'd4:sampleX=4'd6;
            4'd5:sampleX=4'd7;
            4'd6:sampleX=4'd8;
            4'd7:sampleX=4'd10;
            4'd8:sampleX=4'd11;
            4'd9:sampleX=4'd12;
            4'd10:sampleX=4'd14;
            4'd11:sampleX=4'd15;
            default:sampleX=0;
        endcase
    endfunction
    function automatic logic [4:0] sampleY(input logic [4:0] y);
        case(y)
            5'd0:sampleY=5'd6;
            5'd1:sampleY=5'd7;
            5'd2:sampleY=5'd9;
            5'd3:sampleY=5'd10;
            5'd4:sampleY=5'd11;
            5'd5:sampleY=5'd13;
            5'd6:sampleY=5'd14;
            5'd7:sampleY=5'd15;
            5'd8:sampleY=5'd16;
            5'd9:sampleY=5'd18;
            5'd10:sampleY=5'd19;
            5'd11:sampleY=5'd20;
            5'd12:sampleY=5'd22;
            5'd13:sampleY=5'd23;
            default:sampleY=5'd6;
        endcase
    endfunction
    always_comb begin
        panelHit=statisticsReady && resultState!=NONE &&
                 pixelX>=11'd248 && pixelX<11'd536 && pixelY>=11'd24 && pixelY<11'd456;
        mapAddress=0;digitHit=0;twoDigits=0;
        fieldOffsetX=0;glyphOffsetX=0;glyphOffsetY=0;
        selectedBCD=0;selectedDigit=0;digitColor=8'hF9;
        if(panelHit) begin
            // Lossless2x2 dictionary, NOT image scaling.144x216 map per state.
            // Row stride144=128+16; address calculation contains no division.
            mapAddress=(resultState==DEFEAT ? 16'd31104 : 16'd0) +
                       ((({5'b0,pixelY}-16'd24)>>1)<<7) +
                       ((({5'b0,pixelY}-16'd24)>>1)<<4) +
                       (({5'b0,pixelX}-16'd248)>>1);
            if(resultState==VICTORY) begin
                if(pixelX>=438 && pixelX<474 && pixelY>=290 && pixelY<304) begin
                    digitHit=1;selectedBCD=finalRubyBCD;digitColor=8'hED;
                    fieldOffsetX=pixelX[5:0]-6'd54;glyphOffsetY=pixelY[4:0]-5'd2;
                end else if(pixelX>=437 && pixelX<473 && pixelY>=331 && pixelY<345) begin
                    digitHit=1;selectedBCD=finalSapphireBCD;digitColor=8'h57;
                    fieldOffsetX=pixelX[5:0]-6'd53;glyphOffsetY=pixelY[4:0]-5'd11;
                end else if(pixelX>=437 && pixelX<473 && pixelY>=371 && pixelY<385) begin
                    digitHit=1;selectedBCD=finalCursedBCD;digitColor=8'hB3;
                    fieldOffsetX=pixelX[5:0]-6'd53;glyphOffsetY=pixelY[4:0]-5'd19;
                end
            end else begin
                if(pixelX>=443 && pixelX<467 && pixelY>=230 && pixelY<244) begin
                    digitHit=1;twoDigits=1;selectedBCD={4'd0,finalScoreBCD};
                    fieldOffsetX=pixelX[5:0]-6'd59;glyphOffsetY=pixelY[4:0]-5'd6;
                end else if(pixelX>=431 && pixelX<467 && pixelY>=286 && pixelY<300) begin
                    digitHit=1;selectedBCD=finalRubyBCD;digitColor=8'hED;
                    fieldOffsetX=pixelX[5:0]-6'd47;glyphOffsetY=pixelY[4:0]-5'd30;
                end else if(pixelX>=431 && pixelX<467 && pixelY>=324 && pixelY<338) begin
                    digitHit=1;selectedBCD=finalSapphireBCD;digitColor=8'h57;
                    fieldOffsetX=pixelX[5:0]-6'd47;glyphOffsetY=pixelY[4:0]-5'd4;
                end else if(pixelX>=431 && pixelX<467 && pixelY>=363 && pixelY<377) begin
                    digitHit=1;selectedBCD=finalCursedBCD;digitColor=8'hB3;
                    fieldOffsetX=pixelX[5:0]-6'd47;glyphOffsetY=pixelY[4:0]-5'd11;
                end
            end
            if(twoDigits)selectedDigit=fieldOffsetX<12 ? selectedBCD[7:4] : selectedBCD[3:0];
            else if(fieldOffsetX<12)selectedDigit=selectedBCD[11:8];
            else if(fieldOffsetX<24)selectedDigit=selectedBCD[7:4];
            else selectedDigit=selectedBCD[3:0];
            glyphOffsetX=fieldOffsetX<12 ? fieldOffsetX :
                         fieldOffsetX<24 ? fieldOffsetX-6'd12 : fieldOffsetX-6'd24;
        end
        fontAddress={selectedDigit,sampleY(glyphOffsetY),sampleX(glyphOffsetX[3:0])};
    end
    logic panelD,panelDD,digitD,digitDD;
    logic [7:0] digitColorD,digitColorDD;
    // Stage1: registered map read and subpixel; stage2: dictionary read.
    // Font and all request/color metadata retain the same two-stage latency.
    always_ff @(posedge clk or negedge resetN) begin
        if(!resetN) begin
            subpixelD<=0;fontAddressD<=0;
            panelD<=0;panelDD<=0;digitD<=0;digitDD<=0;
            digitColorD<=0;digitColorDD<=0;
        end else begin
            subpixelD<={pixelY[0],pixelX[0]};fontAddressD<=fontAddress;
            panelD<=panelHit;panelDD<=panelD;digitD<=digitHit;digitDD<=digitD;
            digitColorD<=digitColor;digitColorDD<=digitColorD;
        end
    end
    // Alpha is an independent supplied binary bit, never a color sentinel.
    // Packing{alpha,RGB332} into9bits avoids a separate large mask allocation.
    lpm_rom #(.LPM_WIDTH(15),.LPM_WIDTHAD(16),.LPM_NUMWORDS(62208),
        .LPM_FILE("RTL/mifs/results_v3/results_tilemap.mif"),.LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"),.LPM_OUTDATA("UNREGISTERED"),.INTENDED_DEVICE_FAMILY("Cyclone V"))
        map_rom(.address(mapAddress),.inclock(clk),.q(tileIndex));
    lpm_rom #(.LPM_WIDTH(9),.LPM_WIDTHAD(17),.LPM_NUMWORDS(69628),
        .LPM_FILE("RTL/mifs/results_v3/results_tiles_rgba9.mif"),.LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"),.LPM_OUTDATA("UNREGISTERED"),.INTENDED_DEVICE_FAMILY("Cyclone V"))
        payload_rom(.address(payloadAddress),.inclock(clk),.q(rgba));
    wire fontBit;
    lpm_rom #(.LPM_WIDTH(1),.LPM_WIDTHAD(13),.LPM_NUMWORDS(8192),
        .LPM_FILE("RTL/mifs/numbers_new_font.mif"),.LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"),.LPM_OUTDATA("UNREGISTERED"),.INTENDED_DEVICE_FAMILY("Cyclone V"))
        font_rom(.address(fontAddressD),.inclock(clk),.q(fontBit));
    assign report_DR=panelDD && (rgba[8] || (digitDD && fontBit));
    assign report_RGB=digitDD && fontBit ? digitColorDD : rgba[7:0];
endmodule
