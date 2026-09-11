module end_message_display (

//------------- Inputs -----------

	input logic clk,
	input logic resetN,

	input logic [10:0] pixelX,
	input logic [10:0] pixelY,

	input logic gameWonPulse,
	input logic gameOverPulse,
	input logic gameStartPulse,

//------------- Outputs -----------

	output logic message_DR,
	output logic [7:0] message_RGB

);

//------------- Panel Parameters -----------

localparam int PANEL_LEFT   = 40;
localparam int PANEL_TOP    = 190;
localparam int PANEL_WIDTH  = 560;
localparam int PANEL_HEIGHT = 90;

localparam int ROM_DEPTH = PANEL_WIDTH * PANEL_HEIGHT;

//------------- Message States -----------

//Define params to improve readability and clearity
localparam logic [1:0] MSG_NONE = 2'd0;
localparam logic [1:0] MSG_WIN  = 2'd1;
localparam logic [1:0] MSG_LOST = 2'd2;

//------------- Internal Signals -----------

logic [1:0] messageState;

logic insidePanel;

logic [10:0] localX;
logic [10:0] localY;

logic [15:0] romAddress;

logic [7:0] winRGB;
logic [7:0] lostRGB;

//------------- Area Detection -----------

assign insidePanel =
	(pixelX >= PANEL_LEFT) &&
	(pixelX <  PANEL_LEFT + PANEL_WIDTH) &&
	(pixelY >= PANEL_TOP) &&
	(pixelY <  PANEL_TOP + PANEL_HEIGHT);

//------------- Address Calculation -----------

always_comb begin

	localX = 11'd0;
	localY = 11'd0;
	romAddress = 16'd0;

	if (insidePanel) begin

		localX = pixelX - PANEL_LEFT;
		localY = pixelY - PANEL_TOP;

		romAddress =
			(localY * PANEL_WIDTH) + localX;

	end

end

//------------- Message State Register -----------

always_ff @(posedge clk or negedge resetN)
begin
	if (!resetN) begin

		messageState <= MSG_NONE;

	end

	else begin

		if (gameStartPulse) begin
			messageState <= MSG_NONE;
		end

		else if (gameWonPulse) begin
			messageState <= MSG_WIN;
		end

		else if (gameOverPulse) begin
			messageState <= MSG_LOST;
		end

	end
end

//------------- Win Message ROM -------------

lpm_rom #(
	.LPM_WIDTH              (8),
	.LPM_WIDTHAD            (16),
	.LPM_NUMWORDS           (ROM_DEPTH),
	.LPM_FILE               ("RTL/mifs/end_message_win.mif"),
	.LPM_TYPE               ("LPM_ROM"),
	.LPM_ADDRESS_CONTROL    ("REGISTERED"),
	.LPM_OUTDATA            ("UNREGISTERED"),
	.AUTO_CARRY_CHAINS      ("ON"),
	.AUTO_CASCADE_BUFFERS   ("ON"),
	.INTENDED_DEVICE_FAMILY ("Cyclone V")
) win_rom_inst (
	.address (romAddress),
	.inclock (clk),
	.q       (winRGB)
);

//------------- Lost Message ROM -------------

lpm_rom #(
	.LPM_WIDTH              (8),
	.LPM_WIDTHAD            (16),
	.LPM_NUMWORDS           (ROM_DEPTH),
	.LPM_FILE               ("RTL/mifs/end_message_lost.mif"),
	.LPM_TYPE               ("LPM_ROM"),
	.LPM_ADDRESS_CONTROL    ("REGISTERED"),
	.LPM_OUTDATA            ("UNREGISTERED"),
	.AUTO_CARRY_CHAINS      ("ON"),
	.AUTO_CASCADE_BUFFERS   ("ON"),
	.INTENDED_DEVICE_FAMILY ("Cyclone V")
) lost_rom_inst (
	.address (romAddress),
	.inclock (clk),
	.q       (lostRGB)
);

//------------- Output Logic -----------

always_comb begin

	message_DR = 1'b0;
	message_RGB = 8'h00;

	if (insidePanel && (messageState == MSG_WIN)) begin

		message_DR = 1'b1;
		message_RGB = winRGB;

	end

	else if (insidePanel && (messageState == MSG_LOST)) begin

		message_DR = 1'b1;
		message_RGB = lostRGB;

	end

end

endmodule