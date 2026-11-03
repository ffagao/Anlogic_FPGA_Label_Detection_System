`timescale 1ns/1ps
module tb_v23_awb_green_bias;
reg [47:0] gain_q16=0;
wire [19:0] gain_biased;
awb_gain_bias dut(.I_gain_q16(gain_q16),.O_gain_q16(gain_biased));
task check_gain(input [47:0] value,input [19:0] expected);
begin
 gain_q16=value;#1;
 if(gain_biased!==expected) $fatal(1,"WB gain %h -> %h expected %h",value,gain_biased,expected);
end endtask
initial begin
 check_gain(48'h0000010000,20'h10400); // unity + 1/64
 check_gain(48'h0000008000,20'h08200); // half-scale + 1/64
 check_gain(48'h00000fffff,20'hfffff); // saturate 20-bit overflow
 check_gain(48'h0000100000,20'hfffff); // saturate oversized divider result
 $display("PASS AWB red/blue 1/64 tint correction and gain saturation");
 $display("PASS tb_v23_awb_green_bias");$finish;
end
endmodule
