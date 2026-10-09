module snake_head (

//------------- Inputs -----------

	input logic clk,
	input logic resetN,
	input logic startOfFrame,

	input logic key_8,
	input logic key_6,
	input logic key_4,
	input logic key_2,

	input logic gameStarted,

	input logic signed [10:0] moveSpeed,

//------------- Outputs -----------

	output logic signed [10:0] topLeftX,
	output logic signed [10:0] topLeftY,

	output logic [2:0] snakeHeadDir

);

//------------- Parameters -----------

parameter int INITIAL_X  = 384;
parameter int INITIAL_Y  = 240;

 //To improve smoothness using scaling
localparam int FIXED_POINT_MULTIPLIER = 64;

//normal and improved tile size, we descale at the end
localparam int TILE_SIZE = 24;	
localparam int TILE_SIZE_FIXED = TILE_SIZE * FIXED_POINT_MULTIPLIER;

//------------- FSM States -----------

//We update the position of the head at the SOF to avoid glitch-like behavior
enum logic [1:0] {
	IDLE_ST,
	MOVE_ST,
	POSITION_CHANGE_ST
} SM_Motion;

//------------- Direction Values -----------

//Define params for readablity and clearity
localparam logic [2:0] DIR_NONE  = 3'd0;
localparam logic [2:0] DIR_UP    = 3'd1;
localparam logic [2:0] DIR_RIGHT = 3'd2;
localparam logic [2:0] DIR_LEFT  = 3'd3;
localparam logic [2:0] DIR_DOWN  = 3'd4;

//------------- Motion -----------

int Xspeed;
int Yspeed;

int Xposition;
int Yposition;

//To achieve fixed movement onto the tiles
int targetX;
int targetY;

//To time the fixed movement on the tiles
//currentDir = current dire
//requestedDir = the raw input by the user
//pendingDir = is the direction we want to move 
//at the targetXY after the validation of the raw input
logic [2:0] currentDir;
logic [2:0] requestedDir;
logic [2:0] pendingDir;

//------------- Requested Direction From Keys -----------

always_comb begin

	requestedDir = DIR_NONE;

	if (key_8)
		requestedDir = DIR_UP;

	else if (key_6)
		requestedDir = DIR_RIGHT;

	else if (key_4)
		requestedDir = DIR_LEFT;

	else if (key_2)
		requestedDir = DIR_DOWN;

end

//------------- Motion FSM -----------

