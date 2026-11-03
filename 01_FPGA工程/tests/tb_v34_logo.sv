`timescale 1ns/1ps
module tb_v34_logo;
reg clk=0;always #5 clk=~clk;
reg [11:0] x=0,y=0;reg label_mode=0;reg [14:0] address=0;
wire [24:0] original,actual;reg [24:0] expect1=0,expect2=0;
anlogic_logo_rom golden(address,original);
v34_logo_rom dut(clk,x,y,label_mode,actual);
integer i,j,layout,count=0;
always @(posedge clk)begin expect1<=original;expect2<=expect1;end
initial begin
 repeat(4)@(negedge clk);
 for(layout=0;layout<2;layout=layout+1)begin
  label_mode=layout;
  for(j=0;j<(layout?80:160);j=j+1)for(i=0;i<(layout?80:160);i=i+1)begin
   x=(layout?1184:16)+i;y=(layout?32:16)+j;
   address=layout ? j*2*160+i*2 : j*160+i;
   @(posedge clk);#1;
   if(count>2 && actual!==expect2)$fatal(1,"lossless logo mismatch layout%d x%d y%d got%h expected%h",layout,x,y,actual,expect2);
   count=count+1;@(negedge clk);
  end
 end
 x=1279;y=719;repeat(4)@(negedge clk);if(actual!==0)$fatal(1,"transparent outside logo");
 $display("PASS tb_v34_logo: all 160x160 original pixels and 80x80 label samples match exactly, including alpha");$finish;
end
endmodule
