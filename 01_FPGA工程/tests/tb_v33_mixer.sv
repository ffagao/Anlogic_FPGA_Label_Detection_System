`timescale 1ns/1ps
module tb_v33_mixer;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,user=0;reg [3:0] mode=0;
reg [3:0] algorithm=0;
reg [71:0] debug_data={4'h5,12'h064,12'h096,16'h3000,12'h016,8'h01,8'h01};reg debug_toggle=0;
reg [9:0] diag_in_line=10'h140,diag_spatial_line=10'h140;
reg [8:0] diag_pack_line=9'h0f0,diag_fifo_level=9'h0a0,diag_burst_count=9'h0f0;
reg [17:0] diag_in_frame=18'h38400,diag_spatial_frame=18'h38400,diag_pack_frame=18'h2a300,diag_ddr_frame=18'h2a300;
reg track=1,black=0,black_valid=0,zoom=0,prepare=0,start=0;
reg [2:0] colour=5;reg [1:0] shape=1;
wire [39:0] report;wire report_update;
wire [23:0] pixel;
hdmi_mixer dut(.I_label_remote_action(3'd0),.I_label_enable(1'b0),.I_label_keys_n(4'hf),.I_label_imaging_locked(1'b0),.O_label_imaging_lock(),.O_label_buzzer_n(),.I_clk(clk),.I_rst_n(rst_n),
 .I_video_vsync(1'b0),.I_video_hsync(1'b0),.I_video_de(1'b0),
 .I_video_user(user),.I_video_last(1'b0),.I_debug_status(4'd0),
 .I_switch_state(mode),.I_algo_mode(algorithm),.I_track_enable(track),
 .I_track_color(colour),.I_track_shape(shape),.I_learn_prepare(prepare),.I_learn_start(start),.I_servo_state(4'd0),.I_pan_pulse_us(12'd1500),
 .I_tilt_pulse_us(12'd1300),.I_motion_enable(1'b0),.I_black_enable(black),
 .I_black_valid(black_valid),.I_black_left(12'd400),.I_black_right(12'd500),
 .I_black_top(12'd200),.I_black_bottom(12'd300),.I_black_update_toggle(1'b0),
 .I_zoom_active(zoom),.I_capture_frame_bcd(24'h123456),
 .I_display_frame_bcd(24'h123454),.I_camera_fps_bcd(8'h30),
 .I_delay_frames_bcd(8'h02),.I_ae_debug(debug_data),.I_ae_debug_toggle(debug_toggle),
 .I_diag_in_line(diag_in_line),.I_diag_spatial_line(diag_spatial_line),.I_diag_pack_line(diag_pack_line),
 .I_diag_in_frame(diag_in_frame),.I_diag_spatial_frame(diag_spatial_frame),.I_diag_pack_frame(diag_pack_frame),
 .I_diag_ddr_frame(diag_ddr_frame),.I_diag_fifo_level(diag_fifo_level),.I_diag_burst_count(diag_burst_count),
 .I_diag_burst_active(1'b1),.I_diag_line_error(3'b0),.I_diag_frame_error(3'b0),
 .I_video_rd_data(24'h123456),.O_measure_update(),.O_measure_valid(),.O_measure_dx(),.O_measure_dy(),.O_video_rd_en(),.O_zoom_request(),.O_hdmi_vsync(),.O_hdmi_hsync(),.O_hdmi_de(),.O_hdmi_data(pixel));

integer x=0,y=0,xx,yy,f;
reg raw_de=0;reg [11:0] raw_x=0,raw_y=0;reg [23:0] raw_rgb=24'hd08020,frame_id=0;
task tick;begin @(negedge clk);end endtask
task frame_start;
 begin user=1;tick();user=0;repeat(10)tick();end
endtask
task camera_frame(input integer id);
 begin
  frame_id=id;raw_x=0;raw_y=0;raw_de=1;tick();raw_de=0;tick();
  for(yy=328;yy<392;yy=yy+4) for(xx=608;xx<672;xx=xx+4)begin
   raw_x=xx;raw_y=yy;raw_de=1;tick();
  end
  raw_de=0;repeat(4)tick();
 end
endtask
initial begin
 repeat(6)tick();rst_n=1;mode=4;frame_start();
 force dut.S_video_de_2d=raw_de;force dut.S_video_de_1d=raw_de;force dut.S_x_2d=raw_x;force dut.S_x_1d=raw_x;force dut.S_y_2d=raw_y;force dut.S_y_1d=raw_y;
 force dut.S_video_data_raw_2d=raw_rgb;force dut.S_display_frame_bcd_osd=frame_id;
 prepare=1;tick();prepare=0;repeat(3)tick();if(!dut.S_custom_preparing) $fatal(1,"mixer prepare");
 start=1;tick();start=0;repeat(3)tick();
 for(f=1;f<=8;f=f+1) camera_frame(f);
 frame_id=9;raw_x=0;raw_y=0;raw_de=1;tick();raw_de=0;repeat(4)tick();
 if(!dut.S_custom_valid || dut.S_learn_rgb!==24'hd08020 || !dut.S_custom_mask) $fatal(1,"raw RGB learning integration");
 if(dut.F_color_name(5,0)!="C" || dut.F_color_name(5,5)!="M") $fatal(1,"CUSTOM OSD name");
 // Real raw-pixel learning is isolated from all drawn pixels and fill.
 raw_rgb=24'h20c020;#1;if(dut.S_custom_mask) $fatal(1,"custom mask unrelated colour");
 raw_rgb=24'hd08020;#1;if(!dut.S_custom_mask || !dut.S_track_mask_pixel) $fatal(1,"custom mask/fill routing");
 release dut.S_video_de_2d;release dut.S_x_2d;release dut.S_y_2d;
 force dut.S_x=x;force dut.S_y=y;
 x=1099;y=471;repeat(8)tick();if(pixel!==24'h70d8ff) $fatal(1,"panel not in final mixer %h",pixel);
 x=640;y=360;prepare=1;tick();prepare=0;repeat(4)tick();
 x=607;y=327;repeat(8)tick();if(pixel!==24'hffffff) $fatal(1,"ROI border missing from final mixer %h",pixel);
 // Learned colour survives leaving the detection view.
 mode=2;track=0;black=0;black_valid=0;zoom=0;
 frame_start();
 if(!dut.S_custom_valid) $fatal(1,"mode exit lost learned model");
 black_valid=0;frame_start();
 $display("PASS tb_v33_mixer: actual raw-pixel teach engine, mask/fill wiring, CUSTOM font, panel/ROI in final output, learned model survives mode exit");$finish;
end
initial begin #2000000;$fatal(1,"mixer integration timeout");end
endmodule
