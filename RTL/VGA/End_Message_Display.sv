module end_message_display (

//------------- Inputs -----------

	input logic clk,
	input logic resetN,

	input logic [10:0] pixelX,
	input logic [10:0] pixelY,

	input logic gameWonPulse,
	input logic gameOverPulse,
	input logic gameStartPulse,
	input logic [3:0] scoreLow, scoreHigh,
	input logic [11:0] rubyCountBCD, sapphireCountBCD, cursedCountBCD,

//------------- Outputs -----------

	output logic message_DR,
	output logic [7:0] message_RGB

);

// Initial MENU already disables gameplay in game_controller. This drawing-only
// latch mirrors reset -> first gameStartPulse, without adding gameplay feedback
// or changing gameplay. The result branch below uses display-only statistic taps.
logic menuActive;
logic menuModeD, menuModeDD, menuVisibleD, menuVisibleDD;
logic [16:0] menuAddress, menuAddressD;
logic [13:0] menuBackgroundAddress;
logic [8:0] menuX,menuY;
wire [10:0] menuLocalX=pixelX-11'd144;
logic [7:0] menuRGB;
logic menuVisible;
// The existing live HUD owns x[0,144). MENU never masks or duplicates it.
assign menuVisible = pixelX>=11'd144 && pixelX<11'd640 && pixelY<11'd480;
assign menuX=menuVisible ? menuLocalX[8:0] : 9'd0;
assign menuY=menuVisible ? pixelY[8:0] : 9'd0;
// Right area496x480:124x120 RGB332 base displayed4x, then native detail patches.
//124=128-4, so the background stride needs shifts only, never a divider.
assign menuBackgroundAddress=({7'b0,menuY[8:2]} << 7) -
                            ({7'b0,menuY[8:2]} << 2) + {7'b0,menuX[8:2]};
`include "RTL/VGA/opening_supplied_layout.svh"

always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        menuActive <= 1'b1;
        menuModeD <= 1'b1; menuModeDD <= 1'b1;
        menuVisibleD <= 1'b0; menuVisibleDD <= 1'b0;
        menuAddressD <= 17'd0;
    end else begin
        if (gameStartPulse) menuActive <= 1'b0;
        menuModeD <= menuActive;
        menuModeDD <= menuModeD;
        menuVisibleD <= menuVisible;
        menuVisibleDD <= menuVisibleD;
        menuAddressD <= menuAddress;
    end
end

// Stage1 address + stage2 vendor-ROM address register match the HUD/head path.
// Only the right area is opaque;00/FF are colors, not transparency. Background
// and supplied native detail share ONE ROM/read path with the original latency.
lpm_rom #(.LPM_WIDTH(8), .LPM_WIDTHAD(MENU_ADDRESS_WIDTH), .LPM_NUMWORDS(MENU_ROM_DEPTH),
    .LPM_FILE("RTL/mifs/opening_supplied_atlas.mif"), .LPM_TYPE("LPM_ROM"),
    .LPM_ADDRESS_CONTROL("REGISTERED"), .LPM_OUTDATA("UNREGISTERED"),
    .AUTO_CARRY_CHAINS("ON"), .AUTO_CASCADE_BUFFERS("ON"),
    .INTENDED_DEVICE_FAMILY("Cyclone V")) menu_rom
    (.address(menuAddressD), .inclock(clk), .q(menuRGB));

// Shared results renderer owns only x[248,536),y[24,456).
wire reportDR;
wire [7:0] reportRGB;
results_report_renderer results (
    .clk(clk),.resetN(resetN),.pixelX(pixelX),.pixelY(pixelY),
    .gameWonPulse(gameWonPulse),.gameOverPulse(gameOverPulse),.gameStartPulse(gameStartPulse),
    .scoreLow(scoreLow),.scoreHigh(scoreHigh),.rubyCountBCD(rubyCountBCD),
    .sapphireCountBCD(sapphireCountBCD),.cursedCountBCD(cursedCountBCD),
    .report_DR(reportDR),.report_RGB(reportRGB));
always_comb begin
    message_DR=menuModeDD ? menuVisibleDD : reportDR;
    message_RGB=menuModeDD ? menuRGB : reportRGB;
end
endmodule

`include "RTL/VGA/results_report_renderer.svh"
