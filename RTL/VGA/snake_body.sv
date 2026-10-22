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
parameter int MAX_SEGMENTS = 63;
parameter int INITIAL_LENGTH = 14;

//in pixels between every two segments
parameter int SEGMENT_SPACING = 6;

//We save the movement of the Head by saving a trail of head positionXY
// One entry per history frame, including the current sample at index zero.
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

// Reset/clear fills the trail with a visual seed, not actual movement history.
// Start counting only once the head leaves the configured spawn, so waiting for
// a direction key cannot mature stationary seed copies into self-collisions.
// After movement begins every running frame counts, preserving six-frame spacing.
localparam int TRAIL_COUNT_WIDTH = $clog2(MAX_TRAIL + 1);
logic [TRAIL_COUNT_WIDTH-1:0] validTrailSamples;

//------------- MIF ROM Signals -----------

logic insideBody;

logic [9:0] address;
logic [11:0] atlasAddress;
logic [4:0] visualX, visualY, sourceX, sourceY;
logic [2:0] baseSprite;
logic [8:0] spriteWord;
logic [3:0] spriteIndex;
localparam int SELECT_INDEX_WIDTH = (MAX_SEGMENTS > 1) ? $clog2(MAX_SEGMENTS) : 1;
logic [SELECT_INDEX_WIDTH-1:0] selectedSegment;
logic [10:0] selectedCurrentX, selectedCurrentY;
logic [10:0] selectedTowardHeadX, selectedTowardHeadY;
logic [10:0] selectedTowardTailX, selectedTowardTailY;

//------------- Self Collision Signals -----------

logic selfCollisionHit;

//------------- Emerald Body MIF ROM -----------

lpm_rom #(
	.LPM_WIDTH(9), .LPM_WIDTHAD(12), .LPM_NUMWORDS(2880),
	.LPM_FILE("RTL/mifs/snake_variants/emerald_body_bases_rgba9.mif"), .LPM_TYPE("LPM_ROM"),
	.LPM_ADDRESS_CONTROL("REGISTERED"), .LPM_OUTDATA("UNREGISTERED"),
	.AUTO_CARRY_CHAINS("ON"), .AUTO_CASCADE_BUFFERS("ON"),
	.INTENDED_DEVICE_FAMILY("Cyclone V")
) rom_inst (
	.address(atlasAddress), .inclock(clk), .q(spriteWord)
);

//------------- Trail / Length Logic -----------

// Widen before addition: at the six-bit cap, 63 + 5 must be 68, not 4.
localparam int LENGTH_WIDTH = $bits(snakeLength);
function automatic logic [LENGTH_WIDTH-1:0] saturatingGrow(
    input logic [LENGTH_WIDTH-1:0] currentLength,
    input logic [LENGTH_WIDTH-1:0] amount
);
    logic [LENGTH_WIDTH:0] sum;
    begin
        sum = {1'b0, currentLength} + {1'b0, amount};
        saturatingGrow = (sum >= MAX_SEGMENTS) ?
            LENGTH_WIDTH'(MAX_SEGMENTS) : sum[LENGTH_WIDTH-1:0];
    end
endfunction

always_ff @(posedge clk or negedge resetN)
begin
	//reset values
	if (!resetN) begin

		snakeLength <= INITIAL_LENGTH;
		validTrailSamples <= '0;

		for (int i = 0; i < MAX_TRAIL; i++) begin
			trailX[i] <= INITIAL_X;
			trailY[i] <= INITIAL_Y;
		end

	end

	else begin
		
		//The of the game
		if (clear) begin

			snakeLength <= INITIAL_LENGTH;
			validTrailSamples <= '0;

			for (int i = 0; i < MAX_TRAIL; i++) begin
				trailX[i] <= headX[10:0];
				trailY[i] <= headY[10:0];
			end

		end

		else begin

			//------------- Length Changes -------------

			if (blackAppleHitPulse) begin

				snakeLength <= saturatingGrow(snakeLength, BLACK_GROW_VALUE);

			end

			else if (blueAppleHitPulse) begin
			
				//Must always have at least one
				if (snakeLength <= BLUE_SHRINK_VALUE)
					snakeLength <= 6'd1;
				else
					snakeLength <= snakeLength - BLUE_SHRINK_VALUE;

			end

			else if (redAppleHitPulse) begin

				snakeLength <= saturatingGrow(snakeLength, RED_GROW_VALUE);

			end

			//------------- Trail Update -------------

			if (gameStarted && startOfFrame) begin
				if ((validTrailSamples < MAX_TRAIL) &&
					((validTrailSamples != 0) ||
					 (headX != INITIAL_X) || (headY != INITIAL_Y)))
					validTrailSamples <= validTrailSamples + 1'b1;
	
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

