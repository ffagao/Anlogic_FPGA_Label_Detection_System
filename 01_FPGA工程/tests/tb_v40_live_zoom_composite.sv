`timescale 1ns/1ps
module tb_v40_live_zoom_composite;
tb_v40_live_zoom_pixels bus();
wire [23:0] rgb;wire vs,hs,de;
reg learn_mode=0,learn_start=0;
hdmi_mixer mix(.I_clk(bus.pixel),.I_rst_n(bus.rst),
 .I_video_vsync(~bus.vs),.I_video_hsync(1'b1),.I_video_de(bus.de),
 .I_video_user(bus.de && bus.xx==0 && bus.yy==0),.I_video_last(bus.de && bus.xx==1279),
 .I_debug_status(4'd0),.I_switch_state(learn_mode?4'd4:4'd5),.I_algo_mode(4'd0),
 .I_track_enable(1'b0),.I_track_color(3'd5),.I_track_shape(2'd1),
 .I_learn_prepare(1'b0),.I_learn_start(learn_start),.I_label_enable(!learn_mode),
 .I_label_keys_n(4'hf),.I_label_remote_action(3'd0),.I_label_imaging_locked(1'b1),
 .I_label_zoom_supported(1'b0),.I_label_zoom_active(bus.view),
 .I_label_zoom_src_x(bus.vx),.I_label_zoom_src_y(bus.vy),
 .I_servo_state(4'd0),.I_pan_pulse_us(12'd1500),.I_tilt_pulse_us(12'd1300),
 .I_motion_enable(1'b0),.I_black_enable(1'b0),.I_black_valid(1'b0),
 .I_black_left(12'd0),.I_black_right(12'd0),.I_black_top(12'd0),.I_black_bottom(12'd0),
 .I_black_update_toggle(1'b0),.I_zoom_active(1'b0),
 .I_capture_frame_bcd(bus.frame_id),.I_camera_fps_bcd(8'h30),.I_display_frame_bcd(bus.display_id),
 .I_delay_frames_bcd(8'h02),.I_ae_debug(72'd0),.I_ae_debug_toggle(1'b0),
 .I_diag_in_line(10'd0),.I_diag_spatial_line(10'd0),.I_diag_pack_line(9'd0),
 .I_diag_fifo_level(9'd0),.I_diag_burst_count(9'd0),.I_diag_in_frame(18'd0),
 .I_diag_spatial_frame(18'd0),.I_diag_pack_frame(18'd0),.I_diag_ddr_frame(18'd0),
 .I_diag_burst_active(1'b0),.I_diag_line_error(3'd0),.I_diag_frame_error(3'd0),
 .I_video_rd_data(bus.rgb),.O_hdmi_vsync(vs),.O_hdmi_hsync(hs),.O_hdmi_de(de),.O_hdmi_data(rgb));
integer ox=0,oy=0,normal_x=-1,normal_y=-1,points=0,minx=2000,maxx=0,miny=2000,maxy=0,red_points=0,green_points=0,panel_points=0,live_proof=0;reg [23:0] live_pixel_first,live_pixel_next;
always @(posedge bus.pixel)begin
 #2;
 if(!vs)begin ox=0;oy=0;end
 else if(de)begin
  if(ox==1100 && oy==600 && bus.f==1)live_pixel_first=rgb;
  if(ox==1100 && oy==600 && bus.f==2)begin
   live_pixel_next=rgb;
   if(live_pixel_first===live_pixel_next)$fatal(1,"zoomed RGB did not update on the new live bank");
   live_proof=live_proof+1;
  end
  if((bus.f==2 || bus.f==3) && ox==816 && oy==360 && rgb!==24'hff4040)
   $fatal(1,"actual reference outline moved while video was live");
  if((bus.f==2 || bus.f==3) && ox==896 && oy==280 && rgb!==24'h00ff40)
   $fatal(1,"theoretical reference outline moved while video was live");
  if(bus.f==1 && ox==511 && oy==500)begin
   if(rgb!==24'h101c29)$fatal(1,"fixed left panel was obscured: %h",rgb);panel_points=panel_points+1;
  end
  if(bus.f==1 && ox==512 && oy==500 && rgb!==24'hffffff)$fatal(1,"512-pixel ROI boundary moved");
  if(bus.f==1 && ox==816 && oy==360)begin
   if(rgb!==24'hff4040)$fatal(1,"actual rotated label edge not red: %h",rgb);red_points=red_points+1;
  end
  if(bus.f==1 && ox==896 && oy==280)begin
   if(rgb!==24'h00ff40)$fatal(1,"theoretical rotated label edge not green: %h",rgb);green_points=green_points+1;
  end
  if(rgb==24'hffffff && ox>860 && ox<940 && oy>340 && oy<380)begin
   if(bus.f==0)begin normal_x=ox;normal_y=oy;end
   if(bus.f==1)begin
    points=points+1;if(ox<minx)minx=ox;if(ox>maxx)maxx=ox;
    if(oy<miny)miny=oy;if(oy>maxy)maxy=oy;
   end
  end
  if(ox==1279)begin ox=0;oy=oy+1;end else ox=ox+1;
 end
end
initial begin
 bus.test_finish_enable=0;
 force bus.origin_y=12'sd180;force bus.origin_x=12'd721;
 force mix.u_label_application.state=0;force mix.u_label_application.result=2;
 force mix.u_label_application.fail=4;force mix.u_label_application.size_fail=0;
 force mix.u_label_application.locked=1;force mix.u_label_application.geometry=0;
 force mix.u_label_application.scene=1;force mix.u_label_application.reference_set=1;
 force mix.u_label_application.box_x=913;force mix.u_label_application.box_y=360;
 force mix.u_label_application.box_w=400;force mix.u_label_application.box_h=300;
 force mix.u_label_application.box_a=0;force mix.u_label_application.label_x=913;
 force mix.u_label_application.label_y=360;force mix.u_label_application.label_w=80;
 force mix.u_label_application.label_h=40;force mix.u_label_application.label_a=0;
 force mix.u_label_application.tx=913;force mix.u_label_application.ty=360;
 force mix.u_label_application.ta=180;force mix.u_label_application.rhw=40;
 force mix.u_label_application.rhh=20;force mix.u_label_application.rp=0;
 force mix.u_label_application.rq=0;force mix.u_label_application.da=180;
 wait(bus.view===1);
 if(normal_x!=913 || normal_y!=360)$fatal(1,"normal display coordinate origin changed %d,%d",normal_x,normal_y);
 force mix.u_label_application.geometry=1;
 wait(bus.f==2);#1;
 if(points!=4 || minx!=896 || maxx!=897 || miny!=360 || maxy!=361)
  $fatal(1,"image/geometry centre mismatch: pixels%0d bounds[%0d,%0d]-[%0d,%0d], expected[896,360]-[897,361]",points,minx,miny,maxx,maxy);
 if(red_points!=1 || green_points!=1 || panel_points!=1)$fatal(1,"outline/panel coverage incomplete");
 wait(bus.f==4);release bus.origin_y;release bus.origin_x;
 wait(bus.test_done);#1;
 if(live_proof!=1)$fatal(1,"live frame-update proof incomplete");
 $display("PASS tb_v40_live_zoom_composite: changing live DDR/FIFO/mixer RGB with fixed red/green geometry, right-centre pixel alignment, unchanged 512px left panel, and normal view restored");
 bus.test_finish_enable=1;
end
endmodule
