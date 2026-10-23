`timescale 1ns/1ps
// Controls: keypad 8/4/6/5 = Up/Left/Right/Down; either Enter = Start/Restart.
module keypad_remap_tb;
    reg clk=0,resetN=0,make=0,brakee=0,sof=0,wall=0;
    reg [8:0] code=0;
    reg [3:0] low=0,high=0;
    wire [9:0] keys;
    wire plus,back,slash,del,enterKey,minus,star,num,valid;
    wire [3:0] key;
    wire running,startPulse,endPulse,lost,won,ruby,sapphire,cursed;
    wire signed [10:0] x,y;
    wire [2:0] direction;
    wire soundStart;
    wire [3:0] soundID;
    reg testPassed=0;
    integer checks=0,starts=0,moves=0,restarts=0;
    reg [8:0] directions[0:3];
    keyPad_decoder decoder(clk,resetN,code,make,brakee,keys,plus,back,slash,del,enterKey,minus,star,num,key,valid);
    game_controller game(clk,resetN,sof,1'b1,1'b0,wall,1'b0,1'b0,1'b0,1'b0,
        low,high,enterKey,running,startPulse,endPulse,lost,won,ruby,sapphire,cursed);
    snake_head head(clk,resetN,sof,keys[8],keys[6],keys[4],keys[5],running,11'sd130,x,y,direction);
    sound_effect_controller sound(clk,resetN,startPulse,lost,won,ruby,sapphire,cursed,valid,soundStart,soundID);
    always #5 clk=~clk;
    always @(posedge clk) begin
        #1;
        if(resetN && startPulse) starts++;
        if(resetN && soundStart && soundID==4) moves++;
        if(resetN && soundStart && soundID==6) restarts++;
    end
    task check(input bit ok,input string message);
        checks++; if(!ok) $fatal(1,"%s",message);
    endtask
    task eventKey(input reg [8:0] value,input bit pressed);
        @(negedge clk); code=value;make=pressed;brakee=!pressed;
        @(posedge clk);#2;
        check(valid===(pressed && (value==9'h075 || value==9'h074 || value==9'h06B || value==9'h073)),"exact movement/sound make pulse");
        @(negedge clk);make=0;brakee=0;
        repeat(4) @(negedge clk);
        check(!valid,"movement pulse clears; break does not generate sound");
    endtask
    task resetGame;
        @(negedge clk);resetN=0;make=0;brakee=0;wall=0;low=0;high=0;
        repeat(3) @(negedge clk);
        check(keys==0 && !enterKey && !valid,"reset clears all held keys");
        resetN=1;repeat(3) @(negedge clk);
    endtask
    initial begin
        integer beforeStart,beforeMove;
        directions[0]=9'h075;directions[1]=9'h074;directions[2]=9'h06B;directions[3]=9'h073;
        for(integer d=0;d<4;d++) begin
            resetGame();
            eventKey(9'h072,1);check(!running && head.requestedDir==0,"keypad2 no longer moves/starts");eventKey(9'h072,0);
            eventKey(9'h175,1);check(keys==0,"extended arrow does not alias keypad8");eventKey(9'h175,0);
            eventKey(9'h073,1);check(!running,"keypad5 does not start game");eventKey(9'h073,0);
            beforeStart=starts;
            eventKey((d%2)?9'h15A:9'h05A,1);
            check(running && starts==beforeStart+1,"main/keypad Enter starts once");
            eventKey((d%2)?9'h15A:9'h05A,0);check(!enterKey,"Enter break clears held state");
            beforeMove=moves;eventKey(directions[d],1);
            check(moves==beforeMove+1 && head.requestedDir==d+1,"direction and original direction sound ID");
            for(integer f=0;f<22;f++) begin
                @(negedge clk);sof=1;@(negedge clk);sof=0;repeat(4) @(negedge clk);
            end
            case(d)
                0:check(y<240 && x==384,"Up movement");
                1:check(x>384 && y==240,"Right movement");
                2:check(x<384 && y==240,"Left movement");
                3:check(y>240 && x==384,"Down movement");
            endcase
            eventKey(directions[d],0);check(keys==0 && head.requestedDir==0,"direction release clears request");
        end
        resetGame();beforeStart=starts;
        eventKey(9'h05A,1);eventKey(9'h15A,1);eventKey(9'h05A,0);
        check(enterKey && starts==beforeStart+1,"two Enter keys tracked independently");
        wall=1;repeat(6) @(negedge clk);wall=0;
        check(!running && game.SMGame==3,"defeat entered");
        eventKey(9'h15A,1);check(!running,"held/typematic Enter cannot auto-restart");
        eventKey(9'h15A,0);check(!enterKey,"last Enter release clears level");
        eventKey(9'h15A,1);check(running && starts==beforeStart+2,"fresh keypad Enter restarts defeat");
        eventKey(9'h15A,0);
        high=9;low=0;repeat(6) @(negedge clk);
        check(!running && game.SMGame==2,"score90 victory preserved");
        high=0;eventKey(9'h05A,1);check(running && starts==beforeStart+3,"main Enter restarts victory");
        check(restarts==starts,"each game start retains explicit restart sound request");
        resetGame();
        testPassed=1;
        $display("KEYPAD_REMAP_PASS checks=%0d controls=8465+Enter main_and_extended=1 releases=1 typematic=1 defeat_restart=1 victory_restart=1 sound_IDs_preserved=1",checks);
        $finish;
    end
    initial begin #1000000; $fatal(1,"keypad test timeout"); end
endmodule
