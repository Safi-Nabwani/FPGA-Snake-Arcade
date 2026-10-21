`timescale 1ns/1ps
// Board-level resolved-wire fault model, not an analog/acoustic simulation.
module audio_pin_contention_tb;
    logic codecClock=0,backgroundBit=0,debugConnected=1;
    tri dacWordClock;
    assign dacWordClock=codecClock;
    assign dacWordClock=debugConnected?backgroundBit:1'bz;
    bit testPassed=0;
    integer checks=0,conflicts=0;
    task automatic check(input logic ok);
        checks++;if(ok!==1'b1)$fatal(1,"DACLRCK board contention assertion failed");
    endtask
    initial begin
        for(integer c=0;c<2;c++)for(integer b=0;b<2;b++)begin
            codecClock=c;backgroundBit=b;#1;
            if(c!=b)begin check(dacWordClock===1'bx);conflicts++;end
            else check(dacWordClock===codecClock);
        end
        debugConnected=0;
        for(integer c=0;c<2;c++)for(integer b=0;b<2;b++)begin
            codecClock=c;backgroundBit=b;#1;
            check(dacWordClock===codecClock);
        end
        check(conflicts==2);
        $display("AUDIO_PIN_CONTENTION_PASS checks=%0d reproduced_conflicts=%0d corrected_conflicts=0",checks,conflicts);
        testPassed=1;$finish;
    end
endmodule
