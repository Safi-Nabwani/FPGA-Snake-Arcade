// Independent decimal collection totals. Existing controller events are one-clock pulses.
module relic_collection_counters (
    input logic clk, resetN, gameStartPulse,
    input logic redAppleHitPulse, blueAppleHitPulse, blackAppleHitPulse,
    output logic [11:0] rubyCountBCD, sapphireCountBCD, cursedCountBCD
);
    // Three packed BCD digits: hundreds, tens, ones. Saturate rather than wrap at 999.
    function automatic logic [11:0] incrementBCD(input logic [11:0] value);
        begin
            incrementBCD = value;
            if (value != 12'h999) begin
                if (value[3:0] != 4'd9)
                    incrementBCD[3:0] = value[3:0] + 4'd1;
                else begin
                    incrementBCD[3:0] = 4'd0;
                    if (value[7:4] != 4'd9)
                        incrementBCD[7:4] = value[7:4] + 4'd1;
                    else begin
                        incrementBCD[7:4] = 4'd0;
                        incrementBCD[11:8] = value[11:8] + 4'd1;
                    end
                end
            end
        end
    endfunction

    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin
            rubyCountBCD <= 12'h000;
            sapphireCountBCD <= 12'h000;
            cursedCountBCD <= 12'h000;
        end else if (gameStartPulse) begin
            rubyCountBCD <= 12'h000;
            sapphireCountBCD <= 12'h000;
            cursedCountBCD <= 12'h000;
        end else begin
            if (redAppleHitPulse) rubyCountBCD <= incrementBCD(rubyCountBCD);
            if (blueAppleHitPulse) sapphireCountBCD <= incrementBCD(sapphireCountBCD);
            if (blackAppleHitPulse) cursedCountBCD <= incrementBCD(cursedCountBCD);
        end
    end
endmodule
