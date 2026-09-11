module snake_body (

//------------- Inputs -----------

	input logic clk,
	input logic resetN,

	input logic clear,                
	input logic gameStarted,
	input logic startOfFrame,

	input logic [10:0] pixelX,
	input logic [10:0] pixelY,

	input logic signed [10:0] headX,
	input logic signed [10:0] headY,

	input logic redAppleHitPulse,
	input logic blueAppleHitPulse,
	input logic blackAppleHitPulse,

//------------- Outputs -----------

	output logic snakeBody_DR,
	output logic [7:0] snakeBody_RGB,

	output logic [5:0] snakeLength,
	output logic snakeSelfCollision

);

//------------- Parameters -----------

parameter int INITIAL_X = 320;
parameter int INITIAL_Y = 280;

//The MIF is 24x24
parameter int BODY_SIZE = 24;

//Segments = body nodes
parameter int MAX_SEGMENTS = 32;
parameter int INITIAL_LENGTH = 4;

//in pixels between every two segments
parameter int SEGMENT_SPACING = 6;

//We save the movement of the Head by saving a trail of head positionXY
//Later we want to use indices starting from zero up to 192 -> overall 193, so we add the plus one
localparam int MAX_TRAIL = (MAX_SEGMENTS * SEGMENT_SPACING) + 1;

localparam logic [7:0] TRANSPARENT_ENCODING = 8'hFF;

//The Apple-Length adjustments
localparam logic [5:0] RED_GROW_VALUE    = 6'd1;
localparam logic [5:0] BLUE_SHRINK_VALUE = 6'd3;
localparam logic [5:0] BLACK_GROW_VALUE  = 6'd5;

//To have a valid self-collision logic and avoid fake collisions
//We minimize the body hitbox by 6, and avoid checking 
// the first 4 segments, since they overlap the head
//4 segments with 6 for spacing -> 6*4=24
localparam int SELF_COLLISION_START_SEGMENT = 4;
localparam int SELF_COLLISION_MARGIN = 6;

//------------- Trail Memory -----------

logic [10:0] trailX [0:MAX_TRAIL-1];
logic [10:0] trailY [0:MAX_TRAIL-1];

//------------- MIF ROM Signals -----------

logic insideBody;

logic [9:0] address;
logic [7:0] color;

//------------- Self Collision Signals -----------

logic selfCollisionHit;

//------------- Body MIF ROM -----------

lpm_rom #(
	.LPM_WIDTH              (8),
	.LPM_WIDTHAD            (10),
	.LPM_NUMWORDS           (576),
	.LPM_FILE               ("RTL/mifs/snake_body_24.mif"),
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

//------------- Trail / Length Logic -----------

always_ff @(posedge clk or negedge resetN)
begin
	//reset values
	if (!resetN) begin

		snakeLength <= INITIAL_LENGTH;

		for (int i = 0; i < MAX_TRAIL; i++) begin
			trailX[i] <= INITIAL_X;
			trailY[i] <= INITIAL_Y;
		end

	end

	else begin
		
		//The of the game
		if (clear) begin

			snakeLength <= INITIAL_LENGTH;

			for (int i = 0; i < MAX_TRAIL; i++) begin
				trailX[i] <= headX[10:0];
				trailY[i] <= headY[10:0];
			end

		end

		else begin

			//------------- Length Changes -------------

			if (blackAppleHitPulse) begin

				//To avoid passing the max
				if (snakeLength + BLACK_GROW_VALUE >= MAX_SEGMENTS)
					snakeLength <= MAX_SEGMENTS;
				else
					snakeLength <= snakeLength + BLACK_GROW_VALUE;

			end

			else if (blueAppleHitPulse) begin
			
				//Must always have at least one
				if (snakeLength <= BLUE_SHRINK_VALUE)
					snakeLength <= 6'd1;
				else
					snakeLength <= snakeLength - BLUE_SHRINK_VALUE;

			end

			else if (redAppleHitPulse) begin

				//To avoid passing the max
				if (snakeLength + RED_GROW_VALUE >= MAX_SEGMENTS)
					snakeLength <= MAX_SEGMENTS;
				else
					snakeLength <= snakeLength + RED_GROW_VALUE;

			end

			//------------- Trail Update -------------

			if (gameStarted && startOfFrame) begin
	
				//Save the latest
				trailX[0] <= headX[10:0];
				trailY[0] <= headY[10:0];
				
				//Shift the rest
				for (int i = 1; i < MAX_TRAIL; i++) begin
					trailX[i] <= trailX[i-1];
					trailY[i] <= trailY[i-1];
				end

			end

		end

	end
