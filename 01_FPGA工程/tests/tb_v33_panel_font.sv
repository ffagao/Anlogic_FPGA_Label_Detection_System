`timescale 1ns/1ps
module tb_v33_panel_font;
reg clk=0;always #5 clk=~clk;
reg rst=0,enable=1,custom=1,teach=1,preparing=0,target_valid=1,model_valid=1;
reg [3:0] status=3;reg [23:0] rgb=24'hd08020;
reg [11:0] x=0,y=0,cx=960,cy=240;
wire on;wire [23:0] pixel;
target_teach_overlay dut(clk,rst,enable,custom,teach,preparing,target_valid,model_valid,status,rgb,x,y,cx,cy,16'h0960,16'h0240,on,pixel);
reg [7:0] reference_char=0;reg [3:0] reference_row=0;wire [15:0] reference_bits;
osd_char_lib font(reference_char,reference_row,reference_bits);
task text_check(input integer y0,input string text,input [23:0] colour);
 integer row,pos,col;reg [23:0] expected;
 begin
  for(row=0;row<16;row=row+1)for(pos=0;pos<text.len();pos=pos+1)for(col=0;col<8;col=col+1)begin
   @(negedge clk);x=1100+pos*8+col;y=y0+row;
   reference_char=text.getc(pos);reference_row=(row+1)%16;
   #1;expected=24'h101820;
   if(y0==508 && (x==1180 || y==517)) expected=24'h405060;
   if(col<5 && reference_bits[13-col*2]) expected=colour;
   @(posedge clk);#1;if(!on || pixel!==expected) $fatal(1,"font [%s] row%0d pos%0d col%0d got%h want%h",text,row,pos,col,pixel,expected);
  end
 end
endtask
integer s,xx,yy,fd;string label;
initial begin
 repeat(5)@(negedge clk);rst=1;
 text_check(448,"TARGET POSITION",24'hd0f0ff);
 text_check(580,"X:0960 Y:0240",24'hd0f0ff);
 for(s=0;s<8;s=s+1)begin
  status=s;
  case(s)
   0:label="LEARN: EMPTY";1:label="LEARN: READY";2:label="LEARN: SAMPLING";3:label="LEARN: OK";
   4:label="FAIL: DARK";5:label="FAIL: BRIGHT";6:label="FAIL: MIXED";7:label="FAIL: UNSTABLE";
  endcase
  text_check(612,label,s>=4?24'hff7050:24'hd0f0ff);
 end
 status=3;text_check(644,"K1 READY K2 LEARN",24'hd0f0ff);
 teach=0;text_check(644,"K3 PAUSE K4 START",24'hd0f0ff);
 custom=0;teach=1;text_check(644,"K1 COLOR K2 SHAPE",24'hd0f0ff);
 target_valid=0;text_check(580,"X:---- Y:----",24'hd0f0ff);
 text_check(508,"    NO TARGET",24'hd0f0ff);
 // Export an actual HDL-rendered panel for visual inspection.
 custom=1;target_valid=1;status=3;
 fd=$fopen("v33_panel_preview.ppm","w");$fdisplay(fd,"P3\n184 232\n255");
 for(yy=440;yy<672;yy=yy+1)for(xx=1088;xx<1272;xx=xx+1)begin
  @(negedge clk);x=xx;y=yy;@(posedge clk);#1;
  $fdisplay(fd,"%0d %0d %0d",pixel[23:16],pixel[15:8],pixel[7:0]);
 end
 $fclose(fd);
 $display("PASS tb_v33_panel_font: independent original-font comparison for all status text, decimal coordinates, both mode key hints and NO TARGET; actual HDL panel preview exported");$finish;
end
initial begin #3000000;$fatal(1,"panel font timeout");end
endmodule
