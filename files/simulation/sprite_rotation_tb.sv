`timescale 1ns/1ps
module sprite_rotation_tb;
    reg clk=0,resetN=0;
    always #5 clk=~clk;
    reg [10:0] px=0,py=0;
    reg [2:0] dir=1;
    wire hd,bd,collision;
    wire [7:0] hr,br;
    wire [5:0] length;
    reg [8:0] original[0:8063];
    reg [8:0] previousH=0,previousB=0;
    reg previousValid=0,enabled=0;
    integer sprite=0,checks=0,headIndex=0;
    bit testPassed=0;
    jungle_head_draw head(clk,resetN,px,py,11'sd400,11'sd300,dir,hd,hr);
    snake_body body(clk,resetN,1'b0,1'b1,1'b0,px,py,11'sd384,11'sd240,
        1'b0,1'b0,1'b0,bd,br,length,collision);
    task check(input bit ok,input string why);
        checks++;if(!ok)$fatal(1,"sprite=%0d pixel=(%0d,%0d) %s",sprite,px,py,why);
    endtask
    always @(posedge clk) begin
        #1;
        if(resetN)begin
            check(hd===(previousValid && previousH[8]),"head DR latency");
            check(hr===(previousValid ? previousH[7:0] : 8'hff),"head color latency including hidden RGB");
            check(bd===(previousValid && previousB[8]),"body DR latency");
            check(br===(previousValid ? previousB[7:0] : 8'hff),"body color latency including hidden RGB");
            if(enabled)begin
                check(head.spriteWord===original[headIndex*576+(py-300)*24+px-400],"head all nine ROM bits");
                check(body.spriteWord===original[sprite*576+(py-300)*24+px-400],"body all nine ROM bits");
                previousH=original[headIndex*576+(py-300)*24+px-400];
                previousB=original[sprite*576+(py-300)*24+px-400];
            end
            previousValid=enabled;
        end else begin previousValid=0;previousH=0;previousB=0;end
    end
    initial begin
        $readmemh("db/sprite_opt_build/original.hex",original);
        force body.selectedCurrentX=400;force body.selectedCurrentY=300;
        force body.insideBody=enabled;
        force body.spriteIndex=sprite;
        repeat(3)@(negedge clk);resetN=1;
        for(integer i=4;i<14;i++)begin
            sprite=i;headIndex=(i-4)%4;
            case(headIndex)0:dir=1;1:dir=2;2:dir=4;3:dir=3;endcase
            for(integer y=0;y<24;y++)for(integer x=0;x<24;x++)begin
                @(negedge clk);enabled=1;px=400+x;py=300+y;
            end
            @(negedge clk);enabled=0;px=0;py=0;
            repeat(2)@(negedge clk);
        end
        resetN=0;repeat(2)@(negedge clk);
        check(!hd && !bd && hr==255 && br==255,"reset outputs unchanged");
        testPassed=1;$display("SPRITE_ROTATION_PIPELINE_PASS checks=%0d all14sprites alpha hiddenRGB two_stage_latency blanking reset",checks);$finish;
    end
    initial begin #1000000;$fatal(1,"timeout");end
endmodule
