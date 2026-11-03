`timescale 1ns/1ps
module tb_motion_regions_stream;
 reg clk=0,rst=0,en=0,fs=0,de=0;reg [23:0] frame_id=0,rgb=0;reg [11:0] x=0,y=0;
 wire mv,valid,overflow;wire [4:0] regions;wire [11:0] l,r,t,b;wire [15:0] blocks;
 integer px,py,f;
 always #5 clk=~clk;
 motion_detector #(.IMG_WIDTH(128),.IMG_HEIGHT(64),.MIN_BLOCKS(1),.MAX_BLOCKS(100)) dut(
 .I_clk(clk),.I_rst_n(rst),.I_enable(en),.I_frame_start(fs),.I_frame_id(frame_id),.I_de(de),.I_x(x),.I_y(y),.I_rgb(rgb),
 .O_motion_valid(mv),.O_left(l),.O_right(r),.O_top(t),.O_bottom(b),.O_count_bcd(blocks),
 .O_regions(regions),.O_regions_valid(valid),.O_regions_overflow(overflow));
 initial begin
  repeat(4)@(negedge clk);rst=1;en=1;
  for(f=0;f<3;f=f+1)begin
   @(negedge clk);fs=1;frame_id=f;de=0;
   @(negedge clk);fs=0;
   if(f==2)begin
    if(!valid || overflow || regions!=2)$fatal(1,"expected two changing regions valid=%b overflow=%b count=%0d blocks=%h",valid,overflow,regions,blocks);
    $display("PASS pixel-frame to region count, 2 regions");$finish;
   end
   for(py=0;py<64;py=py+1)for(px=0;px<128;px=px+1)begin
    @(negedge clk);de=1;x=px;y=py;
    rgb=(f==1 && py>=8 && py<24 && ((px>=8 && px<32)||(px>=72 && px<96)))?24'hffffff:0;
   end
   @(negedge clk);de=0;repeat(10)@(negedge clk);
  end
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
