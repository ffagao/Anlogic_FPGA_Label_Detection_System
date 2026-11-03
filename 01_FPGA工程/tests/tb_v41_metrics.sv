`timescale 1ns/1ps
module tb_v41_metrics;
reg clk=0;always #5 clk=~clk;
reg rst=0;
rectangle_tracker dut(.I_clk(clk),.I_rst_n(rst),.I_enable(1'b0),.I_de(1'b0),.I_x(12'd0),.I_y(12'd0),.I_rgb(24'd0),.I_frame_id(24'd0),.I_require_rectangle(1'b1),.I_view_id(2'd0),.I_color_select(3'd0),.I_custom_mask(1'b0),.I_shape_select(2'd1));
rectangle_tracker_v40_reference ref40(.I_clk(clk),.I_rst_n(rst),.I_enable(1'b0),.I_de(1'b0),.I_x(12'd0),.I_y(12'd0),.I_rgb(24'd0),.I_frame_id(24'd0),.I_require_rectangle(1'b1),.I_view_id(2'd0),.I_color_select(3'd0),.I_custom_mask(1'b0),.I_shape_select(2'd1));
reg [25:0] axis;
reg [27:0] diag,near_area,far_area;
reg [19:0] hits;
reg [12:0] width,height;
integer i,j;reg [31:0] seed=32'h41123456;
function automatic [31:0] random_word;
begin seed=seed^(seed<<13);seed=seed^(seed>>17);seed=seed^(seed<<5);random_word=seed;end
endfunction
task compare;
begin
 repeat(3)begin @(posedge clk);#1;end
 if(dut.area_axis_q!==ref40.area_axis_q || dut.area_diag_q!==ref40.area_diag_q ||
    dut.area_near_q!==ref40.area_near_q || dut.area_far_q!==ref40.area_far_q ||
    dut.min_area_q!==ref40.min_area_q || dut.max_area_q!==ref40.max_area_q ||
    dut.pixels_metric_q!==ref40.pixels_metric_q || dut.comp_shape!==ref40.comp_shape ||
    dut.comp_triangle_profile!==ref40.comp_triangle_profile ||
    dut.comp_circle_profile!==ref40.comp_circle_profile || dut.comp_rect_profile!==ref40.comp_rect_profile)
  $fatal(1,"v40 numerical mismatch at sample%0d",i);
 @(negedge clk);
end
endtask
initial begin
 force dut.proj_axis_q=axis;force ref40.proj_axis_q=axis;
 force dut.proj_diag_q=diag;force ref40.proj_diag_q=diag;
 force dut.proj_near_q=near_area;force ref40.proj_near_q=near_area;
 force dut.proj_far_q=far_area;force ref40.proj_far_q=far_area;
 force dut.proj_pixels_q=hits;force ref40.proj_pixels_q=hits;
 force dut.comp_width=width;force ref40.comp_width=width;
 force dut.comp_height=height;force ref40.comp_height=height;
 axis=0;diag=0;near_area=0;far_area=0;hits=0;width=1;height=1;
 repeat(3)@(negedge clk);rst=1;
 for(i=0;i<50000;i=i+1)begin
  axis=random_word()%921601;diag=random_word()%4000001;
  near_area=random_word()%48294401;far_area=random_word()%48294401;
  hits=random_word()&20'hfffff;width=1+random_word()%1280;height=1+random_word()%720;
  compare();
 end
 axis=921600;diag=4000000;near_area=48294400;far_area=48294400;hits=20'hfffff;width=1280;height=720;compare();
 // Threshold-adjacent fill counts with equal normalized enclosure scales.
 for(j=0;j<1000;j=j+1)begin
  axis=1000+j;diag=axis*2;near_area=axis*29;far_area=axis*29;
  for(i=0;i<20;i=i+1)begin hits=(axis*(40+i*5))/100;compare();end
 end
 $display("PASS tb_v41_metrics: 70001 v40-reference pipeline/shape comparisons, full-image area bounds, full20bit hit-counter range and threshold-adjacent fills");$finish;
end
endmodule
