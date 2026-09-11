module appleCounter (

//------------- Inputs -----------

	input logic clk,
	input logic resetN,

	input logic gameStartPulse,

	input logic redAppleHitPulse,     // +1
	input logic blueAppleHitPulse,    // +3
	input logic blackAppleHitPulse,   // -5

//------------- Outputs -----------

	output logic [3:0] scoreLow,
	output logic [3:0] scoreHigh

);

//------------- Score Logic -----------

always_ff @(posedge clk or negedge resetN)
begin
	//reset values
	if (!resetN) begin

		scoreLow  <= 4'd0;
		scoreHigh <= 4'd0;

	end

	else begin
		
		//clear the score at the start of a new game
		if (gameStartPulse) begin

			scoreLow  <= 4'd0;
			scoreHigh <= 4'd0;

		end

		// Blue apple = +3
		else if (blueAppleHitPulse) begin
			
			if (scoreLow >= 4'd7) begin
				scoreLow  <= scoreLow + 4'd3 - 4'd10;
				scoreHigh <= scoreHigh + 4'd1;
			end

			else begin
				scoreLow <= scoreLow + 4'd3;
			end

		end

		// Red apple = +1
		else if (redAppleHitPulse) begin

			if (scoreLow == 4'd9) begin
				scoreLow  <= 4'd0;
				scoreHigh <= scoreHigh + 4'd1;
			end

			else begin
				scoreLow <= scoreLow + 4'd1;
			end

		end

		// Black apple = -5
		else if (blackAppleHitPulse) begin

			//Dont get negative values, this is also a losing condition
			if (scoreHigh == 4'd0 && scoreLow <= 4'd5) begin
				scoreLow  <= 4'd0;
				scoreHigh <= 4'd0;
			end

			else if (scoreLow >= 4'd5) begin
				scoreLow <= scoreLow - 4'd5;
			end

			else begin
				scoreLow  <= scoreLow + 4'd5;
				scoreHigh <= scoreHigh - 4'd1;
			end

		end

	end
end

endmodule