`timescale 1ns/1ps
module tb_v33_osd_stream;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,user=0;reg [3:0] mode=0;
reg [3:0] algorithm=0;
reg [71:0] debug_data={4'h5,12'h064,12'h096,16'h3000,12'h016,8'h01,8'h01};reg debug_toggle=0;
reg [9:0] diag_in_line=10'h140,diag_spatial_line=10'h140;
reg [8:0] diag_pack_line=9'h0f0,diag_fifo_level=9'h0a0,diag_burst_count=9'h0f0;
reg [17:0] diag_in_frame=18'h38400,diag_spatial_frame=18'h38400,diag_pack_frame=18'h2a300,diag_ddr_frame=18'h2a300;
reg de=1,track=0,vsync_in=0,hsync_in=0;wire [23:0] pixel,reference_pixel;wire vs,hs,out_de,ref_vs,ref_hs,ref_de;
hdmi_mixer dut(.I_label_remote_action(3'd0),.I_label_enable(1'b0),.I_label_keys_n(4'hf),.I_label_imaging_locked(1'b0),.O_label_imaging_lock(),.O_label_buzzer_n(),.I_clk(clk),.I_rst_n(rst_n),
 .I_video_vsync(vsync_in),.I_video_hsync(hsync_in),.I_video_de(de),
 .I_video_user(user),.I_video_last(1'b0),.I_debug_status(4'd0),
 .I_switch_state(mode),.I_algo_mode(algorithm),.I_track_enable(track),
 .I_track_color(3'd0),.I_track_shape(2'd1),.I_learn_prepare(1'b0),.I_learn_start(1'b0),.I_servo_state(4'd0),.I_pan_pulse_us(12'd1500),
 .I_tilt_pulse_us(12'd1300),.I_motion_enable(1'b0),.I_black_enable(1'b0),
 .I_black_valid(1'b0),.I_black_left(12'd0),.I_black_right(12'd0),
 .I_black_top(12'd0),.I_black_bottom(12'd0),.I_black_update_toggle(1'b0),
 .I_zoom_active(1'b0),.I_capture_frame_bcd(24'h123456),
 .I_display_frame_bcd(24'h123454),.I_camera_fps_bcd(8'h30),
 .I_delay_frames_bcd(8'h02),.I_ae_debug(debug_data),.I_ae_debug_toggle(debug_toggle),
 .I_diag_in_line(diag_in_line),.I_diag_spatial_line(diag_spatial_line),.I_diag_pack_line(diag_pack_line),
 .I_diag_in_frame(diag_in_frame),.I_diag_spatial_frame(diag_spatial_frame),.I_diag_pack_frame(diag_pack_frame),
 .I_diag_ddr_frame(diag_ddr_frame),.I_diag_fifo_level(diag_fifo_level),.I_diag_burst_count(diag_burst_count),
 .I_diag_burst_active(1'b1),.I_diag_line_error(3'b0),.I_diag_frame_error(3'b0),
 .I_video_rd_data(24'h181818),.O_measure_update(),.O_measure_valid(),.O_measure_dx(),.O_measure_dy(),.O_video_rd_en(),.O_zoom_request(),.O_hdmi_vsync(vs),.O_hdmi_hsync(hs),.O_hdmi_de(out_de),.O_hdmi_data(pixel));
v32ref_hdmi_mixer golden(.I_clk(clk),.I_rst_n(rst_n),
 .I_video_vsync(vsync_in),.I_video_hsync(hsync_in),.I_video_de(de),
 .I_video_user(user),.I_video_last(1'b0),.I_debug_status(4'd0),
 .I_switch_state(mode),.I_algo_mode(algorithm),.I_track_enable(track),
 .I_track_color(3'd0),.I_track_shape(2'd1),.I_servo_state(4'd0),.I_pan_pulse_us(12'd1500),
 .I_tilt_pulse_us(12'd1300),.I_motion_enable(1'b0),.I_black_enable(1'b0),
 .I_black_valid(1'b0),.I_black_left(12'd0),.I_black_right(12'd0),
 .I_black_top(12'd0),.I_black_bottom(12'd0),.I_black_update_toggle(1'b0),
 .I_zoom_active(1'b0),.I_capture_frame_bcd(24'h123456),
 .I_display_frame_bcd(24'h123454),.I_camera_fps_bcd(8'h30),
 .I_delay_frames_bcd(8'h02),.I_ae_debug(debug_data),.I_ae_debug_toggle(debug_toggle),
 .I_diag_in_line(diag_in_line),.I_diag_spatial_line(diag_spatial_line),.I_diag_pack_line(diag_pack_line),
 .I_diag_in_frame(diag_in_frame),.I_diag_spatial_frame(diag_spatial_frame),.I_diag_pack_frame(diag_pack_frame),
 .I_diag_ddr_frame(diag_ddr_frame),.I_diag_fifo_level(diag_fifo_level),.I_diag_burst_count(diag_burst_count),
 .I_diag_burst_active(1'b1),.I_diag_line_error(3'b0),.I_diag_frame_error(3'b0),
 .I_video_rd_data(24'h181818),.O_measure_update(),.O_measure_valid(),.O_measure_dx(),.O_measure_dy(),.O_video_rd_en(),.O_zoom_request(),.O_hdmi_vsync(ref_vs),.O_hdmi_hsync(ref_hs),.O_hdmi_de(ref_de),.O_hdmi_data(reference_pixel));

reg [26:0] golden1=0,golden2=0,golden3=0;
always @(posedge clk) begin
 golden1<={ref_vs,ref_hs,ref_de,reference_pixel};golden2<=golden1;golden3<=golden2;
end
integer x=0,y=0,xx,yy,pass,skip0=1,skip1=1,checked=0,cycles=0;
reg skip_now;reg [4:0] skip_pipe=31;
task tick;begin @(negedge clk);end endtask
initial begin
 repeat(6)tick();rst_n=1;debug_toggle=1;repeat(10)tick();
 // Adapt only the reference FPS input to the authorized new mapping.
 force golden.u_latency_ms.I_fps60=(mode==0);
 force dut.S_x=x;force dut.S_y=y;force golden.S_x=x;force golden.S_y=y;
 for(pass=0;pass<32;pass=pass+1) begin
  de=pass[1];vsync_in=pass[2];hsync_in=pass[0];
  @(posedge clk);#1;if({vs,hs,out_de}!==golden3[26:24]) $fatal(1,"sync pulse delay mismatch");tick();
 end
 de=1;vsync_in=0;hsync_in=0;repeat(10)tick();
 for(pass=0;pass<2;pass=pass+1) begin
  mode=pass==0?0:3;track=pass!=0;user=1;tick();user=0;repeat(80)tick();cycles=0;
  for(yy=0;yy<720;yy=yy+1)for(xx=0;xx<1280;xx=xx+1) begin
   x=xx;y=yy;
   skip_now=(pass!=0 && xx>=1088 && xx<1272 && yy>=440 && yy<672);
   @(posedge clk);#1;
   if(cycles>=8 && !skip_pipe[4]) begin
    if({vs,hs,out_de}!==golden3[26:24]) $fatal(1,"video sync latency changed");
    if(pixel!==golden3[23:0]) $fatal(1,"legacy OSD pixel alignment pass%0d near%d,%d got%h ref%h",pass,xx,yy,pixel,golden3[23:0]);
    checked=checked+1;
   end
   skip1=skip0;skip0=skip_now;skip_pipe={skip_pipe[3:0],skip_now};cycles=cycles+1;tick();
  end
 end
 $display("PASS tb_v33_osd_stream: %0d continuous pixels agree with independent v32 baseline including full logo, left diagnostics and tracking text; legacy picture and sync preserved with a uniform 3-cycle label overlay delay",checked);$finish;
end
initial begin #30000000;$fatal(1,"OSD stream timeout");end
endmodule
