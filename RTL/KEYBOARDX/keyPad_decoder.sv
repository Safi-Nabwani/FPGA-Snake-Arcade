module keyPad_decoder (

//------------- Inputs -----------

	input logic clk,
	input logic resetN,

	input logic [8:0] keyCode,
	input logic make,
	input logic brakee,   // "break" is a reserved word

//------------- Outputs -----------

	output logic [9:0] NumberKey,

	output logic plus,
	output logic Back,
	output logic slash,
	output logic del,
	output logic enter,
	output logic minus,
	output logic star,
	output logic num,

	output logic [3:0] key,
	output logic keyIsValid

);

//------------- Parameters -----------

localparam int NUM_OF_KEYS = 18;

//------------- Key Encoding Table -----------

// Index:
// 0 1 2 3 4 5 6 7 8 9 + Back / DEL ENTER - * NUM

logic [0:NUM_OF_KEYS-1][8:0] KEYS_ENCODING = {
	9'h070, // 0
	9'h069, // 1
	9'h072, // 2
	9'h07A, // 3
	9'h06B, // 4
	9'h073, // 5
	9'h074, // 6
	9'h06C, // 7
	9'h075, // 8
	9'h07D, // 9
	9'h079, // +
	9'h066, // Backspace
	9'h14A, // /
	9'h071, // DEL
	9'h15A, // ENTER
	9'h07B, // -
	9'h07C, // *
	9'h077  // NUM
};

//------------- Internal Signals -----------

logic [NUM_OF_KEYS-1:0] keyIsPressed;

//------------- Key Press / Release Logic -----------

always_ff @(posedge clk or negedge resetN)
begin
	if (!resetN) begin

		key <= 4'd0;
		keyIsPressed <= '0;
		keyIsValid <= 1'b0;

	end

	else begin

		// keyIsValid is a one-clock pulse
		keyIsValid <= 1'b0;

		for (int i = 0; i < NUM_OF_KEYS; i++) begin

			if (keyCode == KEYS_ENCODING[i]) begin

				if (make) begin

					keyIsPressed[i] <= 1'b1;

					// only number keys update "key"
					if (i < 10)
						key <= i[3:0];

					// valid movement keys: 2, 4, 6, 8
					if ((i == 2) || (i == 4) || (i == 6) || (i == 8))
						keyIsValid <= 1'b1;

				end

				if (brakee) begin

					keyIsPressed[i] <= 1'b0;

				end

			end

		end

	end
end

//------------- Number Outputs -----------

assign NumberKey = keyIsPressed[9:0];

//------------- Special Key Outputs -----------

assign plus  = keyIsPressed[10];
assign Back  = keyIsPressed[11];
assign slash = keyIsPressed[12];
assign del   = keyIsPressed[13];
assign enter = keyIsPressed[14];
assign minus = keyIsPressed[15];
assign star  = keyIsPressed[16];
assign num   = keyIsPressed[17];

endmodule