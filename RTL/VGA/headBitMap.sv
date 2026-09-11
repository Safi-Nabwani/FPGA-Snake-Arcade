module headBitMap (

//------------- Inputs -----------

	input	logic clk,
	input	logic resetN,

	input	logic [10:0] offsetX,          
	input	logic [10:0] offsetY,
	input	logic headSquare_DR,          

	input logic [2:0] snakeHeadDir,        

//------------- Outputs -----------

	output logic drawingRequest,           
	output logic [7:0] RGBout              

);

//------------- Bitmap Parameters -----------

localparam int OBJECT_WIDTH_X  = 24;
localparam int OBJECT_HEIGHT_Y = 24;
localparam int OBJECT_PIXELS   = OBJECT_WIDTH_X * OBJECT_HEIGHT_Y; 

localparam logic [7:0] TRANSPARENT_ENCODING = 8'hFF;

//------------- Direction Values -----------
//
// The MIF itself is drawn facing UP.
// We rotate the ROM address according to snakeHeadDir.

localparam logic [2:0] DIR_NONE  = 3'd0;
localparam logic [2:0] DIR_UP    = 3'd1;
localparam logic [2:0] DIR_RIGHT = 3'd2;
localparam logic [2:0] DIR_LEFT  = 3'd3;
localparam logic [2:0] DIR_DOWN  = 3'd4;

//------------- Internal Signals -----------

//	ROM
logic [9:0] address;
logic [7:0] color;

//	offset
logic [4:0] localX;
logic [4:0] localY;

//	Adjusted oofset
logic [4:0] rotatedX;
logic [4:0] rotatedY;

//------------- Local Pixel Position -----------

assign localX = offsetX[4:0];
assign localY = offsetY[4:0];

//------------- Rotation Logic -----------


always_comb begin

	rotatedX = localX; //deafults
	rotatedY = localY;

	case (snakeHeadDir)

		DIR_UP,//	MIF is facing up
		DIR_NONE: begin

			rotatedX = localX;
			rotatedY = localY;

		end

		DIR_RIGHT: begin	

			rotatedX = localY;
			rotatedY = 5'd23 - localX;

		end

		DIR_DOWN: begin

			rotatedX = 5'd23 - localX;
			rotatedY = 5'd23 - localY;

		end

		DIR_LEFT: begin

			rotatedX = 5'd23 - localY;
			rotatedY = localX;

		end

		default: begin

			rotatedX = localX;
			rotatedY = localY;

		end

	endcase

end

//------------- Address Calculation -----------

assign address = rotatedY * OBJECT_WIDTH_X + rotatedX;

//------------- Head Bitmap ROM -----------

lpm_rom #(
	.LPM_WIDTH              (8),
	.LPM_WIDTHAD            (10),
	.LPM_NUMWORDS           (576),
	.LPM_FILE               ("RTL/mifs/snake_head_24.mif"),
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

//------------- Drawing Logic -----------

always_ff @(posedge clk or negedge resetN)
begin
	if (!resetN) begin //reset values

		RGBout <= TRANSPARENT_ENCODING;
		drawingRequest <= 1'b0;

	end

	else begin

		// defaults
		RGBout <= TRANSPARENT_ENCODING;
		drawingRequest <= 1'b0;

		//if inside the square object
		if (headSquare_DR) begin

			RGBout <= color;

			//if there is color send a DR
			if (color != TRANSPARENT_ENCODING)
				drawingRequest <= 1'b1;
			else
				drawingRequest <= 1'b0;

		end

	end
end

endmodule