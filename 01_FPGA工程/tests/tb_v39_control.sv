`timescale 1ns/1ps
module tb_v39_control;
reg sys=0,pll=0,hdmi=0,cam=0;always #10 sys=~sys;always #5 pll=~pll;always #6.667 hdmi=~hdmi;always #20.833 cam=~cam;
reg rst=0,rx=1;reg[3:0] sw=0;
v38_remote_fixture dut(sys,pll,hdmi,cam,rst,rst,rx,sw,4'd0);
defparam dut.u_uart_switch_control.CLOCK_HZ=1600;
defparam dut.u_uart_switch_control.BAUD=100;
defparam dut.u_uart_switch_control.DEBOUNCE_CYCLES=4;
defparam dut.u_uart_switch_control.FRAME_TIMEOUT_CYCLES=64;
defparam dut.u_servo_pan_tracker.CLK_MHZ=1;
task tick;begin @(negedge sys);end endtask
task byte_send(input[7:0] b);integer k;begin rx=0;repeat(16)tick();for(k=0;k<8;k=k+1)begin rx=b[k];repeat(16)tick();end rx=1;repeat(20)tick();end endtask
task packet(input[7:0] op,lo,hi);begin byte_send(8'ha5);byte_send(op);byte_send(lo);byte_send(hi);byte_send(8'ha5^op^lo^hi);repeat(40)tick();end endtask
integer c,s;reg[2:0] saved;
initial begin
 repeat(5)tick();rst=1;repeat(30)tick();
 for(c=0;c<3;c=c+1)for(s=1;s<4;s=s+1)begin
  packet(8'h10,1,c*4+s);
  if(dut.S_switch_hdmi_sync!=1 || dut.S_track_color!=c || dut.S_track_shape!=s)$fatal(1,"absolute RGB/shape scene");
 end
 for(c=0;c<4;c=c+1)for(s=1;s<4;s=s+1)begin
  packet(8'h10,8'h13,c*4+s);
  if(dut.S_switch_hdmi_sync!=3 || dut.S_track_color!=(c==3?5:c) || dut.S_track_shape!=s || !dut.u_servo_pan_tracker.S_armed)$fatal(1,"atomic scene run lost to colour-change guard c%0d s%0d",c,s);
  packet(8'h10,3,c*4+s);if(dut.u_servo_pan_tracker.S_armed)$fatal(1,"absolute scene pause");
 end
 packet(8'h10,1,1);packet(8'h10,1,13);if(dut.S_track_color!=0 || dut.S_switch_hdmi_sync!=1)$fatal(1,"CUSTOM accepted in RGB mode");
 packet(8'h10,8'h11,1);if(dut.S_switch_hdmi_sync!=1)$fatal(1,"run accepted in RGB mode");
 packet(8'h10,3,0);if(dut.S_switch_hdmi_sync!=1)$fatal(1,"invalid shape acted");
 packet(1,0,0);packet(8'h12,8'h38,0);
 if(dut.S_switch_hdmi_sync!=3 || !dut.u_servo_pan_tracker.S_armed || dut.u_servo_pan_tracker.S_mode_stable!=3)$fatal(1,"context K4 did not enter/start immediately");
 saved=dut.S_track_color;packet(8'h12,8'h31,0);if(dut.S_track_color!=saved)$fatal(1,"physical active-selection protection bypassed");
 packet(8'h12,8'h34,0);if(dut.u_servo_pan_tracker.S_armed)$fatal(1,"context pause");
 packet(1,2,0);packet(8'h12,8'h31,0);if(dut.S_switch_hdmi_sync!=3 || dut.S_track_color==saved)$fatal(1,"context colour key after external mode change");
 packet(8'h12,8'h48,0);if(dut.S_switch_hdmi_sync!=4 || !dut.u_servo_pan_tracker.S_home_active)$fatal(1,"context home");
 packet(8'h12,8'h44,0);if(dut.u_servo_pan_tracker.S_returning)$fatal(1,"context home pause");
 packet(8'h12,8'h41,0);if(dut.learn_status!=1)$fatal(1,"context learning prepare");
 packet(8'h12,8'h42,0);if(dut.learn_status!=2)$fatal(1,"context learning sample");
 packet(8'h12,8'h21,0);if(dut.S_switch_hdmi_sync!=2 || dut.ae.target_luma!=88)$fatal(1,"context AE down");
 packet(8'h12,8'h02,0);if(dut.S_switch_hdmi_sync!=0 || dut.ae.target_luma!=96)$fatal(1,"context AE up");
 packet(8'h12,8'h08,0);if(dut.S_algo_mode!=1)$fatal(1,"context next algorithm");
 packet(8'h12,8'h04,0);if(dut.S_algo_mode!=0)$fatal(1,"context previous algorithm");
 packet(8'h12,8'h58,0);if(dut.S_switch_hdmi_sync!=5 || !dut.lab.bg_ready || dut.lab.bg_busy || dut.lab.bg_failed)$fatal(1,"context label background bypass");
 @(negedge hdmi);dut.lab.controller.total=123;packet(8'h12,8'h58,1);if(dut.lab.controller.total!=0)$fatal(1,"context label long clear");
 packet(8'h12,8'h68,0);if(dut.S_switch_hdmi_sync!=5)$fatal(1,"invalid context mode acted");
 packet(8'h12,8'h38,1);if(dut.S_switch_hdmi_sync!=5)$fatal(1,"invalid context long acted");
 $display("PASS tb_v39_control: all RGB/shape scenes, CUSTOM tracking, atomic arm after colour commit, immediate mode-bound keys, physical guards, learning/AE/algorithms/label and invalid fields");$finish;
end
initial begin #30000000;$fatal(1,"v39 control timeout");end
endmodule
