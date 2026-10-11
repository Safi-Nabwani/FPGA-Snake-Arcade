module ScoreConstants (

//------------- Outputs -----------

	output logic signed [10:0] scoreTopLeftX,
	output logic signed [10:0] scoreTopLeftY,

	output logic signed [10:0] highScoreTopLeftX,
	output logic signed [10:0] highScoreTopLeftY

);

//------------- Score Number Positions -----------

`include "RTL/VGA/jungle_hud_layout.svh"

//------------- Output Assignments -----------

assign scoreTopLeftX     = SCORE_X;
assign scoreTopLeftY     = SCORE_Y;

assign highScoreTopLeftX = HIGH_SCORE_X;
assign highScoreTopLeftY = HIGH_SCORE_Y;

endmodule

//Helper module to pass the wanted topLeftXY to the squareObjects
