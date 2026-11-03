`timescale 1ns/1ps
module tb_v25_target_selection;
reg clk=0;always #5 clk=~clk;
reg rst=0,de=0;reg [11:0] x=0,y=0;reg [23:0] rgb=0,fid=0;
reg [2:0] colour=0;reg [1:0] shape=1;
wire mask,valid,det;wire [1:0] detected;
rectangle_tracker #(.IMG_WIDTH(240),.IMG_HEIGHT(200)) dut(
 .I_clk(clk),.I_rst_n(rst),.I_enable(1'b1),.I_de(de),.I_x(x),.I_y(y),
 .I_rgb(rgb),.I_frame_id(fid),.I_require_rectangle(1'b1),.I_view_id(2'd0),
 .I_color_select(colour),.I_custom_mask(1'b0),.I_shape_select(shape),.O_mask_pixel(mask),.O_mask_seen(),
 .O_result_update(),.O_detect_valid(det),.O_detect_shape(detected),
 .O_candidate_valid(),.O_candidate_ok(),.O_raw_left(),.O_raw_right(),.O_raw_top(),.O_raw_bottom(),
 .O_track_valid(valid),.O_left(),.O_right(),.O_top(),.O_bottom());
function [23:0] colour_rgb(input integer c);
 begin case(c)
 0:colour_rgb=24'h0000ff;1:colour_rgb=24'hff0000;2:colour_rgb=24'h00ff00;
 3:colour_rgb=24'h7030a0;default:colour_rgb=24'hffff00;
 endcase end
endfunction
function inside_shape(input integer s,input integer xx,input integer yy);
 integer dx,dy,halfspan;
 begin
 dx=xx-110;dy=yy-95;halfspan=(yy-35)*60/100;
 case(s)
 1:inside_shape=(xx>=50 && xx<170 && yy>=40 && yy<110);
 2:inside_shape=dx*dx+dy*dy<=2500;
 4:inside_shape=(xx>=40 && xx<190 && yy>=10 && yy<65) ||
                ((xx-110)*(xx-110)+(yy-140)*(yy-140)<=1600);
 default:inside_shape=yy>=35 && yy<135 && xx>=110-halfspan && xx<=110+halfspan;
 endcase
 end
endfunction
task frame(input integer drawn_shape,input integer drawn_colour);
 integer xx,yy;
 begin
 fid=fid+1;
 for(yy=0;yy<200;yy=yy+1) begin
  for(xx=0;xx<240;xx=xx+1) begin
   @(negedge clk);de=1;x=xx;y=yy;
   rgb=inside_shape(drawn_shape,xx,yy) ? colour_rgb(drawn_colour) : 24'h181818;
  end
  @(negedge clk);de=0;repeat(8) @(negedge clk);
 end
 repeat(16) @(negedge clk);
 end
endtask
integer c,s,i,j;
initial begin
 repeat(5) @(negedge clk);rst=1;
 for(i=0;i<5;i=i+1) for(j=0;j<5;j=j+1) begin
  colour=i;rgb=colour_rgb(j);#1;
  if(mask!==((i==j) && i<3)) $fatal(1,"colour classes overlap/miss: select=%0d sample=%0d",i,j);
 end
 rgb=24'hffffff;#1;if(mask) $fatal(1,"white accepted as yellow");
 rgb=24'h383050;colour=3;#1;if(mask) $fatal(1,"low saturation accepted as purple");
 rgb=24'h381850;#1;if(mask) $fatal(1,"removed purple choice still active");
 colour=0;#1;if(mask) $fatal(1,"dim purple accepted as blue");
 rgb=24'h808000;colour=4;#1;if(mask) $fatal(1,"removed yellow choice still active");
 for(c=0;c<3;c=c+1) for(s=1;s<=3;s=s+1) begin
  @(negedge clk);colour=c;shape=s;
  repeat(4) frame(s,c);
  if(!valid || !det || detected!=s) $fatal(1,"positive colour=%0d shape=%0d valid=%b det=%b detected=%0d metric=%0d/%0d/%0d",c,s,valid,det,detected,dut.pixels_metric_q,dut.min_area_q,dut.max_area_q);
  shape=s==3 ? 1 : s+1;
  repeat(2) frame(s,c);
  if(valid || det) $fatal(1,"wrong shape accepted colour=%0d drawn=%0d selected=%0d",c,s,shape);
  $display("PASS colour=%0d shape=%0d positive and mismatching shape rejection",c,s);
 end
 colour=4;shape=1;repeat(2) frame(1,3);
 if(valid || det) $fatal(1,"wrong colour accepted");
 colour=0;shape=2;repeat(4) frame(4,0);
 if(!valid || !det || detected!=2 || dut.O_top<80) $fatal(1,"larger wrong-shape distractor suppressed matching circle");
 $display("PASS all 9 RGB colour/shape combinations, class separation, wrong-shape/colour rejection and selection reset");
 $display("PASS tb_v25_target_selection");$finish;
end
initial begin #60000000;$fatal(1,"target selection timeout");end
endmodule
