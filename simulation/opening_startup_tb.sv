`timescale 1ns/1ps
// Small real-score regression for the pre-existing victory -> restart race.
module opening_startup_tb;
    bit testPassed=0;
    logic clk=0,resetN=0,sof=0,key5=0,red=0;
    always #5 clk=~clk;
    wire running,startEvent,endEvent,lost,won,rp,bp,kp;
    wire [3:0] sl,sh;
    game_controller game(clk,resetN,sof,1'b1,1'b0,1'b0,1'b0,red,1'b0,1'b0,
        sl,sh,key5,running,startEvent,endEvent,lost,won,rp,bp,kp);
    appleCounter score(clk,resetN,startEvent,rp,bp,kp,sl,sh);
    integer i;
    initial begin
        #12;resetN=1;
        @(negedge clk);key5=1;
        repeat(4)@(negedge clk);
        key5=0;
        for(i=0;i<20;i++)begin
            @(negedge clk);sof=1;red=0;
            @(negedge clk);sof=0;
            @(negedge clk);red=1;
            repeat(3)@(negedge clk);red=0;
        end
        repeat(5)@(negedge clk);
        if(running || {sh,sl}!=8'h20)$fatal(1,"winning score setup failed");
        key5=1;
        repeat(5)begin
            @(negedge clk);
            $display("RESTART_TRACE: state=%0d run=%b start=%b score=%h%h won=%b",game.SMGame,running,startEvent,sh,sl,won);
        end
        if(!running || {sh,sl}!=0)$fatal(1,"new game re-won on stale score before clearing");
        $display("OPENING_STARTUP_PASS: victory restart survives score-clear edge");
        testPassed=1;$finish;
    end
endmodule
