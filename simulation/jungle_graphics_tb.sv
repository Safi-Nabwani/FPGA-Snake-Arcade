`timescale 1ns/1ps
// Real MIF tests, not a board/full-system/post-fit test. Existing latencies retained.
module jungle_graphics_tb;
    reg clk=0, resetN=0;
    always #5 clk=~clk;
    reg [10:0] ox=0, oy=0, px=0, py=0, bpx=384, bpy=240;
    reg [2:0] direction=1;
    reg headSquare=1;
    wire headDR; wire [7:0] headRGB;
    headBitMap head(clk,resetN,ox,oy,headSquare,direction,headDR,headRGB);
    reg redSquare=0, blueSquare=0, blackSquare=0, blueVisible=1;
    wire redDR, blueDR, blackDR, appleDR; wire [7:0] appleRGB;
    AppleBitMap relic(clk,resetN,redSquare,ox,oy,blueSquare,ox,oy,blueVisible,
        blackSquare,ox,oy,redDR,blueDR,blackDR,appleDR,appleRGB);
    reg gameStarted=1;
    wire bodyDR, selfHit; wire [7:0] bodyRGB; wire [5:0] bodyLength;
    snake_body body(clk,resetN,1'b0,gameStarted,1'b0,bpx,bpy,
        11'sd384,11'sd240,1'b0,1'b0,1'b0,bodyDR,bodyRGB,bodyLength,selfHit);
    wire borderDR, obstacleDR; wire [7:0] bgRGB;
    back_ground_draw bg(clk,resetN,px,py,bgRGB,borderDR,obstacleDR);
    reg [7:0] goldenHead[0:575], goldenBody[0:575];
    reg [7:0] goldenRed[0:575], goldenBlue[0:575], goldenBlack[0:575];
    reg headMask[0:575], bodyMask[0:575], redMask[0:575], blueMask[0:575], blackMask[0:575];
    integer x,y,d,t,rx,ry,address,expectedAddress,previousAddress, previousHead;
    bit insideArena, expectedRock;
    bit testPassed=0;
    task check(input bit valid, input string description);
        if (!valid) $fatal(1,"FAIL: %s at %0t (%0d,%0d)",description,$time,x,y);
    endtask
    task settle;
        repeat(3) @(posedge clk);
        #1;
    endtask
    initial begin
        $readmemh("db/jungle_graphics_fixture/snake_head_24.hex",goldenHead);
        $readmemh("db/jungle_graphics_fixture/snake_body_24.hex",goldenBody);
        $readmemh("db/jungle_graphics_fixture/red_apple_24.hex",goldenRed);
        $readmemh("db/jungle_graphics_fixture/blue_apple_24.hex",goldenBlue);
        $readmemh("db/jungle_graphics_fixture/black_apple_24.hex",goldenBlack);
        $readmemh("db/jungle_graphics_fixture/snake_head_24_mask.hex",headMask);
        $readmemh("db/jungle_graphics_fixture/snake_body_24_mask.hex",bodyMask);
        $readmemh("db/jungle_graphics_fixture/red_apple_24_mask.hex",redMask);
        $readmemh("db/jungle_graphics_fixture/blue_apple_24_mask.hex",blueMask);
        $readmemh("db/jungle_graphics_fixture/black_apple_24_mask.hex",blackMask);
        #12; resetN=1;
        // All ROM addresses, exact color and original drawing mask for all directions.
        for(d=0; d<=4; d=d+1) begin
            direction=d;
            for(y=0; y<24; y=y+1) for(x=0; x<24; x=x+1) begin
                @(negedge clk); ox=x; oy=y;
                case(d)
                    2: begin rx=y; ry=23-x; end
                    3: begin rx=23-y; ry=x; end
                    4: begin rx=23-x; ry=23-y; end
                    default: begin rx=x; ry=y; end
                endcase
                expectedAddress=ry*24+rx;
                settle();
                check(head.address==expectedAddress,"head rotation address");
                check(headRGB===goldenHead[expectedAddress],"head actual MIF color");
                check(headDR===headMask[expectedAddress],"head original collision mask");
            end
        end
        headSquare=0; settle(); check(!headDR,"head outside square"); headSquare=1;
        // Streaming head: output follows previous ROM address (existing extra head stage).
        direction=1; ox=0; oy=0; settle(); previousAddress=0;
        for(address=0; address<576; address=address+1) begin
            @(negedge clk); ox=address%24; oy=address/24;
            @(posedge clk); #1;
            check(headRGB===goldenHead[previousAddress],"head streaming color latency");
            check(headDR===headMask[previousAddress],"head streaming mask latency");
            previousAddress=address;
        end
        for(t=0; t<3; t=t+1) begin
            redSquare=(t==0); blueSquare=(t==1); blackSquare=(t==2);
            for(y=0; y<24; y=y+1) for(x=0; x<24; x=x+1) begin
                @(negedge clk); ox=x; oy=y;
                @(posedge clk); #1; address=y*24+x;
                case(t)
                    0: begin
                        check(redDR===redMask[address],"Ruby original collection mask");
                        check(appleRGB===(redMask[address]?goldenRed[address]:8'hff),"Ruby real color");
                    end
                    1: begin
                        check(blueDR===blueMask[address],"Sapphire original collection mask");
                        check(appleRGB===(blueMask[address]?goldenBlue[address]:8'hff),"Sapphire real color");
                    end
                    2: begin
                        check(blackDR===blackMask[address],"Cursed original collection mask");
                        check(appleRGB===(blackMask[address]?goldenBlack[address]:8'hff),"Cursed real color");
                    end
                endcase
                check(appleDR===(redDR||blueDR||blackDR),"combined relic drawing request");
            end
        end
        ox=12; oy=12; redSquare=1; blueSquare=1; blackSquare=1; settle();
        check(blackDR && !redDR && !blueDR,"Cursed priority");
        blackSquare=0; settle(); check(blueDR && !redDR,"Sapphire priority");
        blueVisible=0; settle(); check(redDR && !blueDR,"hidden Sapphire falls back to Ruby");
        redSquare=0; settle(); check(!appleDR,"no relic rectangle");
        for(y=0; y<24; y=y+1) for(x=0; x<24; x=x+1) begin
            @(negedge clk); bpx=384+x; bpy=240+y;
            @(posedge clk); #1; address=y*24+x;
            check(bodyRGB===goldenBody[address],"body actual MIF address/color");
            check(bodyDR===bodyMask[address],"body original drawing mask");
        end
        bpx=408; settle(); check(!bodyDR,"exclusive body right bound");
        gameStarted=0; settle(); check(!bodyDR,"body hidden outside running game");
        // Continuous visible raster, real background ROMs and unchanged obstacle map.
        for(y=0; y<480; y=y+1) for(x=0; x<640; x=x+1) begin
            @(negedge clk); px=x; py=y;
            @(posedge clk); #1;
            insideArena=(x>=144 && x<624 && y>=24 && y<456);
            rx=(x-144)/24; ry=(y-24)/24;
            expectedRock=insideArena && (((ry==3 || ry==4) && (rx==11 || rx==12)) ||
                ((ry==9 || ry==10) && (rx==3 || rx==4)) ||
                ((ry==11 || ry==12) && (rx>=3 && rx<=6)));
            check(borderDR===!insideArena && obstacleDR===expectedRock,"unchanged full-frame collision bounds");
            if(insideArena) begin
                address=((y-24)%24)*24+((x-144)%24);
                case(bg.currentTile)
                    0: check(bgRGB===bg.grass_tile_rom.data[address],"moss floor real ROM/address");
                    1: check(bgRGB===bg.stone_tile_rom.data[address],"cracked floor real ROM/address");
                    2: check(bgRGB===bg.rock_tile_rom.data[address],"obstacle real ROM/address");
                    default: $fatal(1,"Unexpected arena tile");
                endcase
            end
        end
        testPassed=1;
        $display("JUNGLE_GRAPHICS_PASS: masks, colors, rotations, stream stages, body and 307200 background pixels");
        $finish;
    end
endmodule
