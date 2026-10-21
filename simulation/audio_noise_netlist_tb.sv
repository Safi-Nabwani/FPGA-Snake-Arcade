`timescale 1ns/1ps
module audio_noise_netlist_tb;
    logic clk=0,resetN=0,start=0,volume=1;
    always #15.873 clk=~clk;
    logic [2:0] requestID=4;
    wire serial,sclk,sdat;
    logic bclk=0,lrclk=0;
    always #162.760 bclk=~bclk;
    integer serialBits=0;
    always @(negedge bclk)begin serialBits++;if(serialBits%32==0)lrclk=~lrclk;end
    // Exported internal hierarchy uses physically complemented selector FFs
    // for request bits 1/2 (both clear low for logical restart ID 6).
    noise_net_AUDIO dut(.melodySelect_1(!requestID[1]),.melodySelect_2(!requestID[2]),
        .melodySelect_0(requestID[0]),.startMelody(start),.AUD_DACDataOut(serial),
        .FPGA_I2C_SCLK(sclk),.SDO(sdat),.AUDIN({lrclk,bclk}),.KEY_3(volume),
        .resetN(resetN),.clk(clk),.devpor(1'b1),.devclrn(1'b1),.devoe(1'b1));
    wire [3:0] tone;
    wire [2:0] octave;
    wire enabled,ended;
    wire [11:0] divisor;
    wire stepEnable,unusedStep;
    wire [7:0] phase;
    wire [15:0] sample;
    // Reassemble the ten unique fitted PCM nets wired into the QXP. Synthesis
    // shares the sign-extension bits. Mux0..8 are original Q[13]..Q[5].
    wire [15:0] fittedSample={dut.inst1.Q_0,dut.inst1.Q_0,dut.inst1.Mux0,
        dut.inst1.Mux1,dut.inst1.Mux2,dut.inst1.Mux3,dut.inst1.Mux4,
        dut.inst1.Mux5,dut.inst1.Mux6,dut.inst1.Mux7,dut.inst1.Mux8,{5{dut.inst1.Q_0}}};
    melody_player_1 reference(resetN,clk,start,{1'b0,requestID},tone,octave,enabled,ended);
    ToneDecoder pitch(tone,octave,divisor);
    prescaler divider(clk,resetN,divisor,stepEnable,unusedStep);
    addr_counter oscillator(clk,resetN,stepEnable,enabled,phase);
    sintable wave(clk,resetN,phase,volume,sample);
    integer checks=0,cycles=0;
    bit testPassed=0;
    task automatic check(input logic ok,input string message);
        checks++;if(ok!==1'b1)$fatal(1,"AUDIO_NETLIST cycle=%0d: %s",cycles,message);
    endtask
    always @(posedge clk)begin
        #2;cycles++;
        if(resetN && cycles>20)begin
            check(dut.inst5.EnableSoundOut1===enabled,"fitted versus RTL enable");
            check(dut.\inst9|addr ===phase,"fitted versus RTL oscillator phase");
            check({dut.inst5.noteWord_15,dut.inst5.noteWord_14,dut.inst5.noteWord_13,dut.inst5.noteWord_12}===tone,"fitted versus RTL tone");
            check(fittedSample===sample,"actual fitted codec-input PCM equals RTL sample");
            check(!$isunknown({sample,serial}),"known continuous PCM and modeled serial output");
        end
    end
    task automatic cycle;
        @(posedge clk);#3;@(negedge clk);
    endtask
    initial begin
        #2;resetN=1;#7;resetN=0;repeat(5)cycle();#3;resetN=1;
        repeat(30)cycle();requestID=6;start=1;cycle();start=0;
        // Real 30-ms tick parameters: both restart notes, termination and a
        // further ~3.5-ms idle tail. No forced tick or timing acceleration.
        repeat(2000000)cycle();
        check(reference.SM_Maestro==reference.s_idle && !enabled,"real effect ended and stayed idle");
        $display("AUDIO_NETLIST_PASS checks=%0d clocks=%0d",checks,cycles);
        testPassed=1;$finish;
    end
endmodule
