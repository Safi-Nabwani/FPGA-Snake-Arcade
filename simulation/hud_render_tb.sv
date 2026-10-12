`timescale 1ns/1ps
module hud_render_tb;
    bit testPassed=0;
    logic clk=0,resetN=0;
    always #5 clk=~clk;
    logic [10:0] px=1023,py=1023;
    wire signed [10:0] sx,sy,hx,hy;
    ScoreConstants constants(sx,sy,hx,hy);
    wire [10:0] sox,soy,hox,hoy;
    wire scoreRect,highRect;
    wire [7:0] unusedScore,unusedHigh;
    square_object #(.OBJECT_WIDTH_X(32),.OBJECT_HEIGHT_Y(18))
        squareScore(clk,resetN,px,py,sx,sy,sox,soy,scoreRect,unusedScore);
    square_object #(.OBJECT_WIDTH_X(32),.OBJECT_HEIGHT_Y(18))
        squareHigh(clk,resetN,px,py,hx,hy,hox,hoy,highRect,unusedHigh);
    logic [3:0] sl=2,sh=1,hl=9,hh=1;
    logic [11:0] ruby=12'h012,sapphire=12'h345,cursed=12'h678;
    wire sd,hd;
    wire [7:0] srgb,hrgb;
    NumbersBitMap display(clk,resetN,sox,soy,scoreRect,sl,sh,
        hox,hoy,highRect,hl,hh,px,py,ruby,sapphire,cursed,sd,srgb,hd,hrgb);
    wire [7:0] bgRGB;
    wire borderDR,obstacleDR;
    back_ground_draw bg(clk,resetN,px,py,bgRGB,borderDR,obstacleDR);
    wire [7:0] muxRGB;
    objects_mux mux(clk,resetN,1'b0,8'h00,1'b0,8'h00,
        sd,srgb,hd,hrgb,1'b0,8'h00,1'b0,8'h00,bgRGB,muxRGB);
    // Independent expectations use the approved flat raster, not atlas addressing.
    reg [7:0] approvedScreen[0:307199];
    reg font[0:8191];
    bit seen[0:99839];
    bit fullScan=0;
    integer prevX=1023,prevY=1023,prevPrevX=1023,prevPrevY=1023;
    integer x,y,digit,localX,localY,addr,word,n,i;
    integer lastExpectedRGB=4,checks=0,visited=0,blackPixels=0,whitePixels=0,fontPixels=0;
    bit expectedPanel,expectedHigh,mask;
    logic [7:0] expectedRGB,numberRGB;
    task automatic check(input bit ok,input string message);
        checks++;
        if(!ok) begin
            $display("DR=%b%b expectedBoundary=%b addressD=%0d",sd,hd,expectedPanel,display.panel_rom.addressD);
            $fatal(1,"%s at source pixel (%0d,%0d)",message,prevX,prevY);
        end
    endtask
    function automatic bit boundary(input integer x,y);
        boundary=(x>=0 && x<640 && y>=0 && y<480) &&
                 !(x>=144 && x<624 && y>=24 && y<456);
    endfunction
    function automatic bit rock(input integer x,y);
        rock=((y==3) && (x>=2 && x<=5 || x>=14 && x<=17)) ||
             ((y==4 || y==5) && (x==2 || x==17)) ||
             (x==3 && (y==9 || y==10)) || (x==4 && y==10) ||
             (y==11 && x>=14 && x<=16) || (x==16 && (y==12 || y==13)) ||
             (y==15 && x>=6 && x<=8) || (x==6 && y==14) ||
             (x==11 && (y==4 || y==15)) || (x==6 && y==7) ||
             (x==17 && y==8) || ((x==3 || x==18) && y==14);
    endfunction
    task automatic scan(input integer nx,ny);
        @(negedge clk);px=nx;py=ny;
        expectedPanel=boundary(prevX,prevY);
        expectedHigh=0;digit=-1;localX=0;localY=0;expectedRGB=4;numberRGB=8'hFF;
        if(expectedPanel) begin
            expectedRGB=approvedScreen[prevY*640+prevX];
            if(fullScan && expectedRGB==0) blackPixels++;
            if(fullScan && expectedRGB==255) whitePixels++;
        end
        if(prevX>=57 && prevX<89 && prevY>=116 && prevY<134) begin
            digit=prevX<73 ? sh:sl;localX=(prevX-57)%16;localY=prevY-116;numberRGB=8'hF9;
        end else if(prevX>=56 && prevX<88 && prevY>=182 && prevY<200) begin
            digit=prevX<72 ? hh:hl;localX=(prevX-56)%16;localY=prevY-182;
            expectedHigh=1;numberRGB=8'hF9;
        end else if(prevX>=64 && prevX<112) begin
            word=-1;
            if(prevY>=273 && prevY<291) begin word=ruby;localY=prevY-273;numberRGB=8'hED;end
            else if(prevY>=317 && prevY<335) begin word=sapphire;localY=prevY-317;numberRGB=8'h57;end
            else if(prevY>=362 && prevY<380) begin word=cursed;localY=prevY-362;numberRGB=8'hB3;end
            if(word>=0) begin
                if(prevX<80) digit=(word>>8)&15;
                else if(prevX<96) digit=(word>>4)&15;
                else digit=word&15;
                localX=(prevX-64)%16;
            end
        end
        mask=0;
        if(digit>=0) begin
            addr=digit*512+(6+localY)*16+localX;mask=font[addr];
            if(mask) begin expectedRGB=numberRGB;fontPixels++;end
        end
        @(posedge clk);#1;
        check((sd||hd)===expectedPanel,"opaque frame DR, bounds, blanking exclusion");
        check(!(sd&&hd),"mutually exclusive original mux layers");
        check(hd===(expectedPanel && expectedHigh && mask),"high-score font mask/metadata alignment");
        check(display.panelAddress<99840 && display.panel_rom.addressD<99840,"legal packed addresses including blanking");
        if(expectedPanel) begin
            check((hd ? hrgb:srgb)===expectedRGB,"exact approved background/font and latency;opaque00/FF");
            if(fullScan) begin
                addr=display.panel_rom.addressD;
                check(!seen[addr],"each packed address sampled once per frame");
                seen[addr]=1;visited++;
            end
        end
        if(boundary(prevPrevX,prevPrevY))
            check(muxRGB===lastExpectedRGB,"original mux adds one aligned stage");
        check(borderDR===!(nx>=144 && nx<624 && ny>=24 && ny<456),"unchanged gameplay border mask");
        if(nx>=144 && nx<624 && ny>=24 && ny<456) begin
            check(bg.tileX==(nx-144)/24 && bg.tileY==(ny-24)/24,"unchanged20x18 tile index");
            check(obstacleDR===rock((nx-144)/24,(ny-24)/24),"unchanged30-cell obstacle map");
        end
        prevPrevX=prevX;prevPrevY=prevY;lastExpectedRGB=expectedRGB;prevX=nx;prevY=ny;
    endtask
    task automatic fieldsScan;
        for(y=116;y<380;y++) for(x=56;x<120;x++) scan(x,y);
        scan(1023,1023);scan(1023,1023);
    endtask
    initial begin
        $readmemh("db/jungle_hud_final_fixture/screen.hex",approvedScreen);
        $readmemh("db/jungle_hud_final_fixture/font.hex",font);
        for(i=0;i<99840;i++) seen[i]=0;
        #12;resetN=1;#1;
        check(sx==57 && sy==116 && hx==56 && hy==182,"approved enlarged origins");
        fullScan=1;
        for(y=0;y<480;y++) for(x=0;x<640;x++) scan(x,y);
        scan(1023,1023);scan(1023,1023);fullScan=0;
        check(visited==99840,"all and only non-gameplay ROM pixels covered once");
        for(i=0;i<99840;i++) check(seen[i],"complete packed atlas coverage");
        check(fontPixels>1000 && blackPixels>1000,"full-detail digits and opaque-black wells exercised");
        $display("PASS:307200 streaming pixels;99840 exact boundary addresses;00/FF opaque;unchanged arena");
        sl=0;sh=0;hl=0;hh=0;ruby=0;sapphire=0;cursed=0;fieldsScan();
        sl=9;sh=9;hl=9;hh=9;ruby=12'h999;sapphire=12'h999;cursed=12'h999;fieldsScan();
        // No new clamp on unchanged4-bit score input ports.
        sl=15;sh=15;hl=15;hh=15;fieldsScan();
        for(n=0;n<10;n++) begin
            sl=n;sh=(n+1)%10;hl=(n+2)%10;hh=(n+3)%10;
            ruby={4'(n),4'((n+1)%10),4'((n+2)%10)};
            sapphire={4'((n+3)%10),4'((n+4)%10),4'((n+5)%10)};
            cursed={4'((n+6)%10),4'((n+7)%10),4'((n+8)%10)};
            fieldsScan();
        end
        scan(640,0);scan(0,480);scan(2047,2047);scan(639,479);scan(1023,1023);scan(1023,1023);
        $display("HUD_FINAL_RENDER_PASS:%0d checks;five dynamic16x18 fields;00/99/FF,000/999;aligned ROM/DR/RGB/mux",checks);
        testPassed=1;$finish;
    end
    initial begin #10000000;$fatal(1,"render test timeout");end
endmodule
