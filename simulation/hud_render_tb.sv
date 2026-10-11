`timescale 1ns/1ps
module hud_render_tb;
    bit testPassed = 0;
    logic clk = 0, resetN = 0;
    always #5 clk = ~clk;
    logic [10:0] px = 0, py = 0;
    wire signed [10:0] sx, sy, hx, hy;
    ScoreConstants constants(sx, sy, hx, hy);
    wire [10:0] sox, soy, hox, hoy;
    wire scoreRect, highRect;
    wire [7:0] unusedScore, unusedHigh;
    square_object #(.OBJECT_WIDTH_X(16), .OBJECT_HEIGHT_Y(9))
        squareScore(clk, resetN, px, py, sx, sy, sox, soy, scoreRect, unusedScore);
    square_object #(.OBJECT_WIDTH_X(16), .OBJECT_HEIGHT_Y(9))
        squareHigh(clk, resetN, px, py, hx, hy, hox, hoy, highRect, unusedHigh);
    logic [3:0] sl = 3, sh = 2, hl = 9, hh = 1;
    logic [11:0] ruby = 12'h012, sapphire = 12'h345, cursed = 12'h678;
    wire sd, hd;
    wire [7:0] srgb, hrgb;
    NumbersBitMap display(clk, resetN, sox, soy, scoreRect, sl, sh,
        hox, hoy, highRect, hl, hh, px, py, ruby, sapphire, cursed, sd, srgb, hd, hrgb);
    // Current raw background must preserve the exact previous arena geometry/collisions.
    wire [7:0] bgRGB;
    wire borderDR, obstacleDR;
    back_ground_draw bg(clk, resetN, px, py, bgRGB, borderDR, obstacleDR);
    wire [7:0] muxRGB;
    objects_mux mux(clk, resetN, 1'b0, 8'h00, 1'b0, 8'h00,
        sd, srgb, hd, hrgb, 1'b0, 8'h00, 1'b0, 8'h00, bgRGB, muxRGB);
    integer prevX = 0, prevY = 0, prevPrevX = 0, prevPrevY = 0;
    integer x, y, digit, localX, localY, addr, word, n;
    integer lastExpectedRGB = 0;
    integer fontPixels = 0, blackPixels = 0, transparentPixels = 0, checks=0;
    reg [7:0] panel[0:51839];
    reg alpha[0:51839], font[0:8191];
    bit expectedPanel, expectedHigh, mask, expectedOpaque;
    logic [7:0] expectedRGB, numberRGB;
    task automatic check(input bit ok, input string message);
        checks++;
        if (!ok) begin
            $display("Diagnostic DR=%b%b expectedAlpha=%b ROMAlpha=%b panelD=%b addressD=%0d", sd,hd,expectedOpaque,display.panelMask,display.panelD,display.panel_alpha_rom.addressD);
            $fatal(1, "%s at source pixel (%0d,%0d)", message, prevX, prevY);
        end
    endtask
    function automatic bit rock(input integer x, input integer y);
        rock = ((y==3) && (x>=2 && x<=5 || x>=14 && x<=17)) ||
               ((y==4 || y==5) && (x==2 || x==17)) ||
               (x==3 && (y==9 || y==10)) || (x==4 && y==10) ||
               (y==11 && x>=14 && x<=16) || (x==16 && (y==12 || y==13)) ||
               (y==15 && x>=6 && x<=8) || (x==6 && y==14) ||
               (x==11 && (y==4 || y==15)) || (x==6 && y==7) ||
               (x==17 && y==8) || ((x==3 || x==18) && y==14);
    endfunction
    task automatic scan(input integer nx, ny);
        @(negedge clk); px = nx; py = ny;
        expectedPanel = prevX >= 8 && prevX < 128 && prevY >= 24 && prevY < 456;
        expectedOpaque = 0;
        expectedHigh = 0; digit = -1; localX = 0; localY = 0;
        expectedRGB = 8'h04; numberRGB = 8'hFF;
        if (expectedPanel) begin
            addr = (prevY-24)*120+prevX-8;
            expectedOpaque = alpha[addr];
            expectedRGB = panel[addr];
            if (expectedOpaque && expectedRGB==0) blackPixels++;
            if (!expectedOpaque) transparentPixels++;
        end
        if (prevX >= 62 && prevX < 78 && prevY >= 141 && prevY < 150) begin
            digit = prevX < 70 ? sh : sl; localX = (prevX-62)%8; localY = prevY-141;
            numberRGB = 8'hF9;
        end else if (prevX >= 62 && prevX < 78 && prevY >= 190 && prevY < 199) begin
            digit = prevX < 70 ? hh : hl; localX = (prevX-62)%8; localY = prevY-190;
            expectedHigh = 1; numberRGB = 8'hF9;
        end else if (prevX >= 70 && prevX < 94) begin
            word = 0;
            if (prevY >= 259 && prevY < 268) begin word = ruby; localY = prevY-259; numberRGB = 8'hED; end
            else if (prevY >= 292 && prevY < 301) begin word = sapphire; localY = prevY-292; numberRGB = 8'h57; end
            else if (prevY >= 325 && prevY < 334) begin word = cursed; localY = prevY-325; numberRGB = 8'hB3; end
            else word = -1;
            if (word >= 0) begin
                if (prevX < 78) digit = (word >> 8) & 15;
                else if (prevX < 86) digit = (word >> 4) & 15;
                else digit = word & 15;
                localX = (prevX-70)%8;
            end
        end
        mask = 0;
        if (digit >= 0) begin
            addr = digit*512+(6+2*localY)*16+2*localX;
            mask = font[addr];
            if (mask) begin expectedRGB = numberRGB; fontPixels = fontPixels + 1; end
        end
        @(posedge clk); #1;
        check((sd || hd) === (expectedPanel && expectedOpaque), "panel alpha/DR pipeline and half-open bounds");
        check(hd === (expectedPanel && expectedOpaque && expectedHigh && mask), "high-score DR aligned with font mask");
        check(display.panelAddress < 51840, "panel address is always legal, including blanking coordinates");
        if (expectedPanel && expectedOpaque) begin
            check((hd ? hrgb : srgb) === expectedRGB, "actual panel/font RGB and metadata alignment, including opaque00");
            check(prevX < 128, "HUD never enters arena");
        end
        if (prevPrevX >= 8 && prevPrevX < 128 && prevPrevY >= 24 && prevPrevY < 456)
            check(muxRGB == lastExpectedRGB, "original mux adds one aligned register stage");
        check(borderDR === !(nx >= 144 && nx < 624 && ny >= 24 && ny < 456), "unchanged arena border");
        if (nx >= 144 && nx < 624 && ny >= 24 && ny < 456) begin
            check(bg.tileX == (nx-144)/24 && bg.tileY == (ny-24)/24, "unchanged 20x18 tile index");
            check(obstacleDR === rock((nx-144)/24,(ny-24)/24), "unchanged obstacle map");
        end
        prevPrevX = prevX; prevPrevY = prevY;
        lastExpectedRGB = expectedPanel && expectedOpaque ? expectedRGB : 4;
        prevX = nx; prevY = ny;
    endtask
    initial begin
        $readmemh("db/jungle_hud_fixture/panel.hex", panel);
        $readmemh("db/jungle_hud_fixture/alpha.hex", alpha);
        $readmemh("db/jungle_hud_fixture/font.hex", font);
        #12; resetN = 1;
        check(sx == 62 && sy == 141 && hx == 62 && hy == 190, "native supplied counter-window origins");
        for (y = 0; y < 480; y = y + 1)
            for (x = 0; x < 640; x = x + 1) scan(x,y);
        scan(1023,1023); scan(0,0); scan(0,0);
        check(fontPixels > 200 && blackPixels > 10000 && transparentPixels == 17663,
            "live glyphs, opaque black and separate transparent00 pixels exercised");
        $display("PASS: 307200 actual-MIF streaming pixels, 5 windows, alpha vs opaque00, mux, unchanged arena");
        // Explicit leading-zero and saturation-display values, including every digit 0..9.
        ruby = 12'h000; sapphire = 12'h000; cursed = 12'h999; sl = 0; sh = 1;
        for (y = 141; y < 334; y = y + 1)
            for (x = 62; x < 94; x = x + 1) scan(x,y);
        scan(0,0); scan(0,0);
        for (n=0;n<10;n++) begin
            sl=n;sh=(n+1)%10;hl=(n+2)%10;hh=(n+3)%10;
            ruby={4'(n),4'((n+1)%10),4'((n+2)%10)};
            sapphire={4'((n+3)%10),4'((n+4)%10),4'((n+5)%10)};
            cursed={4'((n+6)%10),4'((n+7)%10),4'((n+8)%10)};
            for (y=141;y<334;y++) for(x=62;x<94;x++) scan(x,y);
            scan(0,0);scan(0,0);
        end
        $display("HUD_RENDER_PASS: %0d checks, five updating fields, digits0..9, leading zeros and999, aligned DR/RGB",checks);
        testPassed = 1;
        $finish;
    end
    initial begin #5000000; $fatal(1, "render test timeout"); end
endmodule
