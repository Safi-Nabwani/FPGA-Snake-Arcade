`timescale 1ns/1ps
// Continuous waveform oracle, keyboard requests and long idle tails. The QXP
// and analog output are NOT modeled here; fitted-QXP checks are separate.
module audio_noise_output_tb;
    logic clk=0,resetN=1,volume=1,make=0,brakee=0;
    always #15.873 clk=~clk;
    logic [8:0] keyCode=0;
    wire [9:0] numberKey;
    wire keyValid;
    wire [3:0] key;
    wire plus,back,slash,del,enter,minus,star,num;
    logic [6:0] directEvents=0;
    logic keyboardMode=0;
    wire gStart,gOver,gWon,gStarted,gEnd,gRed,gBlue,gBlack;
    wire start;
    wire [3:0] requestID,tone;
    wire [2:0] octave;
    wire enabled,ended;
    wire [11:0] divisor;
    wire stepEnable,unusedStep;
    wire [7:0] phase;
    wire [15:0] sample;
    wire [6:0] events=keyboardMode ? {gWon,gOver,gBlack,gBlue,gRed,gStart,keyValid} : directEvents;
    keyPad_decoder keyboard(clk,resetN,keyCode,make,brakee,numberKey,plus,back,slash,del,enter,minus,star,num,key,keyValid);
    game_controller game(.clk(clk),.resetN(resetN),.startOfFrame(1'b0),.snakeHead_DR(1'b0),
        .snakeSelfCollision(1'b0),.border_DR(1'b0),.obstacle_DR(1'b0),.redApple_DR(1'b0),
        .blueApple_DR(1'b0),.blackApple_DR(1'b0),.score_Low(4'd0),.score_High(4'd0),.key_5(enter),
        .gameStarted(gStarted),.gameStartPulse(gStart),.gameEndPulse(gEnd),.gameOverPulse(gOver),
        .gameWonPulse(gWon),.redAppleHitPulse(gRed),.blueAppleHitPulse(gBlue),.blackAppleHitPulse(gBlack));
    sound_effect_controller selector(clk,resetN,events[1],events[5],events[6],events[2],events[3],events[4],events[0],start,requestID);
    melody_player_1 dut(resetN,clk,start,requestID,tone,octave,enabled,ended);
    defparam dut.mili_sec_counter_inst.SIMULATION_MODE=1;
    ToneDecoder pitch(tone,octave,divisor);
    prescaler divider(clk,resetN,divisor,stepEnable,unusedStep);
    addr_counter oscillator(clk,resetN,stepEnable,enabled,phase);
    sintable wave(clk,resetN,phase,volume,sample);
    bit initialized=0,testPassed=0;
    integer checks=0,clocks=0,idleClocks=0,played=0,heldNonzero=0;
    logic [15:0] heldSample=0;
    task automatic check(input logic ok,input string message);
        checks++;if(ok!==1'b1)$fatal(1,"NOISE_OUTPUT cycle=%0d: %s",clocks,message);
    endtask
    function automatic logic [15:0] expand(input logic [7:0] value,input logic [1:0] level);
        case(level)
            0:expand=0;
            1:expand={{3{value[7]}},value,{5{value[7]}}};
            2:expand={{2{value[7]}},value,{6{value[7]}}};
            3:expand={value[7],value,{7{value[7]}}};
        endcase
    endfunction
    always @(posedge clk)begin
        logic [7:0] oldPhase,expectedPhase,expectedSample8;
        logic [1:0] expectedVolume;
        bit wasReset,volumeChanged;
        oldPhase=phase;wasReset=!resetN;
        expectedPhase=wasReset?0:((stepEnable && enabled)?oldPhase+8'd1:oldPhase);
        expectedSample8=wasReset?0:wave.sin_table[oldPhase];
        expectedVolume=wasReset?3:((!volume && wave.volume_d)?wave.volume_level-2'd1:wave.volume_level);
        volumeChanged=(expectedVolume!=wave.volume_level);
        #2;clocks++;
        if(initialized)begin
            check(!$isunknown({sample,phase,enabled,ended,tone,octave,divisor,dut.SM_Maestro}),"known controls and every codec-input sample");
            check(phase===expectedPhase,"continuous phase enable/gating and wrap");
            check(sample===expand(expectedSample8,expectedVolume),"every 16-bit sample is exact unchanged lookup/volume expansion");
            check($signed(sample)>=-16257 && $signed(sample)<=16256,"PCM never exceeds existing volume envelope");
            if(enabled)check(tone<=11 && octave>=3 && octave<=6 && divisor>=58 && divisor<=470,"valid active pitch and divider bounds");
            if(wasReset)begin idleClocks=0;heldSample=sample;end
            else if(dut.SM_Maestro==dut.s_idle && !start && !volumeChanged)begin
                idleClocks++;
                if(idleClocks>3)check(sample===heldSample,"no indefinitely changing output after playback completes");
                heldSample=sample;
            end else idleClocks=0;
        end
    end
    task automatic cycle;
        @(posedge clk);#3;@(negedge clk);
    endtask
    task automatic resetAudio(input integer offset);
        directEvents=0;make=0;brakee=0;
        #1;resetN=0;initialized=1;repeat(4)cycle();
        #(offset+1);resetN=1;repeat(4)cycle();
    endtask
    task automatic finishAndMonitor;
        integer guard;
        guard=0;
        while(!ended && guard<12000)begin cycle();guard++;end
        check(ended,"effect terminates rather than running indefinitely");played++;
        repeat(10000)cycle();
        check(!enabled && dut.SM_Maestro==dut.s_idle,"stable completed state throughout long idle tail");
        if(sample!=0)heldNonzero++;
    endtask
    initial begin
        integer codes[0:4];
        codes[0]='h073;codes[1]='h06b;codes[2]='h05a;codes[3]='h074;codes[4]='h075;
        resetAudio(2);
        // Each sound-producing physical keypad key immediately after async
        // reset, at several sub-cycle reset-release offsets.
        for(integer offset=0;offset<4;offset++)for(integer k=0;k<5;k++)begin
            resetAudio(offset*5);keyboardMode=1;
            keyCode=codes[k];make=1;cycle();make=0;repeat(4)cycle();
            brakee=1;cycle();brakee=0;finishAndMonitor();
        end
        keyboardMode=0;
        for(integer repeatID=0;repeatID<4;repeatID++)for(integer id=0;id<6;id++)begin
            directEvents=7'b1<<((id==0)?6:(id==1)?5:(id==3)?4:(id==2)?3:(id==5)?2:0);
            cycle();directEvents=0;repeat(2)cycle();finishAndMonitor();
        end
        // Inject reset in fetch, note and gap; then verify all requests again.
        for(integer stateID=1;stateID<=4;stateID++)begin
            resetAudio(3);directEvents=16;cycle();directEvents=0;
            while(dut.SM_Maestro!=stateID)cycle();
            resetAudio(stateID);directEvents=2;cycle();directEvents=0;repeat(2)cycle();finishAndMonitor();
        end
        for(integer v=0;v<4;v++)begin volume=0;repeat(3)cycle();volume=1;repeat(100)cycle();end
        check(wave.volume_level==3,"mute/wrap unchanged");
        $display("AUDIO_NOISE_OUTPUT_PASS checks=%0d clocks=%0d effects=%0d held_nonzero=%0d",checks,clocks,played,heldNonzero);
        testPassed=1;$finish;
    end
    initial begin #50000000;$fatal(1,"Noise output timeout");end
endmodule
