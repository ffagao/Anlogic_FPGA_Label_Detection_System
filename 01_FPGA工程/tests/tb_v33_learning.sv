`timescale 1ns/1ps
module tb_v33_learning;
reg clk=0;always #5 clk=~clk;
reg rst=0,selected=1,enable=1,prepare=0,start=0,de=0;
reg [11:0] x=0,y=0;
reg [23:0] rgb=0,frame=0;
wire valid,generation,mask,preparing;
wire [3:0] status;wire [23:0] learned;
target_color_learning dut(clk,rst,selected,enable,prepare,start,de,x,y,rgb,frame,valid,status,learned,generation,mask,preparing);
task tick;begin @(negedge clk);end endtask
task begin_learn;
 begin start=1;tick();start=0;tick();if(status!=2 || !preparing) $fatal(1,"start teach");end
endtask
task camera_frame(input integer id,input [23:0] colour,input integer pattern);
 integer xx,yy;
 begin
  frame=id;x=0;y=0;de=1;tick();de=0;tick();
  for(yy=328;yy<392;yy=yy+4) for(xx=608;xx<672;xx=xx+4) begin
   x=xx;y=yy;rgb=colour;
   if(pattern==1 && xx>=640) rgb=24'h20c020;
   de=1;tick();
  end
  de=0;repeat(3) tick();
 end
endtask
task finish_frame(input integer id);
 begin frame=id;x=0;y=0;de=1;tick();de=0;repeat(3)tick();end
endtask
integer i;reg saved_gen;
initial begin
 repeat(4)tick();rst=1;tick();
 if(valid || status!=0) $fatal(1,"reset model");
 prepare=1;tick();prepare=0;tick();if(status!=1 || !preparing) $fatal(1,"prepare");
 begin_learn();
 for(i=1;i<=7;i=i+1) camera_frame(i,24'hd08020,0);
 if(valid) $fatal(1,"committed before 8 unique frames");
 camera_frame(7,24'hd08020,0);camera_frame(7,24'hd08020,0);
 if(valid) $fatal(1,"duplicate camera frame counted");
 camera_frame(8,24'hd08020,0);finish_frame(9);
 if(!valid || status!=3 || learned!==24'hd08020 || !generation) $fatal(1,"learn result %h %d",learned,status);
 rgb=24'hd08020;#1;if(!mask) $fatal(1,"learned orange missing");
 rgb=24'h20c020;#1;if(mask) $fatal(1,"green matches orange");
 rgb=24'hd88828;#1;if(!mask) $fatal(1,"common brightness offset rejected");
 saved_gen=generation;
 begin_learn();camera_frame(20,24'h080808,0);finish_frame(21);
 if(status!=4 || !valid || generation!=saved_gen || learned!==24'hd08020) $fatal(1,"dark failure overwrote model");
 begin_learn();camera_frame(30,24'hffffff,0);finish_frame(31);if(status!=5) $fatal(1,"bright failure");
 begin_learn();camera_frame(40,24'hd08020,1);finish_frame(41);if(status!=6) $fatal(1,"mixed ROI failure %d",status);
 begin_learn();camera_frame(50,24'hd08020,0);camera_frame(51,24'hc03020,0);finish_frame(52);
 if(status!=7) $fatal(1,"unstable frame colour accepted");
 begin_learn();camera_frame(60,24'hd08020,0);enable=0;tick();
 if(status!=3 || preparing || !valid) $fatal(1,"mode exit must cancel and retain previous model");
 enable=1;begin_learn();
 for(i=70;i<78;i=i+1) camera_frame(i,24'hff0000,0);finish_frame(78);
 if(!valid || status!=3 || learned!==24'hff0000 || generation==saved_gen) $fatal(1,"relearn saturated red");
 rgb=24'hff0000;#1;if(!mask || dut.cr_high!=511) $fatal(1,"upper bound clamp");
 rst=0;tick();if(valid) $fatal(1,"reset retained model");
 $display("PASS tb_v33_learning: exact 8 unique frames, ROI/raw RGB, prepare, colour mask, duplicate frames, quality rejection, old-model retention, cancel/reset, bound saturation");$finish;
end
initial begin #2000000;$fatal(1,"learning timeout");end
endmodule
