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
    square_object #(.OBJECT_WIDTH_X(32), .OBJECT_HEIGHT_Y(32))
        squareScore(clk, resetN, px, py, sx, sy, sox, soy, scoreRect, unusedScore);
    square_object #(.OBJECT_WIDTH_X(32), .OBJECT_HEIGHT_Y(32))
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
    integer x, y, digit, localX, localY, addr, word;
    integer lastExpectedRGB = 0;
    integer labelPixels = 0, fontPixels = 0;
    bit expectedPanel, expectedHigh, mask, labelPrevious = 0;
    logic [7:0] expectedRGB, numberRGB, previousLabelRGB = 0;
    task automatic check(input bit ok, input string message);
        if (!ok) $fatal(1, "%s at source pixel (%0d,%0d)", message, prevX, prevY);
    endtask
    function automatic bit rock(input integer tx, input integer ty);
        rock = ((ty == 3 || ty == 4) && (tx == 11 || tx == 12)) ||
               ((ty == 9 || ty == 10) && (tx == 3 || tx == 4)) ||
               ((ty == 11 || ty == 12) && (tx >= 3 && tx <= 6));
    endfunction
    task automatic scan(input integer nx, ny);
        @(negedge clk); px = nx; py = ny;
        // Reference label selection is sampled BEFORE the ROM/metadata edge.
        labelPrevious = display.labelBit; previousLabelRGB = display.labelRGB;
        expectedPanel = prevX >= 8 && prevX < 128 && prevY >= 24 && prevY < 456;
        expectedHigh = 0; digit = -1; localX = 0; localY = 0;
        expectedRGB = 8'h24; numberRGB = 8'hFF;
        if (prevX < 10 || prevX >= 126 || prevY < 26 || prevY >= 454 || prevY == 100 || prevY == 192)
            expectedRGB = 8'h6D;
        if (prevX >= 48 && prevX < 80 && prevY >= 64 && prevY < 96) begin
            digit = prevX < 64 ? sh : sl; localX = (prevX-48)%16; localY = prevY-64;
            numberRGB = sh == 0 || (sh == 1 && sl == 0) ? 8'hFF : 8'hFC;
        end else if (prevX >= 48 && prevX < 80 && prevY >= 148 && prevY < 180) begin
            digit = prevX < 64 ? hh : hl; localX = (prevX-48)%16; localY = prevY-148;
            expectedHigh = 1; numberRGB = 8'hE0;
        end else if (prevX >= 40 && prevX < 88) begin
            word = 0;
            if (prevY >= 260 && prevY < 292) begin word = ruby; localY = prevY-260; numberRGB = 8'hE0; end
            else if (prevY >= 328 && prevY < 360) begin word = sapphire; localY = prevY-328; numberRGB = 8'h03; end
            else if (prevY >= 396 && prevY < 428) begin word = cursed; localY = prevY-396; numberRGB = 8'hA3; end
            else word = -1;
            if (word >= 0) begin
                if (prevX < 56) digit = (word >> 8) & 15;
                else if (prevX < 72) digit = (word >> 4) & 15;
                else digit = word & 15;
                localX = (prevX-40)%16;
            end
        end
        mask = 0;
        if (digit >= 0) begin
            addr = digit*512+localY*16+localX;
            mask = display.rom_inst.mem_data[addr];
            if (mask) begin expectedRGB = numberRGB; fontPixels = fontPixels + 1; end
        end
        if (labelPrevious) begin expectedRGB = previousLabelRGB; labelPixels = labelPixels + 1; end
        @(posedge clk); #1;
        check((sd || hd) === expectedPanel, "sidebar DR pipeline and half-open bounds");
        check(hd === (expectedPanel && expectedHigh && mask), "high-score DR aligned with font mask");
        if (expectedPanel) begin
            check((hd ? hrgb : srgb) === expectedRGB, "real font/color/address/metadata pixel alignment");
            check(prevX < 128, "HUD never enters arena");
        end
        if (prevPrevX >= 8 && prevPrevX < 128 && prevPrevY >= 24 && prevPrevY < 456)
            check(muxRGB == lastExpectedRGB, "original mux adds one aligned register stage");
        check(borderDR === !(nx >= 144 && nx < 624 && ny >= 24 && ny < 456), "unchanged arena border");
        if (nx >= 144 && nx < 624 && ny >= 24 && ny < 456) begin
            check(bg.tileX == (nx-144)/24 && bg.tileY == (ny-24)/24, "unchanged 20x18 tile index");
            check(obstacleDR === rock((nx-144)/24,(ny-24)/24), "unchanged obstacle map");
        end
        prevPrevX = prevX; prevPrevY = prevY; lastExpectedRGB = expectedRGB;
        prevX = nx; prevY = ny;
    endtask
    initial begin
        #12; resetN = 1;
        check(sx == 48 && sy == 64 && hx == 48 && hy == 148, "score origins");
        for (y = 0; y < 480; y = y + 1)
            for (x = 0; x < 640; x = x + 1) scan(x,y);
        scan(1023,1023); scan(0,0); scan(0,0);
        check(labelPixels > 500 && fontPixels > 500, "labels and real numeric font are nonempty");
        $display("PASS: full-frame streaming real-font pixels, 5 numeric fields, labels, panel, mux, no arena overlap");
        // Explicit leading-zero and saturation-display values, including every digit 0..9.
        ruby = 12'h000; sapphire = 12'h000; cursed = 12'h999; sl = 0; sh = 1;
        for (y = 260; y < 428; y = y + 1)
            for (x = 40; x < 88; x = x + 1) scan(x,y);
        scan(0,0); scan(0,0);
        $display("HUD_RENDER_PASS: leading zeros, 999 display, real MIF data and aligned DR/RGB");
        testPassed = 1;
        $finish;
    end
    initial begin #5000000; $fatal(1, "render test timeout"); end
endmodule
