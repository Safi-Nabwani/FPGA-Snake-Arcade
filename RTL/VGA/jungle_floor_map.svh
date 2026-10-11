// Supplied approved floor selection only; obstacles remain in jungle_map.svh.
// Generated map: seed 20261011; 162/90/72/36 cells. No floor artwork rotation.
function automatic [1:0] jungleFloorTile(input logic [4:0] x, y);
    logic [39:0] row;
    begin
        case (y)
        5'd0: row = 40'hC48480C430;
        5'd1: row = 40'h07B84904C4;
        5'd2: row = 40'h908190C0BD;
        5'd3: row = 40'h2416632106;
        5'd4: row = 40'h4608809A65;
        5'd5: row = 40'h2090944122;
        5'd6: row = 40'h723CC41866;
        5'd7: row = 40'h0181423108;
        5'd8: row = 40'h8860D2AE80;
        5'd9: row = 40'h2D44F80E19;
        5'd10: row = 40'h4B3C404805;
        5'd11: row = 40'h7021051481;
        5'd12: row = 40'h07C1214520;
        5'd13: row = 40'hE3645C9411;
        5'd14: row = 40'h110E04104D;
        5'd15: row = 40'h48A1904190;
        5'd16: row = 40'h2212A11502;
        5'd17: row = 40'h013F60A2A3;
        default: row = 40'd0;
        endcase
        jungleFloorTile = (x < 20 && y < 18) ? ((row >> (x * 2)) & 40'h3) : 2'd0;
    end
endfunction
