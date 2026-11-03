`timescale 1ns/1ps
module tb_v41_caption;
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
wire [23:0] pixel;reg [23:0] scene_rgb=24'h123456;
hdmi_mixer dut(.I_label_remote_action(3'd0),.I_label_enable(1'b0),.I_label_keys_n(4'hf),.I_label_imaging_locked(1'b0),.O_label_imaging_lock(),.O_label_buzzer_n(),.I_clk(clk),.I_rst_n(rst_n),
 .I_video_vsync(1'b0),.I_video_hsync(1'b0),.I_video_de(1'b1),
 .I_video_user(user),.I_video_last(1'b0),.I_debug_status(4'd0),
 .I_switch_state(mode),.I_algo_mode(algorithm),.I_track_enable(track),
 .I_label_zoom_supported(1'b0),.I_label_zoom_active(1'b0),.I_label_zoom_src_x(12'd0),.I_label_zoom_src_y(12'sd0),.I_track_color(colour),.I_track_shape(shape),.I_learn_prepare(prepare),.I_learn_start(start),.I_servo_state(4'd0),.I_pan_pulse_us(12'd1500),
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
 .I_video_rd_data(scene_rgb),.O_measure_update(),.O_measure_valid(),.O_measure_dx(),.O_measure_dy(),.O_video_rd_en(),.O_zoom_request(),.O_hdmi_vsync(),.O_hdmi_hsync(),.O_hdmi_de(),.O_hdmi_data(pixel));


integer fd;integer x=0,y=0,l=600,r=740,t=300,b=500,c,sh,row,col,xx,yy,points=0;
reg valid=1;reg [7:0] fc;reg [3:0] fr;wire [15:0] fb;
osd_char_lib reference_font(fc,fr,fb);
task tick;begin @(negedge clk);end endtask
task frame;
begin x=0;y=0;user=1;tick();x=1;user=0;repeat(8)tick();end
endtask
task check_text(input string text,input integer line);
reg [23:0] expected;integer pos;
begin
 for(row=0;row<16;row=row+1)for(pos=0;pos<8;pos=pos+1)for(col=0;col<16;col=col+1)begin
  x=dut.S_caption_x+4+pos*16+col;y=dut.S_caption_y+2+line*16+row;
  fc=pos<text.len()?text.getc(pos):8'h20;fr=row;#1;
  expected=fb[15-col]?(line?24'hffffff:24'h00e6ff):24'h101820;
  repeat(9)tick();if(pixel!==expected)$fatal(1,"caption [%s] row%0d pos%0d col%0d got%h expected%h",text,row,pos,col,pixel,expected);
  points=points+1;
 end
end
endtask
string colour_name,shape_name;
initial begin
 force dut.S_x=x;force dut.S_y=y;
 force dut.S_track_valid=valid;force dut.S_track_detect_valid=valid;
 force dut.S_track_shape=shape;
 force dut.S_track_left=l;force dut.S_track_right=r;force dut.S_track_top=t;force dut.S_track_bottom=b;
 repeat(5)tick();rst_n=1;mode=1;track=1;
 for(c=0;c<4;c=c+1)for(sh=1;sh<=3;sh=sh+1)begin
  colour=c==3?5:c;mode=c==3?3:1;shape=sh;frame();frame();
  if(!dut.S_caption_visible || dut.S_caption_x!=600 || dut.S_caption_y!=260)$fatal(1,"caption not placed above matched target");
  case(c)0:colour_name="BLUE";1:colour_name="RED";2:colour_name="GREEN";3:colour_name="CUSTOM";endcase
  case(sh)1:shape_name="RECT";2:shape_name="CIRCLE";3:shape_name="TRIANGLE";endcase
  check_text(colour_name,0);check_text(shape_name,1);
 end
 l=600;r=740;t=300;b=500;frame();
 x=0;y=0;user=1;tick();x=1;user=0;
 wait(dut.u_rectangle_tracker.frame_start);@(posedge clk);#1;l=700;t=250;
 repeat(6)tick();if(dut.S_caption_x!=700 || dut.S_caption_y!=210)$fatal(1,"caption missed the same-frame tracker publication");
 l=1200;r=1279;t=0;b=30;frame();if(dut.S_caption_x!=888 || dut.S_caption_y!=34)$fatal(1,"right/top edge clamp failed");
 l=0;r=80;t=0;b=710;#1;if(dut.S_caption_x!=888)$fatal(1,"caption moved within frame");
 frame();if(dut.S_caption_x!=272 || dut.S_caption_y!=4)$fatal(1,"left/large target clamp failed");
 valid=0;#1;if(dut.S_caption_visible)$fatal(1,"invalid target retained caption");
 valid=1;colour=1;#1;if(dut.S_caption_visible)$fatal(1,"selector change retained stale caption");
 frame();frame();mode=2;frame();if(dut.S_caption_visible)$fatal(1,"caption leaked into motion mode");
 mode=5;frame();if(dut.S_caption_visible)$fatal(1,"caption leaked into label mode");
 valid=1;mode=3;colour=0;shape=1;l=600;r=740;t=300;b=500;frame();frame();
 fd=$fopen("v41_caption_preview.ppm","w");$fdisplay(fd,"P3\n240 120\n255");
 for(yy=240;yy<360;yy=yy+1)for(xx=560;xx<800;xx=xx+1)begin
  x=xx;y=yy;scene_rgb=(xx>=600 && xx<=740 && yy>=300 && yy<=500)?24'h2040e0:24'h808080;
  repeat(9)tick();$fdisplay(fd,"%0d %0d %0d",pixel[23:16],pixel[15:8],pixel[7:0]);
 end
 $fclose(fd);
 $display("PASS tb_v41_caption: %0d final mixer glyph pixels, RGB+CUSTOM times3shapes, both modes, clamping, frame-atomic motion, loss/selector/mode hiding",points);$finish;
end
initial begin #10000000;$fatal(1,"caption timeout");end
endmodule
