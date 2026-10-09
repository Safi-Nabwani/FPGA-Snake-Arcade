// Simulation adapter for the legacy uppercase LPM interface, NOT a Quartus source.
// The numeric HUD font is loaded from the REAL, unchanged HEX-address/BIN-data MIF.
// Non-font ROMs are zero-filled: arena tests inspect geometry, not their colors.
module lpm_rom #(
    parameter LPM_WIDTH = 8, LPM_WIDTHAD = 10, LPM_NUMWORDS = 576,
    parameter LPM_FILE = "", LPM_TYPE = "LPM_ROM",
    parameter LPM_ADDRESS_CONTROL = "REGISTERED", LPM_OUTDATA = "UNREGISTERED",
    parameter AUTO_CARRY_CHAINS = "ON", AUTO_CASCADE_BUFFERS = "ON",
    parameter INTENDED_DEVICE_FAMILY = "Cyclone V"
) (
    input wire [LPM_WIDTHAD-1:0] address,
    input wire inclock,
    output wire [LPM_WIDTH-1:0] q
);
    reg [LPM_WIDTH-1:0] mem_data [0:LPM_NUMWORDS-1];
    reg [LPM_WIDTHAD-1:0] addressD;
    reg [4095:0] line;
    integer descriptor, result, location, value, loaded, i;
    initial begin
        for (i = 0; i < LPM_NUMWORDS; i = i + 1) mem_data[i] = 0;
        if (LPM_WIDTH == 1 && LPM_FILE == "RTL/mifs/numbers_new_font.mif") begin
            descriptor = $fopen(LPM_FILE, "r");
            if (!descriptor) $fatal(1, "Cannot open real font MIF");
            loaded = 0;
            while (!$feof(descriptor)) begin
                result = $fgets(line, descriptor);
                result = $sscanf(line, "%h : %b;", location, value);
                if (result == 2) begin
                    if (location < 0 || location >= LPM_NUMWORDS || value < 0 || value > 1)
                        $fatal(1, "Invalid font MIF record");
                    mem_data[location] = value;
                    loaded = loaded + 1;
                end
            end
            $fclose(descriptor);
            if (loaded != 8192) $fatal(1, "Font MIF coverage is %0d, expected 8192", loaded);
            $display("Loaded real HUD font: %0d bits", loaded);
        end
    end
    always @(posedge inclock) addressD <= address;
    assign q = mem_data[addressD];
endmodule
