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

	output logic [4:0] redX,
	output logic [4:0] redY,

	output logic [4:0] blueX,
	output logic [4:0] blueY,

	output logic [4:0] blackX,
	output logic [4:0] blackY

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
logic [9:0] redCounter;
logic [9:0] blueCounter;
logic [9:0] blackCounter;

// Fold the five-bit candidates into the 20x18 grid without a divider.
// This retains counter-based sampling; the distribution is not uniform.
function automatic logic [4:0] boundX(input logic [4:0] candidate);
	boundX = (candidate >= 5'd20) ? candidate - 5'd20 : candidate;
endfunction

function automatic logic [4:0] boundY(input logic [4:0] candidate);
	boundY = (candidate >= 5'd18) ? candidate - 5'd18 : candidate;
endfunction

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

		redCounter   <= {1'b0, redSeed[7:4], 1'b0, redSeed[3:0]};
		blueCounter  <= {1'b0, blueSeed[7:4], 1'b0, blueSeed[3:0]};
		blackCounter <= {1'b0, blackSeed[7:4], 1'b0, blackSeed[3:0]};

		redX   <= {1'b0, redSeed[3:0]};
		redY   <= {1'b0, redSeed[7:4]};

		blueX  <= {1'b0, blueSeed[3:0]};
		blueY  <= {1'b0, blueSeed[7:4]};

		blackX <= {1'b0, blackSeed[3:0]};
		blackY <= {1'b0, blackSeed[7:4]};

	end

	else begin

		//Diiferent incremation values
		redCounter   <= redCounter   + 10'd5;
		blueCounter  <= blueCounter  + 10'd7;
		blackCounter <= blackCounter + 10'd13;

		if (sampleRed) begin
			redX <= boundX(redCounter[4:0]);
			redY <= boundY(redCounter[9:5]);
		end

		if (sampleBlue) begin
			blueX <= boundX(blueCounter[4:0]);
			blueY <= boundY(blueCounter[9:5]);
		end

		if (sampleBlack) begin
			blackX <= boundX(blackCounter[4:0]);
			blackY <= boundY(blackCounter[9:5]);
		end

	end
end

endmodule
