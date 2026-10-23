// Supplied approved V4 floor selection; frozen obstacles remain in jungle_map.svh.
// Seed 20261014; 270/43/36/11 cells. No supplied pixel changes or floor rotation.
function automatic [1:0] jungleFloorTile(input logic [4:0] x, y);
    logic [39:0] row;
    begin
        case (y)
        5'd0: row = 40'h0004008200;
        5'd1: row = 40'h0400110014;
        5'd2: row = 40'h8480208502;
        5'd3: row = 40'h0060802000;
        5'd4: row = 40'h0840010088;
        5'd5: row = 40'h440510080C;
        5'd6: row = 40'h3100040140;
        5'd7: row = 40'h0020883000;
        5'd8: row = 40'h00300B4132;
        5'd9: row = 40'h0801600204;
        5'd10: row = 40'h0080042001;
        5'd11: row = 40'h0200200470;
        5'd12: row = 40'hC004010100;
        5'd13: row = 40'h380208010E;
        5'd14: row = 40'h4080201004;
        5'd15: row = 40'h0030004080;
        5'd16: row = 40'h0200401000;
        5'd17: row = 40'h8010080101;
        default: row = 40'd0;
        endcase
        jungleFloorTile = (x < 20 && y < 18) ? ((row >> (x * 2)) & 40'h3) : 2'd0;
    end
endfunction
