`timescale 1ns/1ps
module audio_noise_probe_tb;
    logic clk=0,tck=0,resetN=1,ir=0,capture=0,shift=0,tdi=0;
    always #5 clk=~clk;
    always #17 tck=~tck;
    logic [191:0] payload=0;
    wire tdo;
    bit testPassed=0;
    integer checks=0;
    logic [255:0] result;
    logic [191:0] expected;
    audio_noise_probe #(.INDEX(80),.TEST(1)) dut(clk,resetN,payload,tck,ir,capture,shift,tdi,tdo);
    task automatic check(input logic ok);
        checks++;if(ok!==1'b1)$fatal(1,"JTAG coherent snapshot assertion failed");
    endtask
    initial begin
        #2;resetN=0;#39;resetN=1;
        for(integer r=0;r<50;r++)begin
            @(negedge tck);payload={$random,$random,$random,$random,$random,$random};
            expected=payload;ir=~ir;
            repeat(8)@(negedge tck);
            // Deliberately change live data while shift-out is in progress.
            payload=~expected;capture=1;@(negedge tck);capture=0;shift=1;
            for(integer b=0;b<256;b++)begin result[b]=tdo;@(negedge tck);end
            shift=0;
            check(result[191:0]===expected);
            check(result[223:192]=={31'd0,ir});
            check(result[255:224]==32'h44500050);
        end
        $display("AUDIO_NOISE_PROBE_PASS checks=%0d snapshots=50",checks);
        testPassed=1;$finish;
    end
    initial begin #1000000;$fatal(1,"Probe test timeout");end
endmodule
