module NumbersBitMap (

//------------- Inputs -----------

	input logic clk,
	input logic resetN,

//------------- Score Display Inputs -----------

	input logic [5:0] scoreOffsetX,
	input logic [5:0] scoreOffsetY,
	input logic scoreSquare_DR,

	input logic [3:0] scoreLow,
	input logic [3:0] scoreHigh,

//------------- High Score Display Inputs -----------

	input logic [5:0] highScoreOffsetX,
	input logic [5:0] highScoreOffsetY,
	input logic highScoreSquare_DR,

	input logic [3:0] highScoreLow,
	input logic [3:0] highScoreHigh,

//------------- Outputs -----------

	output logic score_DR,
	output logic [7:0] score_RGB,

	output logic highScore_DR,
	output logic [7:0] highScore_RGB

);

//------------- Digit Bitmap Parameters -----------

localparam int DIGIT_WIDTH  = 16;
localparam int DIGIT_HEIGHT = 32;

localparam int DIGIT_PIXELS = DIGIT_WIDTH * DIGIT_HEIGHT; // 512

//We stretch the digits to get larger displayed numbers
localparam int DISPLAYED_DIGIT_WIDTH  = 32;
localparam int DISPLAYED_DIGIT_HEIGHT = 64;

//------------- Color Parameters -----------

//To add a sense of levels, we change the color of the score digits after reaching 10
parameter logic [7:0] SCORE_COLOR_LOW  = 8'hFF; // white, score <= 10
parameter logic [7:0] SCORE_COLOR_HIGH = 8'hFC; // gold/yellow, score > 10
parameter logic [7:0] HIGH_SCORE_COLOR = 8'hE0; // red

//------------- Internal Signals -----------

logic [12:0] address;
logic color;

//The selected digit to display
logic [3:0] selectedDigit;

logic [5:0] selectedOffsetY;

//we count the offestX from the topleft of the said digit
//, not the topleft of the sqaureobject
logic [4:0] digitOffsetX;

logic selectedScore;
logic selectedHighScore;

logic scoreLessOrEqualTen;

//------------- Score Color Condition -----------

//Check if the 10 was passed to change the color
assign scoreLessOrEqualTen =
	(scoreHigh == 4'd0) ||
	((scoreHigh == 4'd1) && (scoreLow == 4'd0));

//------------- Select Active Display -----------

always_comb begin

	//default values
	selectedDigit = 4'd0;

	selectedOffsetY = 6'd0;
	digitOffsetX    = 5'd0;

	selectedScore     = 1'b0;
	selectedHighScore = 1'b0;

	//were drawing the score
	if (scoreSquare_DR) begin

		selectedScore = 1'b1;

		selectedOffsetY = scoreOffsetY;

		//The if condition tells this is the high digit
		if (scoreOffsetX < DISPLAYED_DIGIT_WIDTH) begin
			selectedDigit = scoreHigh;
			digitOffsetX  = scoreOffsetX[4:0];
		end

		//If its the low digit, we want to have a shifted offset
		else begin
			selectedDigit = scoreLow;
			digitOffsetX  = scoreOffsetX - DISPLAYED_DIGIT_WIDTH;
		end

	end

	//Same logic for the highscore
	else if (highScoreSquare_DR) begin

		selectedHighScore = 1'b1;

		selectedOffsetY = highScoreOffsetY;

		if (highScoreOffsetX < DISPLAYED_DIGIT_WIDTH) begin
			selectedDigit = highScoreHigh;
			digitOffsetX  = highScoreOffsetX[4:0];
		end

		else begin
			selectedDigit = highScoreLow;
			digitOffsetX  = highScoreOffsetX - DISPLAYED_DIGIT_WIDTH;
		end

	end

end

//------------- Address Calculation -----------

//selecteddigit, tells which digit image to use
//We selectedDigit * DIGIT_PIXELS because the 
//digits in the MIF are saved one afoter another
//We use /2 to achieve the stretching eefect,
//such that every two pixels take the same pixel in the MIF
assign address =
	(selectedDigit * DIGIT_PIXELS) +
	((selectedOffsetY / 2) * DIGIT_WIDTH) +
	(digitOffsetX / 2);

//------------- Numbers Bitmap ROM -----------

lpm_rom #(
	.LPM_WIDTH              (1),
	.LPM_WIDTHAD            (13),
	.LPM_NUMWORDS           (8192),
	.LPM_FILE               ("RTL/mifs/numbers_new_font.mif"),
	.LPM_TYPE               ("LPM_ROM"),
	.LPM_ADDRESS_CONTROL    ("REGISTERED"),
	.LPM_OUTDATA            ("UNREGISTERED"),
	.AUTO_CARRY_CHAINS      ("ON"),
	.AUTO_CASCADE_BUFFERS   ("ON"),
	.INTENDED_DEVICE_FAMILY ("Cyclone V")
) rom_inst (
	.address (address),
	.inclock (clk),
	.q       (color)
);

//------------- Drawing Logic -----------

always_comb begin

	score_DR = 1'b0;
	highScore_DR = 1'b0;

	if (color == 1'b1) begin

		if (selectedScore) begin
			score_DR = 1'b1;
		end

		else if (selectedHighScore) begin
			highScore_DR = 1'b1;
		end

	end

end

//------------- RGB Output -----------

assign score_RGB =
	(scoreLessOrEqualTen) ? SCORE_COLOR_LOW : SCORE_COLOR_HIGH;

assign highScore_RGB =
	HIGH_SCORE_COLOR;

endmodule