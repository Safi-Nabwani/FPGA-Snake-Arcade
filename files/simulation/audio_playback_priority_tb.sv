`timescale 1ns/1ps
// Independent MIF/event/tick scoreboard. Does not copy the production FSM.
module audio_playback_priority_tb #(parameter bit FAST=1);
    logic clk=0,resetN=1;
    always #5 clk=~clk;
    logic directMode=1,directStart=0,gameMode=0,volume=1;
    logic [3:0] directID=4;
    logic [6:0] events=0;
    wire requestedStart;
    wire [3:0] requestedID;
    wire start=directMode ? directStart : requestedStart;
    wire [3:0] requestID=directMode ? directID : requestedID;
    wire [3:0] tone;
    wire [2:0] octave;
    wire enabled,ended;
    wire [11:0] divisor;
    wire stepEnable,unusedStep;
    wire [7:0] phase;
    wire [15:0] sample;
    logic key5=0,headDR=0,blackDR=0,wallDR=0;
    logic [3:0] scoreLow=0,scoreHigh=0;
    wire gStarted,gStart,gEnd,gOver,gWon,gRed,gBlue,gBlack;
    wire [6:0] selectedEvents=gameMode ? {gWon,gOver,gBlack,gBlue,gRed,gStart,1'b0} : events;
    game_controller game(.clk(clk),.resetN(resetN),.startOfFrame(1'b0),
        .snakeHead_DR(headDR),.snakeSelfCollision(1'b0),.border_DR(wallDR),
        .obstacle_DR(1'b0),.redApple_DR(1'b0),.blueApple_DR(1'b0),.blackApple_DR(blackDR),
        .score_Low(scoreLow),.score_High(scoreHigh),.key_5(key5),
        .gameStarted(gStarted),.gameStartPulse(gStart),.gameEndPulse(gEnd),
        .gameOverPulse(gOver),.gameWonPulse(gWon),.redAppleHitPulse(gRed),
        .blueAppleHitPulse(gBlue),.blackAppleHitPulse(gBlack));
    sound_effect_controller selector(clk,resetN,selectedEvents[1],selectedEvents[5],
        selectedEvents[6],selectedEvents[2],selectedEvents[3],selectedEvents[4],
        selectedEvents[0],requestedStart,requestedID);
    melody_player_1 dut(resetN,clk,start,requestID,tone,octave,enabled,ended);
    defparam dut.mili_sec_counter_inst.SIMULATION_MODE=FAST;
    ToneDecoder pitch(tone,octave,divisor);
    prescaler divider(clk,resetN,divisor,stepEnable,unusedStep);
    addr_counter oscillator(clk,resetN,stepEnable,enabled,phase);
    sintable wave(clk,resetN,phase,volume,sample);

    logic [15:0] golden [0:4095];
    bit seen [0:4095];
    bit initialized=0,testPassed=0,busy=0,wantEnable=0;
    integer checks=0,cycles=0,accepted=0,rejected=0,completions=0;
    integer bank=4,priorityLevel=0,noteIndex=0,noteLeft=0,gapLeft=0,fetchLeft=0;
    integer lastTick=-1,ticks=0,notes=0,zeroGaps=0,nonzeroGaps=0,resets=0;
    logic [15:0] wordHeld=0;
    bit [5:0] statesSeen=0;
    integer stateRequests[0:5];
    integer acceptedIDs[0:6];

    task automatic check(input logic ok,input string message);
        checks++;
        if(ok!==1'b1) $fatal(1,"AUDIO_PLAYBACK fast=%0d cycle=%0d bank=%0d index=%0d: %s",
            FAST,cycles,bank,noteIndex,message);
    endtask
    function automatic integer rankOf(input integer id);
        case(id)
            0:rankOf=7; 1:rankOf=6; 3:rankOf=5; 2:rankOf=4;
            5:rankOf=3; 6:rankOf=2; 4:rankOf=1; default:rankOf=0;
        endcase
    endfunction
    function automatic integer selectedID(input integer mask);
        if(mask&64)selectedID=0;
        else if(mask&32)selectedID=1;
        else if(mask&16)selectedID=3;
        else if(mask&8)selectedID=2;
        else if(mask&4)selectedID=5;
        else if(mask&2)selectedID=6;
        else selectedID=4;
    endfunction

    initial begin : readGolden
        integer fd,status,first,last,value,count,i;
        reg [4095:0] line;
        count=0;
        for(i=0;i<4096;i++)seen[i]=0;
        fd=$fopen("RTL/AUDIO/songs.mif","r");
        if(!fd)$fatal(1,"Missing authoritative songs.mif");
        while(!$feof(fd))begin
            status=$fgets(line,fd);
            status=$sscanf(line," [%h..%h] : %h;",first,last,value);
            if(status!=3)begin
                status=$sscanf(line,"%h : %h;",first,value);
                if(status==2)begin last=first;status=3;end
            end
            if(status==3)for(i=first;i<=last;i++)begin
                if(i<0 || i>=4096 || seen[i])$fatal(1,"Bad golden MIF record");
                golden[i]=value;seen[i]=1;count++;
            end
        end
        $fclose(fd);
        if(count!=4096)$fatal(1,"Incomplete golden MIF");
    end

    always @(posedge clk)begin : monitor
        bit acceptedNow,wantEnded,wasReset,wasTick;
        integer oldState,oldEvents,newRank,oldPhase;
        logic [11:0] oldAddress;
        wasReset=!resetN;wasTick=dut.hundredthSecPulse;
        oldState=dut.SM_Maestro;oldEvents=selectedEvents;
        oldAddress=dut.note_address;oldPhase=phase;
        acceptedNow=0;wantEnded=0;
        if(wasReset)begin
            bank=4;priorityLevel=0;noteIndex=0;noteLeft=0;gapLeft=0;fetchLeft=0;
            wordHeld=0;wantEnable=0;busy=0;lastTick=-1;
        end else if(initialized)begin
            newRank=rankOf(requestID);
            acceptedNow=start && newRank>0 && (requestID==6 || !busy || newRank>priorityLevel);
            if(start && oldState<6)stateRequests[oldState]++;
            if(acceptedNow)begin
                bank=(requestID==6)?4:requestID;
                priorityLevel=newRank;noteIndex=0;noteLeft=0;gapLeft=0;
                fetchLeft=2;wantEnable=0;busy=1;accepted++;acceptedIDs[requestID]++;
            end else begin
                if(start)rejected++;
                if(fetchLeft>0)begin
                    fetchLeft--;
                    if(fetchLeft==0)begin
                        if(golden[bank*256+noteIndex][9:5]==0)begin
                            busy=0;priorityLevel=0;wantEnable=0;wantEnded=1;completions++;
                        end else begin
                            wordHeld=golden[bank*256+noteIndex];
                            noteLeft=wordHeld[9:5];wantEnable=1;notes++;
                        end
                    end
                end else if(noteLeft>0 && wasTick)begin
                    noteLeft--;
                    if(noteLeft==0)begin
                        wantEnable=0;gapLeft=wordHeld[4:0];
                        if(gapLeft==0)begin zeroGaps++;noteIndex++;fetchLeft=2;end
                        else nonzeroGaps++;
                    end
                end else if(gapLeft>0 && wasTick)begin
                    gapLeft--;
                    if(gapLeft==0)begin noteIndex++;fetchLeft=2;end
                end
            end
            if(wasTick)begin
                if(lastTick>=0)check(cycles-lastTick==(FAST?21:945001),"unchanged inclusive free-running tick period");
                lastTick=cycles;ticks++;
            end
            check(!(gStart && (gWon||gOver||gRed||gBlue||gBlack)),"real game start excludes obsolete collection/terminal pulses");
        end
        #1;cycles++;
        if(initialized)begin
            check(!$isunknown({dut.SM_Maestro,dut.activeBank,dut.activePriority,dut.noteIndex,
                dut.noteTimeCounter,tone,octave,enabled,ended,divisor,phase,sample}),"all initialized audio controls/data stay known");
            check(dut.activeBank==bank && dut.activePriority==priorityLevel,"accepted bank/priority stable; rejected requests cannot splice bank");
            check(dut.noteIndex==noteIndex,"every accepted effect starts at zero and advances in order");
            check(enabled===wantEnable && ended===wantEnded,"note/gap/termination edge timing from independent MIF oracle");
            check(dut.noteTimeCounter==(noteLeft>0?noteLeft:gapLeft),"exact intended remaining note/gap ticks");
            check(tone===wordHeld[15:12] && octave==({1'b0,wordHeld[11:10]}+3'd3),"correct complete captured note word/pitch");
            if(!wasReset)begin
                check(requestedStart==(|oldEvents),"selector pulse timing");
                if(oldEvents)check(requestedID==selectedID(oldEvents),"same-edge priority, restart ID separate from direction");
                check(dut.songs_mem===golden[oldAddress],"registered-ROM address ordering against independent MIF array");
            end
            if(!wasReset && !acceptedNow && oldState==dut.s_gap)
                check(phase==oldPhase,"gap retains legacy held waveform phase rather than adding mute/reset");
            if(dut.SM_Maestro<6)statesSeen[dut.SM_Maestro]=1;
        end
    end

    task automatic cycle;
        @(posedge clk);#2;@(negedge clk);
    endtask
    task automatic resetAudio;
        directStart=0;events=0;gameMode=0;directMode=1;
        key5=0;headDR=0;blackDR=0;wallDR=0;scoreLow=0;scoreHigh=0;
        #2;resetN=0;initialized=1;#1;
        check(dut.noteTimeCounter===0 && !enabled && !ended,"asynchronous constant reset before next edge");
        repeat(3)cycle();#1;resetN=1;repeat(3)cycle();resets++;
    endtask
    task automatic emit(input integer id);
        directMode=1;directID=id;directStart=1;cycle();directStart=0;
    endtask
    task automatic finishEffect;
        integer guard;
        guard=0;
        while(!ended && guard<(FAST?12000:2500000))begin cycle();guard++;end
        check(ended,"sequence reached its terminator");
        repeat(3)cycle();
    endtask
    task automatic reachState(input integer target);
        integer guard;
        guard=0;
        while(dut.SM_Maestro!=target && guard<12000)begin cycle();guard++;end
        check(dut.SM_Maestro==target,"requested phase reached for event/reset injection");
    endtask

    initial begin : stimulus
        integer prior,id,incoming,target,mask,r,beforeAccepted;
        for(r=0;r<6;r++)stateRequests[r]=0;
        for(r=0;r<7;r++)acceptedIDs[r]=0;
        resetAudio();
        if(!FAST)begin
            emit(6);finishEffect();
            check(ticks>=2,"production timing traversed two actual 945001-clock intervals");
            $display("AUDIO_PLAYBACK_REAL_PASS checks=%0d clocks=%0d ticks=%0d notes=%0d",checks,cycles,ticks,notes);
        end else begin
            // All six sequences after every different previous bank, no reset
            // between effects. Oracle verifies EVERY duration, gap and word.
            for(prior=0;prior<6;prior++)for(id=0;id<6;id++)begin
                emit(prior);finishEffect();emit(id);finishEffect();
            end
            // Sweep every fast tick phase, including fetch crossing a pulse.
            for(r=0;r<21;r++)for(id=0;id<6;id++)begin
                resetAudio();repeat(r)cycle();emit(id);finishEffect();
            end
            // Every ordered pair, including equal/lower priority and restart,
            // injected in fetch-wait, load, note, gap and ended phases.
            for(target=1;target<6;target++)for(id=0;id<7;id++)for(incoming=0;incoming<7;incoming++)begin
                resetAudio();emit(id);
                if(target==4 && (id==4 || id==5 || id==6))continue;
                reachState(target);emit(incoming);repeat(4)cycle();
            end
            // Every simultaneous event mask through the actual registered
            // selector, once idle and once protected by a terminal sequence.
            for(mask=1;mask<128;mask++)begin
                resetAudio();directMode=0;events=mask;cycle();events=0;repeat(4)cycle();
                resetAudio();emit(0);repeat(3)cycle();
                directMode=0;events=mask;cycle();events=0;repeat(4)cycle();
            end
            // Reset in every state, including fetch and nonzero gap.
            for(target=0;target<6;target++)begin
                resetAudio();if(target!=0)begin emit(3);reachState(target);end
                resetAudio();emit(6);finishEffect();
            end
            // Requests one cycle apart: no independent bank/start race/queue.
            resetAudio();emit(5);emit(2);emit(3);emit(1);emit(0);
            beforeAccepted=accepted;emit(4);emit(5);emit(2);emit(3);emit(1);emit(0);
            check(accepted==beforeAccepted,"terminal rejects later direction/relic/equal/lower-terminal requests");
            emit(6);finishEffect();
            emit(15);repeat(3)cycle();check(!busy,"invalid request cannot play unselected legacy ROM banks");
            // Actual game-controller start, victory, restart and fatal Cursed.
            resetAudio();directMode=0;gameMode=1;key5=1;repeat(5)cycle();key5=0;
            scoreHigh=9;repeat(6)cycle();check(bank==0,"score90 requests Victory");
            key5=1;cycle();scoreHigh=0;repeat(5)cycle();key5=0;
            check(bank==4 && priorityLevel==2,"keypad5 cancels terminal and starts new game audio");
            scoreLow=4;headDR=1;blackDR=1;repeat(6)cycle();headDR=0;blackDR=0;
            check(bank==1,"fatal Cursed chooses Defeat, not explosion");
            key5=1;cycle();scoreLow=0;repeat(5)cycle();key5=0;
            check(bank==4 && priorityLevel==2,"restart cancels Defeat cleanly");
            for(r=0;r<4;r++)begin volume=0;repeat(3)cycle();volume=1;repeat(3)cycle();end
            check(wave.volume_level==3,"unchanged global volume cycle");
            check(statesSeen==6'b111111 && zeroGaps>0 && nonzeroGaps>0,"all states and both gap types covered");
            for(r=0;r<6;r++)check(stateRequests[r]>0,"requests exercised in every FSM phase");
            for(r=0;r<7;r++)check(acceptedIDs[r]>0,"all seven event IDs accepted");
            $display("AUDIO_PLAYBACK_PRIORITY_PASS checks=%0d clocks=%0d accepted=%0d rejected=%0d complete=%0d notes=%0d zero_gaps=%0d nonzero_gaps=%0d resets=%0d",
                checks,cycles,accepted,rejected,completions,notes,zeroGaps,nonzeroGaps,resets);
        end
        testPassed=1;$finish;
    end
    initial begin #40000000;$fatal(1,"audio playback timeout");end
endmodule

module audio_playback_real_tb;
    audio_playback_priority_tb #(.FAST(0)) test();
endmodule
