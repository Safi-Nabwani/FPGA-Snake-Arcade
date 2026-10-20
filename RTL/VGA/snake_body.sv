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

parameter int INITIAL_X = 384;
parameter int INITIAL_Y = 240;

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
logic [12:0] atlasAddress;
logic [8:0] spriteWord;
logic [3:0] spriteIndex;
logic [5:0] selectedSegment;
logic [10:0] selectedCurrentX, selectedCurrentY;
logic [10:0] selectedTowardHeadX, selectedTowardHeadY;
logic [10:0] selectedTowardTailX, selectedTowardTailY;

//------------- Self Collision Signals -----------

logic selfCollisionHit;

//------------- Emerald Body MIF ROM -----------

lpm_rom #(
	.LPM_WIDTH(9), .LPM_WIDTHAD(13), .LPM_NUMWORDS(8064),
	.LPM_FILE("RTL/mifs/snake_variants/01_emerald_rgba9.mif"), .LPM_TYPE("LPM_ROM"),
	.LPM_ADDRESS_CONTROL("REGISTERED"), .LPM_OUTDATA("UNREGISTERED"),
	.AUTO_CARRY_CHAINS("ON"), .AUTO_CASCADE_BUFFERS("ON"),
	.INTENDED_DEVICE_FAMILY("Cyclone V")
) rom_inst (
	.address(atlasAddress), .inclock(clk), .q(spriteWord)
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

//------------- Visual Sprite Selection -----------

localparam logic [2:0] SIDE_NONE  = 3'd0;
localparam logic [2:0] SIDE_UP    = 3'd1;
localparam logic [2:0] SIDE_RIGHT = 3'd2;
localparam logic [2:0] SIDE_DOWN  = 3'd3;
localparam logic [2:0] SIDE_LEFT  = 3'd4;

function automatic logic [2:0] sideBetween(
	input integer originX,
	input integer originY,
	input integer otherX,
	input integer otherY
);
	integer deltaX;
	integer deltaY;
	begin
		deltaX = otherX - originX;
		deltaY = otherY - originY;
		if ((deltaX == 0) && (deltaY == 0))
			sideBetween = SIDE_NONE;
		else if ((deltaX >= deltaY) && (deltaX >= -deltaY))
			sideBetween = SIDE_RIGHT;
		else if ((-deltaX >= deltaY) && (-deltaX >= -deltaY))
			sideBetween = SIDE_LEFT;
		else if (deltaY < 0)
			sideBetween = SIDE_UP;
		else
			sideBetween = SIDE_DOWN;
	end
endfunction

function automatic logic [3:0] chooseSprite(
	input logic isTail,
	input integer currentX,
	input integer currentY,
	input integer towardHeadX,
	input integer towardHeadY,
	input integer towardTailX,
	input integer towardTailY
);
	logic [2:0] headSide;
	logic [2:0] tailSide;
	logic connectsUp;
	logic connectsRight;
	logic connectsDown;
	logic connectsLeft;
	begin
		headSide = sideBetween(currentX, currentY, towardHeadX, towardHeadY);
		tailSide = sideBetween(currentX, currentY, towardTailX, towardTailY);

		if (isTail) begin
			// Tail name is the direction of its pointed tip, away from the body.
			case (headSide)
				SIDE_UP:    chooseSprite = 4'd12; // tail_down
				SIDE_RIGHT: chooseSprite = 4'd13; // tail_left
				SIDE_DOWN:  chooseSprite = 4'd10; // tail_up
				SIDE_LEFT:  chooseSprite = 4'd11; // tail_right
				default:    chooseSprite = 4'd10;
			endcase
		end
		else begin
			connectsUp = (headSide == SIDE_UP) || (tailSide == SIDE_UP);
			connectsRight = (headSide == SIDE_RIGHT) || (tailSide == SIDE_RIGHT);
			connectsDown = (headSide == SIDE_DOWN) || (tailSide == SIDE_DOWN);
			connectsLeft = (headSide == SIDE_LEFT) || (tailSide == SIDE_LEFT);

			if (connectsUp && connectsLeft)
				chooseSprite = 4'd6;  // corner_top_left
			else if (connectsUp && connectsRight)
				chooseSprite = 4'd7;  // corner_top_right
			else if (connectsDown && connectsLeft)
				chooseSprite = 4'd8;  // corner_bottom_left
			else if (connectsDown && connectsRight)
				chooseSprite = 4'd9;  // corner_bottom_right
			else if (connectsLeft || connectsRight)
				chooseSprite = 4'd5;  // body_horizontal
			else
				chooseSprite = 4'd4;  // body_vertical / stationary fallback
		end
	end
endfunction

//------------- Body Area / ROM Address Logic -----------

always_comb begin

	insideBody = 1'b0;
	address = 10'd0;
	selectedSegment = 6'd0;
	selectedCurrentX = 11'd0;
	selectedCurrentY = 11'd0;
	selectedTowardHeadX = 11'd0;
	selectedTowardHeadY = 11'd0;
	selectedTowardTailX = 11'd0;
	selectedTowardTailY = 11'd0;
	spriteIndex = 4'd4;

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
				selectedSegment = segmentIndex[5:0];
				selectedCurrentX = trailX[trailIndex];
				selectedCurrentY = trailY[trailIndex];
				selectedTowardHeadX = trailX[trailIndex - SEGMENT_SPACING];
				selectedTowardHeadY = trailY[trailIndex - SEGMENT_SPACING];
				// Default is always in range and is ignored for an actual tail.
				selectedTowardTailX = trailX[trailIndex - SEGMENT_SPACING];
				selectedTowardTailY = trailY[trailIndex - SEGMENT_SPACING];
				if (segmentIndex < (MAX_SEGMENTS - 1)) begin
					if (segmentIndex != (snakeLength - 1'b1)) begin
						selectedTowardTailX = trailX[trailIndex + SEGMENT_SPACING];
						selectedTowardTailY = trailY[trailIndex + SEGMENT_SPACING];
					end
				end

				address =
					((pixelY - trailY[trailIndex]) * BODY_SIZE) +
					(pixelX - trailX[trailIndex]);

			end

		end

	end

	if (insideBody) begin
		spriteIndex = chooseSprite(
			selectedSegment == (snakeLength - 1'b1),
			selectedCurrentX,
			selectedCurrentY,
			selectedTowardHeadX,
			selectedTowardHeadY,
			selectedTowardTailX,
			selectedTowardTailY
		);
	end

	atlasAddress = (spriteIndex * 13'd576) + address;

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

// Visual metadata only: trail, length and self-collision above are unchanged.
logic bodyVisibleD;
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        bodyVisibleD <= 1'b0;
        snakeBody_DR <= 1'b0;
        snakeBody_RGB <= TRANSPARENT_ENCODING;
    end else begin
        bodyVisibleD <= gameStarted && insideBody;
        snakeBody_DR <= bodyVisibleD && spriteWord[8];
        snakeBody_RGB <= bodyVisibleD ? spriteWord[7:0] : TRANSPARENT_ENCODING;
    end
end

assign snakeSelfCollision =
	gameStarted &&
	selfCollisionHit;

endmodule
