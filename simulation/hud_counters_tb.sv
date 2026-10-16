`timescale 1ns/1ps
module hud_counters_tb;
    bit testPassed = 0;
    logic clk = 0, resetN = 0;
    always #5 clk = ~clk;
    logic manual = 1, overflowTest = 0;
    logic start = 0, ended = 0, red = 0, blue = 0, black = 0;
    logic key5 = 0, sof = 0, headDR = 0, redDR = 0, blueDR = 0, blackDR = 0;
    wire running, startEvent, endEvent, lost, won, redEvent, blueEvent, blackEvent;
    wire gs = manual ? start : startEvent;
    wire ge = manual ? ended : endEvent;
    wire rp = manual ? red : redEvent;
    wire bp = manual ? blue : blueEvent;
    wire kp = manual ? black : blackEvent;
    wire [3:0] scoreLow, scoreHigh, highLow, highHigh;
    appleCounter score(clk, resetN, gs, rp && !overflowTest,
        bp && !overflowTest, kp && !overflowTest, scoreLow, scoreHigh);
    highscoreComp high(clk, resetN, ge, scoreLow, scoreHigh, highLow, highHigh);
    wire [11:0] ruby, sapphire, cursed;
    relic_collection_counters counters(clk, resetN, gs, rp, bp, kp, ruby, sapphire, cursed);
    game_controller game(clk, resetN, sof, headDR, 1'b0, 1'b0, 1'b0,
        redDR, blueDR, blackDR, scoreLow, scoreHigh, key5,
        running, startEvent, endEvent, lost, won, redEvent, blueEvent, blackEvent);
    wire blueVisible, blueSpawn;
    blue_apple_controller spawn(clk, resetN, gs, rp, bp, blueVisible, blueSpawn);
    task automatic check(input bit ok, input string message);
        if (!ok) $fatal(1, "%s", message);
    endtask
    function automatic integer decimal(input logic [11:0] bcd);
        decimal = bcd[11:8]*100 + bcd[7:4]*10 + bcd[3:0];
    endfunction
    task automatic pulse(input integer eventKind);
        @(negedge clk);
        case (eventKind)
            0: start = 1;
            1: red = 1;
            2: blue = 1;
            3: black = 1;
            4: ended = 1;
        endcase
        @(negedge clk); start = 0; red = 0; blue = 0; black = 0; ended = 0;
    endtask
    task automatic newFrame;
        @(negedge clk); sof = 1;
        @(negedge clk); sof = 0;
    endtask
    integer i;
    initial begin
        #12; resetN = 1; #1;
        check(ruby == 0 && sapphire == 0 && cursed == 0 && scoreLow == 0 && highLow == 0,
            "hardware reset clears all totals");
        repeat (8) pulse(1);
        check(ruby == 12'h008 && sapphire == 0 && cursed == 0 && scoreLow == 8,
            "Ruby independent and score +1");
        check(blueVisible && spawn.redModuloCounter == 3, "modulo-five spawn unchanged");
        pulse(2);
        check(ruby == 12'h008 && sapphire == 12'h001 && cursed == 0 &&
            scoreHigh == 1 && scoreLow == 1, "Sapphire +3 score but +1 relic");
        pulse(3);
        check(cursed == 12'h001 && scoreHigh == 0 && scoreLow == 6, "Cursed -5 score but +1 relic");
        pulse(4); check(highLow == 6 && highHigh == 0, "original high-score capture");
        pulse(0);
        check(ruby == 0 && sapphire == 0 && cursed == 0 && scoreLow == 0 && scoreHigh == 0,
            "new game clears relics and current score");
        check(highLow == 6 && highHigh == 0, "high score survives local restart");
        check(!blueVisible && spawn.redModuloCounter == 0, "blue-spawn reset remains separate");
        pulse(3); check(cursed == 12'h001 && scoreLow == 0 && scoreHigh == 0, "negative score floor");
        pulse(0);
        overflowTest = 1;
        @(negedge clk); red = 1; blue = 1; black = 1;
        for (i = 1; i <= 1005; i = i + 1) begin
            @(posedge clk); #1;
            check(decimal(ruby) == (i > 999 ? 999 : i) &&
                  decimal(sapphire) == (i > 999 ? 999 : i) &&
                  decimal(cursed) == (i > 999 ? 999 : i), "BCD carry/saturation/independence");
            check(ruby[3:0] <= 9 && ruby[7:4] <= 9 && ruby[11:8] <= 9, "valid BCD digits");
        end
        // Reset wins over simultaneous collection events.
        @(negedge clk); start = 1;
        @(posedge clk); #1; check(ruby == 0 && sapphire == 0 && cursed == 0, "reset priority");
        @(negedge clk); start = 0; red = 0; blue = 0; black = 0;
        repeat (8) @(negedge clk);
        check(ruby == 0 && sapphire == 0 && cursed == 0, "idle totals hold");
        overflowTest = 0;
        #1; resetN = 0; #1;
        check(highLow == 0 && highHigh == 0, "only hardware reset clears high score");
        #2; resetN = 1; manual = 0;
        @(negedge clk); key5 = 1;
        @(negedge clk); key5 = 0;
        repeat (3) @(negedge clk);
        headDR = 1; redDR = 1;
        repeat (12) @(negedge clk);
        check(ruby == 12'h001 && scoreLow == 1, "held overlap produces one controller event");
        newFrame(); repeat (12) @(negedge clk);
        check(ruby == 12'h002 && scoreLow == 2, "one further collection in next frame");
        redDR = 0; newFrame(); blueDR = 1;
        repeat (12) @(negedge clk);
        check(sapphire == 12'h001 && scoreLow == 5, "controller Sapphire event routed correctly");
        blueDR = 0; newFrame(); blackDR = 1;
        repeat (12) @(negedge clk);
        check(cursed == 12'h001 && !running && scoreLow == 0 && highLow == 5,
            "lethal Cursed event and pre-penalty high-score ordering preserved");
        blackDR = 0; headDR = 0;
        key5 = 1; @(negedge clk); key5 = 0; repeat (3) @(negedge clk);
        check(running && ruby == 0 && sapphire == 0 && cursed == 0 && highLow == 5,
            "controller restart clears counters, keeps high score");
        // Win at 90 is driven by the score, not the Ruby total.
        headDR = 1; redDR = 1;
        for (i = 0; i < 90; i = i + 1) begin newFrame(); repeat (4) @(negedge clk); end
        repeat (3) @(negedge clk);
        check(!running && scoreHigh == 9 && scoreLow == 0 && ruby == 12'h090 &&
              highHigh == 9 && highLow == 0, "win90 threshold and independent relic total");
        $display("HUD_COUNTERS_PASS: independent pulses, 000..999, saturation, resets, high score, original game events");
        testPassed = 1;
        $finish;
    end
    initial begin #100000; $fatal(1, "counter test timeout"); end
endmodule
