
module simple_up_counter (

//------------- Inputs -----------

	input logic clk,
	input logic resetN,

//------------- Outputs -----------

	output logic [3:0] keyPad   // counter output name matches pin assignment

);

//------------- Counter Logic -----------

always_ff @(posedge clk or negedge resetN)
begin
	if (!resetN) begin

		keyPad <= 4'd0;

	end

	else begin

		keyPad <= keyPad + 4'd1;

	end
end

endmodule