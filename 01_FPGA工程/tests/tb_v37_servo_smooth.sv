`timescale 1ns/1ps
module tb_v37_servo_smooth;
reg clk=0;always #5 clk=~clk;reg rst=0,stop=0,start=0,update=0,valid=1;
reg [3:0] mode=3;reg signed [12:0] dx=0,dy=0;
wire [11:0] pan,tilt;wire [3:0] state;
servo_pan_tracker #(.CLK_MHZ(1)) dut(clk,rst,mode,1'b0,3'd0,2'd1,stop,start,update,valid,dx,dy,,,state,pan,tilt,,1'b0,3'd0);
task tick;begin @(negedge clk);end endtask
task boundary;begin wait(dut.S_frame_us==19999);tick();tick();end endtask
task measure(input integer xx,yy);begin dx=xx;dy=yy;update=1;tick();update=0;tick();end endtask
integer i;reg [11:0] p,t;
initial begin
 repeat(5)tick();rst=1;repeat(3)boundary();start=1;tick();start=0;tick();
 measure(12,-12);if(state!=4 || dut.S_adjusting || dut.S_adjusting_tilt)$fatal(1,"12px stop");
 measure(19,-19);if(state!=8 || dut.S_adjusting || dut.S_adjusting_tilt)$fatal(1,"19px hysteresis hold");
 p=pan;t=tilt;measure(20,-20);if(!dut.S_adjusting || !dut.S_adjusting_tilt || dut.S_command_pan!=-1 || dut.S_command_tilt!=-1)$fatal(1,"20px restart, one us");
 boundary();p=pan;t=tilt;measure(13,-13);measure(13,-13);if(dut.S_command_pan!=-1 || dut.S_command_tilt!=-1)$fatal(1,"13px zero-step trap");
 boundary();measure(12,-12);p=pan;t=tilt;boundary();if(pan!=p || tilt!=t)$fatal(1,"deadzone drift");
 for(i=0;i<30;i=i+1)begin
  p=pan;t=tilt;measure(200,-200);boundary();
  if(pan>=p || pan<p-8 || tilt>=t || tilt<t-8)$fatal(1,"bounded large-error rate");
 end
 p=pan;t=tilt;measure(95,95);measure(95,95);if(dut.S_command_pan>=0 || dut.S_command_tilt<=0)$fatal(1,"95px fine step");
 measure(96,96);if(dut.S_command_pan>=0 || dut.S_command_tilt<=0)$fatal(1,"96px large step");
 stop=1;tick();stop=0;tick();p=pan;t=tilt;boundary();if(pan!=p||tilt!=t)$fatal(1,"pause moved");
 start=1;tick();start=0;tick();measure(-200,200);p=pan;t=tilt;boundary();if(pan!=p+1||tilt!=t+1)$fatal(1,"reverse direction");
 valid=0;repeat(110000)tick();p=pan;t=tilt;boundary();if(pan!=p||tilt!=t)$fatal(1,"stale target moved");
 if(dut.F_slew(1500,1600,5)!=1505 || dut.F_slew(1500,1400,5)!=1495)$fatal(1,"homing speed changed");
 $display("PASS tb_v37_servo_smooth: both-axis adaptive rates,12/20px hysteresis, nonzero near-centre correction, reversal braking/pause/stale safety and homing5us retained");$finish;
end
initial begin #20000000;$fatal(1,"servo timeout");end
endmodule
