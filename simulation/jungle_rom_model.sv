// Test-only legacy uppercase LPM adapter. Loads real MIFs, registered address.
// Eight new assets use HEX addresses; unchanged wood ROM uses decimal addresses.
// Not listed in QSF. Missing, duplicate or incomplete ROM data is a fatal error.
module lpm_rom #(
    parameter LPM_WIDTH=8, LPM_WIDTHAD=10, LPM_NUMWORDS=576,
    parameter LPM_FILE="", LPM_TYPE="LPM_ROM",
    parameter LPM_ADDRESS_CONTROL="REGISTERED", LPM_OUTDATA="UNREGISTERED",
    parameter AUTO_CARRY_CHAINS="ON", AUTO_CASCADE_BUFFERS="ON",
    parameter INTENDED_DEVICE_FAMILY="Cyclone V"
) (
    input wire [LPM_WIDTHAD-1:0] address,
    input wire inclock,
    output wire [LPM_WIDTH-1:0] q
);
    reg [LPM_WIDTH-1:0] data [0:LPM_NUMWORDS-1];
    reg seen [0:LPM_NUMWORDS-1];
    reg [LPM_WIDTHAD-1:0] addressD;
    reg [4095:0] line;
    integer fileHandle, status, location, value, count, i;
    initial begin
        for (i=0; i<LPM_NUMWORDS; i=i+1) begin data[i]=0; seen[i]=0; end
        fileHandle=$fopen(LPM_FILE,"r");
        if (!fileHandle) $fatal(1,"Cannot open %s",LPM_FILE);
        count=0;
        while (!$feof(fileHandle)) begin
            status=$fgets(line,fileHandle);
            if (LPM_FILE=="RTL/mifs/wood_tile_32.mif")
                status=$sscanf(line,"%d : %h;",location,value);
            else
                status=$sscanf(line,"%h : %h;",location,value);
            if (status==2) begin
                if (location<0 || location>=LPM_NUMWORDS || value<0 || value>=(1<<LPM_WIDTH))
                    $fatal(1,"Invalid ROM record: %s",LPM_FILE);
                if (seen[location]) $fatal(1,"Duplicate ROM record: %s",LPM_FILE);
                data[location]=value; seen[location]=1; count=count+1;
            end
        end
        $fclose(fileHandle);
        if (count!=LPM_NUMWORDS) $fatal(1,"Incomplete ROM %s: %0d/%0d",LPM_FILE,count,LPM_NUMWORDS);
    end
    always @(posedge inclock) addressD <= address;
    assign q = data[addressD];
endmodule
