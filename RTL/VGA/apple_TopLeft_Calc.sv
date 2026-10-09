module apple_topleft_calc (

//------------- Inputs -----------

	input logic [4:0] redX,
	input logic [4:0] redY,

	input logic [4:0] blueX,
	input logic [4:0] blueY,

	input logic [4:0] blackX,
	input logic [4:0] blackY,

//------------- Outputs -----------

	output logic signed [10:0] redTopLeftX,
	output logic signed [10:0] redTopLeftY,

	output logic signed [10:0] blueTopLeftX,
	output logic signed [10:0] blueTopLeftY,

	output logic signed [10:0] blackTopLeftX,
	output logic signed [10:0] blackTopLeftY

);

//------------- Parameters -----------

localparam int ARENA_LEFT = 144;
localparam int ARENA_TOP  = 24;
localparam int TILE_SIZE  = 24;

//------------- Top Left Calculation -----------

assign redTopLeftX = ARENA_LEFT + redX * TILE_SIZE;
assign redTopLeftY = ARENA_TOP  + redY * TILE_SIZE;

assign blueTopLeftX = ARENA_LEFT + blueX * TILE_SIZE;
assign blueTopLeftY = ARENA_TOP  + blueY * TILE_SIZE;

assign blackTopLeftX = ARENA_LEFT + blackX * TILE_SIZE;
assign blackTopLeftY = ARENA_TOP  + blackY * TILE_SIZE;

endmodule

//This helper module is used to compute the topLeftXY of the 
//tile we want the apple to be on
