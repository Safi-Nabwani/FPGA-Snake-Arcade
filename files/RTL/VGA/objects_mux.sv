module objects_mux (

//------------- Inputs -----------

	input logic clk,
	input logic resetN,

	// snake head
	input logic snakeHead_DR,
	input logic [7:0] snakeHead_RGB,

	// snake body
	input logic snakeBody_DR,
	input logic [7:0] snakeBody_RGB,

	// score digits
	input logic score_DR,
	input logic [7:0] score_RGB,

	// highscore digits
	input logic highScore_DR,
	input logic [7:0] highScore_RGB,

	// apples
	input logic apple_DR,
	input logic [7:0] apple_RGB,
	
	// message
	input logic message_DR,
	input logic [7:0] message_RGB,

	// background
	input logic [7:0] BG_RGB,

//------------- Outputs -----------

	output logic [7:0] RGBOut

);

//------------- Priority Mux -----------

always_ff @(posedge clk or negedge resetN)
begin
	if (!resetN) begin

		RGBOut <= 8'h00;

	end

	else begin

		if (message_DR) begin
			RGBOut <= message_RGB;
		end

		else if (snakeHead_DR) begin
			RGBOut <= snakeHead_RGB;
		end

		else if (snakeBody_DR) begin
			RGBOut <= snakeBody_RGB;
		end

		else if (score_DR) begin
			RGBOut <= score_RGB;
		end

		else if (highScore_DR) begin
			RGBOut <= highScore_RGB;
		end

		else if (apple_DR) begin
			RGBOut <= apple_RGB;
		end

		else begin
			RGBOut <= BG_RGB;
		end

	end
end

endmodule