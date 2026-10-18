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

    logic panelHit, nativeHit, digitHit;
    logic [14:0] backgroundAddress;
    logic [15:0] nativeAddress;
    logic [12:0] fontAddress;
    logic [3:0] selectedDigit, digitX;
    logic [4:0] digitY;
    logic [11:0] selectedBCD;
    logic [7:0] digitColor;
    logic [5:0] digitOffsetX;
    always_comb begin
        panelHit=statisticsReady && resultState!=NONE &&
                 pixelX>=11'd248 && pixelX<11'd536 && pixelY>=11'd24 && pixelY<11'd456;
        backgroundAddress=0; nativeAddress=0; nativeHit=0;
        digitHit=0; selectedDigit=0; digitX=0; digitY=0;
        selectedBCD=0; digitOffsetX=0; digitColor=8'hF9;
        if (panelHit) begin
            // Exact2x nearest-neighbor: source144x216. All coordinates are bounded.
            backgroundAddress=((({4'b0,pixelY}-15'd24)>>1)<<7) +
                              ((({4'b0,pixelY}-15'd24)>>1)<<4) +
                              (({4'b0,pixelX}-15'd248)>>1);
            if(pixelX>=280 && pixelX<504 && pixelY>=40 && pixelY<72) begin
                nativeHit=1;
                nativeAddress=(resultState==VICTORY ? 16'd0 : 16'd7168) +
                              ({5'b0,pixelY}-16'd40)*16'd224 + {5'b0,pixelX}-16'd280;
            end else if(pixelX>=312 && pixelX<472 && pixelY>=80 && pixelY<152) begin
                nativeHit=1;
                nativeAddress=(resultState==VICTORY ? 16'd14336 : 16'd25856) +
                              ({5'b0,pixelY}-16'd80)*16'd160 + {5'b0,pixelX}-16'd312;
            end else if(resultState==VICTORY && pixelX>=280 && pixelX<504 && pixelY>=164 && pixelY<196) begin
                nativeHit=1;
                nativeAddress=16'd37376+({5'b0,pixelY}-16'd164)*16'd224+{5'b0,pixelX}-16'd280;
            end else if(resultState==DEFEAT && pixelX>=280 && pixelX<416 && pixelY>=172 && pixelY<188) begin
                nativeHit=1;
                nativeAddress=16'd44544+({5'b0,pixelY}-16'd172)*16'd136+{5'b0,pixelX}-16'd280;
            end else if(pixelX>=280 && pixelX<304) begin
                if(pixelY>=232 && pixelY<256) begin
                    nativeHit=1; nativeAddress=16'd46720+({5'b0,pixelY}-16'd232)*16'd24+{5'b0,pixelX}-16'd280;
                end else if(pixelY>=288 && pixelY<312) begin
                    nativeHit=1; nativeAddress=16'd47296+({5'b0,pixelY}-16'd288)*16'd24+{5'b0,pixelX}-16'd280;
                end else if(pixelY>=344 && pixelY<368) begin
                    nativeHit=1; nativeAddress=16'd47872+({5'b0,pixelY}-16'd344)*16'd24+{5'b0,pixelX}-16'd280;
                end
            end
            if(resultState==DEFEAT && pixelX>=456 && pixelX<488 && pixelY>=171 && pixelY<189) begin
                digitHit=1; digitOffsetX=pixelX[5:0]-6'd8;
                selectedDigit=digitOffsetX<16 ? finalScoreBCD[7:4] : finalScoreBCD[3:0];
                digitY=5'd6+(pixelY[4:0]-5'd11);
            end else if(pixelX>=440 && pixelX<488) begin
                digitOffsetX=pixelX[5:0]-6'd56;
                if(pixelY>=235 && pixelY<253) begin
                    digitHit=1;selectedBCD=finalRubyBCD;digitColor=8'hED;
                    digitY=5'd6+(pixelY[4:0]-5'd11);
                end else if(pixelY>=291 && pixelY<309) begin
                    digitHit=1;selectedBCD=finalSapphireBCD;digitColor=8'h57;
                    digitY=5'd6+(pixelY[4:0]-5'd3);
                end else if(pixelY>=347 && pixelY<365) begin
                    digitHit=1;selectedBCD=finalCursedBCD;digitColor=8'hB3;
                    digitY=5'd6+(pixelY[4:0]-5'd27);
                end
                if(digitOffsetX<16)selectedDigit=selectedBCD[11:8];
                else if(digitOffsetX<32)selectedDigit=selectedBCD[7:4];
                else selectedDigit=selectedBCD[3:0];
            end
            digitX=digitOffsetX[3:0];
        end
        fontAddress={selectedDigit,digitY,digitX};
    end

    logic [14:0] backgroundAddressD;
    logic [15:0] nativeAddressD;
    logic [12:0] fontAddressD;
    logic panelD,panelDD,nativeD,nativeDD,digitD,digitDD;
    logic [7:0] digitColorD,digitColorDD;
    // Stage1 registered addresses; stage2 ROM address registers + same metadata.
    // Matches the unchanged HUD/opening latency before the existing mux register.
    always_ff @(posedge clk or negedge resetN) begin
        if(!resetN) begin
            backgroundAddressD<=0;nativeAddressD<=0;fontAddressD<=0;
            panelD<=0;panelDD<=0;nativeD<=0;nativeDD<=0;digitD<=0;digitDD<=0;
            digitColorD<=0;digitColorDD<=0;
        end else begin
            backgroundAddressD<=backgroundAddress;nativeAddressD<=nativeAddress;fontAddressD<=fontAddress;
            panelD<=panelHit;panelDD<=panelD;nativeD<=nativeHit;nativeDD<=nativeD;
            digitD<=digitHit;digitDD<=digitD;digitColorD<=digitColor;digitColorDD<=digitColorD;
        end
    end
    wire [7:0] backgroundRGB,nativeRGB;
    wire nativeAlpha,fontBit;
    lpm_rom #(.LPM_WIDTH(8),.LPM_WIDTHAD(15),.LPM_NUMWORDS(31104),
        .LPM_FILE("RTL/mifs/results/report_shared_144x216_rgb332.mif"),.LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"),.LPM_OUTDATA("UNREGISTERED"),.INTENDED_DEVICE_FAMILY("Cyclone V"))
        background_rom(.address(backgroundAddressD),.inclock(clk),.q(backgroundRGB));
    lpm_rom #(.LPM_WIDTH(8),.LPM_WIDTHAD(16),.LPM_NUMWORDS(48448),
        .LPM_FILE("RTL/mifs/results/results_details_rgb332.mif"),.LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"),.LPM_OUTDATA("UNREGISTERED"),.INTENDED_DEVICE_FAMILY("Cyclone V"))
        detail_rom(.address(nativeAddressD),.inclock(clk),.q(nativeRGB));
    lpm_rom #(.LPM_WIDTH(1),.LPM_WIDTHAD(16),.LPM_NUMWORDS(48448),
        .LPM_FILE("RTL/mifs/results/results_details_mask1.mif"),.LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"),.LPM_OUTDATA("UNREGISTERED"),.INTENDED_DEVICE_FAMILY("Cyclone V"))
        mask_rom(.address(nativeAddressD),.inclock(clk),.q(nativeAlpha));
    lpm_rom #(.LPM_WIDTH(1),.LPM_WIDTHAD(13),.LPM_NUMWORDS(8192),
        .LPM_FILE("RTL/mifs/numbers_new_font.mif"),.LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"),.LPM_OUTDATA("UNREGISTERED"),.INTENDED_DEVICE_FAMILY("Cyclone V"))
        font_rom(.address(fontAddressD),.inclock(clk),.q(fontBit));
    assign report_DR=panelDD;
    assign report_RGB=digitDD && fontBit ? digitColorDD :
                      nativeDD && nativeAlpha ? nativeRGB : backgroundRGB;
endmodule
