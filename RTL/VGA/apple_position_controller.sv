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

`include "RTL/VGA/jungle_map.svh"
always_comb begin
    for (int row = 0; row < 18; row++)
        rockMap[row] = jungleRockRow(row[4:0]);
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
