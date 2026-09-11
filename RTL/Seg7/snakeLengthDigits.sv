module snakeLengthDigits (

//------------- Inputs -----------

	input logic [5:0] snakeLength,

//------------- Outputs -----------

	output logic [3:0] onesDigit,
	output logic [3:0] tensDigit

);

//------------- Decimal Digit Split -----------

always_comb begin

	tensDigit = 4'd0;
	onesDigit = 4'd0;

	if (snakeLength >= 6'd30) begin
		tensDigit = 4'd3;
		onesDigit = snakeLength - 6'd30;
	end

	else if (snakeLength >= 6'd20) begin
		tensDigit = 4'd2;
		onesDigit = snakeLength - 6'd20;
	end

	else if (snakeLength >= 6'd10) begin
		tensDigit = 4'd1;
		onesDigit = snakeLength - 6'd10;
	end

	else begin
		tensDigit = 4'd0;
		onesDigit = snakeLength[3:0];
	end

end

endmodule

// This helper module Converts one binary number (sankeLength) to two decimal digits (onesDigit and tensDigit).
