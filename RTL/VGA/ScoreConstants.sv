module ScoreConstants (

//------------- Outputs -----------

	output logic signed [10:0] scoreTopLeftX,
	output logic signed [10:0] scoreTopLeftY,

	output logic signed [10:0] highScoreTopLeftX,
	output logic signed [10:0] highScoreTopLeftY

);

//------------- Score Number Positions -----------

localparam int SCORE_X      = 48;
localparam int SCORE_Y      = 64;

localparam int HIGH_SCORE_X = 48;
localparam int HIGH_SCORE_Y = 148;

//------------- Output Assignments -----------

assign scoreTopLeftX     = SCORE_X;
assign scoreTopLeftY     = SCORE_Y;

assign highScoreTopLeftX = HIGH_SCORE_X;
assign highScoreTopLeftY = HIGH_SCORE_Y;

endmodule

//Helper module to pass the wanted topLeftXY to the squareObjects
