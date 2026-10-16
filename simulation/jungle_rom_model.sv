// Test-only legacy uppercase LPM adapter. Loads real MIFs, registered address.
// Supplied floors use UNS addresses; previous assets use HEX (wood uses DEC).
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
    integer fileHandle, status, location, lastLocation, value, count, i;
    string addressRadix;
    bit decimalAddress;
    initial begin
        decimalAddress=(LPM_FILE=="RTL/mifs/wood_tile_32.mif");
        for (i=0; i<LPM_NUMWORDS; i=i+1) begin data[i]=0; seen[i]=0; end
        fileHandle=$fopen(LPM_FILE,"r");
        if (!fileHandle) $fatal(1,"Cannot open %s",LPM_FILE);
        count=0;
        while (!$feof(fileHandle)) begin
            status=$fgets(line,fileHandle);
            // Read the supplied header instead of rewriting its address records.
            status=$sscanf(line,"ADDRESS_RADIX=%s",addressRadix);
            if (status==1)
                decimalAddress=(addressRadix=="UNS;" || addressRadix=="DEC;");
            // Existing WIN/LOST MIFs use legal compressed address ranges.
            if (decimalAddress)
                status=$sscanf(line," [%d..%d] : %h;",location,lastLocation,value);
            else
                status=$sscanf(line," [%h..%h] : %h;",location,lastLocation,value);
            if(status!=3) begin
                if(decimalAddress) status=$sscanf(line,"%d : %h;",location,value);
                else status=$sscanf(line,"%h : %h;",location,value);
                if(status==2)begin lastLocation=location;status=3;end
            end
            if (status==3) begin
                if (location<0 || lastLocation<location || lastLocation>=LPM_NUMWORDS || value<0 || value>=(1<<LPM_WIDTH))
                    $fatal(1,"Invalid ROM record: %s",LPM_FILE);
                for(i=location;i<=lastLocation;i=i+1)begin
                    if (seen[i]) $fatal(1,"Duplicate ROM record: %s",LPM_FILE);
                    data[i]=value;seen[i]=1;count=count+1;
                end
            end
        end
        $fclose(fileHandle);
        if (count!=LPM_NUMWORDS) $fatal(1,"Incomplete ROM %s: %0d/%0d",LPM_FILE,count,LPM_NUMWORDS);
    end
    always @(posedge inclock) addressD <= address;
    assign q = data[addressD];
endmodule
