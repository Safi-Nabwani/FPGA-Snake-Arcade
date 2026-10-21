// Only for simulation of observation-only instrumentation, never production.
module sld_virtual_jtag #(parameter sld_auto_instance_index="NO",sld_instance_index=0,sld_ir_width=1)(
    output wire tck,tdi,output wire [sld_ir_width-1:0] ir_in,input wire tdo,
    input wire [sld_ir_width-1:0] ir_out,output wire virtual_state_cdr,virtual_state_sdr);
    assign tck=0;assign tdi=0;assign ir_in=0;assign virtual_state_cdr=0;assign virtual_state_sdr=0;
endmodule
