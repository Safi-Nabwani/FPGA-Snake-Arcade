`timescale 1ns/1ps
// Digital audio path only: no simulation of the opaque codec QXP or analog output.
// FAST changes only the existing timing instance's simulation parameter.
module audio_timer_reset_tb #(parameter bit FAST=1);
    logic clk=0, resetN=1;
    always #5 clk=~clk;
    logic directMode=1, directStart=0, volume=1;
    logic [3:0] directBank=4;
    logic [6:0] events=0;
    wire requestedStart;
    wire [3:0] requestedBank;
    wire start=directMode ? directStart : requestedStart;
    wire [3:0] bank=directMode ? directBank : requestedBank;
    wire [3:0] tone,oldTone;
    wire [2:0] octave,oldOctave;
    wire enabled,oldEnabled,ended,oldEnded;
    wire [11:0] divisor,oldDivisor;
    wire stepEnable,oldStepEnable,unusedStep,oldUnusedStep;
    wire [7:0] phase,oldPhase;
    wire [15:0] sample,oldSample;
    integer checks=0,cycles=0,completed=0,resetTests=0,resetDifferences=0;
    integer durationLoads=0,decrements=0,zeroGaps=0,nonzeroGaps=0;
    integer lastTick=-1,ticks=0,activeComparisons=0;
    bit resetSeen=0,compareTimer=0,testPassed=0;
    bit [3:0] statesSeen=0;

    sound_effect_controller selector(clk,resetN,events[1],events[5],events[6],
        events[2],events[3],events[4],events[0],requestedStart,requestedBank);
    melody_player_1 dut(resetN,clk,start,bank,tone,octave,enabled,ended);
    audio_timer_reset_reference legacy(resetN,clk,start,bank,oldTone,oldOctave,oldEnabled,oldEnded);
    defparam dut.mili_sec_counter_inst.SIMULATION_MODE=FAST;
    defparam legacy.mili_sec_counter_inst.SIMULATION_MODE=FAST;

    ToneDecoder pitch(tone,octave,divisor);
    ToneDecoder oldPitch(oldTone,oldOctave,oldDivisor);
    prescaler divider(clk,resetN,divisor,stepEnable,unusedStep);
    prescaler oldDivider(clk,resetN,oldDivisor,oldStepEnable,oldUnusedStep);
    addr_counter oscillator(clk,resetN,stepEnable,enabled,phase);
    addr_counter oldOscillator(clk,resetN,oldStepEnable,oldEnabled,oldPhase);
    sintable wave(clk,resetN,phase,volume,sample);
    sintable oldWave(clk,resetN,oldPhase,volume,oldSample);

    task automatic check(input logic ok,input string message);
        checks++;
        if(ok!==1'b1) $fatal(1,"AUDIO_RESET fast=%0d cycle=%0d: %s",FAST,cycles,message);
    endtask

    // Independent one-edge oracle, plus cycle-exact frozen-module comparison.
    always @(posedge clk) begin : monitor
        integer s,c,i,d,g,nextState,nextCount,nextIndex;
        logic nextEnable,nextEnded,wasReset,wasStart,wasTick;
        logic [11:0] romAddress;
        s=dut.SM_Maestro;c=dut.noteTimeCounter;i=dut.noteIndex;
        d=dut.noteDuration;g=dut.gapDuration;
        wasReset=!resetN;wasStart=start;wasTick=dut.hundredthSecPulse;
        romAddress={bank,dut.noteIndex};
        nextState=s;nextCount=c;nextIndex=i;nextEnable=0;nextEnded=0;
        if(wasReset) begin
            nextState=0;nextCount=0;nextIndex=0;compareTimer=0;
        end else begin
            case(s)
                0:begin
                    nextIndex=0;
                    if(wasStart)begin nextCount=d;nextState=1;compareTimer=1;durationLoads++;end
                end
                1:begin
                    nextEnable=1;
                    if(d!=0)begin
                        if(wasTick)begin nextCount=(c-1)&31;decrements++;end
                        if(c==0)begin
                            nextIndex=(i+1)&255;nextState=2;nextCount=g;
                            if(g==0)zeroGaps++;else nonzeroGaps++;
                        end
                    end else nextState=3;
                end
                2:begin
                    if(wasTick)begin nextCount=(c-1)&31;decrements++;end
                    if(c==0)begin nextState=1;nextCount=d;durationLoads++;end
                end
                3:begin nextEnded=1;nextState=0;end
                default:nextState=0;
            endcase
        end
        #1;cycles++;
        if(resetSeen)begin
            check(!$isunknown(dut.noteTimeCounter),"timer stays known after reset, including ROM changes");
            check(dut.SM_Maestro==nextState && dut.noteTimeCounter==nextCount &&
                  dut.noteIndex==nextIndex && enabled===nextEnable && ended===nextEnded,
                  "exact synchronous duration/gap/FSM oracle without scheduling fixes");
            check({tone,octave,enabled,ended,dut.noteIndex,dut.SM_Maestro,dut.songs_mem,
                   divisor,stepEnable,phase,sample} ===
                  {oldTone,oldOctave,oldEnabled,oldEnded,legacy.noteIndex,legacy.SM_Maestro,
                   legacy.songs_mem,oldDivisor,oldStepEnable,oldPhase,oldSample},
                  "old/new notes, requests, timing, waveform phase and 16-bit codec-input sample match");
            if(compareTimer && !wasReset)begin
                check(dut.noteTimeCounter===legacy.noteTimeCounter,"timer equivalence after accepted synchronous load");
                activeComparisons++;
            end
            if(!$isunknown(romAddress))
                check(dut.songs_mem===dut.rom_inst.data[romAddress],"actual MIF data with one registered address stage");
            if(!compareTimer && dut.noteTimeCounter!==legacy.noteTimeCounter)resetDifferences++;
            statesSeen[dut.SM_Maestro]=1;
            if(!wasReset && dut.hundredthSecPulse)begin
                if(lastTick>=0)check(cycles-lastTick==(FAST?21:945001),"inclusive timing divider period in clock cycles");
                lastTick=cycles;ticks++;
            end
            if(wasReset)lastTick=-1;
        end
    end

    task automatic cycle;
        @(posedge clk);#2;@(negedge clk);
    endtask
    task automatic settle;
        repeat(4)cycle();
    endtask
    task automatic assertReset(input bit corruptROM);
        // Assert between clock edges: zero must appear before the next posedge.
        #2;resetN=0;compareTimer=0;resetSeen=1;#1;
        check(dut.noteTimeCounter===5'd0 && dut.SM_Maestro==0 &&
              dut.noteIndex==0 && !enabled && !ended,"asynchronous constant reset, not delayed to clock");
        directStart=0;events=0;settle();
        directBank=3;settle();
        check(dut.noteTimeCounter===0,"held reset ignores a different nonzero ROM duration");
        if(corruptROM)begin
            directBank=4'bxxxx;settle();
            check($isunknown(dut.noteDuration) && dut.noteTimeCounter===0,
                "unknown ROM data during held reset cannot contaminate corrected timer");
        end
        directBank=4;settle();
        #1;resetN=1;settle();resetTests++;
        check(dut.noteTimeCounter===0 && dut.SM_Maestro==0,"reset release holds deterministic idle timer");
    endtask
    task automatic play(input integer selected);
        integer guard;
        directBank=selected;directStart=1;cycle();directStart=0;
        guard=0;
        while(!ended && guard<(FAST?20000:2500000))begin cycle();guard++;end
        check(ended && dut.SM_Maestro==0,"effect completes and returns to idle");
        completed++;settle();
    endtask
    task automatic waitState(input integer selectedState,input bit zeroCounter);
        integer guard;
        guard=0;
        while((dut.SM_Maestro!=selectedState ||
               (zeroCounter && dut.noteTimeCounter!=0)) && guard<20000)begin cycle();guard++;end
        check(dut.SM_Maestro==selectedState && (!zeroCounter || dut.noteTimeCounter==0),
              "requested reset-injection playback phase reached");
    endtask
    function automatic integer priorityBank(input integer mask);
        if(mask&64)priorityBank=0;
        else if(mask&32)priorityBank=1;
        else if(mask&16)priorityBank=3;
        else if(mask&8)priorityBank=2;
        else if(mask&4)priorityBank=5;
        else priorityBank=4;
    endfunction

    initial begin : stimulus
        integer p,b,r,mask;
        #2;resetN=0;resetSeen=1;#1;
        check(dut.noteTimeCounter===0,"first asynchronous initialization is known zero");
        settle();#1;resetN=1;settle();
        if(!FAST)begin
            play(4);
            check(ticks>=2 && activeComparisons>1800000,"real 945001-cycle ticks exercised with full player/waveform equivalence");
            $display("AUDIO_TIMER_REAL_TICK_PASS checks=%0d clocks=%0d ticks=%0d",checks,cycles,ticks);
        end else begin
            assertReset(1); // Idle + held reset while ROM becomes unknown.
            // All six effects from every settled previous bank. Preserve stale
            // first-duration and zero-gap scheduling behavior intentionally.
            for(p=0;p<6;p++)for(b=0;b<6;b++)begin
                directBank=p;settle();play(b);
            end
            directBank=3;settle();directStart=1;cycle();directStart=0;
            waitState(1,0);assertReset(0); // Playing note.
            directBank=2;settle();directStart=1;cycle();directStart=0;
            waitState(2,0);assertReset(1); // Gap, changing ROM/reset data.
            directBank=0;settle();directStart=1;cycle();directStart=0;
            waitState(1,1);cycle();assertReset(0); // Note-index transition.
            for(r=0;r<12;r++)begin
                directBank=r%6;settle();directStart=1;cycle();directStart=0;
                repeat(r%9)cycle();assertReset(r%3==0);
            end
            // Real selector inputs exercise all simultaneous event combinations,
            // later low-priority overrides and busy-bank splicing without fixes.
            directMode=0;events=2;cycle();events=0;settle();
            for(mask=1;mask<128;mask++)begin
                events=mask;cycle();
                check(requestedStart && requestedBank==priorityBank(mask),"original simultaneous-event priority");
                events=0;cycle();
                repeat(mask%7)cycle();
            end
            events=0;repeat(1000)cycle();
            for(r=0;r<4;r++)begin
                volume=0;settle();volume=1;settle();
                check(wave.volume_level==((2-r)&3),"unchanged global volume cycle, including mute and wrap");
            end
            directMode=1;directBank=4;directStart=0;settle();
            assertReset(0);play(5);play(4);
            check(statesSeen==4'b1111 && zeroGaps>0 && nonzeroGaps>0 &&
                  decrements>0 && durationLoads>0 && resetDifferences>0,
                  "all states/gap kinds/load/decrement/reset differences covered");
            $display("AUDIO_TIMER_RESET_PASS checks=%0d clocks=%0d effects=%0d resets=%0d reset_differences=%0d loads=%0d decrements=%0d zero_gaps=%0d nonzero_gaps=%0d active_comparisons=%0d",
                checks,cycles,completed,resetTests,resetDifferences,durationLoads,decrements,zeroGaps,nonzeroGaps,activeComparisons);
        end
        testPassed=1;$finish;
    end
    initial begin #40000000;$fatal(1,"audio timer reset timeout");end
endmodule

module audio_timer_reset_real_tb;
    audio_timer_reset_tb #(.FAST(0)) test();
endmodule
