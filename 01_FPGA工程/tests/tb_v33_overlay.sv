`timescale 1ns/1ps
module tb_v33_overlay;
reg clk=0;always #5 clk=~clk;
reg rst=0,enable=1,custom=0,teach=1,preparing=0,target_valid=1,model_valid=0;
reg [3:0] status=0;reg [23:0] rgb=24'hd08020;
reg [11:0] x=0,y=0,cx=640,cy=360;
reg [15:0] x_bcd=16'h0640,y_bcd=16'h0360;
wire on;wire [23:0] pixel;
target_teach_overlay dut(clk,rst,enable,custom,teach,preparing,target_valid,model_valid,status,rgb,x,y,cx,cy,x_bcd,y_bcd,on,pixel);
task check(input integer xx,input integer yy,input bit expected_on,input [23:0] expected);
 begin @(negedge clk);x=xx;y=yy;@(negedge clk);
 if(on!==expected_on || (on && pixel!==expected)) $fatal(1,"overlay %d,%d on=%b colour=%h expected=%h",xx,yy,on,pixel,expected);
 end
endtask
integer i,xx,yy;reg [23:0] expected;reg hit;
initial begin
 repeat(5)@(negedge clk);rst=1;
 check(1099,471,1,24'h70d8ff);check(1180,517,1,24'hfff200);
 check(1180,500,1,24'h405060);check(1104,480,1,24'h101820);
 cx=1279;cy=719;check(1259,561,1,24'hfff200);
 cx=0;cy=0;check(1100,472,1,24'hfff200);
 target_valid=0;check(1100,472,1,24'h101820);
 preparing=1;custom=1;status=1;check(607,327,1,24'hffffff);check(640,360,0,0);
 check(606,328,0,0);check(673,391,0,0);
 model_valid=1;check(1250,620,1,rgb);
 // One pixel each clock verifies the registered output, not only static points.
 target_valid=1;cx=640;cy=360;preparing=0;
 for(yy=470;yy<564;yy=yy+1) for(xx=1097;xx<1263;xx=xx+1) begin
  @(negedge clk);x=xx;y=yy;
  expected=24'h101820;
  if(xx>=1099 && xx<=1260 && yy>=471 && yy<=562) begin
   if(xx>=1178 && xx<=1182 && yy>=515 && yy<=519) expected=24'hfff200;
   else if(xx==1099 || xx==1260 || yy==471 || yy==562) expected=24'h70d8ff;
   else if(xx==1180 || yy==517) expected=24'h405060;
  end
  @(posedge clk);#1;if(!on || pixel!==expected) $fatal(1,"stream map %d,%d got %h want %h",xx,yy,pixel,expected);
 end
 enable=0;check(1180,517,0,0);
 $display("PASS tb_v33_overlay: exact 1/8 mapping, all corners, grid/dot, lost-target clearing, sample ROI, learned colour swatch, 15604 streaming graphic pixels, enable exit");$finish;
end
initial begin #1000000;$fatal(1,"overlay timeout");end
endmodule
