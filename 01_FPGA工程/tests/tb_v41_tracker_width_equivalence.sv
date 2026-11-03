`timescale 1ns/1ps
module tb_v41_tracker_width_equivalence;
reg clk=0; always #5 clk=~clk;
reg rst=0, de=0;
reg [11:0] x=0,y=0;
reg [23:0] rgb=24'h181818, fid=0;
reg [1:0] view_id=0;
wire mask,valid,detect_valid,seen,update;
wire [1:0] shape;
wire cand_valid,cand_ok;
wire [11:0] raw_left,raw_right,raw_top,raw_bottom;
wire [11:0] left,right,top,bottom;

rectangle_tracker dut(
    .I_clk(clk),.I_rst_n(rst),.I_enable(1'b1),.I_de(de),.I_x(x),.I_y(y),
    .I_rgb(rgb),.I_frame_id(fid),.I_require_rectangle(1'b1),.I_view_id(view_id),
    .I_color_select(3'd0),.I_custom_mask(1'b0),.I_shape_select(2'd1),
    .O_mask_pixel(mask),.O_mask_seen(seen),.O_result_update(update),
    .O_detect_valid(detect_valid),.O_detect_shape(shape),
    .O_candidate_valid(cand_valid),.O_candidate_ok(cand_ok),
    .O_raw_left(raw_left),.O_raw_right(raw_right),.O_raw_top(raw_top),.O_raw_bottom(raw_bottom),
    .O_track_valid(valid),.O_left(left),.O_right(right),.O_top(top),.O_bottom(bottom));

rectangle_tracker_v40_reference reference40(
    .I_clk(clk),.I_rst_n(rst),.I_enable(1'b1),.I_de(de),.I_x(x),.I_y(y),
    .I_rgb(rgb),.I_frame_id(fid),.I_require_rectangle(1'b1),.I_view_id(view_id),
    .I_color_select(3'd0),.I_custom_mask(1'b0),.I_shape_select(2'd1),
    .O_mask_pixel(),.O_mask_seen(),.O_result_update(),
    .O_detect_valid(),.O_detect_shape(),.O_candidate_valid(),.O_candidate_ok(),
    .O_raw_left(),.O_raw_right(),.O_raw_top(),.O_raw_bottom(),
    .O_track_valid(),.O_left(),.O_right(),.O_top(),.O_bottom());

always @(posedge clk) begin
    #1;
    if(rst && {mask,seen,update,detect_valid,shape,cand_valid,cand_ok,
               raw_left,raw_right,raw_top,raw_bottom,valid,left,right,top,bottom} !==
              {reference40.O_mask_pixel,reference40.O_mask_seen,reference40.O_result_update,
               reference40.O_detect_valid,reference40.O_detect_shape,
               reference40.O_candidate_valid,reference40.O_candidate_ok,
               reference40.O_raw_left,reference40.O_raw_right,
               reference40.O_raw_top,reference40.O_raw_bottom,
               reference40.O_track_valid,reference40.O_left,reference40.O_right,
               reference40.O_top,reference40.O_bottom})
        $fatal(1,"default-size tracker mismatch at x=%0d y=%0d fid=%0d",x,y,fid);
end

task send_pixel(input [11:0] px,input [11:0] py,input [23:0] colour);
begin
    @(negedge clk); de=1; x=px; y=py; rgb=colour;
end
endtask

task start_frame(input [1:0] view);
begin
    @(negedge clk); fid=fid+1; view_id=view; de=1; x=0; y=0; rgb=24'h181818;
end
endtask

task reset_tracker;
begin
    @(negedge clk); rst=0; de=0;
    repeat(4) @(negedge clk);
    rst=1;
end
endtask

task draw_rect(input integer x0,input integer x1,input integer y0,input integer y1);
    integer xx,yy;
begin
    for(yy=y0;yy<=y1;yy=yy+1) begin
        for(xx=x0;xx<=x1;xx=xx+1) send_pixel(xx,yy,24'h0000ff);
        if(x1!=1279) send_pixel(12'd1279,yy,24'h181818);
    end
end
endtask

initial begin
    repeat(5) @(negedge clk); rst=1;

    // Exercise the maximum default raster coordinates and right/bottom clamp.
    start_frame(0);
    draw_rect(1190,1279,672,719);
    start_frame(0);
    repeat(3) @(posedge clk); #2;
    if(!valid || left!=1186 || right!=1279 || top!=668 || bottom!=719)
        $fatal(1,"right/bottom raster limit mismatch: %0d,%0d,%0d,%0d",left,right,top,bottom);

    // Reset and exercise the left clamp without making (0,0) the frame marker.
    reset_tracker();
    start_frame(0);
    draw_rect(0,79,100,147);
    start_frame(0);
    repeat(3) @(posedge clk); #2;
    if(!valid || left!=0 || right!=83 || top!=96 || bottom!=151)
        $fatal(1,"left raster limit mismatch: %0d,%0d,%0d,%0d",left,right,top,bottom);

    reset_tracker();
    start_frame(0);
    draw_rect(200,279,0,47);
    start_frame(0);
    repeat(3) @(posedge clk); #2;
    if(!valid || left!=196 || right!=283 || top!=0 || bottom!=51)
        $fatal(1,"top raster limit mismatch: %0d,%0d,%0d,%0d",left,right,top,bottom);

    $display("PASS default 1280x720 tracker equivalence at all four coordinate bounds");
    $display("PASS tb_v41_tracker_width_equivalence");
    $finish;
end
initial begin #50000000;$fatal(1,"default-width tracker timeout");end
endmodule
