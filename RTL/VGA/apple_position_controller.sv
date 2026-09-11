module apple_position_controller (

//------------- Inputs -----------

	input logic [3:0] redX,
	input logic [3:0] redY,

	input logic [3:0] blueX,
	input logic [3:0] blueY,

	input logic [3:0] blackX,
	input logic [3:0] blackY,

//------------- Outputs -----------

	output logic redPositionError,
	output logic bluePositionError,
	output logic blackPositionError,

	output logic [3:0] redFixedX,
	output logic [3:0] redFixedY,

	output logic [3:0] blueFixedX,
	output logic [3:0] blueFixedY,

	output logic [3:0] blackFixedX,
	output logic [3:0] blackFixedY

);

//------------- Rock Map -----------

// 1 = rock obstacle
// 0 = safe tile

logic [15:0] rockMap [0:15];

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
	rockMap[0]  = 16'b0000_0000_0000_0000;
	rockMap[1]  = 16'b0000_0000_0000_0000;
	rockMap[2]  = 16'b0000_0000_0000_0000;
	rockMap[3]  = 16'b0001_1000_0000_0000;
	rockMap[4]  = 16'b0001_1000_0000_0000;
	rockMap[5]  = 16'b0000_0000_0000_0000;
	rockMap[6]  = 16'b0000_0000_0000_0000;
	rockMap[7]  = 16'b0000_0000_0000_0000;
	rockMap[8]  = 16'b0000_0000_0000_0000;
	rockMap[9]  = 16'b0000_0000_0001_1000;
	rockMap[10] = 16'b0000_0000_0001_1000;
	rockMap[11] = 16'b0000_0000_0111_1000;
	rockMap[12] = 16'b0000_0000_0111_1000;
	rockMap[13] = 16'b0000_0000_0000_0000;
	rockMap[14] = 16'b0000_0000_0000_0000;
	rockMap[15] = 16'b0000_0000_0000_0000;

end

//------------- Rock Check -----------

//<color> apple is inside an obstacle ccheck
assign redInsideRock =
	rockMap[redY][redX];

assign blueInsideRock =
	rockMap[blueY][blueX];

assign blackInsideRock =
	rockMap[blackY][blackX];

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
	redInsideRock ||
	redBlueOverlap ||
	redBlackOverlap;

assign bluePositionError =
	blueInsideRock ||
	redBlueOverlap ||
	blueBlackOverlap;

assign blackPositionError =
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