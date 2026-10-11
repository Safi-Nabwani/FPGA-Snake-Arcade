`timescale 1ns/1ps
// Actual MIFs + previous-build RTL: visual pipeline and cycle-exact hit equivalence.
// No PLL, board, audio QXP or post-fit timing simulation is claimed.
module jungle_implementation_tb;
    bit testPassed=0;
    logic clk=0, resetN=0;
    always #5 clk=~clk;
    logic [10:0] px=0, py=0;
    logic signed [10:0] hx=384, hy=240;
    logic [2:0] dir=1;
    wire [10:0] ox, oy;
    wire hs; wire [7:0] unused;
    square_object #(.OBJECT_WIDTH_X(22),.OBJECT_HEIGHT_Y(24)) headSquare
        (clk,resetN,px,py,hx,hy,ox,oy,hs,unused);
    wire hit, oldHit; wire [7:0] hitRGB, oldHitRGB;
    headBitMap collision(clk,resetN,ox,oy,hs,dir,hit,hitRGB);
    legacy_headBitMap originalHead(clk,resetN,ox,oy,hs,dir,oldHit,oldHitRGB);
    wire headDR; wire [7:0] headRGB;
    jungle_head_draw headArt(clk,resetN,px,py,hx,hy,dir,headDR,headRGB);

    logic signed [10:0] redX=312, redY=96, blueX=264, blueY=264, blackX=432, blackY=168;
    logic visible=1;
    wire [10:0] rox,roy,box,boy,kox,koy;
    wire rs,bs,ks; wire [7:0] unusedR,unusedB,unusedK;
    square_object #(.OBJECT_WIDTH_X(24),.OBJECT_HEIGHT_Y(24)) redSquare(clk,resetN,px,py,redX,redY,rox,roy,rs,unusedR);
    square_object #(.OBJECT_WIDTH_X(24),.OBJECT_HEIGHT_Y(24)) blueSquare(clk,resetN,px,py,blueX,blueY,box,boy,bs,unusedB);
    square_object #(.OBJECT_WIDTH_X(24),.OBJECT_HEIGHT_Y(24)) blackSquare(clk,resetN,px,py,blackX,blackY,kox,koy,ks,unusedK);
    wire rh,bh,kh,ad,orh,obh,okh,oad; wire [7:0] ac,oac;
    AppleBitMap relic(clk,resetN,rs,rox,roy,bs,box,boy,visible,ks,kox,koy,rh,bh,kh,ad,ac);
    legacy_AppleBitMap originalRelic(clk,resetN,rs,rox,roy,bs,box,boy,visible,ks,kox,koy,orh,obh,okh,oad,oac);
    logic started=1, clear=0, sof=0, redPulse=0,bluePulse=0,blackPulse=0;
    wire bodyDR,oldBodyDR,selfHit,oldSelfHit;
    wire [7:0] bodyRGB,oldBodyRGB; wire [5:0] length,oldLength;
    snake_body body(clk,resetN,clear,started,sof,px,py,hx,hy,redPulse,bluePulse,blackPulse,bodyDR,bodyRGB,length,selfHit);
    legacy_snake_body originalBody(clk,resetN,clear,started,sof,px,py,hx,hy,redPulse,bluePulse,blackPulse,oldBodyDR,oldBodyRGB,oldLength,oldSelfHit);
    wire [7:0] bgRGB,muxRGB; wire border,obstacle;
    back_ground_draw bg(clk,resetN,px,py,bgRGB,border,obstacle);
    logic key5=1;
    wire [7:0] eventsNew,eventsOld;
    wire [3:0] scoreLow,scoreHigh,oldScoreLow,oldScoreHigh;
    game_controller newEvents(clk,resetN,sof,hit,selfHit,border,obstacle,rh,bh,kh,
        scoreLow,scoreHigh,key5,eventsNew[7],eventsNew[6],eventsNew[5],eventsNew[4],eventsNew[3],eventsNew[2],eventsNew[1],eventsNew[0]);
    game_controller oldEvents(clk,resetN,sof,oldHit,oldSelfHit,border,obstacle,orh,obh,okh,
        oldScoreLow,oldScoreHigh,key5,eventsOld[7],eventsOld[6],eventsOld[5],eventsOld[4],eventsOld[3],eventsOld[2],eventsOld[1],eventsOld[0]);
    appleCounter newScore(clk,resetN,eventsNew[6],eventsNew[2],eventsNew[1],eventsNew[0],scoreLow,scoreHigh);
    appleCounter oldScore(clk,resetN,eventsOld[6],eventsOld[2],eventsOld[1],eventsOld[0],oldScoreLow,oldScoreHigh);
    integer rubyEvents=0,sapphireEvents=0,cursedEvents=0,wallDeaths=0,selfContacts=0;
    objects_mux mux(clk,resetN,headDR,headRGB,bodyDR,bodyRGB,1'b0,8'h00,1'b0,8'h00,ad,ac,1'b0,8'h00,bgRGB,muxRGB);
    reg [7:0] hrom[0:575],brom[0:575],rrom[0:575],srom[0:575],crom[0:575];
    reg [7:0] floor0[0:575],floor1[0:575],floor2[0:575],floor3[0:575],ruin0[0:575],ruin1[0:575],ruin2[0:575];
    reg [4:0] map[0:359];
    integer checks=0,prevX=0,prevY=0,prevDir=1,x,y,d,t,i,j,a,rx,ry,desc,c,r;
    integer bodyX,bodyY,expectedHead,expectedRelic,expectedBody,expectedBG;
    integer lastMux=4;
    bit bodyValid, expectedInside;
    task check(input bit ok,input string description);
        checks++;
        if(!ok) $fatal(1,"%s at raw (%0d,%0d), previous (%0d,%0d), time %0t",description,px,py,prevX,prevY,$time);
    endtask
    function automatic integer rotated(input integer x,y,direction);
        case(direction)
        2: rotated=(23-x)*24+y;
        3: rotated=x*24+(23-y);
        4: rotated=(23-y)*24+(23-x);
        default: rotated=y*24+x;
        endcase
    endfunction
    function automatic bit rect(input integer x,y,left,top,width);
        rect=x>=left && x<left+width && y>=top && y<top+24;
    endfunction
    task collisionCheck;
        check(hit===oldHit,"original 22x24 head hit stream");
        check({rh,bh,kh}==={orh,obh,okh},"original relic hit streams/priority/visibility");
        check(length===oldLength && selfHit===oldSelfHit,"length and self-collision unaffected");
        check(eventsNew===eventsOld,"identical game FSM, collection/death/start/end/win pulses");
        check({scoreHigh,scoreLow}==={oldScoreHigh,oldScoreLow},"identical score accumulation from real collision events");
        if(eventsNew[2]) rubyEvents++;
        if(eventsNew[1]) sapphireEvents++;
        if(eventsNew[0]) cursedEvents++;
        if(eventsNew[4] && !selfHit) wallDeaths++;
        if(selfHit) selfContacts++;
    endtask
    task contact(input integer left,top);
        @(negedge clk); hx=left;hy=top;sof=1;
        @(negedge clk);sof=0;
        for(integer cy=top-2;cy<top+26;cy++) for(integer cx=left-2;cx<left+26;cx++) begin
            @(negedge clk);px=cx;py=cy;
            @(posedge clk);#1;collisionCheck();
        end
    endtask
    task scan(input integer nx,ny,nd);
        @(negedge clk); px=nx; py=ny; dir=nd;
        // All visuals below describe the previous raw pixel after this edge.
        expectedHead=255;
        if(rect(prevX,prevY,hx,hy,24)) expectedHead=hrom[rotated(prevX-hx,prevY-hy,prevDir)];
        expectedRelic=255;
        if(rect(prevX,prevY,blackX,blackY,24)) expectedRelic=crom[(prevY-blackY)*24+prevX-blackX];
        else if(visible && rect(prevX,prevY,blueX,blueY,24)) expectedRelic=srom[(prevY-blueY)*24+prevX-blueX];
        else if(rect(prevX,prevY,redX,redY,24)) expectedRelic=rrom[(prevY-redY)*24+prevX-redX];
        expectedBody=255;
        if(started) begin
            bodyValid=0;
            for(j=0;j<32;j++) begin
                bodyX=body.trailX[(j+1)*6]; bodyY=body.trailY[(j+1)*6];
                if(j<length && !bodyValid && rect(prevX,prevY,bodyX,bodyY,24)) begin
                    bodyValid=1; expectedBody=brom[(prevY-bodyY)*24+prevX-bodyX];
                end
            end
        end
        expectedBG=4;
        expectedInside=prevX>=144 && prevX<624 && prevY>=24 && prevY<456;
        if(expectedInside) begin
            c=(prevX-144)/24; r=(prevY-24)/24; desc=map[r*20+c];
            x=(prevX-144)%24; y=(prevY-24)%24;
            // Descriptor rotation is 0..3 clockwise quarter-turns.
            case(desc>>3)
            1: a=(23-x)*24+y;
            2: a=(23-y)*24+23-x;
            3: a=x*24+23-y;
            default: a=y*24+x;
            endcase
            case(desc&7)
            0: expectedBG=floor0[a]; 1: expectedBG=floor1[a];
            2: expectedBG=floor2[a]; 3: expectedBG=floor3[a];
            4: expectedBG=ruin0[a]; 5: expectedBG=ruin1[a]; 6: expectedBG=ruin2[a];
            endcase
        end
        @(posedge clk); #1;
        collisionCheck();
        check(headDR===(expectedHead!=255) && headRGB===expectedHead[7:0],"full24 head visual request/color alignment and rotation");
        check(ad===(expectedRelic!=255) && ac===expectedRelic[7:0],"relic visual alpha/request/color alignment");
        check(bodyDR===(expectedBody!=255) && bodyRGB===expectedBody[7:0],"body visual request/color alignment");
        check(bgRGB===expectedBG[7:0],"background variant/rotation/color alignment");
        check(muxRGB===lastMux[7:0],"objects_mux pair and priority latency");
        lastMux=expectedHead!=255 ? expectedHead : expectedBody!=255 ? expectedBody : expectedRelic!=255 ? expectedRelic : expectedBG;
        prevX=nx; prevY=ny; prevDir=nd;
    endtask
    initial begin
        $readmemh("db/jungle_implementation_fixture/snake_head_24.hex",hrom);
        $readmemh("db/jungle_implementation_fixture/snake_body_24.hex",brom);
        $readmemh("db/jungle_implementation_fixture/red_apple_24.hex",rrom);
        $readmemh("db/jungle_implementation_fixture/blue_apple_24.hex",srom);
        $readmemh("db/jungle_implementation_fixture/black_apple_24.hex",crom);
        $readmemh("db/jungle_implementation_fixture/ancient_stone_24x24_rgb332.hex",floor0);
        $readmemh("db/jungle_implementation_fixture/mossy_stone_24x24_rgb332.hex",floor1);
        $readmemh("db/jungle_implementation_fixture/cracked_stone_24x24_rgb332.hex",floor2);
        $readmemh("db/jungle_implementation_fixture/engraved_stone_24x24_rgb332.hex",floor3);
        $readmemh("db/jungle_implementation_fixture/rock_tile_24.hex",ruin0);
        $readmemh("db/jungle_implementation_fixture/ruin_wall_24.hex",ruin1);
        $readmemh("db/jungle_implementation_fixture/ruin_pillar_24.hex",ruin2);
        $readmemh("db/jungle_implementation_fixture/map.hex",map);
        #12; resetN=1;
        repeat(3) @(negedge clk);
        for(i=0;i<480;i++) for(t=0;t<640;t++) scan(t,i,1);
        scan(0,0,1);scan(0,0,1);
        $display("PASS: 307200 streaming pixels, full arena variants/rotation, head/body/relic/mux pipeline");
        for(d=0;d<=4;d++) begin
            for(i=238;i<266;i++) for(t=382;t<410;t++) scan(t,i,d);
        end
        $display("PASS: full24 centered head, all directions including columns22/23; legacy22 collision unchanged");
        for(i=0;i<8;i++) contact(redX,redY);
        contact(blueX,blueY); contact(blackX,blackY);
        contact(136,240); contact(192,96);
        check(rubyEvents>0 && sapphireEvents>0 && cursedEvents>0 && wallDeaths>0,"real sprite-driven collection and border/obstacle events exercised");
        // Priority transitions, hidden Sapphire, disjoint offsets and reset cycles.
        blueX=redX;blueY=redY;blackX=redX;blackY=redY;
        for(i=0;i<5000;i++) begin
            @(negedge clk); px=redX+i%28;py=redY+(i/28)%28;
            visible=(i%3!=0); blackX=(i%7==0)?redX:432;
            dir=i%5; resetN=(i%997!=0);
            @(posedge clk);#1; collisionCheck();
        end
        resetN=1;
        // Independent reference has original length/trail/self-hit logic and old art.
        for(i=0;i<800;i++) begin
            @(negedge clk); sof=1; clear=(i%199==0);started=(i%101!=0);
            hx=384+((i%12)<6?i%6:11-i%12)*4;
            hy=240+((i/12)%6)*4;
            redPulse=i%17==0;bluePulse=i%29==0;blackPulse=i%43==0;
            @(posedge clk);#1;collisionCheck();
            for(j=0;j<193;j++) check(body.trailX[j]===originalBody.trailX[j] && body.trailY[j]===originalBody.trailY[j],"original complete movement trail");
            @(negedge clk);sof=0;
            @(posedge clk);#1;collisionCheck();
        end
        $display("PASS: cycle-exact legacy head/relic masks, length, 193-entry trail, self-hit, resets and priority transitions");
        check(selfContacts>0,"actual self-collision contacts exercised");
        $display("PASS: real-mask events Ruby=%0d Sapphire=%0d Cursed=%0d deaths=%0d self-contacts=%0d and cycle-exact scoring",rubyEvents,sapphireEvents,cursedEvents,wallDeaths,selfContacts);
        $display("PASS: %0d focused checks; no hardware functionality claimed",checks);
        testPassed=1;$finish;
    end
endmodule