end

//------------- Body Area / ROM Address Logic -----------

always_comb begin

	insideBody = 1'b0;
	address = 10'd0;

	for (int segmentIndex = 0; segmentIndex < MAX_SEGMENTS; segmentIndex++) begin

		int trailIndex;
		
		// We skip the spacing indices in the trail t achieve visible movement 
		trailIndex = (segmentIndex + 1) * SEGMENT_SPACING;
		
		//if insideBody = 1, then we already scanned the body segment for this pixel
		//To avoid the overlapping of segments
		if (!insideBody && (segmentIndex < snakeLength)) begin

			//InsideSqure kind of check
			if (
				(pixelX >= trailX[trailIndex]) &&
				(pixelX <  trailX[trailIndex] + BODY_SIZE) &&
				(pixelY >= trailY[trailIndex]) &&
				(pixelY <  trailY[trailIndex] + BODY_SIZE)
			) begin

				insideBody = 1'b1;

				address =
					((pixelY - trailY[trailIndex]) * BODY_SIZE) +
					(pixelX - trailX[trailIndex]);

			end

		end

	end

end

//------------- Self Collision Logic -----------

always_comb begin

	//deafult
	selfCollisionHit = 1'b0;

	//Start the scanning from SELF_COLLISION_START_SEGMENT to avoid the fake collisions
	for (int segmentIndex = SELF_COLLISION_START_SEGMENT; segmentIndex < MAX_SEGMENTS; segmentIndex++) begin

		int trailIndex;

		//Minimize the hitbox using SELF_COLLISION_MARGIN to avoid fake collsion
		int headLeft;
		int headRight;
		int headTop;
		int headBottom;

		int bodyLeft;
		int bodyRight;
		int bodyTop;
		int bodyBottom;

		trailIndex = (segmentIndex + 1) * SEGMENT_SPACING;

		if (segmentIndex < snakeLength) begin

			//The minimized hitbox computation
			headLeft   = headX + SELF_COLLISION_MARGIN;
			headRight  = headX + BODY_SIZE - SELF_COLLISION_MARGIN;
			headTop    = headY + SELF_COLLISION_MARGIN;
			headBottom = headY + BODY_SIZE - SELF_COLLISION_MARGIN;

			bodyLeft   = trailX[trailIndex] + SELF_COLLISION_MARGIN;
			bodyRight  = trailX[trailIndex] + BODY_SIZE - SELF_COLLISION_MARGIN;
			bodyTop    = trailY[trailIndex] + SELF_COLLISION_MARGIN;
			bodyBottom = trailY[trailIndex] + BODY_SIZE - SELF_COLLISION_MARGIN;

			//Self collision check
			if (
				(headLeft   < bodyRight)  &&
				(headRight  > bodyLeft)   &&
				(headTop    < bodyBottom) &&
				(headBottom > bodyTop)
			) begin

				selfCollisionHit = 1'b1;

			end

		end

	end

end

//------------- Outputs -----------

assign snakeBody_DR =
	gameStarted &&
	insideBody &&
	(color != TRANSPARENT_ENCODING);

assign snakeBody_RGB = color;

assign snakeSelfCollision =
	gameStarted &&
	selfCollisionHit;

endmodule