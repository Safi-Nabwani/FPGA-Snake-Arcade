// Temporary 5x7 text, doubled to 10x14 pixels with a two-pixel character gap.
// Numeric displays reuse the original font ROM; these few labels need no image ROM.
module hud_labels (
    input logic [10:0] pixelX, pixelY,
    output logic labelBit,
    output logic [7:0] labelRGB
);
    function automatic logic [34:0] glyph(input logic [7:0] letter);
        case (letter)
            "A": glyph = 35'b01110_10001_10001_11111_10001_10001_10001;
            "B": glyph = 35'b11110_10001_10001_11110_10001_10001_11110;
            "C": glyph = 35'b01111_10000_10000_10000_10000_10000_01111;
            "D": glyph = 35'b11110_10001_10001_10001_10001_10001_11110;
            "E": glyph = 35'b11111_10000_10000_11110_10000_10000_11111;
            "G": glyph = 35'b01111_10000_10000_10111_10001_10001_01111;
            "H": glyph = 35'b10001_10001_10001_11111_10001_10001_10001;
            "I": glyph = 35'b11111_00100_00100_00100_00100_00100_11111;
            "L": glyph = 35'b10000_10000_10000_10000_10000_10000_11111;
            "O": glyph = 35'b01110_10001_10001_10001_10001_10001_01110;
            "P": glyph = 35'b11110_10001_10001_11110_10000_10000_10000;
            "R": glyph = 35'b11110_10001_10001_11110_10100_10010_10001;
            "S": glyph = 35'b01111_10000_10000_01110_00001_00001_11110;
            "U": glyph = 35'b10001_10001_10001_10001_10001_10001_01110;
            "Y": glyph = 35'b10001_10001_01010_00100_00100_00100_00100;
            default: glyph = 35'd0;
        endcase
    endfunction

    function automatic logic textPixel(
        input logic [10:0] x, y,
        input integer originY, characters,
        input logic [95:0] text
    );
        integer characterIndex, column, row;
        logic [7:0] letter;
        logic [34:0] bits;
        begin
            textPixel = 1'b0;
            characterIndex = 0; column = 0; row = 0; letter = 0; bits = 0;
            if (x >= 11'd16 && x < 16 + characters*12 &&
                y >= originY && y < originY + 14) begin
                characterIndex = (x - 16) / 12;
                column = ((x - 16) % 12) / 2;
                row = (y - originY) / 2;
                letter = text[(characters-1-characterIndex)*8 +: 8];
                bits = glyph(letter);
                if (column < 5) textPixel = bits[34-row*5-column];
            end
        end
    endfunction

    always_comb begin
        labelRGB = 8'hF9;
        labelBit = textPixel(pixelX, pixelY, 40, 5, "SCORE") ||
                   textPixel(pixelX, pixelY, 112, 4, "HIGH") ||
                   textPixel(pixelX, pixelY, 128, 5, "SCORE") ||
                   textPixel(pixelX, pixelY, 208, 6, "RELICS");
        if (textPixel(pixelX, pixelY, 240, 4, "RUBY")) begin
            labelBit = 1'b1; labelRGB = 8'hED;
        end else if (textPixel(pixelX, pixelY, 308, 8, "SAPPHIRE")) begin
            labelBit = 1'b1; labelRGB = 8'h57;
        end else if (textPixel(pixelX, pixelY, 376, 6, "CURSED")) begin
            labelBit = 1'b1; labelRGB = 8'hB3;
        end
    end
endmodule