always_ff @(posedge clk or negedge resetN)
begin
	//reset values
	if (!resetN) begin

		SM_Motion <= IDLE_ST;

		Xspeed <= 0;
		Yspeed <= 0;

		Xposition <= INITIAL_X * FIXED_POINT_MULTIPLIER;
		Yposition <= INITIAL_Y * FIXED_POINT_MULTIPLIER;

		targetX <= INITIAL_X * FIXED_POINT_MULTIPLIER;
		targetY <= INITIAL_Y * FIXED_POINT_MULTIPLIER;

		currentDir <= DIR_NONE;
		pendingDir <= DIR_NONE;

	end

	else begin

		//------------- Game Not Started -------------

		//Default of the idle state
		if (!gameStarted) begin

			SM_Motion <= IDLE_ST;

			Xspeed <= 0;
			Yspeed <= 0;

			Xposition <= INITIAL_X * FIXED_POINT_MULTIPLIER;
			Yposition <= INITIAL_Y * FIXED_POINT_MULTIPLIER;

			targetX <= INITIAL_X * FIXED_POINT_MULTIPLIER;
			targetY <= INITIAL_Y * FIXED_POINT_MULTIPLIER;

			currentDir <= DIR_NONE;
			pendingDir <= DIR_NONE;

		end

		//------------- Game Running -------------

		else begin

			case (SM_Motion)

				//------------- IDLE State -------------

				IDLE_ST: begin

					Xspeed <= 0;
					Yspeed <= 0;

					Xposition <= INITIAL_X * FIXED_POINT_MULTIPLIER;
					Yposition <= INITIAL_Y * FIXED_POINT_MULTIPLIER;

					targetX <= INITIAL_X * FIXED_POINT_MULTIPLIER;
					targetY <= INITIAL_Y * FIXED_POINT_MULTIPLIER;

					currentDir <= DIR_NONE;
					pendingDir <= DIR_NONE;

					
					if (startOfFrame)
						SM_Motion <= MOVE_ST;

				end

				//------------- MOVE State -------------

				//Update the movement direction
				MOVE_ST: begin

					//valid input
					if (requestedDir != DIR_NONE) begin 

						//The validation step: check if the requested is opposite the current
						if ((currentDir == DIR_NONE) ||
							!((currentDir == DIR_UP    && requestedDir == DIR_DOWN) ||
							  (currentDir == DIR_DOWN  && requestedDir == DIR_UP)   ||
							  (currentDir == DIR_RIGHT && requestedDir == DIR_LEFT)  ||
							  (currentDir == DIR_LEFT  && requestedDir == DIR_RIGHT))) begin

							//Validations passed -> update the pending 
							pendingDir <= requestedDir;

						end

					end

					//Positionb updates are done at the SOF to avoid unwanted-behavior
					if (startOfFrame)
						SM_Motion <= POSITION_CHANGE_ST;

				end

				//------------- Position Change State -------------

				POSITION_CHANGE_ST: begin

					//The head was Idle
					if (currentDir == DIR_NONE) begin

						//and has valid input
						if (pendingDir != DIR_NONE) begin

							//update the direction
							currentDir <= pendingDir;

							case (pendingDir)

								DIR_UP: begin
									Xspeed <= 0;
									Yspeed <= -moveSpeed;

									targetX <= Xposition;
									targetY <= Yposition - TILE_SIZE_FIXED;
								end

								DIR_RIGHT: begin
									Xspeed <= moveSpeed;
									Yspeed <= 0;

									targetX <= Xposition + TILE_SIZE_FIXED;
									targetY <= Yposition;
								end

								DIR_LEFT: begin
									Xspeed <= -moveSpeed;
									Yspeed <= 0;

									targetX <= Xposition - TILE_SIZE_FIXED;
									targetY <= Yposition;
								end

								DIR_DOWN: begin
									Xspeed <= 0;
									Yspeed <= moveSpeed;

									targetX <= Xposition;
									targetY <= Yposition + TILE_SIZE_FIXED;
								end

								default: begin
									Xspeed <= 0;
									Yspeed <= 0;
								end

							endcase

						end

					end

					else begin

						//The head was moving right
						if (Xspeed > 0) begin

							//Reached the target tile
							if (Xposition + Xspeed >= targetX) begin
							
								//Update the position to 
								//the topleft of the tile
								//to achieve tile-fixed movement
								Xposition <= targetX;
								Yposition <= targetY;
								
								//Change the dir after reaching the target tile
								currentDir <= pendingDir;

								//UIpdate the Dir
								case (pendingDir)

									DIR_UP: begin
										Xspeed <= 0;
										Yspeed <= -moveSpeed;

										targetX <= targetX;
										targetY <= targetY - TILE_SIZE_FIXED;
									end

									DIR_RIGHT: begin
										Xspeed <= moveSpeed;
										Yspeed <= 0;

										targetX <= targetX + TILE_SIZE_FIXED;
										targetY <= targetY;
									end

									DIR_LEFT: begin
										Xspeed <= -moveSpeed;
										Yspeed <= 0;

										targetX <= targetX - TILE_SIZE_FIXED;
										targetY <= targetY;
									end

									DIR_DOWN: begin
										Xspeed <= 0;
										Yspeed <= moveSpeed;

										targetX <= targetX;
										targetY <= targetY + TILE_SIZE_FIXED;
									end

									default: begin
										Xspeed <= 0;
										Yspeed <= 0;

										currentDir <= DIR_NONE;
										pendingDir <= DIR_NONE;
									end

								endcase

							end

							else begin

								Xposition <= Xposition + Xspeed;

							end

						end

						// The head was moving left
						// Same behavior as before
						else if (Xspeed < 0) begin

							if (Xposition + Xspeed <= targetX) begin

								Xposition <= targetX;
								Yposition <= targetY;

								currentDir <= pendingDir;

								case (pendingDir)

									DIR_UP: begin
										Xspeed <= 0;
										Yspeed <= -moveSpeed;

										targetX <= targetX;
										targetY <= targetY - TILE_SIZE_FIXED;
									end

									DIR_RIGHT: begin
										Xspeed <= moveSpeed;
										Yspeed <= 0;

										targetX <= targetX + TILE_SIZE_FIXED;
										targetY <= targetY;
									end

									DIR_LEFT: begin
										Xspeed <= -moveSpeed;
										Yspeed <= 0;

										targetX <= targetX - TILE_SIZE_FIXED;
										targetY <= targetY;
									end

									DIR_DOWN: begin
										Xspeed <= 0;
										Yspeed <= moveSpeed;

										targetX <= targetX;
										targetY <= targetY + TILE_SIZE_FIXED;
									end

									default: begin
										Xspeed <= 0;
										Yspeed <= 0;

										currentDir <= DIR_NONE;
										pendingDir <= DIR_NONE;
									end

								endcase

							end

							else begin

								Xposition <= Xposition + Xspeed;

							end

						end

						// The head was moving down
						// Same behavior as before
						else if (Yspeed > 0) begin

							if (Yposition + Yspeed >= targetY) begin

								Xposition <= targetX;
								Yposition <= targetY;

								currentDir <= pendingDir;

								case (pendingDir)

									DIR_UP: begin
										Xspeed <= 0;
										Yspeed <= -moveSpeed;

										targetX <= targetX;
										targetY <= targetY - TILE_SIZE_FIXED;
									end

									DIR_RIGHT: begin
										Xspeed <= moveSpeed;
										Yspeed <= 0;

										targetX <= targetX + TILE_SIZE_FIXED;
										targetY <= targetY;
									end

									DIR_LEFT: begin
										Xspeed <= -moveSpeed;
										Yspeed <= 0;

										targetX <= targetX - TILE_SIZE_FIXED;
										targetY <= targetY;
									end

									DIR_DOWN: begin
										Xspeed <= 0;
										Yspeed <= moveSpeed;

										targetX <= targetX;
										targetY <= targetY + TILE_SIZE_FIXED;
									end

									default: begin
										Xspeed <= 0;
										Yspeed <= 0;

										currentDir <= DIR_NONE;
										pendingDir <= DIR_NONE;
									end

								endcase

							end

							else begin

								Yposition <= Yposition + Yspeed;

							end

						end

						// The head was moving up
						// Same behavior as before
						else if (Yspeed < 0) begin

							if (Yposition + Yspeed <= targetY) begin

								Xposition <= targetX;
								Yposition <= targetY;

								currentDir <= pendingDir;

								case (pendingDir)

									DIR_UP: begin
										Xspeed <= 0;
										Yspeed <= -moveSpeed;

										targetX <= targetX;
										targetY <= targetY - TILE_SIZE_FIXED;
									end

									DIR_RIGHT: begin
										Xspeed <= moveSpeed;
										Yspeed <= 0;

										targetX <= targetX + TILE_SIZE_FIXED;
										targetY <= targetY;
									end

									DIR_LEFT: begin
										Xspeed <= -moveSpeed;
										Yspeed <= 0;

										targetX <= targetX - TILE_SIZE_FIXED;
										targetY <= targetY;
									end

									DIR_DOWN: begin
										Xspeed <= 0;
										Yspeed <= moveSpeed;

										targetX <= targetX;
										targetY <= targetY + TILE_SIZE_FIXED;
									end

									default: begin
										Xspeed <= 0;
										Yspeed <= 0;

										currentDir <= DIR_NONE;
										pendingDir <= DIR_NONE;
									end

								endcase

							end

							else begin

								Yposition <= Yposition + Yspeed;

							end

						end

					end

					SM_Motion <= MOVE_ST;

				end

				//------------- Default State -------------

				default: begin

					SM_Motion <= IDLE_ST;

					Xspeed <= 0;
					Yspeed <= 0;

					Xposition <= INITIAL_X * FIXED_POINT_MULTIPLIER;
					Yposition <= INITIAL_Y * FIXED_POINT_MULTIPLIER;

					targetX <= INITIAL_X * FIXED_POINT_MULTIPLIER;
					targetY <= INITIAL_Y * FIXED_POINT_MULTIPLIER;

					currentDir <= DIR_NONE;
					pendingDir <= DIR_NONE;

				end

			endcase

		end

	end
end

//------------- Fixed Point To Pixel Position -----------

//Descaling the improved tile
assign topLeftX = Xposition / FIXED_POINT_MULTIPLIER;
assign topLeftY = Yposition / FIXED_POINT_MULTIPLIER;

//Send a direction for the headBitMap to rotate the MIF accordingly
assign snakeHeadDir =
	(currentDir == DIR_NONE) ? DIR_UP : currentDir;

endmodule
