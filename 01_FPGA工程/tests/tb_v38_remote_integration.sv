`timescale 1ns/1ps
module tb_v38_remote_integration;
reg sys=0,pll=0,hdmi=0,cam=0;always #10 sys=~sys;always #5 pll=~pll;always #6.667 hdmi=~hdmi;always #20.833 cam=~cam;
reg rst=0,rx=1;reg[3:0] sw=0;
v38_remote_fixture dut(sys,pll,hdmi,cam,rst,rst,rx,sw,4'd0);
defparam dut.u_uart_switch_control.CLOCK_HZ=1600;
defparam dut.u_uart_switch_control.BAUD=100;
defparam dut.u_uart_switch_control.DEBOUNCE_CYCLES=4;
defparam dut.u_uart_switch_control.FRAME_TIMEOUT_CYCLES=64;
defparam dut.u_servo_pan_tracker.CLK_MHZ=1;
task tick;begin @(negedge sys);end endtask
task byte_send(input[7:0] b);integer n;begin rx=0;repeat(16)tick();for(n=0;n<8;n=n+1)begin rx=b[n];repeat(16)tick();end rx=1;repeat(20)tick();end endtask
task packet(input[7:0] op,lo,hi);begin byte_send(8'ha5);byte_send(op);byte_send(lo);byte_send(hi);byte_send(8'ha5^op^lo^hi);repeat(30)tick();end endtask
task go(input[7:0] ms);begin packet(4,ms,0);if(dut.S_switch_hdmi_sync!==ms[7:4])$fatal(1,"GOTO mode mismatch %h",ms);end endtask
integer i;reg[2:0] saved;
initial begin
 repeat(5)tick();rst=1;repeat(30)tick();
 go(8'h05);if(dut.S_algo_mode!=5)$fatal(1,"direct algorithm5");
 packet(3,4,0);if(dut.S_algo_mode!=4)$fatal(1,"instant K3 algorithm");packet(3,8,0);if(dut.S_algo_mode!=5)$fatal(1,"instant K4 algorithm");
 packet(3,1,0);if(dut.ae.target_luma!=88)$fatal(1,"instant AE K1");packet(3,2,0);if(dut.ae.target_luma!=96)$fatal(1,"instant AE K2");
 packet(16'h10,8'hff,8'hff);if(dut.ae.target_luma!=96)$fatal(1,"reserved parameter acted");
 packet(1,1,0);packet(3,1,0);if(dut.S_track_color!=1)$fatal(1,"instant RGB K1");packet(3,2,0);if(dut.S_track_shape!=2)$fatal(1,"instant shape K2");
 packet(2,1,0);if(dut.S_track_color!=2)$fatal(1,"key down");packet(2,1,0);if(dut.S_track_color!=2)$fatal(1,"held key repeated");packet(2,0,0);packet(2,1,0);if(dut.S_track_color!=0)$fatal(1,"release and repress");
 packet(1,0,0);go(8'h31);if(!dut.u_servo_pan_tracker.S_armed || dut.S_servo_state!=2 || dut.u_servo_pan_tracker.S_mode_stable!=3)$fatal(1,"direct tracking run waited for buttons/PWM qualification");
 saved=dut.S_track_color;packet(3,1,0);if(dut.S_track_color!=saved)$fatal(1,"active tracking colour changed");
 packet(3,4,0);if(dut.u_servo_pan_tracker.S_armed)$fatal(1,"instant K3 pause");packet(3,8,0);if(!dut.u_servo_pan_tracker.S_armed)$fatal(1,"instant K4 run");packet(3,8,0);if(!dut.u_servo_pan_tracker.S_armed)$fatal(1,"second K4 changed run");
 go(8'h30);if(dut.u_servo_pan_tracker.S_armed)$fatal(1,"direct pause");
 go(8'h41);if(!dut.u_servo_pan_tracker.S_home_active)$fatal(1,"direct homing");packet(3,4,0);if(dut.u_servo_pan_tracker.S_returning)$fatal(1,"homing K3");packet(3,8,0);if(!dut.u_servo_pan_tracker.S_home_active)$fatal(1,"homing K4");
 go(8'h43);if(dut.learn_status!=1)$fatal(1,"direct learning prepare");go(8'h44);if(dut.learn_status!=2)$fatal(1,"direct learning sample");
 packet(3,1,0);if(dut.learn_status!=1)$fatal(1,"home K1 prepare");packet(3,2,0);if(dut.learn_status!=2)$fatal(1,"home K2 sample");
 go(8'h51);if(!dut.lab.bg_busy)$fatal(1,"direct background did not start");
 force dut.lab.bg_ready=1;force dut.lab.bg_busy=0;force dut.lab.bg_pending=0;
 packet(3,2,0);if(dut.lab.state!=2)$fatal(1,"instant label K2 learn");
 @(negedge hdmi);dut.lab.controller.state=0;packet(3,1,0);if(dut.lab.state!=1)$fatal(1,"instant label K1 check");
 // Re-enter idle between independent operations, without waiting for physical keys.
 go(0);go(8'h53);if(dut.lab.state!=1)$fatal(1,"direct label check");
 packet(3,4,0);if(!dut.lab.controller.muted)$fatal(1,"instant label K3 acknowledge");
 go(0);go(8'h50);@(negedge hdmi);dut.lab.controller.total=24'h000123;
 packet(3,8,1);if(dut.lab.controller.total!=0)$fatal(1,"instant label long K4 clear");
 release dut.lab.bg_ready;release dut.lab.bg_busy;release dut.lab.bg_pending;
 packet(3,8,0);if(!dut.lab.bg_busy)$fatal(1,"instant label short K4 background");
 go(0);packet(1,2,0);packet(3,1,0);if(dut.ae.target_luma!=88)$fatal(1,"motion-mode AE key");
 $display("PASS tb_v38_remote_integration: all modes immediate key events, AE/color/shape/algorithm, hold/release, direct tracking/home/learning/label actions and reserved parameters ignored");$finish;
end
initial begin #20000000;$fatal(1,"remote integration timeout");end
endmodule
