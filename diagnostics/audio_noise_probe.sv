// Diagnostic-only coherent snapshot reader. Never listed in production QSF.
// IR bit changes request a snapshot; DR reads {header,ack,192-bit snapshot}.
module audio_noise_probe #(parameter integer INDEX=80, parameter bit TEST=0)(
    input logic clk,resetN,input logic [191:0] payload,
    input wire testTck,testIr,testCapture,testShift,testTdi,output wire testTdo
);
    wire tck,tdi,ir,capture,shift;
    logic requestMeta,requestSync,seen;
    logic ackMeta,ackSync;
    logic [191:0] snapshot;
    logic [255:0] shiftReg;
    assign testTdo=shiftReg[0];
    generate if(TEST)begin
        assign tck=testTck;assign tdi=testTdi;assign ir=testIr;
        assign capture=testCapture;assign shift=testShift;
    end else begin
        sld_virtual_jtag #(.sld_auto_instance_index("NO"),.sld_instance_index(INDEX),
            .sld_ir_width(1)) tap(.tck(tck),.tdi(tdi),.ir_in(ir),
            .tdo(shiftReg[0]),.ir_out(1'b0),.virtual_state_cdr(capture),
            .virtual_state_sdr(shift));
    end endgenerate
    // Payload stays fixed until the NEXT request. No multi-bit bitwise CDC.
    always_ff @(posedge clk or negedge resetN)begin
        if(!resetN)begin requestMeta<=0;requestSync<=0;seen<=0;snapshot<=0;end
        else begin
            requestMeta<=ir;requestSync<=requestMeta;
            if(requestSync!=seen)begin snapshot<=payload;seen<=requestSync;end
        end
    end
    // Host waits for ack and repeats a read before accepting its payload.
    always_ff @(posedge tck or negedge resetN)begin
        if(!resetN)begin ackMeta<=0;ackSync<=0;shiftReg<=0;end
        else begin
            ackMeta<=seen;ackSync<=ackMeta;
            if(capture)shiftReg<={32'h44500000+INDEX,{31'd0,ackSync},snapshot};
            else if(shift)shiftReg<={tdi,shiftReg[255:1]};
        end
    end
endmodule
