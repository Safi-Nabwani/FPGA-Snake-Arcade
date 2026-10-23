`timescale 1ns/1ps
// Capture actual production renderer output, not a replacement graphics implementation.
// Collection/collision stimuli exercise the real controller/counters deterministically.
module readme_images_tb;
    reg clk=0,resetN=0,sof=0,enterKey=0,up=0,leftKey=0;
    reg redContact=0,blueContact=0,blackContact=0;
    reg capturePassed=0;
    reg [10:0] px=1023,py=1023;
    always #5 clk=~clk;
    wire running,startEvent,endEvent,lost,won,redEvent,blueEvent,blackEvent;
    wire [3:0] sl,sh,hl,hh;
    wire [11:0] ruby,sapphire,cursed;
    wire signed [10:0] speed,hx,hy;
    wire [2:0] direction;
    wire headDR,bodyDR,bodySelf,scoreDR,highDR,appleDR,messageDR;
    wire [7:0] headRGB,bodyRGB,scoreRGB,highRGB,appleRGB,messageRGB,bgRGB,rgb;
    wire [5:0] length;
    `include "RTL/VGA/jungle_map.svh"
    game_controller game(clk,resetN,sof,1'b1,bodySelf,1'b0,1'b0,
        redContact,blueContact,blackContact,sl,sh,enterKey,
        running,startEvent,endEvent,lost,won,redEvent,blueEvent,blackEvent);
    appleCounter score(clk,resetN,startEvent,redEvent,blueEvent,blackEvent,sl,sh);
    highscoreComp high(clk,resetN,endEvent,sl,sh,hl,hh);
    relic_collection_counters counts(clk,resetN,startEvent,redEvent,blueEvent,blackEvent,ruby,sapphire,cursed);
    speed_controller velocity(clk,resetN,startEvent,redEvent,blueEvent,blackEvent,speed);
    snake_head head(clk,resetN,sof,up,1'b0,leftKey,1'b0,running,speed,hx,hy,direction);
    snake_body body(clk,resetN,startEvent,running,sof,px,py,hx,hy,
        redEvent,blueEvent,blackEvent,bodyDR,bodyRGB,length,bodySelf);
    jungle_head_draw visualHead(clk,resetN,px,py,hx,hy,direction,headDR,headRGB);
    wire borderDR,obstacleDR;
    back_ground_draw arena(clk,resetN,px,py,bgRGB,borderDR,obstacleDR);
    wire [10:0] sx,sy,hsx,hsy; wire scoreSquare,highSquare;
    wire [7:0] unusedS,unusedH,unusedR,unusedB,unusedK;
    wire unusedRD,unusedBD,unusedKD;
    square_object #(.OBJECT_WIDTH_X(32),.OBJECT_HEIGHT_Y(18)) scoreBox
        (clk,resetN,px,py,11'sd57,11'sd116,sx,sy,scoreSquare,unusedS);
    square_object #(.OBJECT_WIDTH_X(32),.OBJECT_HEIGHT_Y(18)) highBox
        (clk,resetN,px,py,11'sd56,11'sd182,hsx,hsy,highSquare,unusedH);
    NumbersBitMap hud(clk,resetN,sx,sy,scoreSquare,sl,sh,hsx,hsy,highSquare,hl,hh,
        px,py,ruby,sapphire,cursed,scoreDR,scoreRGB,highDR,highRGB);
    wire blueVisible,blueSpawn;
    blue_apple_controller blue(clk,resetN,startEvent,redEvent,blueEvent,blueVisible,blueSpawn);
    wire [4:0] rx,ry,bx,by,kx,ky,rfx,rfy,bfx,bfy,kfx,kfy;
    wire re,be,ke;
    randomCounter positions(clk,resetN,redEvent,blueSpawn,blackEvent,re,be,ke,rx,ry,bx,by,kx,ky);
    apple_position_controller exclusions(rx,ry,bx,by,kx,ky,re,be,ke,rfx,rfy,bfx,bfy,kfx,kfy);
    wire signed [10:0] rtx,rty,btx,bty,ktx,kty;
    apple_topleft_calc locations(rfx,rfy,bfx,bfy,kfx,kfy,rtx,rty,btx,bty,ktx,kty);
    wire [10:0] rox,roy,box,boy,kox,koy; wire rs,bs,ks;
    square_object #(.OBJECT_WIDTH_X(24),.OBJECT_HEIGHT_Y(24)) rSquare(clk,resetN,px,py,rtx,rty,rox,roy,rs,unusedR);
    square_object #(.OBJECT_WIDTH_X(24),.OBJECT_HEIGHT_Y(24)) bSquare(clk,resetN,px,py,btx,bty,box,boy,bs,unusedB);
    square_object #(.OBJECT_WIDTH_X(24),.OBJECT_HEIGHT_Y(24)) kSquare(clk,resetN,px,py,ktx,kty,kox,koy,ks,unusedK);
    AppleBitMap relics(clk,resetN,rs,rox,roy,bs,box,boy,blueVisible,ks,kox,koy,unusedRD,unusedBD,unusedKD,appleDR,appleRGB);
    end_message_display displayLayer(clk,resetN,px,py,won,lost,startEvent,sl,sh,ruby,sapphire,cursed,messageDR,messageRGB);
    objects_mux compositor(clk,resetN,headDR,headRGB,bodyDR,bodyRGB,scoreDR,scoreRGB,
        highDR,highRGB,appleDR,appleRGB,messageDR,messageRGB,bgRGB,rgb);

    task frame;
        @(negedge clk);sof=1;@(negedge clk);sof=0;repeat(6)@(negedge clk);
    endtask
    task startGame;
        @(negedge clk);enterKey=1;repeat(8)@(negedge clk);enterKey=0;repeat(8)@(negedge clk);
        if(!running)$fatal(1,"Enter failed to start/restart");
    endtask
    task collect(input integer kind);
        frame();
        @(negedge clk);redContact=(kind==1);blueContact=(kind==2);blackContact=(kind==3);
        repeat(7)@(negedge clk);redContact=0;blueContact=0;blackContact=0;
        repeat(8)@(negedge clk);
    endtask
    task capture(input string name);
        integer fd,i;
        fd=$fopen({"db/readme_images/",name,".rgb332"},"wb");
        if(!fd)$fatal(1,"Cannot open frame output");
        // All production visual layers and the mux produce the pixel from two edges earlier.
        for(i=0;i<307202;i++)begin
            @(negedge clk);
            if(i<307200)begin px=i%640;py=i/640;end else begin px=1023;py=1023;end
            @(posedge clk);#1;
            if(i>=2)begin
                if($isunknown(rgb))$fatal(1,"Unknown pixel in %s",name);
                $fwrite(fd,"%c",rgb);
            end
        end
        $fclose(fd);
        $display("FRAME_CAPTURE %s score=%0d%0d high=%0d%0d counts=%03h/%03h/%03h head=(%0d,%0d) length=%0d",
            name,sh,sl,hh,hl,ruby,sapphire,cursed,hx,hy,length);
    endtask
    task checkWalkable(input integer x,input integer y);
        integer xx,yy;reg [4:0] tile;
        if(x<144 || x+24>624 || y<24 || y+24>456)$fatal(1,"Screenshot snake outside arena");
        for(yy=y;yy<=y+23;yy+=23)for(xx=x;xx<=x+23;xx+=23)begin
            tile=jungleTile((xx-144)/24,(yy-24)/24);
            if(tile[2:0]>=4)$fatal(1,"Screenshot snake overlaps obstacle at %0d,%0d",x,y);
        end
    endtask
    initial begin
        repeat(4)@(negedge clk);resetN=1;repeat(20)@(negedge clk);
        capture("opening");
        startGame();
        repeat(5)collect(1);
        up=1;repeat(40)frame();up=0;leftKey=1;repeat(55)frame();leftKey=0;
        repeat(20)@(negedge clk);
        if(!running || bodySelf || length!=19 || ruby!=12'h005 || !blueVisible)
            $fatal(1,"Unexpected gameplay snapshot state");
        checkWalkable(hx,hy);
        for(integer node=0;node<19;node++)checkWalkable(body.trailX[(node+1)*6],body.trailY[(node+1)*6]);
        capture("gameplay");
        repeat(85)collect(1);
        repeat(20)@(negedge clk);
        if(running || displayLayer.results.resultState!=1 || {sh,sl}!=8'h90)
            $fatal(1,"Expected actual controller Victory at 90");
        capture("victory");
        startGame();repeat(5)collect(1);collect(3);repeat(20)@(negedge clk);
        if(running || displayLayer.results.resultState!=2 || cursed!=1 || {sh,sl}!=0)
            $fatal(1,"Expected fatal Cursed defeat and settled statistics");
        capture("defeat");
        capturePassed=1;
        $display("README_IMAGES_PASS four actual-renderer frames; scripted functional stimuli; no hardware capture claim");
        $finish;
    end
    initial begin #100000000;$fatal(1,"Frame export timeout");end
endmodule
