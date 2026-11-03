`timescale 1ns/1ps
module tb_v20_osd;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,user=0;reg [3:0] mode=0;
reg [3:0] algorithm=0;
reg [71:0] debug_data={4'h5,12'h064,12'h096,16'h3000,12'h016,8'h01,8'h01};reg debug_toggle=0;
reg [9:0] diag_in_line=10'h140,diag_spatial_line=10'h140;
reg [8:0] diag_pack_line=9'h0f0,diag_fifo_level=9'h0a0,diag_burst_count=9'h0f0;
reg [17:0] diag_in_frame=18'h38400,diag_spatial_frame=18'h38400,diag_pack_frame=18'h2a300,diag_ddr_frame=18'h2a300;
wire [23:0] pixel;
hdmi_mixer dut(.I_label_remote_action(3'd0),.I_label_enable(1'b0),.I_label_keys_n(4'hf),.I_label_imaging_locked(1'b0),.O_label_imaging_lock(),.O_label_buzzer_n(),.I_clk(clk),.I_rst_n(rst_n),
 .I_video_vsync(1'b0),.I_video_hsync(1'b0),.I_video_de(1'b0),
 .I_video_user(user),.I_video_last(1'b0),.I_debug_status(4'd0),
 .I_switch_state(mode),.I_algo_mode(algorithm),.I_track_enable(1'b0),
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
 .I_video_rd_data(24'h123456),.O_measure_update(),.O_measure_valid(),.O_measure_dx(),.O_measure_dy(),.O_video_rd_en(),.O_zoom_request(),.O_hdmi_vsync(),.O_hdmi_hsync(),.O_hdmi_de(),.O_hdmi_data(pixel));
integer x=0,y=0,on_count=0,i;
task scan_line(input integer offset,input [23:0] expected_color);
begin
 on_count=0;
 for(y=168+offset;y<168+offset+16;y=y+1)
  for(x=8;x<248;x=x+1) begin
   #1;
   if(dut.S_dyn_on) begin
    on_count=on_count+1;
    if(dut.S_osd_color!==expected_color) $fatal(1,"OSD color at %0d %0d %h",x,y,dut.S_osd_color);
   end
  end
 if(on_count<20) $fatal(1,"missing OSD text offset=%0d hits=%0d",offset,on_count);
end endtask
task frame_start;
begin @(negedge clk);user=1;@(negedge clk);user=0;repeat(40) @(negedge clk);end
endtask
task check_text(input integer offset,input string wanted);
 integer pos;
 begin
 y=168+offset;
 for(pos=0;pos<wanted.len();pos=pos+1) begin
  x=8+16*pos;#1;
  if(wanted.getc(pos)==32) begin
   if(dut.S_pf_char!==0 && dut.S_pf_char!==32) $fatal(1,"OSD separator offset=%0d pos=%0d",offset,pos);
  end
  else if(dut.S_pf_char!==wanted.getc(pos)) $fatal(1,"OSD text offset=%0d pos=%0d got=%h",offset,pos,dut.S_pf_char);
 end
 end
endtask
initial begin
 repeat(10) @(negedge clk);rst_n=1;
 @(negedge clk);debug_toggle=1;repeat(10) @(negedge clk);
 force dut.S_x_2d=x;force dut.S_x_1d=x;force dut.S_y_2d=y;force dut.S_y_1d=y;force dut.S_video_de_2d=1;force dut.S_video_de_1d=1;
 for(i=0;i<6;i=i+1) begin
  mode=i;frame_start();
  if(dut.S_delay_ms_bcd!==(i==0 ? 16'h0033 : 16'h0067)) $fatal(1,"OSD ms state=%0d",i);
  scan_line(32,24'hfff200);scan_line(132,24'h00ffff);scan_line(204,24'h00ffff);
  scan_line(228,24'hfff200);scan_line(252,24'hfff200);scan_line(276,24'hfff200);
  scan_line(300,24'hfff200);scan_line(324,24'hfff200);scan_line(348,24'hfff200);scan_line(372,24'hfff200);
  x=400;y=300;#1;if(dut.S_osd_hit) $fatal(1,"old center-left OSD remains");
 end
 check_text(228,"AE STATUS:LOCK ");check_text(252,"BRIGHTNESS:064");check_text(276,"TARGET:096");
 check_text(300,"EXP SET:3000");check_text(324,"GAIN INDEX:016");
 check_text(348,"METER CNT:0X01");check_text(372,"CONFIG CNT:0X01");check_text(204,"DELAY:0067 MS");
 mode=0;algorithm=4;frame_start();check_text(156,"MODE:4 HIST EQ");
 mode=0;frame_start();check_text(156,"MODE:4 HIST EQ");check_text(204,"DELAY:0033 MS");
 algorithm=5;frame_start();check_text(156,"MODE:5 RED EDGE");
 $display("PASS all 6 effective states: cyan delay, yellow AE fields, 0000 at60FPS and others at30FPS");
 // Toggle arrives before the payload settles across the first sampling edge.
 // The extra destination settle cycle must prevent accepting the old bus.
 @(negedge clk);debug_toggle=~debug_toggle;
 #9;debug_data={4'h2,12'h080,12'h096,16'h1900,12'h016,8'haa,8'h55};
 repeat(12) @(negedge clk);frame_start();
 if(dut.S_ae_debug_osd!==debug_data) $fatal(1,"CDC skew captured stale diagnostic payload");
 $display("PASS bundled CDC payload arriving after first toggle sampling edge");
 @(negedge clk);debug_data={4'h2,12'h080,12'h096,16'h1900,12'h191,8'haa,8'h55};debug_toggle=~debug_toggle;
 repeat(12) @(negedge clk);frame_start();
 x=184;y=492;#1;if(dut.S_pf_char!==8'h31) $fatal(1,"G hundreds digit is not 1: %h",dut.S_pf_char);
 x=200;y=492;#1;if(dut.S_pf_char!==8'h39) $fatal(1,"G tens digit is not 9: %h",dut.S_pf_char);
 x=216;y=492;#1;if(dut.S_pf_char!==8'h31) $fatal(1,"G units digit is not 1: %h",dut.S_pf_char);
 $display("PASS OSD renders three-digit G=191");
 $display("PASS tb_v20_osd");$finish;
end
initial begin #2000000;$fatal(1,"timeout");end
endmodule
