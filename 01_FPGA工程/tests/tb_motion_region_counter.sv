`timescale 1ns/1ps
module tb_motion_region_counter;
 reg clk=0,rst=0,en=0,fs=0,pub=0,bv=0,on=0;reg [7:0] x=0;reg [6:0] y=0;
 wire [4:0] count;wire valid,overflow;
 always #5 clk=~clk;
 motion_region_counter #(.GRID_WIDTH(8),.MIN_BLOCKS(4)) dut(clk,rst,en,fs,pub,1'b1,bv,on,x,y,count,valid,overflow);
 task frame;input p;begin @(negedge clk);fs=1;pub=p;@(negedge clk);fs=0;pub=0;end endtask
 task pixel;input integer px,py;input bit c;begin @(negedge clk);x=px;y=py;on=c;bv=1;@(negedge clk);bv=0;end endtask
 integer a,b;
 initial begin
  repeat(3)@(negedge clk);rst=1;en=1;frame(0);
  for(b=0;b<4;b=b+1)for(a=0;a<8;a=a+1)pixel(a,b,(b<2 && (a<2 || (a>=5 && a<7))));
  frame(1);if(!valid || count!=2 || overflow)$fatal(1,"two regions: %d %b",count,valid);
  for(b=0;b<4;b=b+1)for(a=0;a<8;a=a+1)pixel(a,b,(b==0 && (a==1 || a==3)) || (b==1 && a>=1 && a<=3) || (b==2 && a==2));
  frame(1);if(!valid || count!=1 || overflow)$fatal(1,"merged region: %d",count);
  for(b=0;b<4;b=b+1)for(a=0;a<8;a=a+1)pixel(a,b,0);
  frame(1);if(!valid || count!=0)$fatal(1,"empty frame: %d",count);
  // Isolated one-block noise must not be counted as a region.
  for(b=0;b<4;b=b+1)for(a=0;a<8;a=a+1)pixel(a,b,((a%2)==0 && b==0));
  frame(1);if(overflow || !valid || count!=0)$fatal(1,"small noise should be filtered");
  for(b=0;b<8;b=b+1)for(a=0;a<8;a=a+1)pixel(a,b,((a%2)==0 && (b%2)==0));
  frame(1);if(!overflow || valid)$fatal(1,"label overflow must invalidate count");
  $display("PASS motion regions two, merging, empty, noise and overflow");$finish;
 end
 initial begin #100000;$fatal(1,"timeout");end
endmodule