// Independent leaf tests and a balanced left-first tree retain the original
// lowest-index bounding-rectangle ownership, even for transparent sprite pixels.
// No pipeline registers are inserted.
localparam int SELECT_LEAVES = 1 << SELECT_INDEX_WIDTH;
localparam int SELECT_PAYLOAD_WIDTH = SELECT_INDEX_WIDTH + (6 * 11) + 10;
wire selectValid [1:2*SELECT_LEAVES-1];
wire [SELECT_PAYLOAD_WIDTH-1:0] selectPayload [1:2*SELECT_LEAVES-1];
genvar node, branch;

generate
    for (node = 0; node < SELECT_LEAVES; node = node + 1) begin : selection_leaf
        if (node < MAX_SEGMENTS) begin : body_node
            localparam int HISTORY_INDEX = (node + 1) * SEGMENT_SPACING;
            localparam logic [SELECT_INDEX_WIDTH-1:0] NODE_INDEX = SELECT_INDEX_WIDTH'(node);
            wire [10:0] tailX, tailY;
            wire [9:0] localAddress;
            if (node < MAX_SEGMENTS-1) begin : has_older_neighbor
                assign tailX = (node == snakeLength-1'b1) ?
                    trailX[HISTORY_INDEX-SEGMENT_SPACING] :
                    trailX[HISTORY_INDEX+SEGMENT_SPACING];
                assign tailY = (node == snakeLength-1'b1) ?
                    trailY[HISTORY_INDEX-SEGMENT_SPACING] :
                    trailY[HISTORY_INDEX+SEGMENT_SPACING];
            end
            else begin : last_node
                assign tailX = trailX[HISTORY_INDEX-SEGMENT_SPACING];
                assign tailY = trailY[HISTORY_INDEX-SEGMENT_SPACING];
            end
            assign localAddress =
                ((pixelY-trailY[HISTORY_INDEX])*BODY_SIZE) +
                (pixelX-trailX[HISTORY_INDEX]);
            assign selectValid[SELECT_LEAVES+node] =
                (node < snakeLength) &&
                (pixelX >= trailX[HISTORY_INDEX]) &&
                (pixelX < trailX[HISTORY_INDEX]+BODY_SIZE) &&
                (pixelY >= trailY[HISTORY_INDEX]) &&
                (pixelY < trailY[HISTORY_INDEX]+BODY_SIZE);
            assign selectPayload[SELECT_LEAVES+node] = {
                NODE_INDEX,
                trailX[HISTORY_INDEX], trailY[HISTORY_INDEX],
                trailX[HISTORY_INDEX-SEGMENT_SPACING],
                trailY[HISTORY_INDEX-SEGMENT_SPACING],
                tailX, tailY, localAddress
            };
        end
        else begin : unused_node
            assign selectValid[SELECT_LEAVES+node] = 1'b0;
            assign selectPayload[SELECT_LEAVES+node] = '0;
        end
    end
    for (branch = 1; branch < SELECT_LEAVES; branch = branch + 1) begin : selection_branch
        assign selectValid[branch] =
            selectValid[branch*2] || selectValid[branch*2+1];
        assign selectPayload[branch] = selectValid[branch*2] ?
            selectPayload[branch*2] : selectPayload[branch*2+1];
    end
endgenerate

always_comb begin
    insideBody = selectValid[1];
    {selectedSegment, selectedCurrentX, selectedCurrentY,
     selectedTowardHeadX, selectedTowardHeadY,
     selectedTowardTailX, selectedTowardTailY, address} =
        insideBody ? selectPayload[1] : '0;
    spriteIndex = 4'd4;
    if (insideBody) begin
        spriteIndex = chooseSprite(
            selectedSegment == (snakeLength - 1'b1),
            selectedCurrentX, selectedCurrentY,
            selectedTowardHeadX, selectedTowardHeadY,
            selectedTowardTailX, selectedTowardTailY
        );
    end
    // Compute local coordinates directly: no division/modulo of the old address.
    visualX = insideBody ? (pixelX-selectedCurrentX) : 5'd0;
    visualY = insideBody ? (pixelY-selectedCurrentY) : 5'd0;
    sourceX=visualX; sourceY=visualY; baseSprite=0;
    case(spriteIndex)
        5: baseSprite=1; // horizontal remains a distinct exact base
        6: baseSprite=2;
        7: baseSprite=3;
        8: begin baseSprite=2; sourceX=5'd23-visualY; sourceY=visualX; end
        9: begin baseSprite=3; sourceX=visualY; sourceY=5'd23-visualX; end
        10: baseSprite=4;
        11: begin baseSprite=4; sourceX=visualY; sourceY=5'd23-visualX; end
        12: begin baseSprite=4; sourceX=5'd23-visualX; sourceY=5'd23-visualY; end
        13: begin baseSprite=4; sourceX=5'd23-visualY; sourceY=visualX; end
        default: begin end
    endcase
    atlasAddress = (baseSprite * 12'd576) + (sourceY * 24) + sourceX;
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

		if ((segmentIndex < snakeLength) && (trailIndex < validTrailSamples)) begin

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

// Preserve the established registered visual metadata / ROM pixel pipeline.
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
