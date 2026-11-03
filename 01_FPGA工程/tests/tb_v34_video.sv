`timescale 1ns/1ps
module tb_v34_video;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,user=0;reg [3:0] mode=5;
reg [3:0] algorithm=0;
reg [71:0] debug_data={4'h5,12'h064,12'h096,16'h3000,12'h016,8'h01,8'h01};reg debug_toggle=0;
reg [9:0] diag_in_line=10'h140,diag_spatial_line=10'h140;
reg [8:0] diag_pack_line=9'h0f0,diag_fifo_level=9'h0a0,diag_burst_count=9'h0f0;
reg [17:0] diag_in_frame=18'h38400,diag_spatial_frame=18'h38400,diag_pack_frame=18'h2a300,diag_ddr_frame=18'h2a300;
reg de=0,track=0,vsync_in=0,hsync_in=0;wire [23:0] pixel,reference_pixel;wire vs,hs,out_de,ref_vs,ref_hs,ref_de;
reg last=0;reg [23:0] rgb=0;
integer xx=0,yy=0;
hdmi_mixer dut(.I_label_remote_action(3'd0),.I_label_enable(1'b1),.I_label_keys_n(4'hf),.I_label_imaging_locked(1'b0),.O_label_imaging_lock(),.O_label_buzzer_n(),.I_clk(clk),.I_rst_n(rst_n),
 .I_video_vsync(vsync_in),.I_video_hsync(hsync_in),.I_video_de(de),
 .I_video_user(user),.I_video_last(last),.I_debug_status(4'd0),
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
 .I_video_rd_data(rgb),.O_measure_update(),.O_measure_valid(),.O_measure_dx(),.O_measure_dy(),.O_video_rd_en(),.O_zoom_request(),.O_hdmi_vsync(vs),.O_hdmi_hsync(hs),.O_hdmi_de(out_de),.O_hdmi_data(pixel));

reg [5:0] valid_pipe=0;reg [23:0] pixels[0:5];
reg [11:0] xp[0:5],yp[0:5];integer n,count=0,raw_checked=0,right_checked=0,left_checked=0;
always @(posedge clk) begin
 valid_pipe<={valid_pipe[4:0],de};pixels[0]<=rgb;xp[0]<=xx;yp[0]<=yy;
 for(n=1;n<6;n=n+1)begin pixels[n]<=pixels[n-1];xp[n]<=xp[n-1];yp[n]<=yp[n-1];end
 #1;
 if(rst_n && count>10)begin
  if(dut.S_video_de_2d!==valid_pipe[1])$fatal(1,"label input DE skew");
  if(valid_pipe[1])begin
   if(dut.S_video_data_raw_2d!==pixels[1]||dut.S_x_2d!==xp[1]||dut.S_y_2d!==yp[1])
    $fatal(1,"label raw/coordinate alignment %d,%d expected%d,%d",dut.S_x_2d,dut.S_y_2d,xp[1],yp[1]);
   raw_checked=raw_checked+1;
  end
  if(out_de!==valid_pipe[5])$fatal(1,"output DE/label pipeline skew");
  if(valid_pipe[5])begin
   if(xp[5]>=1100 && xp[5]<1240 && yp[5]>=500 && yp[5]<600)begin
    if(pixel!==pixels[5])$fatal(1,"right image shifted at%d,%d got%h expected%h",xp[5],yp[5],pixel,pixels[5]);right_checked=right_checked+1;
   end
   if(xp[5]==511 && yp[5]>=500 && yp[5]<600)begin
    if(pixel!==24'h101c29)$fatal(1,"left panel width changed at x511 %h",pixel);left_checked=left_checked+1;
   end
   if(xp[5]==512 && yp[5]>=500 && yp[5]<600 && pixel!==24'hffffff)$fatal(1,"ROI edge not aligned at512 %h",pixel);
  end
 end
 count=count+1;
end
task tick;begin @(negedge clk);end endtask
initial begin
 repeat(6)tick();rst_n=1;repeat(20)tick();user=1;tick();user=0;repeat(12)tick();
 for(yy=0;yy<720;yy=yy+1)begin
  for(xx=0;xx<1280;xx=xx+1)begin
   de=1;last=(xx==1279);rgb={xx[7:0],yy[7:0],xx[7:0]^yy[7:0]};tick();
  end
  de=0;last=0;repeat(12)tick();
 end
 de=0;repeat(12)tick();
 if(raw_checked!=1280*720||right_checked!=14000||left_checked!=100)$fatal(1,"coverage incomplete %d %d %d",raw_checked,right_checked,left_checked);
 $display("PASS tb_v34_video: complete 1280x720 raw coordinates, pixel/sync alignment, right-side image, fixed 512px panel and ROI boundary");$finish;
end
initial begin #20000000;$fatal(1,"video timeout");end
endmodule
