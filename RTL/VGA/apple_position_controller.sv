module apple_position_controller (

//------------- Inputs -----------

	input logic [4:0] redX,
	input logic [4:0] redY,

	input logic [4:0] blueX,
	input logic [4:0] blueY,

	input logic [4:0] blackX,
	input logic [4:0] blackY,

//------------- Outputs -----------

	output logic redPositionError,
	output logic bluePositionError,
	output logic blackPositionError,

	output logic [4:0] redFixedX,
	output logic [4:0] redFixedY,

	output logic [4:0] blueFixedX,
	output logic [4:0] blueFixedY,

	output logic [4:0] blackFixedX,
	output logic [4:0] blackFixedY

);

//------------- Rock Map -----------

// 1 = rock obstacle
// 0 = safe tile

// Zero-based columns: bit 0 is column 0; matches back_ground_draw.
logic [19:0] rockMap [0:17];
logic redInRange, blueInRange, blackInRange;

//------------- Internal Signals -----------

//The positions we want to avoid:

//<color> apple is inside the obstacle
logic redInsideRock;
logic blueInsideRock;
logic blackInsideRock;

//<color><color> apples are ovarlapping
logic redBlueOverlap;
logic redBlackOverlap;
logic blueBlackOverlap;

//------------- Rock Mask -----------

always_comb begin
	
	//The static obstacles positions on the arena
	rockMap[0]  = 20'b0000_0000_0000_0000_0000;
	rockMap[1]  = 20'b0000_0000_0000_0000_0000;
	rockMap[2]  = 20'b0000_0000_0000_0000_0000;
	rockMap[3]  = 20'b0000_0001_1000_0000_0000;
	rockMap[4]  = 20'b0000_0001_1000_0000_0000;
	rockMap[5]  = 20'b0000_0000_0000_0000_0000;
	rockMap[6]  = 20'b0000_0000_0000_0000_0000;
	rockMap[7]  = 20'b0000_0000_0000_0000_0000;
	rockMap[8]  = 20'b0000_0000_0000_0000_0000;
	rockMap[9]  = 20'b0000_0000_0000_0001_1000;
	rockMap[10] = 20'b0000_0000_0000_0001_1000;
	rockMap[11] = 20'b0000_0000_0000_0111_1000;
	rockMap[12] = 20'b0000_0000_0000_0111_1000;
	rockMap[13] = 20'b0000_0000_0000_0000_0000;
	rockMap[14] = 20'b0000_0000_0000_0000_0000;
	rockMap[15] = 20'b0000_0000_0000_0000_0000;
	rockMap[16] = 20'b0000_0000_0000_0000_0000;
	rockMap[17] = 20'b0000_0000_0000_0000_0000;

end

//------------- Rock Check -----------

assign redInRange = (redX < 5'd20) && (redY < 5'd18);
assign blueInRange = (blueX < 5'd20) && (blueY < 5'd18);
assign blackInRange = (blackX < 5'd20) && (blackY < 5'd18);

// Guard array indexing and request a reroll for an invalid coordinate.
//<color> apple is inside an obstacle ccheck
assign redInsideRock =
	redInRange ? rockMap[redY][redX] : 1'b0;

assign blueInsideRock =
	blueInRange ? rockMap[blueY][blueX] : 1'b0;

assign blackInsideRock =
	blackInRange ? rockMap[blackY][blackX] : 1'b0;

//------------- Overlap Check -----------

//<color><color> apples are overlapping check
assign redBlueOverlap =
	(redX == blueX) &&
	(redY == blueY);

assign redBlackOverlap =
	(redX == blackX) &&
	(redY == blackY);

assign blueBlackOverlap =
	(blueX == blackX) &&
	(blueY == blackY);

//------------- Position Error Logic -----------
//
// If an apple is in an unwanted-position
// raise its error signal so the random generator rerolls.

assign redPositionError =
	!redInRange ||
	redInsideRock ||
	redBlueOverlap ||
	redBlackOverlap;

assign bluePositionError =
	!blueInRange ||
	blueInsideRock ||
	redBlueOverlap ||
	blueBlackOverlap;

assign blackPositionError =
	!blackInRange ||
	blackInsideRock ||
	redBlackOverlap ||
	blueBlackOverlap;

//------------- Position Outputs -----------

//The random module will keep rerolling until we get valid posiitons
//Have the valid positions as outputs
assign redFixedX = redX;
assign redFixedY = redY;

assign blueFixedX = blueX;
assign blueFixedY = blueY;

assign blackFixedX = blackX;
assign blackFixedY = blackY;

endmodule
