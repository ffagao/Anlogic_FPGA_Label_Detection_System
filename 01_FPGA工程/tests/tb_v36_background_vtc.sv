`timescale 1ns/1ps
module tb_v36_background_vtc;
reg clk=0;always #5 clk=~clk;
reg rst_n=0;reg [3:0] mode=5,algorithm=0,keys=15;
wire user,last,de,vsync_in,hsync_in;
wire [23:0] pixel;wire vs,hs,out_de;
reg [23:0] fid=0;integer displays=0,frames_checked=0,roi_pixels=0,old_pixels=-1;
reg video_started=0;
reg old_failed=0;wire old_rst=rst_n && !old_failed;
reg [71:0] debug_data=0;reg debug_toggle=0,track=0;
reg [9:0] diag_in_line=0,diag_spatial_line=0;
reg [8:0] diag_pack_line=0,diag_fifo_level=0,diag_burst_count=0;
reg [17:0] diag_in_frame=0,diag_spatial_frame=0,diag_pack_frame=0,diag_ddr_frame=0;
uivtc #(.H_ActiveSize(1280),.H_FrameSize(1650),.H_SyncStart(1390),.H_SyncEnd(1430),
 .V_ActiveSize(720),.V_FrameSize(750),.V_SyncStart(725),.V_SyncEnd(730)) vtc(rst_n,clk,vsync_in,hsync_in,de,user,last);
reg [11:0] refx0=0,refx=0,refy0=0,refy=0;
wire [23:0] rgb=refx<512 ? (fid[0]?24'hff0000:24'h00ffff):24'hd8d8d8;
always @(posedge clk)begin
 refx0<=vtc.hcnt;refx<=refx0;refy0<=vtc.vcnt;refy<=refy0;
 if(rst_n && user)begin video_started=1;roi_pixels=0;displays=displays+1;if(displays%2==1)fid<=fid+1;end
 if(rst_n && video_started && de)begin
  if(dut.S_x!==refx || dut.S_y!==refy)$fatal(1,"real VTC coordinate mismatch got %d,%d expected %d,%d",dut.S_x,dut.S_y,refx,refy);
  if(refx>=512 && refy<720)roi_pixels=roi_pixels+1;
  if(last && refy==719)begin
   if(roi_pixels!=552960)$fatal(1,"ROI count %0d",roi_pixels);
   roi_pixels=0;frames_checked=frames_checked+1;
  end
 end
 if(rst_n && old.u_label_application.bg_failed && !old_failed)begin
  old_pixels=old.u_label_application.background.pixels;old_failed=1;
  $display("REPRODUCED v35 background failure; counted pixels=%0d (expected552960)",old_pixels);
 end
end
hdmi_mixer dut(.I_label_remote_action(3'd0),.I_label_enable(1'b1),.I_label_keys_n(keys),.I_label_imaging_locked(1'b1),.O_label_imaging_lock(),.O_label_buzzer_n(),.I_clk(clk),.I_rst_n(rst_n),
 .I_video_vsync(vsync_in),.I_video_hsync(hsync_in),.I_video_de(de),
 .I_video_user(user),.I_video_last(last),.I_debug_status(4'd0),
 .I_switch_state(mode),.I_algo_mode(algorithm),.I_track_enable(track),
 .I_track_color(3'd0),.I_track_shape(2'd1),.I_learn_prepare(1'b0),.I_learn_start(1'b0),.I_servo_state(4'd0),.I_pan_pulse_us(12'd1500),
 .I_tilt_pulse_us(12'd1300),.I_motion_enable(1'b0),.I_black_enable(1'b0),
 .I_black_valid(1'b0),.I_black_left(12'd0),.I_black_right(12'd0),
 .I_black_top(12'd0),.I_black_bottom(12'd0),.I_black_update_toggle(1'b0),
 .I_zoom_active(1'b0),.I_capture_frame_bcd(24'h123456),
 .I_display_frame_bcd(fid),.I_camera_fps_bcd(8'h30),
 .I_delay_frames_bcd(8'h02),.I_ae_debug(debug_data),.I_ae_debug_toggle(debug_toggle),
 .I_diag_in_line(diag_in_line),.I_diag_spatial_line(diag_spatial_line),.I_diag_pack_line(diag_pack_line),
 .I_diag_in_frame(diag_in_frame),.I_diag_spatial_frame(diag_spatial_frame),.I_diag_pack_frame(diag_pack_frame),
 .I_diag_ddr_frame(diag_ddr_frame),.I_diag_fifo_level(diag_fifo_level),.I_diag_burst_count(diag_burst_count),
 .I_diag_burst_active(1'b1),.I_diag_line_error(3'b0),.I_diag_frame_error(3'b0),
 .I_video_rd_data(rgb),.O_measure_update(),.O_measure_valid(),.O_measure_dx(),.O_measure_dy(),.O_video_rd_en(),.O_zoom_request(),.O_hdmi_vsync(vs),.O_hdmi_hsync(hs),.O_hdmi_de(out_de),.O_hdmi_data(pixel));
hdmi_mixer_v35_baseline old(.I_label_enable(1'b1),.I_label_keys_n(keys),.I_label_imaging_locked(1'b1),.O_label_imaging_lock(),.O_label_buzzer_n(),.I_clk(clk),.I_rst_n(old_rst),
 .I_video_vsync(vsync_in),.I_video_hsync(hsync_in),.I_video_de(de),
 .I_video_user(user),.I_video_last(last),.I_debug_status(4'd0),
 .I_switch_state(mode),.I_algo_mode(algorithm),.I_track_enable(track),
 .I_track_color(3'd0),.I_track_shape(2'd1),.I_learn_prepare(1'b0),.I_learn_start(1'b0),.I_servo_state(4'd0),.I_pan_pulse_us(12'd1500),
 .I_tilt_pulse_us(12'd1300),.I_motion_enable(1'b0),.I_black_enable(1'b0),
 .I_black_valid(1'b0),.I_black_left(12'd0),.I_black_right(12'd0),
 .I_black_top(12'd0),.I_black_bottom(12'd0),.I_black_update_toggle(1'b0),
 .I_zoom_active(1'b0),.I_capture_frame_bcd(24'h123456),
 .I_display_frame_bcd(fid),.I_camera_fps_bcd(8'h30),
 .I_delay_frames_bcd(8'h02),.I_ae_debug(debug_data),.I_ae_debug_toggle(debug_toggle),
 .I_diag_in_line(diag_in_line),.I_diag_spatial_line(diag_spatial_line),.I_diag_pack_line(diag_pack_line),
 .I_diag_in_frame(diag_in_frame),.I_diag_spatial_frame(diag_spatial_frame),.I_diag_pack_frame(diag_pack_frame),
 .I_diag_ddr_frame(diag_ddr_frame),.I_diag_fifo_level(diag_fifo_level),.I_diag_burst_count(diag_burst_count),
 .I_diag_burst_active(1'b1),.I_diag_line_error(3'b0),.I_diag_frame_error(3'b0),
 .I_video_rd_data(rgb),.O_measure_update(),.O_measure_valid(),.O_measure_dx(),.O_measure_dy(),.O_video_rd_en(),.O_zoom_request(),.O_hdmi_vsync(),.O_hdmi_hsync(),.O_hdmi_de(),.O_hdmi_data());
defparam dut.u_label_application.KEY_DEBOUNCE=1;
defparam dut.u_label_application.KEY_HOLD=30;
defparam old.u_label_application.KEY_DEBOUNCE=1;
defparam old.u_label_application.KEY_HOLD=30;
initial begin
 repeat(20)@(negedge clk);rst_n=1;repeat(30)@(negedge clk);
 keys=7;repeat(8)@(negedge clk);keys=15;
 wait(dut.u_label_application.bg_ready);repeat(5)@(negedge clk);
 if(!old_failed || old_pixels!=552959)$fatal(1,"old failure not reproduced %0d",old_pixels);
 if(dut.u_label_application.bg_progress!=8 || dut.u_label_application.bg_failed || frames_checked<20)$fatal(1,"calibration incomplete");
 if(dut.u_label_application.background.reference[0]!==24'hd8d8d8 || dut.u_label_application.background.reference[2159]!==24'hd8d8d8)$fatal(1,"left image contaminated right ROI");
 $display("PASS tb_v36_background_vtc: real 1280x720 VTC USER+DE, complete ROI, 3settle+8 fresh frames, repeated camera IDs, changing left image excluded, old failure reproduced");$finish;
end
initial begin #400000000;$fatal(1,"background VTC timeout status%0d progress%0d pixels%0d",dut.u_label_application.bg_status,dut.u_label_application.bg_progress,dut.u_label_application.background.pixels);end
endmodule
