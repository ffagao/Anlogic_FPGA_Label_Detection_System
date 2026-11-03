`timescale 1ns/1ps
module tb_v25_measure_guard;
reg clk=0;always #5 clk=~clk;
reg rst=0;reg [2:0] colour=0;reg [1:0] shape=1;reg [3:0] mode=3;
reg start_key=0;wire measure_valid,measure_large;
hdmi_mixer dut(.I_label_remote_action(3'd0),.I_label_enable(1'b0),.I_label_keys_n(4'hf),.I_label_imaging_locked(1'b0),.O_label_imaging_lock(),.O_label_buzzer_n(),.I_clk(clk),.I_rst_n(rst),
 .I_video_vsync(1'b0),.I_video_hsync(1'b0),.I_video_de(1'b0),.I_video_user(1'b0),.I_video_last(1'b0),
 .I_debug_status(4'd0),.I_switch_state(mode),.I_algo_mode(4'd0),.I_track_enable(1'b1),
 .I_track_color(colour),.I_track_shape(shape),.I_learn_prepare(1'b0),.I_learn_start(1'b0),.I_servo_state(4'd1),
 .I_pan_pulse_us(12'd1500),.I_tilt_pulse_us(12'd1500),.I_motion_enable(1'b0),.I_black_enable(1'b0),
 .I_black_valid(1'b0),.I_black_left(12'd0),.I_black_right(12'd0),.I_black_top(12'd0),.I_black_bottom(12'd0),
 .I_black_update_toggle(1'b0),.I_zoom_active(1'b0),.I_capture_frame_bcd(24'd0),.I_camera_fps_bcd(8'd0),
 .I_display_frame_bcd(24'd0),.I_delay_frames_bcd(8'd0),.I_ae_debug(72'd0),.I_ae_debug_toggle(1'b0),
 .I_diag_in_line(10'd0),.I_diag_spatial_line(10'd0),.I_diag_pack_line(9'd0),
 .I_diag_in_frame(18'd0),.I_diag_spatial_frame(18'd0),.I_diag_pack_frame(18'd0),.I_diag_ddr_frame(18'd0),
 .I_diag_fifo_level(9'd0),.I_diag_burst_count(9'd0),.I_diag_burst_active(1'b0),
 .I_diag_line_error(3'd0),.I_diag_frame_error(3'd0),
 .I_video_rd_data(24'd0),.O_measure_valid(measure_valid),.O_measure_large(measure_large),.O_measure_update(),.O_measure_dx(),.O_measure_dy(),
 .O_video_rd_en(),.O_zoom_request(),.O_hdmi_vsync(),.O_hdmi_hsync(),.O_hdmi_de(),.O_hdmi_data());
servo_pan_tracker #(.CLK_MHZ(1)) servo(.I_clk(clk),.I_rst_n(rst),.I_mode(mode),.I_zoom_active(1'b0),.I_color(colour),.I_shape(shape),
 .I_key_dec(1'b0),.I_key_inc(start_key),.I_measure_update(1'b0),.I_measure_valid(1'b0),
 .I_measure_dx(13'sd0),.I_measure_dy(13'sd0),.O_pan_pwm(),.O_tilt_pwm(),.O_state(),
 .O_pan_pulse_us(),.O_tilt_pulse_us(),.O_buzzer_n());
initial begin
 repeat(5) @(negedge clk);rst=1;
 force dut.S_track_enable_osd=1;force dut.S_black_enable_osd=0;
 force dut.S_track_valid=1;force dut.S_track_detect_valid=1;
 force dut.S_track_color_osd=3'd0;force dut.S_track_shape_osd=2'd1;force dut.S_track_shape=2'd1;
 force dut.S_measure_snapshot_valid=1;force dut.S_measure_color=3'd0;
 force dut.S_measure_shape=2'd1;force dut.S_measure_view=4'd3;
 #1;if(!measure_valid) $fatal(1,"matching snapshot rejected");
 force dut.S_track_left=100;force dut.S_track_right=500;force dut.S_track_top=100;force dut.S_track_bottom=300;
 force dut.S_measure_pending=1;@(negedge clk);#1;if(!measure_large)$fatal(1,"large footprint not exported with measurement");
 force dut.S_measure_pending=0;force dut.S_track_right=400;repeat(2)@(negedge clk);#1;if(!measure_large)$fatal(1,"footprint changed without completed measurement");
 force dut.S_measure_pending=1;@(negedge clk);#1;if(measure_large)$fatal(1,"small footprint did not clear");
 force dut.S_track_right=450;@(negedge clk);#1;if(measure_large)$fatal(1,"footprint hysteresis restarted below upper threshold");
 release dut.S_measure_pending;

 shape=2;#1;if(measure_valid) $fatal(1,"stale shape measurement exported");
 force dut.S_track_shape_osd=2'd2;#1;if(measure_valid) $fatal(1,"wrong detected shape exported");
 force dut.S_track_shape=2'd2;#1;if(measure_valid) $fatal(1,"stale measurement shape exported");
 force dut.S_measure_shape=2'd2;#1;if(!measure_valid) $fatal(1,"new shape snapshot rejected");
 colour=5;#1;if(measure_valid) $fatal(1,"stale colour measurement exported");
 force dut.S_track_color_osd=3'd5;#1;if(measure_valid) $fatal(1,"three-bit colour cache aliased");
 force dut.S_measure_color=3'd5;#1;if(!measure_valid) $fatal(1,"new CUSTOM snapshot rejected");
 mode=1;#1;if(measure_valid) $fatal(1,"stale view exported");
 @(negedge clk);mode=3;colour=0;shape=1;
 repeat(45000) @(negedge clk);
 start_key=1;@(negedge clk);start_key=0;#1;
 if(!servo.S_armed) $fatal(1,"servo did not start");
 shape=2;@(negedge clk);#1;
 if(servo.S_armed || servo.S_pan_target_us!=servo.S_pan_pulse_us || servo.S_tilt_target_us!=servo.S_tilt_pulse_us)
  $fatal(1,"shape selection did not cancel pending servo movement");
 $display("PASS stale colour/shape/view measurements rejected and shape change disarms servo");
 $display("PASS tb_v25_measure_guard");$finish;
end
initial begin #1000000;$fatal(1,"measure guard timeout");end
endmodule
