`timescale 1ns/1ps
module cursed_audio_tb #(parameter OLD=0, FAST=1);
    reg clk=0,resetN=0,request=0;
    always #5 clk=~clk;
    wire [3:0] tone;
    wire [2:0] octave;
    wire enabled,ended,step,unusedStep;
    wire [11:0] divisor;
    wire [7:0] phase;
    wire [15:0] sample;
    reg [15:0] golden[0:4095];
    reg testPassed=0,previousEnable=0,wasPlaying,wasGap,tick;
    integer notes=0,noteTicks=0,gapTicks=0,endings=0,cycles=0,endCycle=0,checks=0;
    reg [15:0] held;
    reg [7:0] heldPhase;
    melody_player_1 dut(resetN,clk,request,4'd3,tone,octave,enabled,ended);
    defparam dut.mili_sec_counter_inst.SIMULATION_MODE=FAST;
    ToneDecoder decoder(tone,octave,divisor);
    prescaler divider(clk,resetN,divisor,step,unusedStep);
    addr_counter osc(clk,resetN,step,enabled,phase);
    sintable wave(clk,resetN,phase,1'b1,sample);
    task check(input bit ok,input string message);
        checks++;if(!ok)$fatal(1,"OLD=%0d FAST=%0d %s",OLD,FAST,message);
    endtask
    always @(posedge clk)begin
        wasPlaying=(dut.SM_Maestro==3);wasGap=(dut.SM_Maestro==4);tick=dut.hundredthSecPulse;
        #1;
        if(resetN)begin
            cycles++;
            check(!$isunknown({enabled,ended,tone,octave,phase,sample}),"known audio controls and samples");
            if(tick && wasPlaying)noteTicks++;
            if(tick && wasGap)gapTicks++;
            if(enabled && !previousEnable)begin
                check(notes<(OLD?35:4),"no extra note");
                check(dut.noteWord===golden[768+notes],"actual note follows independent MIF oracle");
                notes++;
            end
            if(ended)begin endings++;endCycle=cycles;end
            check(endings<=1,"no loop/repeated end pulse");
            if(endings && cycles>endCycle+4)begin
                check(!enabled && dut.SM_Maestro==0,"finite termination and stable idle");
                check(sample===held && phase===heldPhase,"no changing PCM/phase after termination");
            end else begin held=sample;heldPhase=phase;end
            previousEnable=enabled;
        end
    end
    initial begin
        $readmemh("db/cursed_audio_build/golden.hex",golden);
        repeat(3)@(negedge clk);resetN=1;
        @(negedge clk);request=1;@(negedge clk);request=0;
        wait(endings==1);repeat(10000)@(negedge clk);
        check(notes==(OLD?35:4),"exact note count");
        check(noteTicks==(OLD?104:8) && gapTicks==(OLD?75:3),"exact duration/gap tick totals");
        check(dut.noteIndex==(OLD?35:4),"correct terminator index");
        testPassed=1;$display("CURSED_AUDIO_PASS old=%0d fast=%0d notes=%0d note_ticks=%0d gap_ticks=%0d checks=%0d post_end_clocks=10000",OLD,FAST,notes,noteTicks,gapTicks,checks);$finish;
    end
    initial begin #120000000;$fatal(1,"timeout");end
endmodule
