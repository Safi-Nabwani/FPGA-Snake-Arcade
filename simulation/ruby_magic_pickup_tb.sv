`timescale 1ns/1ps
module ruby_magic_pickup_tb;
    reg clk=0, resetN=0, request=0;
    wire [3:0] tone;
    wire [2:0] octave;
    wire enabled, ended;
    wire [11:0] divisor;
    reg testPassed=0;
    integer notes=0, ticks=0, totalTicks=0, endings=0, cycles=0;
    reg previousEnable=0, playingBefore, tickBefore;
    reg [15:0] expectedWord [0:3];
    integer expectedDivisor [0:3];
    melody_player_1 dut(resetN,clk,request,4'd5,tone,octave,enabled,ended);
    defparam dut.mili_sec_counter_inst.SIMULATION_MODE=1;
    ToneDecoder decoder(tone,octave,divisor);
    always #5 clk=~clk;
    initial begin
        expectedWord[0]=16'h7440; expectedWord[1]=16'h0860;
        expectedWord[2]=16'h2840; expectedWord[3]=16'h78A0;
        expectedDivisor[0]=156; expectedDivisor[1]=117;
        expectedDivisor[2]=104; expectedDivisor[3]=78;
        repeat(3) @(negedge clk);
        resetN=1;
        @(negedge clk); request=1;
        @(negedge clk); request=0;
        repeat(800) @(negedge clk);
        if(notes!=4 || endings!=1 || totalTicks!=12 || enabled!==0 || dut.SM_Maestro!=0)
            $fatal(1,"Ruby final state notes=%0d endings=%0d ticks=%0d",notes,endings,totalTicks);
        testPassed=1;
        $display("RUBY_MAGIC_PICKUP_PASS notes=4 durations=2,3,2,5 gaps=0 ticks=12 idle=1 divisors=156,117,104,78");
        $finish;
    end
    always @(posedge clk) begin
        playingBefore=(dut.SM_Maestro==3);
        tickBefore=dut.hundredthSecPulse;
        #1;
        if(resetN) begin
            cycles=cycles+1;
            if(playingBefore && tickBefore) begin ticks=ticks+1; totalTicks=totalTicks+1; end
            if(enabled && !previousEnable) begin
                if(notes>=4) $fatal(1,"Unexpected fifth Ruby note");
                if(dut.noteWord!==expectedWord[notes] || divisor!==expectedDivisor[notes])
                    $fatal(1,"Ruby note/pitch mismatch index=%0d word=%h divisor=%0d",notes,dut.noteWord,divisor);
                notes=notes+1;
                ticks=0;
            end
            if(!enabled && previousEnable && ticks!=expectedWord[notes-1][9:5])
                $fatal(1,"Ruby duration mismatch index=%0d ticks=%0d",notes-1,ticks);
            if(dut.SM_Maestro==4) $fatal(1,"Unexpected Ruby gap");
            if(ended) endings=endings+1;
            if(endings && enabled) $fatal(1,"Sound restarted after terminator");
            previousEnable=enabled;
        end
    end
endmodule
