module sound_effect_controller (

//------------- Inputs -----------

	input logic clk,
	input logic resetN,

	input logic gameStartPulse,
	input logic gameOverPulse,
	input logic gameWonPulse,	
	
	input logic redAppleHitPulse,
	input logic blueAppleHitPulse,
	input logic blackAppleHitPulse,
	input logic keyIsValid,

//------------- Outputs -----------

	output logic startMelody,			// Enable
	output logic [3:0] melodySelect	// Selector

);

//------------- Sound Select Values -----------

// songs.mif mapping:
// 0 = win sound
// 1 = game over sound
// 2 = blue apple sound
// 3 = black apple / bad apple sound
// 4 = movement / restart sound
// 5 = red apple hit sound

localparam logic [3:0] WIN_SOUND         = 4'd0;
localparam logic [3:0] GAME_OVER_SOUND   = 4'd1;
localparam logic [3:0] BLUE_APPLE_SOUND  = 4'd2;
localparam logic [3:0] BLACK_APPLE_SOUND = 4'd3;
localparam logic [3:0] MOVE_SOUND        = 4'd4;
localparam logic [3:0] RESTART_SOUND     = 4'd4;
localparam logic [3:0] RED_APPLE_SOUND   = 4'd5;

//------------- Sound Trigger Logic -----------

always_ff @(posedge clk or negedge resetN)
begin
	if (!resetN) begin		//reset values

		startMelody <= 1'b0;	
		melodySelect <= RESTART_SOUND;

	end

	else begin

		startMelody <= 1'b0; 	//default

		if (gameWonPulse) begin

			melodySelect <= WIN_SOUND;
			startMelody <= 1'b1;

		end

		else if (gameOverPulse) begin

			melodySelect <= GAME_OVER_SOUND;
			startMelody <= 1'b1;

		end

		else if (blackAppleHitPulse) begin

			melodySelect <= BLACK_APPLE_SOUND;
			startMelody <= 1'b1;

		end

		else if (blueAppleHitPulse) begin

			melodySelect <= BLUE_APPLE_SOUND;
			startMelody <= 1'b1;

		end

		else if (redAppleHitPulse) begin

			melodySelect <= RED_APPLE_SOUND;
			startMelody <= 1'b1;

		end

		else if (gameStartPulse) begin

			melodySelect <= RESTART_SOUND;
			startMelody <= 1'b1;

		end

		else if (keyIsValid) begin

			melodySelect <= MOVE_SOUND;
			startMelody <= 1'b1;

		end

	end
end

endmodule