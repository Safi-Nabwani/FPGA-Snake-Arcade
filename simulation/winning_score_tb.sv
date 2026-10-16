`timescale 1ns/1ps
// Exercise the actual controller and accumulator through real collection overlaps.
// No forced score registers: all boundary values are reached by collecting relics.
module winning_score_tb;
    bit testPassed=0;
    logic clk=0, resetN=0, sof=0, key5=0;
    logic red=0, blue=0, black=0, wall=0, obstacle=0, selfHit=0;
    always #5 clk=~clk;
    wire running,startEvent,endEvent,lost,won,rp,bp,kp;
    wire [3:0] sl,sh,hl,hh;
    wire [11:0] ruby,sapphire,cursed;
    game_controller game(clk,resetN,sof,1'b1,selfHit,wall,obstacle,red,blue,black,
        sl,sh,key5,running,startEvent,endEvent,lost,won,rp,bp,kp);
    appleCounter score(clk,resetN,startEvent,rp,bp,kp,sl,sh);
    highscoreComp high(clk,resetN,endEvent,sl,sh,hl,hh);
    relic_collection_counters counters(clk,resetN,startEvent,rp,bp,kp,ruby,sapphire,cursed);
    integer wins=0,losses=0,ends=0,reds=0,blues=0,blacks=0,checks=0;
    integer target;
    always @(posedge clk) begin
        #1;
        if(resetN) begin
            if(won) wins++;
            if(lost) losses++;
            if(endEvent) ends++;
            if(rp) reds++;
            if(bp) blues++;
            if(kp) blacks++;
        end
    end
    task automatic check(input bit ok,input string message);
        checks++;
        if(!ok)$fatal(1,"%s: score=%0d wins=%0d losses=%0d",message,sh*10+sl,wins,losses);
    endtask
    task automatic restart;
        @(negedge clk);key5=0;
        repeat(2)@(negedge clk);
        key5=1;
        repeat(5)@(negedge clk);
        key5=0;
        check(running && {sh,sl,ruby,sapphire,cursed}==0,"fresh start clears current totals without stale-score victory");
    endtask
    task automatic fresh;
        @(negedge clk);resetN=0;key5=0;sof=0;red=0;blue=0;black=0;
        wall=0;obstacle=0;selfHit=0;
        repeat(2)@(negedge clk);
        wins=0;losses=0;ends=0;reds=0;blues=0;blacks=0;resetN=1;
        repeat(2)@(negedge clk);
        check(!running && {sh,sl,hh,hl}==0,"hardware reset clears score/high score and waits for start");
        restart();
    endtask
    task automatic collect(input integer kind);
        @(negedge clk);sof=1;
        @(negedge clk);sof=0;
        red=kind==1;blue=kind==2;black=kind==3;
        // Held overlap spans several edges: precisely one event per frame.
        repeat(6)@(negedge clk);
        red=0;blue=0;black=0;
        repeat(3)@(negedge clk);
    endtask
    task automatic reach(input integer value);
        for(integer n=1;n<=value;n++) begin
            collect(1);
            check(sh*10+sl==n && sh<=9 && sl<=9,"decimal carries match real Ruby accumulation");
            check(running && wins==0 && ends==0,"every score 1..89 continues, including old threshold20");
        end
    endtask
    initial begin
        fresh();reach(89);
        $display("WIN90_CONTINUE_PASS: every score00..89 including20 and89");
        collect(1);
        check(!running && wins==1 && ends==1 && losses==0 && {sh,sl}==8'h90,
            "89+Ruby reaches90 and emits exactly one victory/end pulse");
        check({hh,hl}==8'h90 && ruby==12'h090 && reds==90,"90 high score and independent Ruby count");
        collect(2);collect(3);
        check(wins==1 && blues==0 && blacks==0 && {sh,sl}==8'h90,"terminal state ignores collections");
        restart();check({hh,hl}==8'h90,"local restart retains high score90");
        $display("WIN90_EXACT_PASS:90 victory, single pulse, terminal gating, stable restart");

        // Sapphire can land on90 or skip it to91/92 without changing arithmetic.
        for(target=87;target<=89;target++) begin
            fresh();reach(target);collect(2);
            check(sh*10+sl==target+3 && !running && wins==1 && ends==1 && losses==0,
                "Sapphire crossing90 triggers victory without equality-only comparison");
            check(hh*10+hl==target+3 && blues==1 && sapphire==1,"Sapphire +3 and high score retained exactly");
            restart();check(hh*10+hl==target+3,"overshoot restart retains original high-score behavior");
        end
        $display("WIN90_SAPPHIRE_PASS:87+3=90;88+3=91;89+3=92");

        fresh();reach(89);collect(3);
        check(running && sh*10+sl==84 && cursed==1 && blacks==1 && wins==0,"Cursed -5 below threshold unchanged");
        collect(2);check(running && sh*10+sl==87,"84+3 remains below90");
        collect(2);check(!running && sh*10+sl==90 && wins==1,"87+3 wins after Cursed penalty");
        fresh();reach(5);collect(3);
        check(!running && losses==1 && wins==0 && {sh,sl}==0,"lethal Cursed at5 unchanged");
        for(target=0;target<3;target++) begin
            fresh();reach(20);
            @(negedge clk);wall=target==0;obstacle=target==1;selfHit=target==2;
            repeat(5)@(negedge clk);
            check(!running && losses==1 && wins==0 && ends==1,"wall/obstacle/self collision still loses at20");
        end
        $display("WIN90_EFFECTS_PASS:penalties, local/hardware reset, collisions and original event behavior");
        $display("WINNING_SCORE_PASS:%0d checks",checks);
        testPassed=1;$finish;
    end
    initial begin #1000000;$fatal(1,"winning-score test timeout");end
endmodule
