module highscoreComp (

//------------- Inputs -----------

	input logic clk,
	input logic resetN,

	input logic gameEndPulse,

	input logic [3:0] scoreLow,
	input logic [3:0] scoreHigh,

//------------- Outputs -----------

	output logic [3:0] highscoreLow,
	output logic [3:0] highscoreHigh

);

//------------- Compare Logic -----------

logic scoreIsHigher;

assign scoreIsHigher =
	(scoreHigh > highscoreHigh) ||
	((scoreHigh == highscoreHigh) && (scoreLow > highscoreLow));

//------------- High Score Register -----------

always_ff @(posedge clk or negedge resetN)
begin
	//reset values
	if (!resetN) begin

		highscoreLow  <= 4'd0;
		highscoreHigh <= 4'd0;

	end

	else begin
	
		//The conditions to update the highscore
		if (gameEndPulse && scoreIsHigher) begin

			highscoreLow  <= scoreLow;
			highscoreHigh <= scoreHigh;

		end

	end
end

endmodule