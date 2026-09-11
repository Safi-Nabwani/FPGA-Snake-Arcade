module AppleBitMap (

//------------- Inputs -----------

	input logic clk,
	input logic resetN,

	input logic redSquare_DR,
	input logic [10:0] redOffsetX,
	input logic [10:0] redOffsetY,

	input logic blueSquare_DR,
	input logic [10:0] blueOffsetX,
	input logic [10:0] blueOffsetY,
	input logic blueAppleVisible,

	input logic blackSquare_DR,
	input logic [10:0] blackOffsetX,
	input logic [10:0] blackOffsetY,

//------------- Outputs -----------

	output logic redApple_DR,
	output logic blueApple_DR,
	output logic blackApple_DR,
	output logic apple_DR,

	output logic [7:0] apple_RGB

);

//------------- Parameters -----------

localparam int APPLE_WIDTH  = 24;
localparam int APPLE_HEIGHT = 24;
localparam int APPLE_PIXELS = APPLE_WIDTH * APPLE_HEIGHT; 

localparam logic [7:0] TRANSPARENT_ENCODING = 8'hFF;

//Define params for readability and clearity 
localparam logic [1:0] RED_APPLE   = 2'd0;
localparam logic [1:0] BLUE_APPLE  = 2'd1;
localparam logic [1:0] BLACK_APPLE = 2'd2;

//------------- Select Active Apple Pixel -----------

//The type of the apple that we want to display
logic insideApple;
logic [1:0] selectedApple;

logic [4:0] selectedOffsetX;
logic [4:0] selectedOffsetY;

always_comb begin

	//defaults
	insideApple = 1'b0;
	selectedApple = RED_APPLE;

	selectedOffsetX = 5'd0;
	selectedOffsetY = 5'd0;

	//Check the DR to know what apple we want to display
	//update the params
	if (blackSquare_DR) begin

		insideApple = 1'b1;
		selectedApple = BLACK_APPLE;

		selectedOffsetX = blackOffsetX[4:0];
		selectedOffsetY = blackOffsetY[4:0];

	end

	//Special check for the blueApple since it might not be visible 
	else if (blueSquare_DR && blueAppleVisible) begin

		insideApple = 1'b1;
		selectedApple = BLUE_APPLE;

		selectedOffsetX = blueOffsetX[4:0];
		selectedOffsetY = blueOffsetY[4:0];

	end

	else if (redSquare_DR) begin

		insideApple = 1'b1;
		selectedApple = RED_APPLE;

		selectedOffsetX = redOffsetX[4:0];
		selectedOffsetY = redOffsetY[4:0];

	end

end

//------------- Address Calculation -----------

logic [9:0] address;

assign address =
	(selectedOffsetY * APPLE_WIDTH) + selectedOffsetX;

//------------- ROM Outputs -----------

logic [7:0] redAppleColor;
logic [7:0] blueAppleColor;
logic [7:0] blackAppleColor;

logic [7:0] selectedAppleColor;

//------------- Red Apple ROM -----------

lpm_rom #(
	.LPM_WIDTH              (8),
	.LPM_WIDTHAD            (10),
	.LPM_NUMWORDS           (576),
	.LPM_FILE               ("RTL/mifs/red_apple_24.mif"),
	.LPM_TYPE               ("LPM_ROM"),
	.LPM_ADDRESS_CONTROL    ("REGISTERED"),
	.LPM_OUTDATA            ("UNREGISTERED"),
	.AUTO_CARRY_CHAINS      ("ON"),
	.AUTO_CASCADE_BUFFERS   ("ON"),
	.INTENDED_DEVICE_FAMILY ("Cyclone V")
) red_apple_rom (
	.address (address),
	.inclock (clk),
	.q       (redAppleColor)
);

//------------- Blue Apple ROM -----------

lpm_rom #(
	.LPM_WIDTH              (8),
	.LPM_WIDTHAD            (10),
	.LPM_NUMWORDS           (576),
	.LPM_FILE               ("RTL/mifs/blue_apple_24.mif"),
	.LPM_TYPE               ("LPM_ROM"),
	.LPM_ADDRESS_CONTROL    ("REGISTERED"),
	.LPM_OUTDATA            ("UNREGISTERED"),
	.AUTO_CARRY_CHAINS      ("ON"),
	.AUTO_CASCADE_BUFFERS   ("ON"),
	.INTENDED_DEVICE_FAMILY ("Cyclone V")
) blue_apple_rom (
	.address (address),
	.inclock (clk),
	.q       (blueAppleColor)
);

//------------- Black Apple ROM -----------

lpm_rom #(
	.LPM_WIDTH              (8),
	.LPM_WIDTHAD            (10),
	.LPM_NUMWORDS           (576),
	.LPM_FILE               ("RTL/mifs/black_apple_24.mif"),
	.LPM_TYPE               ("LPM_ROM"),
	.LPM_ADDRESS_CONTROL    ("REGISTERED"),
	.LPM_OUTDATA            ("UNREGISTERED"),
	.AUTO_CARRY_CHAINS      ("ON"),
	.AUTO_CASCADE_BUFFERS   ("ON"),
	.INTENDED_DEVICE_FAMILY ("Cyclone V")
) black_apple_rom (
	.address (address),
	.inclock (clk),
	.q       (blackAppleColor)
);

//------------- Select ROM Color -----------

always_comb begin

	//default
	selectedAppleColor = TRANSPARENT_ENCODING;

	//pass the actual colors we want to display 
	case (selectedApple)

		RED_APPLE:
			selectedAppleColor = redAppleColor;

		BLUE_APPLE:
			selectedAppleColor = blueAppleColor;

		BLACK_APPLE:
			selectedAppleColor = blackAppleColor;

		default:
			selectedAppleColor = TRANSPARENT_ENCODING;

	endcase

end

//------------- Output Logic -----------

always_comb begin

	redApple_DR   = 1'b0;
	blueApple_DR  = 1'b0;
	blackApple_DR = 1'b0;
	apple_DR      = 1'b0;

	apple_RGB = TRANSPARENT_ENCODING;

	if (insideApple && (selectedAppleColor != TRANSPARENT_ENCODING)) begin

		apple_DR = 1'b1;
		apple_RGB = selectedAppleColor;

		case (selectedApple)

			RED_APPLE:
				redApple_DR = 1'b1;

			BLUE_APPLE:
				blueApple_DR = 1'b1;

			BLACK_APPLE:
				blackApple_DR = 1'b1;

			default: begin
				redApple_DR   = 1'b0;
				blueApple_DR  = 1'b0;
				blackApple_DR = 1'b0;
			end

		endcase

	end

end

endmodule