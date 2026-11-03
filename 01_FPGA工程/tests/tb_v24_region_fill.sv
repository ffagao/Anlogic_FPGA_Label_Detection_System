`timescale 1ns/1ps
module tb_v24_region_fill;
reg clk=0; always #5 clk=~clk;
reg rst_n=0;
wire [23:0] pixel;
hdmi_mixer dut(.I_label_remote_action(3'd0),.I_label_enable(1'b0),.I_label_keys_n(4'hf),.I_label_imaging_locked(1'b0),.O_label_imaging_lock(),.O_label_buzzer_n(),
 .I_clk(clk),.I_rst_n(rst_n),
 .I_video_vsync(1'b0),.I_video_hsync(1'b0),.I_video_de(1'b0),
 .I_video_user(1'b0),.I_video_last(1'b0),.I_debug_status(4'd0),
 .I_switch_state(4'b0001),.I_algo_mode(4'd0),.I_track_enable(1'b1),
 .I_track_color(3'd0),.I_track_shape(2'd1),.I_learn_prepare(1'b0),.I_learn_start(1'b0),.I_servo_state(4'd0),.I_pan_pulse_us(12'd1500),
 .I_tilt_pulse_us(12'd1300),.I_motion_enable(1'b0),.I_black_enable(1'b0),
 .I_black_valid(1'b0),.I_black_left(12'd0),.I_black_right(12'd0),
 .I_black_top(12'd0),.I_black_bottom(12'd0),.I_black_update_toggle(1'b0),
 .I_zoom_active(1'b0),.I_capture_frame_bcd(24'd0),
 .I_display_frame_bcd(24'd0),.I_camera_fps_bcd(8'd0),
 .I_delay_frames_bcd(8'd0),.I_ae_debug(72'd0),.I_ae_debug_toggle(1'b0),
 .I_diag_in_line(10'd0),.I_diag_spatial_line(10'd0),.I_diag_pack_line(9'd0),
 .I_diag_in_frame(18'd0),.I_diag_spatial_frame(18'd0),.I_diag_pack_frame(18'd0),.I_diag_ddr_frame(18'd0),
 .I_diag_fifo_level(9'd0),.I_diag_burst_count(9'd0),.I_diag_burst_active(1'b0),
 .I_diag_line_error(3'd0),.I_diag_frame_error(3'd0),
 .I_video_rd_data(24'd0),.O_measure_update(),.O_measure_valid(),
 .O_measure_dx(),.O_measure_dy(),.O_video_rd_en(),.O_zoom_request(),
 .O_hdmi_vsync(),.O_hdmi_hsync(),.O_hdmi_de(),.O_hdmi_data(pixel)
);
initial begin
 repeat(5) @(negedge clk); rst_n=1;
 force dut.S_osd_hit=1'b0;
 force dut.S_black_enable_osd=1'b0;
 force dut.S_track_enable_osd=1'b1;
 force dut.S_track_cross_2d=1'b0;
 force dut.S_aim_center_cross_2d=1'b0;
 force dut.S_track_border_2d=1'b0;
 force dut.S_track_raw_border_2d=1'b0;
 force dut.S_video_de_2d=1'b1;force dut.S_video_de_1d=1'b1;
 force dut.S_video_data_raw_2d=24'h80a0c0;
 force dut.S_track_mask_pixel=1'b1;
 force dut.S_switch_state_osd=4'b0001;
 repeat(4) @(posedge clk); #1;
 if(pixel!==24'h60b7cf) $fatal(1,"cyan 25%% blend mismatch: got %h expected 60b7cf",pixel);
 force dut.S_track_mask_pixel=1'b0;
 repeat(4) @(posedge clk); #1;
 if(pixel!==24'h80a0c0) $fatal(1,"unmasked pixel changed: got %h",pixel);
 force dut.S_track_mask_pixel=1'b1;
 force dut.S_switch_state_osd=4'b0010;
 repeat(4) @(posedge clk); #1;
 if(pixel!==24'h80a0c0) $fatal(1,"fill leaked outside mask state: got %h",pixel);
 $display("PASS cyan 25%% blend on selected mask pixel");
 $display("PASS unmasked pixels retain original video");
 $display("PASS mask fill is disabled outside state 0001");
 $display("PASS tb_v24_region_fill");
 $finish;
end
initial begin #100000; $fatal(1,"timeout"); end
endmodule
