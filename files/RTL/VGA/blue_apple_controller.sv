module blue_apple_controller (

//------------- Inputs -----------

	input logic clk,
	input logic resetN,
	input logic clear,                 

	input logic redAppleHitPulse,      
	input logic blueAppleHitPulse,     

//------------- Outputs -----------

	output logic blueAppleVisible,
	output logic blueAppleSpawnPulse   

);

//------------- Internal Counter -----------

//count the eaten red apples
logic [2:0] redModuloCounter;        

//------------- Logic -----------

always_ff @(posedge clk or negedge resetN)
begin
	//reset values
	if (!resetN) begin

		redModuloCounter <= 3'd0;
		blueAppleVisible <= 1'b0;
		blueAppleSpawnPulse <= 1'b0;

	end

	else begin

		// default
		blueAppleSpawnPulse <= 1'b0;

		if (clear) begin

			redModuloCounter <= 3'd0;
			blueAppleVisible <= 1'b0;

		end

		else begin

			// Blue apple disappears when eaten
			if (blueAppleHitPulse) begin
				blueAppleVisible <= 1'b0;
			end

			// Count red apples
			if (redAppleHitPulse) begin

				//The snake ate 5 and the blue must be visible
				if (redModuloCounter == 3'd4) begin
					
					//reset the counter
					redModuloCounter <= 3'd0;

					// Spawn only if there is no blue apple already visible
					if (!blueAppleVisible) begin
						blueAppleVisible <= 1'b1;
						blueAppleSpawnPulse <= 1'b1;
					end

				end

				else begin
				
					//count incremation
					redModuloCounter <= redModuloCounter + 3'd1;

				end

			end

		end

	end
end

endmodule