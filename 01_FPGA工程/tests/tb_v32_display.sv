`timescale 1ns/1ps
module tb_v32_display;
reg clk=0;always #5 clk=~clk;
reg rst=0;
reg [3:0] value=0;
wire [7:0] segments,digits;
switch_state_display dut(.I_clk(clk),.I_rst_n(rst),.I_state(value),.I_result(2'd0),.O_segment_n(segments),.O_digit_n(digits));
integer n,k,index,seen;
reg expected;
initial begin
 repeat(5) @(negedge clk);rst=1;
 for(n=0;n<16;n=n+1) begin
  value=n;
  wait(dut.scan==17'h1ffff);@(negedge clk);
  seen=0;
  repeat(131072) begin
   @(negedge clk);
   if(digits!=8'hff) begin
    case(digits)
     8'hfe:index=0;8'hfd:index=1;8'hfb:index=2;8'hf7:index=3;
     default:$fatal(1,"invalid/multiple digit enable %h",digits);
    endcase
    expected=value[3-index];
    if(segments!==(expected ? 8'hf9 : 8'hc0)) $fatal(1,"binary glyph/order mismatch value=%b digit=%0d segments=%h",value,index,segments);
    seen=seen|(1<<index);
   end
  end
  if(seen!=15) $fatal(1,"missing digits %b",seen);
 end
 // A value changing mid-scan cannot splice two mode values across four digits.
 value=0;wait(dut.scan==17'h1ffff);@(negedge clk);
 wait(dut.scan==17'h4003);@(negedge clk);value=15;
 while(dut.scan<17'h1fffe) begin
  @(negedge clk);
  if(digits!=8'hff && segments!=8'hc0) $fatal(1,"mixed display snapshot");
 end
 $display("PASS 4 binary digits: all 16 modes MSB-to-LSB, left SEL0..3 only, active-low polarity, DP off, blanking and coherent scan snapshot");
 $display("PASS tb_v32_display");$finish;
end
initial begin #60000000;$fatal(1,"display timeout");end
endmodule
