`timescale 1ns/1ps
module opening_screen_tb;
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
    logic sof=0,wall=1,selfHit=1,redDR=1,blueDR=1,blackDR=1;
    wire running,startEvent,endEvent,lost,won,redEvent,blueEvent,blackEvent;
    wire [3:0] sl,sh,hl,hh;
    wire [11:0] ruby,sapphire,cursed;
    game_controller game(clk,resetN,sof,1'b1,selfHit,wall,1'b0,redDR,blueDR,blackDR,
        sl,sh,keys[5],running,startEvent,endEvent,lost,won,redEvent,blueEvent,blackEvent);
    appleCounter score(clk,resetN,startEvent,redEvent,blueEvent,blackEvent,sl,sh);
    highscoreComp high(clk,resetN,endEvent,sl,sh,hl,hh);
    relic_collection_counters counts(clk,resetN,startEvent,redEvent,blueEvent,blackEvent,ruby,sapphire,cursed);
    wire signed [10:0] speed,hx,hy;
    wire [2:0] direction;
    speed_controller velocity(clk,resetN,startEvent,redEvent,blueEvent,blackEvent,speed);
    snake_head head(clk,resetN,sof,keys[8],keys[6],keys[4],keys[2],running,speed,hx,hy,direction);
    logic [10:0] px=1023,py=1023;
    wire bodyDR,bodySelf;
    wire [7:0] bodyRGB;
    wire [5:0] length;
    snake_body body(clk,resetN,startEvent,running,sof,px,py,hx,hy,
        redEvent,blueEvent,blackEvent,bodyDR,bodyRGB,length,bodySelf);
    wire messageDR,legacyDR;
    wire [7:0] messageRGB,legacyRGB,muxRGB;
    end_message_display display(clk,resetN,px,py,won,lost,startEvent,sl,sh,ruby,sapphire,cursed,messageDR,messageRGB);
    // Every competing layer is asserted to prove opaque menu/message priority.
    objects_mux mux(clk,resetN,1'b1,8'h11,1'b1,8'h22,1'b1,8'h33,
        1'b1,8'h44,1'b1,8'h55,messageDR,messageRGB,8'h66,muxRGB);
    // Actual unmodified HUD path, including live counters, not a menu sidebar ROM.
    wire signed [10:0] sx,sy,hix,hiy;
    wire [10:0] sox,soy,hox,hoy;
    wire ss,hs,sd,hd;
    wire [7:0] unusedS,unusedH,srgb,hrgb,sceneRGB;
    ScoreConstants hudOrigins(sx,sy,hix,hiy);
    square_object #(.OBJECT_WIDTH_X(32),.OBJECT_HEIGHT_Y(18)) scoreBox(clk,resetN,px,py,sx,sy,sox,soy,ss,unusedS);
    square_object #(.OBJECT_WIDTH_X(32),.OBJECT_HEIGHT_Y(18)) highBox(clk,resetN,px,py,hix,hiy,hox,hoy,hs,unusedH);
    NumbersBitMap hud(clk,resetN,sox,soy,ss,sl,sh,hox,hoy,hs,hl,hh,px,py,ruby,sapphire,cursed,sd,srgb,hd,hrgb);
    objects_mux scene(clk,resetN,1'b0,8'h11,1'b0,8'h22,sd,srgb,hd,hrgb,
        1'b0,8'h55,messageDR,messageRGB,8'h04,sceneRGB);
    reg [7:0] expected[0:307199];
    reg [7:0] composite[0:307199];
    bit seen[0:307199];
    integer checks=0,startCount=0,prevX=1023,prevY=1023,prevPrevX=1023,prevPrevY=1023;
    integer lastRGB=0,visits=0,opaqueBlack=0,opaqueWhite=0,x,y,i,d,j;
    bit activeScan=0;
    always @(posedge clk) begin #2; if(resetN && startEvent) startCount++;end
    task automatic check(input bit ok,input string why);
        checks++;
        if(!ok) $fatal(1,"%s at (%0d,%0d),time%0t",why,prevX,prevY,$time);
    endtask
    function automatic bit visible(input integer x,y);
        return x>=0 && x<640 && y>=0 && y<480;
    endfunction
    function automatic bit menuPixel(input integer x,y);
        return x>=144 && x<640 && y>=0 && y<480;
    endfunction
    task automatic keyEvent(input logic [8:0] c,input bit pressKey);
        @(negedge clk);code=c;makeKey=pressKey;breakKey=!pressKey;
        @(negedge clk);makeKey=0;breakKey=0;
        repeat(4) @(negedge clk);
    endtask
    task automatic frame;
        @(negedge clk);sof=1;
        @(negedge clk);sof=0;
        repeat(4) @(negedge clk);
    endtask
    task automatic collect(input integer kind);
        frame();
        @(negedge clk);redDR=kind==1;blueDR=kind==2;blackDR=kind==3;
        repeat(4) @(negedge clk);
        redDR=0;blueDR=0;blackDR=0;
        repeat(3) @(negedge clk);
    endtask
    task automatic scan(input integer nx,ny);
        @(negedge clk);px=nx;py=ny;sof=(nx==0);
        @(posedge clk);#1;
        check(messageDR===menuPixel(prevX,prevY),"MENU right-only DR bounds/latency; no sidebar coverage");
        check(display.menuAddress<104476 && display.menu_rom.addressD<104476,"legal combined atlas addresses including blanking");
        if(menuPixel(prevX,prevY)) begin
            check(messageRGB===expected[prevY*640+prevX],"actual MIF pixel and independent full-screen expectation aligned");
            if(activeScan) begin
                check(!seen[prevY*640+prevX],"right-area output pixels appear once");
                seen[prevY*640+prevX]=1;visits++;
                if(messageRGB==0)opaqueBlack++;
                if(messageRGB==255)opaqueWhite++;
            end
        end
        if(menuPixel(prevPrevX,prevPrevY))check(muxRGB===lastRGB[7:0],"opaque right MENU wins original mux, one further stage");
        if(visible(prevPrevX,prevPrevY))check(sceneRGB===composite[prevPrevY*640+prevPrevX],
            "full actual-MIF scene: existing HUD unchanged on left, supplied opening on right");
        check(!running && !startEvent && !endEvent && !redEvent && !blueEvent && !blackEvent,
            "all gameplay/collision/collection events disabled in MENU");
        check(hx==384 && hy==240 && length==4 && speed==130,"no movement/length/speed changes during menu SOFs and held directions");
        check({sh,sl,hh,hl,ruby,sapphire,cursed}==0,"menu initial counters/score/high score");
        prevPrevX=prevX;prevPrevY=prevY;lastRGB=messageRGB;prevX=nx;prevY=ny;
    endtask
    task automatic sharedResult;
        check(display.results.statisticsReady && display.results.resultState!=0,
            "new shared result renderer retains the controller terminal state");
        check(display.results.finalScoreBCD=={sh,sl} && display.results.finalRubyBCD==ruby &&
              display.results.finalSapphireBCD==sapphire && display.results.finalCursedBCD==cursed,
            "new terminal report captures original score and counters after updates settle");
    endtask
    initial begin
        $readmemh("db/supplied_opening_fixture/expected.hex",expected);
        $readmemh("db/supplied_opening_fixture/composite.hex",composite);
        for(i=0;i<307200;i++)seen[i]=0;
        #12;resetN=1;
        keyEvent(9'h075,1); // Original keypad8, held through the whole menu.
        keyEvent(9'h02E,1); // Top-row5 is NOT the existing start mapping.
        check(!running && startCount==0,"unmapped top-row5 does not silently remap controls");
        activeScan=1;
        for(y=0;y<480;y++)for(x=0;x<640;x++)scan(x,y);
        scan(1023,1023);scan(1023,1023);activeScan=0;
        check(visits==238080 && opaqueWhite>0,"entire238080-pixel right opening covered, including opaqueFF");
        for(i=0;i<307200;i++)check(seen[i]===(i%640>=144),"complete right-area coverage; zero sidebar masking");
        scan(640,0);scan(0,480);scan(2047,2047);scan(1023,1023);scan(1023,1023);
        $display("OPENING_RENDER_PASS:238080 supplied-menu pixels +69120 existing-HUD pixels; aligned ROM/DR/mux;menu freezes motion/events");
        wall=0;selfHit=0;redDR=0;blueDR=0;blackDR=0;sof=0;
        keyEvent(9'h075,0);
        keyEvent(9'h073,1);
        check(running && startCount==1 && !display.menuActive && !display.menuModeDD,"keypad073 starts once and selects gameplay");
        repeat(5)keyEvent(9'h073,1); // Typematic make events with no break.
        check(startCount==1,"held5 typematic makes do not retrigger start");
        for(i=0;i<8;i++)collect(1);
        check({sh,sl}==8 && ruby==12'h008 && length==12 && speed==154,"Ruby unchanged score/length/speed");
        collect(2);
        check({sh,sl}==8'h11 && sapphire==1 && length==9 && speed==149,"Sapphire +3score/-3length/-5speed");
        collect(3);
        check({sh,sl}==6 && cursed==1 && length==14 && speed==159,"Cursed -5score/+5length/+10speed");
        wall=1;repeat(8)@(negedge clk);wall=0;
        check(!running && startCount==1 && {hh,hl}==6,"held5 cannot auto-restart defeat; high score captured");
        sharedResult();
        keyEvent(9'h073,0);keyEvent(9'h073,1);
        check(running && startCount==2 && {sh,sl,ruby,sapphire,cursed}==0 && {hh,hl}==6 && length==4 && speed==130,
            "fresh press restarts, clears per-game state, preserves high score and gameplay scene");
        for(i=0;i<90;i++)collect(1);
        repeat(6)@(negedge clk);
        check(!running && startCount==2 && {hh,hl}==8'h90 && ruby==12'h090,"win90, high score, held-key suppression");
        sharedResult();
        keyEvent(9'h073,0);keyEvent(9'h073,1);
        check(running && startCount==3 && {hh,hl}==8'h90 && ruby==0,"victory local restart preserves high score");
        // All four original keypad directions, with clean starts; no decoder change.
        for(d=0;d<4;d++)begin
            @(negedge clk);resetN=0;repeat(3)@(negedge clk);resetN=1;
            repeat(6)@(negedge clk);
            check(!running && display.menuActive && {hh,hl}==0,"hardware reset returns MENU and original high-score reset");
            keyEvent(9'h073,1);keyEvent(9'h073,0);
            case(d)
                0:keyEvent(9'h075,1);
                1:keyEvent(9'h074,1);
                2:keyEvent(9'h06B,1);
                3:keyEvent(9'h072,1);
            endcase
            for(j=0;j<22;j++)frame();
            case(d)
                0:check(hy<240 && hx==384,"unchanged UP control");
                1:check(hx>384 && hy==240,"unchanged RIGHT control");
                2:check(hx<384 && hy==240,"unchanged LEFT control");
                3:check(hy>240 && hx==384,"unchanged DOWN control");
            endcase
        end
        $display("OPENING_STATE_PASS:keypad073/typematic/release;four directions;menu/play/reset;score/highscore/relics/length/speed;shared result snapshots");
        $display("OPENING_SCREEN_PASS:%0d checks;no physical FPGA verification",checks);
        testPassed=1;$finish;
    end
    initial begin #15000000;$fatal(1,"opening-screen timeout");end
endmodule
