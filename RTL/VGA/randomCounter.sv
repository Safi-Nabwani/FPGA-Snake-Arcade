module randomCounter (

//------------- Inputs -----------

	input logic clk,
	input logic resetN,

	input logic redRise,
	input logic blueRise,
	input logic blackRise,

	input logic redPositionError,
	input logic bluePositionError,
	input logic blackPositionError,

//------------- Outputs -----------

	output logic [3:0] redX,
	output logic [3:0] redY,

	output logic [3:0] blueX,
	output logic [3:0] blueY,

	output logic [3:0] blackX,
	output logic [3:0] blackY

);

//------------- Parameters -----------

// Each seed is 8 bits:
// [3:0] = X seed
// [7:4] = Y seed

//Diffferenet seeds to help achieve more random-like bnehavior
parameter logic [7:0] redSeed   = 8'h37;
parameter logic [7:0] blueSeed  = 8'hA5;
parameter logic [7:0] blackSeed = 8'h6C;

//------------- Internal Counters -----------

//Different counter for different colors
logic [7:0] redCounter;
logic [7:0] blueCounter;
logic [7:0] blackCounter;

//------------- Sample Conditions -----------

logic sampleRed;
logic sampleBlue;
logic sampleBlack;

assign sampleRed =
	redRise ||
	redPositionError;

assign sampleBlue =
	blueRise ||
	bluePositionError;

assign sampleBlack =
	redRise ||
	blackRise ||
	blackPositionError;

//------------- Counter Random Logic -----------

always_ff @(posedge clk or negedge resetN)
begin
	//reset valuesS
	if (!resetN) begin

		redCounter   <= redSeed;
		blueCounter  <= blueSeed;
		blackCounter <= blackSeed;

		redX   <= redSeed[3:0];
		redY   <= redSeed[7:4];

		blueX  <= blueSeed[3:0];
		blueY  <= blueSeed[7:4];

		blackX <= blackSeed[3:0];
		blackY <= blackSeed[7:4];

	end

	else begin

		//Diiferent incremation values
		redCounter   <= redCounter   + 8'd5;
		blueCounter  <= blueCounter  + 8'd7;
		blackCounter <= blackCounter + 8'd13;

		if (sampleRed) begin
			redX <= redCounter[3:0];
			redY <= redCounter[7:4];
		end

		if (sampleBlue) begin
			blueX <= blueCounter[3:0];
			blueY <= blueCounter[7:4];
		end

		if (sampleBlack) begin
			blackX <= blackCounter[3:0];
			blackY <= blackCounter[7:4];
		end

	end
end

endmodule