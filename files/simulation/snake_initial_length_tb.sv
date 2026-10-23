`timescale 1ns/1ps
module snake_initial_length_tb;
    localparam integer HISTORY=379;
    logic clk=0, resetN=0, sof=0, key5=0;
    always #5 clk=~clk;
    logic up=0, rightKey=0, leftKey=0, down=0;
    logic manual=0, wall=0, red=0, blue=0, black=0;
    logic signed [10:0] manualX=384, manualY=240;
    wire signed [10:0] motionX,motionY;
    wire signed [10:0] hx=manual ? manualX : motionX;
    wire signed [10:0] hy=manual ? manualY : motionY;
    wire [2:0] direction;
    wire running,clear,ended,lost,won,rp,bp,kp,hit,dr;
    wire [7:0] rgb;
    wire referenceDR,referenceHit;
    wire [7:0] referenceRGB;
    wire [5:0] referenceLength;
    wire [5:0] length;
    wire [3:0] ones,tens;
    wire [6:0] onesSegments,tensSegments;
    logic [10:0] px=0,py=0;
    integer checks=0, samples=0, expectedLength=14, defeats=0, frames=0, visiblePixels=0;
    integer historyX[0:HISTORY-1],historyY[0:HISTORY-1];
    bit testPassed=0;

    game_controller game(clk,resetN,sof,1'b1,hit,wall,1'b0,
        1'b0,1'b0,1'b0,4'd0,4'd0,key5,
        running,clear,ended,lost,won,rp,bp,kp);
    snake_head motion(clk,resetN,sof,up,rightKey,leftKey,down,
        running,11'sd130,motionX,motionY,direction);
    snake_body body(clk,resetN,clear,running,sof,px,py,hx,hy,
        red,blue,black,dr,rgb,length,hit);
    // Frozen renderer/history reference with only its initial-length parameter
    // adjusted. Its unguarded startup collision output is deliberately unused.
    snake_body_32_reference #(.MAX_SEGMENTS(63),.INITIAL_LENGTH(14)) reference(
        clk,resetN,clear,running,sof,px,py,hx,hy,
        red,blue,black,referenceDR,referenceRGB,referenceLength,referenceHit);
    snakeLengthDigits digits(length,ones,tens);
    SEG7 onesDisplay(clk,resetN,ones,1'b1,onesSegments);
    SEG7 tensDisplay(clk,resetN,tens,1'b1,tensSegments);

    function automatic logic [6:0] decimalSegments(input integer digit);
        case(digit)
            0:decimalSegments=7'b1000000;
            1:decimalSegments=7'b1111001;
            2:decimalSegments=7'b0100100;
            3:decimalSegments=7'b0110000;
            4:decimalSegments=7'b0011001;
            5:decimalSegments=7'b0010010;
            6:decimalSegments=7'b0000010;
            7:decimalSegments=7'b1111000;
            8:decimalSegments=7'b0000000;
            9:decimalSegments=7'b0011000;
            default:decimalSegments=7'b1111111;
        endcase
    endfunction

    task automatic check(input logic ok,input string message);
        checks++;
        if(ok!==1'b1) $fatal(1,"INITIAL14 check=%0d: %s",checks,message);
    endtask

    task automatic cycle;
        integer sx,sy,i,j,k,seedX,seedY;
        bit wasReset,wasClear,wasFrame,wasRunning,expectedHit;
        begin
            #1; sx=hx;sy=hy;wasReset=!resetN;wasClear=clear;
            wasFrame=sof;wasRunning=running;
            @(posedge clk);#1;
            if(wasReset || wasClear) begin
                expectedLength=14;samples=0;
                seedX=wasReset ? 384 : sx;seedY=wasReset ? 240 : sy;
                for(i=0;i<HISTORY;i++) begin historyX[i]=seedX;historyY[i]=seedY;end
            end else begin
                if(black) expectedLength=(expectedLength+5>63)?63:expectedLength+5;
                else if(blue) expectedLength=(expectedLength<=3)?1:expectedLength-3;
                else if(red) expectedLength=(expectedLength==63)?63:expectedLength+1;
                if(wasRunning && wasFrame) begin
                    for(i=HISTORY-1;i>0;i--) begin
                        historyX[i]=historyX[i-1];historyY[i]=historyY[i-1];
                    end
                    historyX[0]=sx;historyY[0]=sy;
                    if(samples<HISTORY && (samples!=0 || sx!=384 || sy!=240)) samples++;
                end
            end
            check(length==expectedLength,"independent arithmetic and reset oracle");
            check(length===referenceLength && dr===referenceDR && rgb===referenceRGB,
                "fourteen-node Emerald RGB/opacity/output latency equal frozen renderer");
            check(body.insideBody===reference.insideBody && body.address===reference.address &&
                  body.spriteIndex===reference.spriteIndex && body.selectedSegment===reference.selectedSegment,
                "fourteen-node ownership, orientation and ROM address equal frozen renderer");
            if(dr)visiblePixels++;
            check(ones==expectedLength%10 && tens==expectedLength/10,"live physical-display decimal digits");
            check(onesSegments===decimalSegments(expectedLength%10) &&
                  tensSegments===decimalSegments(expectedLength/10),"actual active-low seven-segment glyphs");
            check(body.validTrailSamples==samples,"movement-history validity and saturation");
            for(i=0;i<HISTORY;i++)
                check(body.trailX[i]==historyX[i] && body.trailY[i]==historyY[i],
                    "all 379 history entries retain exact frame sampling/seed behavior");
            expectedHit=0;
            for(j=4;j<expectedLength;j++) begin
                k=(j+1)*6;
                if(running && k<samples && hx+6<historyX[k]+18 &&
                   hx+18>historyX[k]+6 && hy+6<historyY[k]+18 && hy+18>historyY[k]+6)
                    expectedHit=1;
            end
            check(hit===expectedHit,"independent per-node mature-history collision oracle");
            if(lost) defeats++;
            @(negedge clk);
        end
    endtask

    task automatic frame;
        integer node;
        sof=1;cycle();sof=0;
        node=frames%expectedLength;frames++;
        px=historyX[(node+1)*6]+7;py=historyY[(node+1)*6]+11;
        repeat(4)cycle();
    endtask
    task automatic hardwareReset;
        resetN=0;key5=0;sof=0;red=0;blue=0;black=0;
        up=0;rightKey=0;leftKey=0;down=0;wall=0;
        cycle();cycle();resetN=1;repeat(3)cycle();
        check(length==14 && tens==1 && ones==4 && !running && !hit,
            "hardware reset restores fourteen and the 14 display in menu");
    endtask
    task automatic startGame;
        key5=0;cycle();key5=1;repeat(5)cycle();key5=0;cycle();
        check(running && length==14 && samples==0 && !hit,
            "keypad-5 start/restart gives fourteen without immediate defeat");
    endtask
    task automatic pulse(input integer kind);
        red=kind==1;blue=kind==2;black=kind==3;cycle();red=0;blue=0;black=0;cycle();
    endtask

    initial begin : stimulus
        integer d,f,beforeDefeats,n;
        hardwareReset();
        check(body.MAX_SEGMENTS==63 && body.MAX_TRAIL==379 && body.SEGMENT_SPACING==6,
            "capacity and original history spacing unchanged");
        startGame();beforeDefeats=defeats;
        repeat(420) begin frame();check(running && !hit,"waiting for input never matures spawn overlap");end
        check(samples==0 && defeats==beforeDefeats,"stationary startup stays safe beyond a full history");

        // Real production motion/controller integration in every direction.
        for(d=1;d<=4;d++) begin
            manual=0;hardwareReset();startGame();
            case(d)
                1:up=1;
                2:rightKey=1;
                3:leftKey=1;
                4:down=1;
            endcase
            for(f=0;f<94;f++) begin
                frame();check(running && !hit && length==14,"safe real initial movement/body formation");
            end
            check(samples>84,"all fourteen spaced body nodes have actual movement history");
            case(d)
                1:check(motionY<240 && motionX==384,"up speed/path unchanged");
                2:check(motionX>384 && motionY==240,"right speed/path unchanged");
                3:check(motionX<384 && motionY==240,"left speed/path unchanged");
                4:check(motionY>240 && motionX==384,"down speed/path unchanged");
            endcase
            // Restart after a genuine controller defeat; no reset shortcut.
            wall=1;repeat(3)cycle();wall=0;repeat(3)cycle();
            check(!running,"wall defeat remains active");
            up=0;rightKey=0;leftKey=0;down=0;startGame();
            repeat(110)begin frame();check(running && !hit,"local restart followed by input wait remains safe");end
        end

        pulse(1);check(length==15,"Ruby +1 from fourteen");
        pulse(2);check(length==12,"Sapphire -3");
        pulse(3);check(length==17,"Cursed +5");
        repeat(12)pulse(3);check(length==63,"growth saturates at unchanged maximum 63");
        pulse(1);pulse(3);check(length==63,"no overflow or queued excess growth");
        pulse(2);check(length==60,"shrink after saturation has no pending growth");
        repeat(22)pulse(2);check(length==1,"minimum one preserved");
        hardwareReset();startGame();

        // Before all nodes mature, a sampled old point must still collide:
        // this distinguishes per-node validity from a blanket startup grace timer.
        manual=1;manualX=500;manualY=300;
        frame();
        manualX=200;manualY=100;
        for(f=0;f<30;f++)frame();
        check(samples==31 && body.trailX[30]==500 && body.trailY[30]==300,
            "first checked body node matures exactly at actual sample index 30");
        check(samples<85 && running && !hit,"no full-body/global grace period required");
        manualX=500;manualY=300;#1;
        check(hit,"legitimate node-four collision active while later nodes are still invalid");
        cycle();cycle();check(!running,"real self collision reaches the defeat controller");
        manual=0;startGame();check(length==14,"self-collision restart restores fourteen");

        // Full-age saturation and the final legal history index remain valid.
        repeat(5)pulse(2);
        check(length==1,"synthetic stationary fill uses a one-node snake");
        manual=1;manualX=200;manualY=100;
        repeat(379)frame();
        check(samples==379,"history validity counter saturates without wrap");
        repeat(12)frame();check(samples==379,"history remains mature on subsequent frames");
        // Normal post-movement stationary history is deliberately not exempt.
        hardwareReset();check(length==14 && samples==0,"late hardware reset clears age and restores fourteen");
        check(visiblePixels>0,"actual opaque Emerald body pixels exercised during formation");
        $display("SNAKE_INITIAL_LENGTH_14_PASS checks=%0d defeats=%0d visible=%0d",checks,defeats,visiblePixels);
        testPassed=1;$finish;
    end
    initial begin #1000000;$fatal(1,"initial-length test timeout");end
endmodule
