`timescale 1ns/1ps
// Focused Phase 2B.1 unit checks, not a full-system or visual gameplay test.
module arena_geometry_tb;
    logic clk = 0, resetN = 0;
    always #5 clk = ~clk;
    logic [10:0] px = 0, py = 0, bodyPX = 0, bodyPY = 0;
    wire [7:0] bgRGB;
    wire borderDR, obstacleDR;
    back_ground_draw bg(clk, resetN, px, py, bgRGB, borderDR, obstacleDR);

    logic redRise = 0, blueRise = 0, blackRise = 0, feedback = 0;
    wire [4:0] gx, gy, bx, by, kx, ky;
    wire re, be, ke;
    randomCounter gen(clk, resetN, redRise, blueRise, blackRise,
        feedback && re, feedback && be, feedback && ke, gx, gy, bx, by, kx, ky);
    logic manual = 1;
    logic [4:0] mx = 0, my = 0, mbx = 19, mby = 17, mkx = 18, mky = 17;
    wire [4:0] rx = manual ? mx : gx, ry = manual ? my : gy;
    wire [4:0] ux = manual ? mbx : bx, uy = manual ? mby : by;
    wire [4:0] vx = manual ? mkx : kx, vy = manual ? mky : ky;
    wire [4:0] fx, fy, fbx, fby, fkx, fky;
    apple_position_controller validator(rx, ry, ux, uy, vx, vy,
        re, be, ke, fx, fy, fbx, fby, fkx, fky);
    wire signed [10:0] ax, ay, abx, aby, akx, aky;
    apple_topleft_calc calc(fx, fy, fbx, fby, fkx, fky, ax, ay, abx, aby, akx, aky);

    logic sof = 0, started = 0, up = 0, rightKey = 0, leftKey = 0, down = 0;
    logic clearBody = 0;
    wire signed [10:0] hx, hy;
    wire [2:0] headDir;
    snake_head head(clk, resetN, sof, up, rightKey, leftKey, down,
        started, 11'sd130, hx, hy, headDir);
    wire bodyDR, selfHit;
    wire [7:0] bodyRGB;
    wire [5:0] length;
    snake_body body(clk, resetN, clearBody, started, sof, bodyPX, bodyPY,
        hx, hy, 1'b0, 1'b0, 1'b0, bodyDR, bodyRGB, length, selfHit);
    logic [10:0] ox = 0, oy = 0;
    logic [2:0] rotation = 1;
    wire headDR;
    wire [7:0] headRGB;
    headBitMap bitmap(clk, resetN, ox, oy, 1'b1, rotation, headDR, headRGB);

    function automatic bit rock(input integer x, input integer y);
        rock = ((y == 3 || y == 4) && (x == 11 || x == 12)) ||
               ((y == 9 || y == 10) && (x == 3 || x == 4)) ||
               ((y == 11 || y == 12) && (x >= 3 && x <= 6));
    endfunction
    task automatic check(input bit ok, input string description);
        if (!ok) $fatal(1, "FAIL: %s at %0t", description, $time);
    endtask
    task automatic frame;
        @(negedge clk); sof = 1;
        @(negedge clk); sof = 0;
        repeat (3) @(negedge clk);
    endtask
    task automatic generator_tick;
        @(posedge clk); #1;
        check(gx < 20 && gy < 18 && bx < 20 && by < 18 && kx < 20 && ky < 18,
            "all generated axes in range");
    endtask
    bit [359:0] seenRed = 0, seenBlue = 0, seenBlack = 0;
    integer x, y, i, d, previousX, previousY, nextX, nextY, expectedAddress;
    bit inArena;
    initial begin
        #12; resetN = 1; #1;
        check(hx == 384 && hy == 240 && length == 4, "new aligned snake start and original length");
        check(gx == 7 && gy == 3 && bx == 5 && by == 10 && kx == 12 && ky == 6,
            "legacy seed grid positions preserved");
        for (i = 0; i < body.MAX_TRAIL; i = i + 1)
            check(body.trailX[i] == 384 && body.trailY[i] == 240, "body reset alignment");

        // Every visible pixel: half-open bounds, grid index, tile address and rock collision.
        for (y = 0; y < 480; y = y + 1) begin
            for (x = 0; x < 640; x = x + 1) begin
                px = x; py = y; #1;
                inArena = x >= 144 && x < 624 && y >= 24 && y < 456;
                check(borderDR === !inArena, "arena border bounds");
                if (inArena) begin
                    check(bg.selectedRegion == 1, "arena overrides old top HUD");
                    check(bg.tileX == (x-144)/24 && bg.tileY == (y-24)/24, "five-bit tile indexing");
                    check(bg.tileOffsetX == (x-144)%24 && bg.tileOffsetY == (y-24)%24,
                        "24-pixel tile offsets");
                    check(bg.tileAddress == ((y-24)%24)*24 + (x-144)%24, "tile ROM address");
                    check(obstacleDR === rock((x-144)/24, (y-24)/24), "displayed obstacle bounds");
                    check(validator.rockMap[(y-24)/24][(x-144)/24] === obstacleDR,
                        "display and spawn-exclusion maps agree");
                end else check(obstacleDR === 1'b0, "no obstacles outside arena");
            end
        end
        $display("PASS: all 307200 visible pixels and all 360 obstacle-map cells");

        // All representable red inputs; other colors parked in distinct safe edge cells.
        for (y = 0; y < 32; y = y + 1)
            for (x = 0; x < 32; x = x + 1) begin
                mx = x; my = y; #1;
                check(re === (x >= 20 || y >= 18 || rock(x,y) ||
                    (x == 19 && y == 17) || (x == 18 && y == 17)), "red validity/overlap");
                if (x < 20 && y < 18) begin
                    check(ax == 144+x*24 && ay == 24+y*24, "relic grid-to-pixel alignment");
                    check(ax >= 144 && ax+24 <= 624 && ay >= 24 && ay+24 <= 456,
                        "entire relic rectangle within arena");
                end
            end
        mx = 0; my = 0; mkx = 1; mky = 0;
        for (y = 0; y < 32; y = y + 1)
            for (x = 0; x < 32; x = x + 1) begin
                mbx = x; mby = y; #1;
                check(be === (x >= 20 || y >= 18 || rock(x,y) || (y == 0 && x <= 1)),
                    "blue validity/overlap");
                if (x < 20 && y < 18) check(abx == 144+x*24 && aby == 24+y*24, "blue alignment");
            end
        mbx = 1; mby = 0;
        for (y = 0; y < 32; y = y + 1)
            for (x = 0; x < 32; x = x + 1) begin
                mkx = x; mky = y; #1;
                check(ke === (x >= 20 || y >= 18 || rock(x,y) || (y == 0 && x <= 1)),
                    "black validity/overlap");
                if (x < 20 && y < 18) check(akx == 144+x*24 && aky == 24+y*24, "black alignment");
            end
        mx = 0; my = 0; mbx = 0; mby = 0; mkx = 0; mky = 0; #1;
        check(re && be && ke, "all pair-overlap flags");
        $display("PASS: 1024 inputs per color, valid relic extents and overlap rejection");

        manual = 0;
        @(negedge clk); redRise = 1; blueRise = 1; blackRise = 1;
        for (i = 0; i < 1024; i = i + 1) begin
            generator_tick();
            seenRed[gy*20+gx] = 1;
            seenBlue[by*20+bx] = 1;
            seenBlack[ky*20+kx] = 1;
        end
        check(&seenRed && &seenBlue && &seenBlack, "every grid cell reachable for every color");
        @(negedge clk); redRise = 0; blueRise = 0; blackRise = 0;
        previousX = gx; previousY = gy;
        repeat (8) generator_tick();
        check(gx == previousX && gy == previousY, "positions hold without sampling");
        // Find a genuinely rejected candidate, then let the existing error feedback reroll it.
        @(negedge clk); redRise = 1; blueRise = 1; blackRise = 1;
        i = 0;
        while (!(re || be || ke) && i < 1024) begin
            generator_tick(); i = i + 1;
        end
        check(re || be || ke, "exercise an actual obstacle/overlap rejection");
        @(negedge clk); redRise = 0; blueRise = 0; blackRise = 0; feedback = 1;
        #1;
        check(gen.sampleRed === re && gen.sampleBlue === be && gen.sampleBlack === ke,
            "error flags drive reroll sampling");
        repeat (1024) generator_tick();
        check(!re && !be && !ke, "feedback settles to safe distinct cells");
        @(negedge clk); redRise = 1;
        #1; check(gen.sampleRed && gen.sampleBlack && !gen.sampleBlue, "red also rerolls black");
        generator_tick();
        @(negedge clk); redRise = 0;
        repeat (1024) generator_tick();
        check(!re && !be && !ke, "safe respawn after red hit");
        $display("PASS: full 1024-state counter cycles, all 360 cells per color and reroll feedback");

        // Existing sprite dimensions and rotation address range, independent of palette.
        for (d = 1; d <= 4; d = d + 1)
            for (y = 0; y < 24; y = y + 1)
                for (x = 0; x < 24; x = x + 1) begin
                    rotation = d; ox = x; oy = y; #1;
                    case (d)
                        1: expectedAddress = y*24+x;
                        2: expectedAddress = (23-x)*24+y;
                        3: expectedAddress = x*24+(23-y);
                        4: expectedAddress = (23-y)*24+(23-x);
                    endcase
                    check(bitmap.address == expectedAddress && bitmap.address < 576, "24x24 head rotation");
                end
        bodyPX = 384; bodyPY = 240; #1;
        check(body.insideBody && body.address == 0, "body top-left pixel aligned");
        bodyPX = 407; bodyPY = 263; #1;
        check(body.insideBody && body.address == 575, "body final pixel is 24x24");
        bodyPX = 408; #1; check(!body.insideBody, "body right bound exclusive");

        // Four directions from the same start; smooth interpolation is intentionally retained.
        for (d = 1; d <= 4; d = d + 1) begin
            @(negedge clk); started = 0; up = 0; rightKey = 0; leftKey = 0; down = 0;
            repeat (3) @(negedge clk);
            clearBody = 1; @(negedge clk); clearBody = 0;
            check(hx == 384 && hy == 240, "new-game start");
            check(body.trailX[0] == 384 && body.trailY[0] == 240, "new-game body trail");
            started = 1;
            case (d)
                1: begin up = 1; nextX = 384; nextY = 216; end
                2: begin rightKey = 1; nextX = 408; nextY = 240; end
                3: begin leftKey = 1; nextX = 360; nextY = 240; end
                4: begin down = 1; nextX = 384; nextY = 264; end
            endcase
            frame(); frame();
            for (i = 0; i < 12; i = i + 1) frame();
            check(hx == nextX && hy == nextY, "exact 24-pixel first movement target");
            check((hx-144)%24 == 0 && (hy-24)%24 == 0, "head target aligned with arena");
            check((head.targetX-144*64)%(24*64) == 0 &&
                  (head.targetY-24*64)%(24*64) == 0, "next fixed-point target alignment");
            check(body.trailX[0] >= 360 && body.trailX[0] <= 408 &&
                  body.trailY[0] >= 216 && body.trailY[0] <= 264, "body follows translated head");
            check(length == 4, "original length unchanged");
        end
        $display("PASS: head/body reset, 24x24 ROM addresses, four 24-pixel movement directions");
        $display("ARENA_GEOMETRY_PASS");
        $finish;
    end
    initial begin #1000000; $fatal(1, "test timeout"); end
endmodule
