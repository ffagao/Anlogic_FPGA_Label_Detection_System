`timescale 1ns/1ps
module tb_v32_banner;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,user=0;reg [3:0] mode=2;
reg [3:0] algorithm=0;
reg [71:0] debug_data={4'h5,12'h064,12'h096,16'h3000,12'h016,8'h01,8'h01};reg debug_toggle=0;
reg [9:0] diag_in_line=10'h140,diag_spatial_line=10'h140;
reg [8:0] diag_pack_line=9'h0f0,diag_fifo_level=9'h0a0,diag_burst_count=9'h0f0;
reg [17:0] diag_in_frame=18'h38400,diag_spatial_frame=18'h38400,diag_pack_frame=18'h2a300,diag_ddr_frame=18'h2a300;
reg zoom=0;
wire [23:0] pixel;
hdmi_mixer dut(.I_label_enable(1'b0),.I_label_keys_n(4'hf),.I_label_imaging_locked(1'b0),.O_label_imaging_lock(),.O_label_buzzer_n(),.I_clk(clk),.I_rst_n(rst_n),
 .I_video_vsync(1'b0),.I_video_hsync(1'b0),.I_video_de(1'b0),
 .I_video_user(user),.I_video_last(1'b0),.I_debug_status(4'd0),
 .I_switch_state(mode),.I_algo_mode(algorithm),.I_track_enable(1'b0),
 .I_track_color(3'd0),.I_track_shape(2'd1),.I_learn_prepare(1'b0),.I_learn_start(1'b0),.I_servo_state(4'd0),.I_pan_pulse_us(12'd1500),
 .I_tilt_pulse_us(12'd1300),.I_motion_enable(1'b0),.I_black_enable(1'b1),
 .I_black_valid(1'b0),.I_black_left(12'd0),.I_black_right(12'd0),
 .I_black_top(12'd0),.I_black_bottom(12'd0),.I_black_update_toggle(1'b0),
 .I_zoom_active(zoom),.I_capture_frame_bcd(24'h123456),
 .I_display_frame_bcd(24'h123454),.I_camera_fps_bcd(8'h30),
 .I_delay_frames_bcd(8'h02),.I_ae_debug(debug_data),.I_ae_debug_toggle(debug_toggle),
 .I_diag_in_line(diag_in_line),.I_diag_spatial_line(diag_spatial_line),.I_diag_pack_line(diag_pack_line),
 .I_diag_in_frame(diag_in_frame),.I_diag_spatial_frame(diag_spatial_frame),.I_diag_pack_frame(diag_pack_frame),
 .I_diag_ddr_frame(diag_ddr_frame),.I_diag_fifo_level(diag_fifo_level),.I_diag_burst_count(diag_burst_count),
 .I_diag_burst_active(1'b1),.I_diag_line_error(3'b0),.I_diag_frame_error(3'b0),
 .I_video_rd_data(24'h123456),.O_measure_update(),.O_measure_valid(),.O_measure_dx(),.O_measure_dy(),.O_video_rd_en(),.O_zoom_request(),.O_hdmi_vsync(),.O_hdmi_hsync(),.O_hdmi_de(),.O_hdmi_data(pixel));

integer x=0,y=0,pos,col,row,hits=0;
integer ticks=0,flush;
reg [23:0] pipe[0:4];integer pi;
reg [7:0] reference_char=0;
reg [3:0] reference_row=0;
wire [15:0] reference_bits;
string message="BLUE RECTANGLE DETECTED";
reg [23:0] expected;
osd_char_lib reference_font(.I_char(reference_char),.I_row(reference_row),.O_row_bits(reference_bits));
task frame_start;
 begin @(negedge clk);user=1;@(negedge clk);user=0;repeat(10) @(negedge clk);end
endtask
task check_pixel;
 begin
  reference_char=0;reference_row=0;col=0;
  if(x>=896 && x<1264 && y>=24 && y<40) begin
   pos=(x-896)/16;col=(x-896)%16;reference_char=message.getc(pos);reference_row=(y-24+1)%16;
  end
  repeat(6) @(negedge clk);
  expected=24'h123456;
  if(zoom && mode==2 && x>=888 && x<1272 && y>=16 && y<48) begin
   expected=reference_bits[15-col] ? 24'hfff200 : 24'h101820;
   if(reference_bits[15-col]) hits=hits+1;
  end
  if(pixel!==expected) $fatal(1,"banner/pipeline pixel x=%0d y=%0d zoom=%b mode=%h got=%h expected=%h",x,y,zoom,mode,pixel,expected);
  if(dut.S_video_data_raw_2d!==24'h123456) $fatal(1,"banner changed raw detector input");
 end
endtask
initial begin
 repeat(5) @(negedge clk);rst_n=1;mode=2;frame_start();
 force dut.S_x=x;force dut.S_y=y;
 x=900;y=30;check_pixel();
 zoom=1;
 for(y=12;y<52;y=y+1) for(x=880;x<1280;x=x+1) check_pixel();
 if(hits<500) $fatal(1,"missing banner glyphs %0d",hits);
 zoom=0;x=900;y=30;check_pixel();
 zoom=1;mode=3;check_pixel();
 // Stream one new raster pixel every clock. Static held coordinates alone
 // cannot detect a one-clock displacement of the added text/video path.
 mode=2;zoom=1;frame_start();
 for(y=12;y<52;y=y+1) for(x=880;x<1280;x=x+1) begin
  @(negedge clk);
  reference_char=0;reference_row=0;col=0;
  if(x>=896 && x<1264 && y>=24 && y<40) begin
   pos=(x-896)/16;col=(x-896)%16;reference_char=message.getc(pos);reference_row=(y-24+1)%16;
  end
  #1;
  expected=24'h123456;
  if(x>=888 && x<1272 && y>=16 && y<48) expected=reference_bits[15-col] ? 24'hfff200 : 24'h101820;
  @(posedge clk);#1;
  if(ticks>=5 && pixel!==pipe[0]) $fatal(1,"streamed banner latency mismatch input=%0d,%0d got=%h expected=%h",x,y,pixel,pipe[0]);
  for(pi=0;pi<4;pi=pi+1)pipe[pi]=pipe[pi+1];pipe[4]=expected;ticks=ticks+1;
 end
 for(flush=0;flush<5;flush=flush+1) begin
  @(negedge clk);x=0;y=0;@(posedge clk);#1;
  if(pixel!==pipe[0]) $fatal(1,"streamed banner tail mismatch");
  for(pi=0;pi<4;pi=pi+1)pipe[pi]=pipe[pi+1];
 end
 $display("PASS 16000 raster pixels streamed at one pixel/clock: uniform five-cycle video latency including label overlay");
 $display("PASS complete mixer: fixed English banner at top right, all glyph pixels, dark background, video alignment, enable/exit and untouched raw detector image");
 $display("PASS tb_v32_banner");$finish;
end
initial begin #5000000;$fatal(1,"banner timeout");end
endmodule
