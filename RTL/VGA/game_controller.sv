module game_controller (

//--------------------- Inputs ---------------------

	input logic clk,
	input logic resetN,
	input logic startOfFrame,

	input logic snakeHead_DR,
	input logic snakeSelfCollision,

	input logic border_DR,
	input logic obstacle_DR,

	input logic redApple_DR,
	input logic blueApple_DR,
	input logic blackApple_DR,

	input logic [3:0] score_Low,
	input logic [3:0] score_High,

//--------------------- Keys ---------------------

	input logic key_5,

//--------------------- Game State and Pulses ---------------------

	output logic gameStarted,
	output logic gameStartPulse,
	output logic gameEndPulse,
	output logic gameOverPulse,
	output logic gameWonPulse,

	output logic redAppleHitPulse,
	output logic blueAppleHitPulse,
	output logic blackAppleHitPulse

);

//--------------------- Internal Signals ---------------------

logic appleHitFlag;	// We dont want to send a pulse more than once in the same frame

logic collision;		// The losing condition

logic collision_SnakeHead_RedApple;		//
logic collision_SnakeHead_BlueApple;	//  <color>AppleHitPulses
logic collision_SnakeHead_BlackApple;	//

//--------------------- Collision Logic ---------------------

assign collision =
	(snakeHead_DR && (border_DR || obstacle_DR)) ||
	snakeSelfCollision;

assign collision_SnakeHead_RedApple =
	snakeHead_DR &&
	redApple_DR;

assign collision_SnakeHead_BlueApple =
	snakeHead_DR &&
	blueApple_DR;

assign collision_SnakeHead_BlackApple =
	snakeHead_DR &&
	blackApple_DR;

//--------------------- Game FSM ---------------------

enum logic [1:0] {
	s_idle,
	s_gameStarted,
	s_gameWon,
	s_gameLost
} SMGame;

//--------------------- FSM Logic ---------------------

always_ff @(posedge clk or negedge resetN)
begin
	if (!resetN) begin	//reset values

		SMGame <= s_idle;

		appleHitFlag <= 1'b0;

		gameStarted <= 1'b0;
		gameStartPulse <= 1'b0;
		gameEndPulse <= 1'b0;
		gameOverPulse <= 1'b0;
		gameWonPulse <= 1'b0;

		redAppleHitPulse <= 1'b0;
		blueAppleHitPulse <= 1'b0;
		blackAppleHitPulse <= 1'b0;

	end

	else begin

		// Default pulse values
		gameStartPulse <= 1'b0;
		gameEndPulse <= 1'b0;
		gameOverPulse <= 1'b0;
		gameWonPulse <= 1'b0;

		redAppleHitPulse <= 1'b0;
		blueAppleHitPulse <= 1'b0;
		blackAppleHitPulse <= 1'b0;

		// Clear apple hit flag once every frame
		if (startOfFrame) begin
			appleHitFlag <= 1'b0;
		end

		case (SMGame)

//--------------------- Idle State ---------------------

			s_idle: begin

				gameStarted <= 1'b0;
				appleHitFlag <= 1'b0;

				if (key_5) begin

					SMGame <= s_gameStarted;

					gameStarted <= 1'b1;
					gameStartPulse <= 1'b1;

				end

			end

//--------------------- Game Started State ---------------------

			s_gameStarted: begin

				gameStarted <= 1'b1;

				// Winning condition: score >= 20
				if (score_High >= 4'd2) begin

					SMGame <= s_gameWon;

					gameStarted <= 1'b0;
					gameWonPulse <= 1'b1;
					gameEndPulse <= 1'b1;

				end

				// Losing condition
				else if (collision) begin

					SMGame <= s_gameLost;

					gameStarted <= 1'b0;
					gameOverPulse <= 1'b1;
					gameEndPulse <= 1'b1;

				end

				// Black apple collision
				else if (collision_SnakeHead_BlackApple && !appleHitFlag) begin

					appleHitFlag <= 1'b1;
					blackAppleHitPulse <= 1'b1;

					// If score <= 5, black apple causes game over
					if ((score_High == 4'd0) && (score_Low <= 4'd5)) begin

						SMGame <= s_gameLost;

						gameStarted <= 1'b0;
						gameOverPulse <= 1'b1;
						gameEndPulse <= 1'b1;

					end

				end

				// Blue apple collision
				else if (collision_SnakeHead_BlueApple && !appleHitFlag) begin

					appleHitFlag <= 1'b1;
					blueAppleHitPulse <= 1'b1;

				end

				// Red apple collision
				else if (collision_SnakeHead_RedApple && !appleHitFlag) begin

					appleHitFlag <= 1'b1;
					redAppleHitPulse <= 1'b1;

				end

			end

//--------------------- Game Won State ---------------------

			s_gameWon: begin

				gameStarted <= 1'b0;
				appleHitFlag <= 1'b0;

				if (key_5) begin

					SMGame <= s_gameStarted;

					gameStarted <= 1'b1;
					gameStartPulse <= 1'b1;

				end

			end

//--------------------- Game Lost State ---------------------

			s_gameLost: begin

				gameStarted <= 1'b0;
				appleHitFlag <= 1'b0;

				if (key_5) begin

					SMGame <= s_gameStarted;

					gameStarted <= 1'b1;
					gameStartPulse <= 1'b1;

				end

			end

//--------------------- Default State ---------------------

			default: begin

				SMGame <= s_idle;

				gameStarted <= 1'b0;
				appleHitFlag <= 1'b0;

			end

		endcase

	end
end

endmodule