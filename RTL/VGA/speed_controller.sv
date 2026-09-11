module speed_controller (

//------------- Inputs -----------

	input logic clk,
	input logic resetN,

	input logic clear,               

	input logic redAppleHitPulse,
	input logic blueAppleHitPulse,
	input logic blackAppleHitPulse,

//------------- Outputs -----------

	output logic signed [10:0] moveSpeed

);

//------------- Speed Parameters -----------

localparam logic signed [10:0] INITIAL_SPEED = 11'd130;

//To avoid unwatned-behavior
localparam logic signed [10:0] MIN_SPEED     = 11'd80;
localparam logic signed [10:0] MAX_SPEED     = 11'd250;

//Define the <color>Apples effects on the speed 
localparam logic signed [10:0] RED_ACCEL     = 11'd3;
localparam logic signed [10:0] BLUE_DECEL    = 11'd5;
localparam logic signed [10:0] BLACK_ACCEL   = 11'd10;

//------------- Speed Logic -----------

always_ff @(posedge clk or negedge resetN)
begin
	//reset values
	if (!resetN) begin

		moveSpeed <= INITIAL_SPEED;

	end

	else begin

		//default initial speed
		if (clear) begin

			moveSpeed <= INITIAL_SPEED;

		end

		else if (blackAppleHitPulse) begin

			//Avoid going over the max-speed
			if (moveSpeed + BLACK_ACCEL >= MAX_SPEED)
				moveSpeed <= MAX_SPEED;
			else
				moveSpeed <= moveSpeed + BLACK_ACCEL;

		end

		else if (blueAppleHitPulse) begin

			//Avoid going below the min-speed
			if (moveSpeed <= MIN_SPEED + BLUE_DECEL)
				moveSpeed <= MIN_SPEED;
			else
				moveSpeed <= moveSpeed - BLUE_DECEL;

		end

		else if (redAppleHitPulse) begin

			//Avoid going over the max-speed
			if (moveSpeed + RED_ACCEL >= MAX_SPEED)
				moveSpeed <= MAX_SPEED;
			else
				moveSpeed <= moveSpeed + RED_ACCEL;

		end

	end
end

endmodule