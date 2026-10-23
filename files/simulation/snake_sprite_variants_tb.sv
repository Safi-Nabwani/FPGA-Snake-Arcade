`timescale 1ns/1ps

module snake_emerald_production_tb;
    localparam integer MAX_NODES = 63;
    localparam integer VARIANT = 1;
    localparam integer LOCAL_X = 7;
    localparam integer LOCAL_Y = 11;
    localparam integer LOCAL_ADDRESS = LOCAL_Y * 24 + LOCAL_X;

    logic clk = 0;
    logic resetN = 0;
    always #5 clk = ~clk;

    logic [10:0] headPixelX = 0, headPixelY = 0;
    logic signed [10:0] headTopLeftX = 200, headTopLeftY = 100;
    logic [2:0] headDirection = 1;
    wire headDR;
    wire [7:0] headRGB;

    logic clear = 0, gameStarted = 1, startOfFrame = 0;
    logic [10:0] bodyPixelX = 0, bodyPixelY = 0;
    logic signed [10:0] movingHeadX = 384, movingHeadY = 240;
    logic redPulse = 0, bluePulse = 0, blackPulse = 0;
    wire bodyDR, selfCollision;
    wire [7:0] bodyRGB;
    wire [5:0] snakeLength;

    integer checks = 0;
    bit testPassed = 0;
    function automatic integer compactAddress(input integer index);
        integer x,y,b;
        begin
            x=LOCAL_X;y=LOCAL_Y;b=0;
            case(index)
                1,11:begin x=LOCAL_Y;y=23-LOCAL_X;end
                2,12:begin x=23-LOCAL_X;y=23-LOCAL_Y;end
                3,8,13:begin x=23-LOCAL_Y;y=LOCAL_X;end
                9:begin x=LOCAL_Y;y=23-LOCAL_X;end
            endcase
            case(index)
                5:b=1;6,8:b=2;7,9:b=3;10,11,12,13:b=4;
            endcase
            compactAddress=b*576+y*24+x;
        end
    endfunction

    jungle_head_draw head (
        clk, resetN, headPixelX, headPixelY, headTopLeftX, headTopLeftY,
        headDirection, headDR, headRGB
    );

    snake_body body (
        clk, resetN, clear, gameStarted, startOfFrame,
        bodyPixelX, bodyPixelY, movingHeadX, movingHeadY,
        redPulse, bluePulse, blackPulse,
        bodyDR, bodyRGB, snakeLength, selfCollision
    );

    task automatic check(input logic condition, input string message);
        checks++;
        if (!condition)
            $fatal(1, "variant=%0d FAIL: %s", VARIANT, message);
    endtask

    task automatic settle;
        repeat (3) begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic checkHead(input logic [2:0] direction, input integer expectedIndex);
        begin
            @(negedge clk);
            headDirection = direction;
            headPixelX = headTopLeftX + LOCAL_X;
            headPixelY = headTopLeftY + LOCAL_Y;
            #1;
            check(head.spriteIndex == expectedIndex, "head direction selects expected sprite");
            check(head.atlasAddress == compactAddress(expectedIndex),
                  "head atlas address is sprite*576+y*24+x");
            settle();
            check(head.spriteWord[8] == 1'b1, "head center pixel is opaque");
            check(headDR == head.spriteWord[8] && headRGB == head.spriteWord[7:0],
                  "head alpha/color pipeline is aligned");
        end
    endtask

    task checkBody(
        input integer towardHeadX,
        input integer towardHeadY,
        input integer towardTailX,
        input integer towardTailY,
        input integer expectedIndex
    );
        begin
            force body.snakeLength = 6'd2;
            force body.trailX[0] = towardHeadX;
            force body.trailY[0] = towardHeadY;
            force body.trailX[6] = 11'd400;
            force body.trailY[6] = 11'd300;
            force body.trailX[12] = towardTailX;
            force body.trailY[12] = towardTailY;
            @(negedge clk);
            bodyPixelX = 400 + LOCAL_X;
            bodyPixelY = 300 + LOCAL_Y;
            #1;
            check(body.insideBody && body.selectedSegment == 0,
                  "body test pixel resolves to first visible segment");
            check(body.spriteIndex == expectedIndex, "body connectivity selects expected sprite");
            check(body.address == LOCAL_ADDRESS, "body local address remains y*24+x");
            check(body.atlasAddress == compactAddress(expectedIndex),
                  "body atlas address is sprite*576+y*24+x");
            settle();
            check(body.spriteWord[8] == 1'b1, "body center pixel is opaque");
            check(bodyDR == body.spriteWord[8] && bodyRGB == body.spriteWord[7:0],
                  "body alpha/color pipeline is aligned");
        end
    endtask

    task checkTail(
        input integer towardHeadX,
        input integer towardHeadY,
        input integer expectedIndex
    );
        begin
            force body.snakeLength = 6'd1;
            force body.trailX[0] = towardHeadX;
            force body.trailY[0] = towardHeadY;
            force body.trailX[6] = 11'd400;
            force body.trailY[6] = 11'd300;
            @(negedge clk);
            bodyPixelX = 400 + LOCAL_X;
            bodyPixelY = 300 + LOCAL_Y;
            #1;
            check(body.insideBody && body.selectedSegment == 0,
                  "minimum-length snake resolves its only body segment");
            check(body.spriteIndex == expectedIndex, "tail direction selects expected sprite");
            check(body.atlasAddress == compactAddress(expectedIndex),
                  "tail atlas address is in range and aligned");
            settle();
            check(body.spriteWord[8] == 1'b1, "tail center pixel is opaque");
            check(bodyDR == body.spriteWord[8] && bodyRGB == body.spriteWord[7:0],
                  "tail alpha/color pipeline is aligned");
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk);
        resetN = 1;

        // Existing direction convention: 1 up, 2 right, 3 left, 4 down.
        checkHead(3'd1, 0);
        checkHead(3'd2, 1);
        checkHead(3'd4, 2);
        checkHead(3'd3, 3);

        // Straight body sprites.
        checkBody(400, 294, 400, 306, 4); // up + down
        checkBody(394, 300, 406, 300, 5); // left + right

        // Corner sprites named by their two connected sides.
        checkBody(400, 294, 394, 300, 6); // top-left
        checkBody(400, 294, 406, 300, 7); // top-right
        checkBody(400, 306, 394, 300, 8); // bottom-left
        checkBody(400, 306, 406, 300, 9); // bottom-right

        // Tail name is the pointed direction, opposite the body connection.
        checkTail(400, 306, 10); // body below -> tail points up
        checkTail(394, 300, 11); // body left  -> tail points right
        checkTail(400, 294, 12); // body above -> tail points down
        checkTail(406, 300, 13); // body right -> tail points left

        // Exercise the production maximum, including history index 378.
        force body.snakeLength = MAX_NODES;
        force body.trailX[(MAX_NODES-1)*6] = 11'd600;
        force body.trailY[(MAX_NODES-1)*6] = 11'd294;
        force body.trailX[MAX_NODES*6] = 11'd600;
        force body.trailY[MAX_NODES*6] = 11'd300;
        @(negedge clk);
        bodyPixelX = 600 + LOCAL_X;
        bodyPixelY = 300 + 20; // below the overlapping segment 30 rectangle
        #1;
        check(body.insideBody && body.selectedSegment == MAX_NODES-1,
              "maximum-length tail uses legal trail index 378");
        check(body.spriteIndex == 12,
              "maximum-length tail selection is in range");

        // Release visual-geometry overrides before exercising production state logic.
        release body.trailX[0];
        release body.trailY[0];
        release body.trailX[6];
        release body.trailY[6];
        release body.trailX[12];
        release body.trailY[12];
        release body.trailX[(MAX_NODES-1)*6];
        release body.trailY[(MAX_NODES-1)*6];
        release body.trailX[MAX_NODES*6];
        release body.trailY[MAX_NODES*6];
        release body.snakeLength;

        // Original growth/shrink behavior is still active around the new renderer.
        @(negedge clk); clear = 1'b1; redPulse = 0; bluePulse = 0; blackPulse = 0;
        @(posedge clk); #1;
        check(snakeLength == 6'd14, "new game restores fourteen body nodes");
        @(negedge clk); clear = 1'b0; redPulse = 1'b1;
        @(posedge clk); #1;
        check(snakeLength == 6'd15, "Ruby grows by one");
        @(negedge clk); redPulse = 1'b0; bluePulse = 1'b1;
        @(posedge clk); #1;
        check(snakeLength == 6'd12, "Sapphire shrinks by three");
        @(negedge clk); bluePulse = 1'b0; blackPulse = 1'b1;
        @(posedge clk); #1;
        check(snakeLength == 6'd17, "Cursed relic grows by five");
        @(negedge clk); blackPulse = 1'b0; bluePulse = 1'b1;
        @(posedge clk); #1;
        check(snakeLength == 6'd14, "second Sapphire shrink remains exact");
        @(negedge clk);
        @(posedge clk); #1;
        check(snakeLength == 6'd11, "third Sapphire shrink remains exact");
        repeat (4) begin
            @(negedge clk);
            @(posedge clk); #1;
        end
        check(snakeLength == 6'd1, "shrink saturates at the one-segment minimum");
        @(negedge clk); bluePulse = 1'b0;

        // A forced collision geometry must first refer to actual sampled history.
        movingHeadX = 385;
        startOfFrame = 1'b1;
        repeat (31) begin @(posedge clk); #1; end
        @(negedge clk); startOfFrame = 1'b0;

        // Self-collision remains geometric and independent of the visual alpha mask.
        force body.trailX[30] = movingHeadX[10:0];
        force body.trailY[30] = movingHeadY[10:0];
        force body.snakeLength = 6'd5;
        #1;
        check(selfCollision, "legacy self-collision geometry remains active");
        release body.trailX[30];
        release body.trailY[30];
        release body.snakeLength;

        // No renderer may request pixels outside its 24x24 cell.
        @(negedge clk);
        headPixelX = headTopLeftX - 1;
        headPixelY = headTopLeftY;
        bodyPixelX = 0;
        bodyPixelY = 0;
        settle();
        check(!headDR && !bodyDR, "no rendering occurs outside snake cells");

        $display("SNAKE_EMERALD_PRODUCTION_PASS checks=%0d", checks);
        testPassed = 1;
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Emerald production sprite test timeout");
    end
endmodule
