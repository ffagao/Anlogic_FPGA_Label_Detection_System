`timescale 1ns/1ps
module tb_v20_osd_preview;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,user=0;reg [3:0] mode=0;
reg [71:0] debug_data={4'h2,12'h064,12'h096,16'h3000,12'h016,8'h01,8'h01};reg debug_toggle=0;
wire [23:0] pixel;
hdmi_mixer dut(.I_label_enable(1'b0),.I_label_keys_n(4'hf),.I_label_imaging_locked(1'b0),.O_label_imaging_lock(),.O_label_buzzer_n(),.I_clk(clk),.I_rst_n(rst_n),
 .I_video_vsync(1'b0),.I_video_hsync(1'b0),.I_video_de(1'b0),
 .I_video_user(user),.I_video_last(1'b0),.I_debug_status(4'd0),
 .I_switch_state(mode),.I_algo_mode(4'd0),.I_track_enable(1'b0),
 .I_track_color(3'd0),.I_track_shape(2'd1),.I_learn_prepare(1'b0),.I_learn_start(1'b0),.I_servo_state(4'd0),.I_pan_pulse_us(12'd1500),
 .I_tilt_pulse_us(12'd1300),.I_motion_enable(1'b0),.I_black_enable(1'b0),
 .I_black_valid(1'b0),.I_black_left(12'd0),.I_black_right(12'd0),
 .I_black_top(12'd0),.I_black_bottom(12'd0),.I_black_update_toggle(1'b0),
 .I_zoom_active(1'b0),.I_capture_frame_bcd(24'h123456),
 .I_display_frame_bcd(24'h123454),.I_camera_fps_bcd(8'h30),
 .I_delay_frames_bcd(8'h02),.I_ae_debug(debug_data),.I_ae_debug_toggle(debug_toggle),
 .I_video_rd_data(24'h123456),.O_measure_update(),.O_measure_valid(),.O_measure_dx(),.O_measure_dy(),.O_video_rd_en(),.O_zoom_request(),.O_hdmi_vsync(),.O_hdmi_hsync(),.O_hdmi_de(),.O_hdmi_data(pixel));
integer x=0,y=0,on_count=0,i,fp; reg [14:0] logo_addr=0;
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
initial begin
 repeat(10) @(negedge clk);rst_n=1;
 @(negedge clk);debug_toggle=1;repeat(10) @(negedge clk);
 force dut.S_x_2d=x;force dut.S_x_1d=x;force dut.S_y_2d=y;force dut.S_y_1d=y;force dut.S_video_de_2d=1;force dut.S_video_de_1d=1;
 mode=0;frame_start();
 force dut.S_logo_addr=logo_addr;
 fp=$fopen("v20_osd_preview.ppm","w");
 $fwrite(fp,"P3\n320 500\n255\n");
 for(y=0;y<500;y=y+1)
  for(x=0;x<320;x=x+1) begin
   logo_addr=y*160+x;#1;
   if(dut.S_osd_hit) $fwrite(fp,"%0d %0d %0d\n",dut.S_osd_color[23:16],dut.S_osd_color[15:8],dut.S_osd_color[7:0]);
   else $fwrite(fp,"20 24 30\n");
  end
 $fclose(fp);
 $display("OSD preview rendered using HDL font/logo/pixel logic");$finish;
end
initial begin #2000000;$fatal(1,"timeout");end
endmodule
