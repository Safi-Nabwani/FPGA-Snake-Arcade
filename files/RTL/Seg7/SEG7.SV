
module SEG7 (

//------------- Inputs -----------

	input logic clk,              // unused, kept for BDF compatibility
	input logic resetN,           // unused, kept for BDF compatibility

	input logic [3:0] iDIG,       // digit to display
	input logic darkN,            // 0 = turn display off

//------------- Outputs -----------

	output logic [6:0] oSEG

);

//------------- 7-Segment Decode Logic -----------

always_comb
begin

	if (!darkN) begin

		oSEG = 7'b1111111;        // all segments off

	end

	else begin

		case (iDIG)

			4'h0: oSEG = 7'b1000000;
			4'h1: oSEG = 7'b1111001;
			4'h2: oSEG = 7'b0100100;
			4'h3: oSEG = 7'b0110000;
			4'h4: oSEG = 7'b0011001;
			4'h5: oSEG = 7'b0010010;
			4'h6: oSEG = 7'b0000010;
			4'h7: oSEG = 7'b1111000;
			4'h8: oSEG = 7'b0000000;
			4'h9: oSEG = 7'b0011000;

			4'hA: oSEG = 7'b0001000;
			4'hB: oSEG = 7'b0000011;
			4'hC: oSEG = 7'b1000110;
			4'hD: oSEG = 7'b0100001;
			4'hE: oSEG = 7'b0000110;
			4'hF: oSEG = 7'b0001110;

			default: oSEG = 7'b1111111;

		endcase

	end

end

endmodule