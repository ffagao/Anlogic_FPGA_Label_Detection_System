`timescale 1ns/1ps
module tb_v29_mux;
reg clk=0;always #5 clk=~clk;
reg rst=0;reg [3:0] mode=0;reg [8:0] starts=0;
wire [127:0] data;wire valid,user,last;
v29_mux_fixture dut(clk,rst,mode,starts,data,valid,user,last);
integer a,b,old_start,new_start,checks=0;
initial begin
 for(a=0;a<9;a=a+1) for(b=0;b<9;b=b+1) if(a!=b) begin
  @(negedge clk);rst=0;starts=0;mode=0;repeat(2) @(negedge clk);rst=1;
  mode=a;starts=(a>=7) ? (9'b1<<7) : (9'b1<<a);#1;
  if(data!==a || !user) $fatal(1,"initial mode=%0d data=%0d",a,data);
  @(negedge clk);starts=0;
  mode=b;#1;if(data!==a) $fatal(1,"changed before frame start %0d -> %0d",a,b);
  old_start=(a>=7) ? 7 : a;new_start=(b>=7) ? 7 : b;
  if(!(a>=7 && b>=7)) begin
   starts=9'b1<<old_start;#1;
   if(data!==a) $fatal(1,"wrong source SOF %0d -> %0d data=%0d",a,b,data);
  end
  if(b>=7) begin
   starts=9'b1<<7;#1;
   if(data!==b || !user) $fatal(1,"shared spatial SOF %0d -> %0d data=%0d",a,b,data);
  end else begin
   starts=9'b1<<new_start;#1;
   if(data!==b || !user) $fatal(1,"target SOF %0d -> %0d data=%0d",a,b,data);
  end
  @(negedge clk);starts=0;#1;
  if(data!==b || !valid || !last) $fatal(1,"active mode=%0d -> %0d data=%0d",a,b,data);
  checks=checks+1;
 end
 $display("PASS actual ISP mux: all 81 transitions with shared spatial source and target-frame gating");
 $display("PASS tb_v29_mux");$finish;
end
initial begin #100000;$fatal(1,"mux timeout");end
endmodule
