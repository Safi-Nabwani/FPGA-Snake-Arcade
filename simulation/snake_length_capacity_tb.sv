`timescale 1ns/1ps
`ifndef TEST_CAPACITY
`define TEST_CAPACITY 32
`endif
module snake_length_capacity_tb;
    localparam integer CAPACITY = `TEST_CAPACITY;
    localparam integer HISTORY = CAPACITY*6+1;
    logic clk=0, resetN=0, clear=0, started=1, sof=0;
    always #5 clk=~clk;
    logic [10:0] px=0, py=0;
    logic signed [10:0] hx=384, hy=240;
    logic red=0, blue=0, black=0;
    wire dr, refDR, hit, refHit;
    wire [7:0] rgb, refRGB;
    wire [5:0] length, refLength;
    logic [5:0] digitInput=0;
    wire [3:0] ones, tens;
    integer checks=0, frames=0, hitChecks=0, visibleChecks=0;
    integer expectedLength=4;
    integer pathPhase=0;
    bit testPassed=0;

    snake_body #(.MAX_SEGMENTS(CAPACITY)) dut(
        clk,resetN,clear,started,sof,px,py,hx,hy,red,blue,black,
        dr,rgb,length,hit);
    // Frozen pre-feature production RTL: independent linear selection and
    // original arithmetic/state logic, at 32 or the extended storage depth.
    snake_body_32_reference #(.MAX_SEGMENTS(CAPACITY)) reference(
        clk,resetN,clear,started,sof,px,py,hx,hy,red,blue,black,
        refDR,refRGB,refLength,refHit);
    snakeLengthDigits digits(digitInput,ones,tens);

    task automatic check(input logic condition,input string message);
        checks++;
        if(condition !== 1'b1)
            $fatal(1,"capacity=%0d check=%0d %s",CAPACITY,checks,message);
    endtask

    task automatic cycle;
        integer i;
        begin
            @(posedge clk); #1;
            if(!resetN || clear) expectedLength=4;
            else if(black) expectedLength=(expectedLength+5>CAPACITY)?CAPACITY:expectedLength+5;
            else if(blue) expectedLength=(expectedLength<=3)?1:expectedLength-3;
            else if(red) expectedLength=(expectedLength==CAPACITY)?CAPACITY:expectedLength+1;
            check(length==expectedLength,"integer length oracle / saturation / event priority");
            check(length===refLength && hit===refHit,"cycle-equivalent length and self collision");
            check(dr===refDR && rgb===refRGB,"cycle-equivalent Emerald RGB/alpha/latency");
            check(dut.insideBody===reference.insideBody &&
                  dut.address===reference.address &&
                  dut.spriteIndex===reference.spriteIndex &&
                  dut.selectedSegment===reference.selectedSegment,
                  "balanced selector preserves linear lowest rectangle, address and orientation");
            if(hit) hitChecks++;
            if(dr) visibleChecks++;
            if(sof || clear || !resetN) begin
                for(i=0;i<HISTORY;i++) begin
                    check(dut.trailX[i]===reference.trailX[i] &&
                          dut.trailY[i]===reference.trailY[i],"complete history equivalence");
                end
            end
            @(negedge clk);
        end
    endtask

    task automatic pulse(input integer mask);
        red=(mask&1)!=0; blue=(mask&2)!=0; black=(mask&4)!=0;
        cycle(); red=0; blue=0; black=0;
    endtask

    task automatic reach(input integer target);
        clear=1; cycle(); clear=0;
        if(target<4) begin pulse(2); end
        while(expectedLength<target) pulse(1);
        check(length==target,"requested boundary length reached without forcing state");
    endtask

    initial begin : stimulus
        integer i,j,x,y,target,mask,node;
        integer boundary[0:8];
        boundary[0]=1; boundary[1]=4; boundary[2]=31;
        boundary[3]=32; boundary[4]=33; boundary[5]=39;
        boundary[6]=40; boundary[7]=62; boundary[8]=63;
        cycle(); cycle(); resetN=1;
        check(dut.MAX_TRAIL==HISTORY,"parameter-derived history capacity");
        for(i=0;i<64;i++) begin
            digitInput=i; #1;
            check(ones==i%10 && tens==i/10,"all six-bit lengths have decimal digits");
        end
        // Explicit requested boundary lengths and all simultaneous pulse masks.
        for(j=0;j<9;j++) begin
            target=boundary[j];
            if(target<=CAPACITY) begin
                for(mask=0;mask<8;mask++) begin reach(target); pulse(mask); end
            end
        end
        // Exhaust every legal length with every event combination, including
        // 59..63 + Cursed, which must never wrap a six-bit counter.
        for(target=1;target<=CAPACITY;target++) begin
            for(mask=1;mask<8;mask++) begin reach(target); pulse(mask); end
        end
        reach(CAPACITY); pulse(4); pulse(1); pulse(2);
        check(length==CAPACITY-3,"excess growth discarded before later shrink");
        reach(CAPACITY);
        // Fill more than three complete histories using a rectangular route.
        // Adjacent body rectangles overlap, turns exercise all four corners,
        // and a repeated lap exercises real geometry-based self collisions.
        for(i=0;i<HISTORY*4;i++) begin
            sof=1; frames++;
            pathPhase=i%720;
            if(pathPhase<240) begin hx=144+pathPhase*2; hy=24; end
            else if(pathPhase<360) begin hx=624; hy=24+(pathPhase-240)*2; end
            else if(pathPhase<600) begin hx=624-(pathPhase-360)*2; hy=264; end
            else begin hx=144; hy=264-(pathPhase-600)*2; end
            node=i%CAPACITY;
            px=dut.trailX[(node+1)*6]+i%24;
            py=dut.trailY[(node+1)*6]+(i/24)%24;
            if(i%97==0) begin red=1; blue=1; black=1; end
            else if(i%89==0) blue=1;
            else if(i%17==0) red=1;
            cycle(); sof=0; red=0;blue=0;black=0;
            cycle();
        end
        // All visible coordinates and all same-pixel pipeline transitions.
        for(y=0;y<480;y++) for(x=0;x<640;x++) begin px=x;py=y;cycle();end
        cycle();cycle();
        check(visibleChecks>0,"opaque Emerald pixels exercised");
        check(hitChecks>0,"self collision exercised with live history");
        // Isolate the final node using live shifts, with no hierarchical force.
        hx=600;hy=300;reach(CAPACITY);
        hx=200;hy=100;sof=1;
        repeat(CAPACITY*6) cycle();
        sof=0;px=607;py=311;cycle();
        check(dut.insideBody && dut.selectedSegment==CAPACITY-1,
              "last legal history position selects the maximum tail index");
        check(dut.spriteIndex==11 && dut.address==271,
              "last tail points away from its toward-head neighbor with exact ROM offset");
        sof=1;cycle();sof=0;
        check(!dut.insideBody,"oldest sample leaves the trail after one more live shift");
        clear=1;sof=1;red=1;blue=1;black=1;cycle();
        check(length==4,"restart overrides frame shift and all collection pulses");
        clear=0;sof=0;red=0;blue=0;black=0;
        started=0;hx=100;hy=100;cycle();
        check(!hit,"self collision gated off in terminal state");
        resetN=0;cycle();check(length==4,"hardware reset restores initial length");
        $display("SNAKE_LENGTH_CAPACITY_PASS capacity=%0d history=%0d checks=%0d frames=%0d visible=%0d selfhits=%0d",
            CAPACITY,HISTORY,checks,frames,visibleChecks,hitChecks);
        testPassed=1;$finish;
    end
    initial begin #100000000;$fatal(1,"capacity test timeout");end
endmodule
