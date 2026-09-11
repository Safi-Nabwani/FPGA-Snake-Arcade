module square_object (

//------------- Inputs -----------

	input logic clk,
	input logic resetN,

	input logic signed [10:0] pixelX,    // current VGA pixel X
	input logic signed [10:0] pixelY,    // current VGA pixel Y

	input logic signed [10:0] topLeftX,  // object top-left X position
	input logic signed [10:0] topLeftY,  // object top-left Y position

//------------- Outputs -----------

	output logic [10:0] offsetX,         // offset from object top-left X
	output logic [10:0] offsetY,         // offset from object top-left Y

	output logic drawingRequest,         // indicates pixel is inside object
	output logic [7:0] RGBout            // optional color output for mux

);

//------------- Parameters -----------

parameter int OBJECT_WIDTH_X  = 100;
parameter int OBJECT_HEIGHT_Y = 100;

parameter logic [7:0] OBJECT_COLOR = 8'h03;

localparam logic [7:0] TRANSPARENT_ENCODING = 8'hFF;

//------------- Internal Signals -----------

logic signed [11:0] rightX;
logic signed [11:0] bottomY;

logic insideRectangle;

//------------- Rectangle Boundaries -----------

assign rightX  = topLeftX + OBJECT_WIDTH_X;
assign bottomY = topLeftY + OBJECT_HEIGHT_Y;

//Check if inside the square object
assign insideRectangle = 	
	(pixelX >= topLeftX) &&
	(pixelX <  rightX)   &&
	(pixelY >= topLeftY) &&
	(pixelY <  bottomY);

//------------- Drawing Logic -----------

always_ff @(posedge clk or negedge resetN)
begin
	if (!resetN) begin	//reset values

		RGBout <= TRANSPARENT_ENCODING;
		drawingRequest <= 1'b0;

		offsetX <= 11'd0;
		offsetY <= 11'd0;

	end

	else begin

		// default outputs
		RGBout <= TRANSPARENT_ENCODING;
		drawingRequest <= 1'b0;

		offsetX <= 11'd0;
		offsetY <= 11'd0;

		if (insideRectangle) begin

			RGBout <= OBJECT_COLOR;
			drawingRequest <= 1'b1;

			offsetX <= pixelX - topLeftX;
			offsetY <= pixelY - topLeftY;

		end

	end
end

endmodule