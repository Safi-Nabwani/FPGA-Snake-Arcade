// Coordinate-only fixture. NOT a pixel/image/MIF model and NOT a synthesis source.
// The production RTL's uppercase LPM parameters are accepted by Quartus, but not
// by the installed ModelSim 10.5b lowercase-parameter lpm_rom model.
// Geometry tests inspect addresses, bounds and maps; no test asserts ROM colors.
module lpm_rom #(
    parameter LPM_WIDTH = 8,
    parameter LPM_WIDTHAD = 10,
    parameter LPM_NUMWORDS = 576,
    parameter LPM_FILE = "",
    parameter LPM_TYPE = "LPM_ROM",
    parameter LPM_ADDRESS_CONTROL = "REGISTERED",
    parameter LPM_OUTDATA = "UNREGISTERED",
    parameter AUTO_CARRY_CHAINS = "ON",
    parameter AUTO_CASCADE_BUFFERS = "ON",
    parameter INTENDED_DEVICE_FAMILY = "Cyclone V"
) (
    input wire [LPM_WIDTHAD-1:0] address,
    input wire inclock,
    output wire [LPM_WIDTH-1:0] q
);
    assign q = {LPM_WIDTH{1'b0}};
endmodule
