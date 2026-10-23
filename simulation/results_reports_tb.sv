`timescale 1ns/1ps
module results_reports_tb;
    bit testPassed=0;
    logic clk=0,resetN=0;
    always #5 clk=~clk;
    logic [8:0] code=0;
    logic makeKey=0,breakKey=0;
    wire [9:0] keys;
    wire plusKey,backKey,slashKey,delKey,enterKey,minusKey,starKey,numKey,keyValid;
    wire [3:0] keyNumber;
    keyPad_decoder decoder(clk,resetN,code,makeKey,breakKey,keys,plusKey,backKey,
        slashKey,delKey,enterKey,minusKey,starKey,numKey,keyNumber,keyValid);
    logic sof=0,wall=0,selfHit=0,redDR=0,blueDR=0,blackDR=0;
    wire running,startEvent,endEvent,lost,won,redEvent,blueEvent,blackEvent;
    wire [3:0] sl,sh,hl,hh;
    wire [11:0] ruby,sapphire,cursed;
    game_controller game(clk,resetN,sof,1'b1,selfHit,wall,1'b0,redDR,blueDR,blackDR,
        sl,sh,enterKey,running,startEvent,endEvent,lost,won,redEvent,blueEvent,blackEvent);
    appleCounter score(clk,resetN,startEvent,redEvent,blueEvent,blackEvent,sl,sh);
    highscoreComp high(clk,resetN,endEvent,sl,sh,hl,hh);
    relic_collection_counters counts(clk,resetN,startEvent,redEvent,blueEvent,blackEvent,ruby,sapphire,cursed);
    logic manualMode=0,manualWon=0,manualLost=0,manualStart=0;
    logic [7:0] manualScore=0;
    logic [11:0] manualRuby=0,manualSapphire=0,manualCursed=0;
    wire wp=manualMode?manualWon:won, lp=manualMode?manualLost:lost, sp=manualMode?manualStart:startEvent;
    wire [7:0] scoreValue=manualMode?manualScore:{sh,sl};
    wire [11:0] rv=manualMode?manualRuby:ruby, sv=manualMode?manualSapphire:sapphire, cv=manualMode?manualCursed:cursed;
    logic [10:0] px=1023,py=1023;
    wire dr,oldDR;
    wire [7:0] color,oldColor,sceneColor,baseColor;
    end_message_display display(clk,resetN,px,py,wp,lp,sp,scoreValue[3:0],scoreValue[7:4],rv,sv,cv,dr,color);
    previous_end_message_display previous(clk,resetN,px,py,wp,lp,sp,oldDR,oldColor);
    wire signed [10:0] sx,sy,hix,hiy;
    wire [10:0] sox,soy,hox,hoy;
    wire ss,hs,sd,hd;
    wire [7:0] unusedS,unusedH,srgb,hrgb;
    ScoreConstants hudOrigins(sx,sy,hix,hiy);
    square_object #(.OBJECT_WIDTH_X(32),.OBJECT_HEIGHT_Y(18)) scoreBox(clk,resetN,px,py,sx,sy,sox,soy,ss,unusedS);
    square_object #(.OBJECT_WIDTH_X(32),.OBJECT_HEIGHT_Y(18)) highBox(clk,resetN,px,py,hix,hiy,hox,hoy,hs,unusedH);
    NumbersBitMap hud(clk,resetN,sox,soy,ss,scoreValue[3:0],scoreValue[7:4],hox,hoy,hs,hl,hh,px,py,rv,sv,cv,sd,srgb,hd,hrgb);
    // Both muxes have identical live HUD/other inputs; only the report differs.
    objects_mux scene(clk,resetN,1'b0,8'h11,1'b0,8'h22,sd,srgb,hd,hrgb,1'b0,8'h55,dr,color,8'h04,sceneColor);
    objects_mux baseline(clk,resetN,1'b0,8'h11,1'b0,8'h22,sd,srgb,hd,hrgb,1'b0,8'h55,1'b0,8'h00,8'h04,baseColor);
    reg [8:0] victory[0:124415],defeat[0:124415];
    reg font[0:8191];
    integer checks=0,x,y,i,j,px1=1023,py1=1023,px2=1023,py2=1023;
    integer expectedState=0;
    logic [7:0] expectedScore=0;
    logic [11:0] expectedRuby=0,expectedSapphire=0,expectedCursed=0;
    task automatic check(input bit ok,input string why);
        checks++;
        if(!ok)$fatal(1,"%s at %0d,%0d time%0t",why,px1,py1,$time);
    endtask
    function automatic bit insidePanel(input integer xx,yy);
        return xx>=248 && xx<536 && yy>=24 && yy<456;
    endfunction
    function automatic logic [8:0] expectedPixel(input integer xx,yy);
        integer row,dx,dy,digit,addr,fx,fy;
        logic [11:0] value;
        logic [7:0] ink;
        logic [8:0] base;
        begin
            addr=(yy-24)*288+xx-248;
            base=expectedState==1?victory[addr]:defeat[addr];
            row=-1;dx=0;dy=0;digit=0;value=0;ink=0;
            if(expectedState==1)begin
                if(xx>=438 && xx<474 && yy>=290 && yy<304)begin row=1;dx=xx-438;dy=yy-290;value=expectedRuby;ink=8'hED;end
                else if(xx>=437 && xx<473 && yy>=331 && yy<345)begin row=2;dx=xx-437;dy=yy-331;value=expectedSapphire;ink=8'h57;end
                else if(xx>=437 && xx<473 && yy>=371 && yy<385)begin row=3;dx=xx-437;dy=yy-371;value=expectedCursed;ink=8'hB3;end
            end else begin
                if(xx>=443 && xx<467 && yy>=230 && yy<244)begin
                    row=0;dx=xx-443;dy=yy-230;ink=8'hF9;
                    digit=dx<12?expectedScore[7:4]:expectedScore[3:0];
                end else if(xx>=431 && xx<467)begin
                    dx=xx-431;
                    if(yy>=286 && yy<300)begin row=1;dy=yy-286;value=expectedRuby;ink=8'hED;end
                    else if(yy>=324 && yy<338)begin row=2;dy=yy-324;value=expectedSapphire;ink=8'h57;end
                    else if(yy>=363 && yy<377)begin row=3;dy=yy-363;value=expectedCursed;ink=8'hB3;end
                end
            end
            if(row>0)digit=dx<12?value[11:8]:dx<24?value[7:4]:value[3:0];
            // Independent arithmetic nearest-neighbor reference, not RTL LUTs.
            fx=((2*(dx%12)+1)*16)/24;
            fy=6+((2*dy+1)*18)/28;
            if(row>=0 && font[digit*512+fy*16+fx])return {1'b1,ink};
            return base;
        end
    endfunction
    function automatic bit expectedDR(input integer xx,yy);
        logic [8:0] pixel;
        if(!insidePanel(xx,yy))return 0;
        pixel=expectedPixel(xx,yy);
        return pixel[8];
    endfunction
    task automatic scan(input integer nx,ny);
        @(negedge clk);px=nx;py=ny;
        @(posedge clk);#1;
        check(dr===expectedDR(px1,py1),"two-stage report alpha/request; panel-only, never HUD");
        if(expectedDR(px1,py1))check(color===(expectedPixel(px1,py1)&9'h0FF),"actual supplied MIF/mask/font pixel aligned");
        if(expectedDR(px2,py2))check(sceneColor===(expectedPixel(px2,py2)&9'h0FF),"registered compositor priority/latency");
        else check(sceneColor===baseColor,"HUD, exterior frame and other scene pixels unchanged");
        check(display.results.map_rom.addressD<62208 && display.results.payload_rom.addressD<69628,
              "lossless map/payload ROM addresses valid including blanking");
        px2=px1;py2=py1;px1=nx;py1=ny;
    endtask
    task automatic keyEvent(input bit pressed);
        @(negedge clk);code=9'h05A;makeKey=pressed;breakKey=!pressed;
        @(negedge clk);makeKey=0;breakKey=0;
        repeat(5)@(negedge clk);
    endtask
    task automatic collect(input integer kind);
        @(negedge clk);sof=1;
        @(negedge clk);sof=0;
        @(negedge clk);redDR=kind==1;blueDR=kind==2;blackDR=kind==3;
        repeat(4)@(negedge clk);redDR=0;blueDR=0;blackDR=0;
        repeat(5)@(negedge clk);
    endtask
    task automatic snapshotCheck(input integer state);
        check(display.results.statisticsReady && display.results.resultState==state,"terminal state and delayed capture ready");
        check(display.results.finalScoreBCD=={sh,sl} && display.results.finalRubyBCD==ruby &&
              display.results.finalSapphireBCD==sapphire && display.results.finalCursedBCD==cursed,
              "settled score and all three collection counters captured exactly");
    endtask
    task automatic prepare(input integer state,input logic[7:0] scoreBCD,input logic[11:0] a,b,c);
        manualMode=1;
        @(negedge clk);manualStart=1;
        @(negedge clk);manualStart=0;
        repeat(4)@(negedge clk);
        manualScore=scoreBCD;manualRuby=a;manualSapphire=b;manualCursed=c;
        manualWon=state==1;manualLost=state==2;
        @(negedge clk);manualWon=0;manualLost=0;
        repeat(5)@(negedge clk);
        expectedState=state;expectedScore=scoreBCD;expectedRuby=a;expectedSapphire=b;expectedCursed=c;
        check(display.results.finalScoreBCD==scoreBCD && display.results.finalRubyBCD==a &&
              display.results.finalSapphireBCD==b && display.results.finalCursedBCD==c,"independent dynamic report inputs");
        px1=1023;py1=1023;px2=1023;py2=1023;
    endtask
    initial begin
        $readmemh("db/results_v3_fixture/victory_rgba.hex",victory);
        $readmemh("db/results_v3_fixture/defeat_rgba.hex",defeat);
        $readmemh("db/results_v3_fixture/font.hex",font);
        #12;resetN=1;repeat(5)@(negedge clk);
        // Frozen production MENU comparison, including native patch boundaries.
        for(y=0;y<480;y++)for(x=0;x<640;x++)begin
            @(negedge clk);px=x;py=y;
            @(posedge clk);#1;
            check(dr===oldDR && color===oldColor,"opening renderer byte/cycle identical to previous production");
        end
        px=1023;py=1023;repeat(5)@(negedge clk);
        keyEvent(1);
        check(running,"Enter starts game");
        for(i=0;i<5;i++)collect(1);
        collect(3); // lethal at5: score0, Ruby5, Cursed1, original highscore5.
        check(!running && {sh,sl}==0 && ruby==5 && cursed==1 && {hh,hl}==5,"fatal Cursed applies existing score/count/highscore semantics");
        snapshotCheck(2);
        repeat(3)keyEvent(1);
        check(!running && display.results.statisticsReady,"held/typematic5 cannot restart defeat");
        keyEvent(0);keyEvent(1);
        check(running && {sh,sl,ruby,sapphire,cursed}==0 && {hh,hl}==5 &&
              display.results.resultState==0 && !dr,"restart clears report and per-game state; retains highscore");
        for(i=0;i<89;i++)collect(1);
        check(running && {sh,sl}==8'h89,"no early victory below90");
        collect(2);
        check(!running && {sh,sl}==8'h92 && sapphire==1 && ruby==12'h089,"Sapphire skips90 and triggers existing victory");
        snapshotCheck(1);
        check(!display.menuActive,"local restart never returns to opening");
        keyEvent(0);keyEvent(1);
        check(running && {hh,hl}==8'h92,"victory fresh-press restart preserves highscore");
        wall=1;repeat(8)@(negedge clk);wall=0;snapshotCheck(2);
        // Six complete frames: independent counters, all zero, all supported maxima.
        for(j=0;j<6;j++)begin
            if(j<2)prepare(j+1,8'h67,12'h045,12'h016,12'h003);
            else if(j<4)prepare(j-1,8'h00,12'h000,12'h000,12'h000);
            else prepare(j-3,8'h99,12'h999,12'h999,12'h999);
            for(y=0;y<480;y++)for(x=0;x<640;x++)scan(x,y);
            scan(640,480);scan(2047,2047);scan(0,480);scan(640,0);scan(1023,1023);scan(1023,1023);
        end
        // Every decimal digit at each field, plus irregular coordinates/transitions.
        for(j=0;j<10;j++)begin
            prepare(2,j*17,j*273,((j+3)%10)*273,((j+7)%10)*273);
            for(y=230;y<386;y++)for(x=431;x<475;x++)scan(x,y);
            for(i=0;i<64;i++)scan((i*107)%700,(i*179)%520);
            scan(1023,1023);scan(1023,1023);
        end
        @(negedge clk);resetN=0;repeat(3)@(negedge clk);resetN=1;
        repeat(6)@(negedge clk);
        check(display.menuActive && display.results.resultState==0 && !display.results.statisticsReady,
              "hardware reset clears result snapshot and restores original opening");
        $display("RESULTS_V3_REPORTS_PASS:%0d checks; six full frames; native full-art lossless tiles/alpha/font/DR/mux; dynamic values; fatal Cursed;92 victory;Enter restart;unchanged HUD/opening",checks);
        testPassed=1;$finish;
    end
    initial begin #40000000;$fatal(1,"results-report test timeout");end
endmodule
