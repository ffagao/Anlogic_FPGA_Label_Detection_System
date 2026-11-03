`timescale 1ns/1ps
module tb_v38_servo_dynamics;
reg clk=0;always #5 clk=~clk;reg rst=0,start=0,stop=0,update=0,valid=1,remote=0;reg[2:0] sub=0;reg[3:0] mode=3;reg signed[12:0] dx=500,dy=-500;
wire[11:0] p,t,oldp,oldt,v38p,v38t;wire[3:0] state;
servo_pan_tracker #(.CLK_MHZ(1)) dut(clk,rst,mode,1'b0,3'd0,2'd1,stop,start,update,valid,dx,dy,,,state,p,t,,remote,sub);
servo_pan_tracker_v37_baseline #(.CLK_MHZ(1)) old(clk,rst,mode,1'b0,3'd0,2'd1,stop,start,update,valid,dx,dy,,,,oldp,oldt,);
servo_pan_tracker_v38_baseline #(.CLK_MHZ(1)) baseline38(clk,rst,mode,1'b0,3'd0,2'd1,stop,start,update,valid,dx,dy,,,,v38p,v38t,,remote,sub);
task tick;begin @(negedge clk);end endtask
task boundary;begin wait(dut.S_frame_us==19999);tick();tick();end endtask
task measure(input integer xx,yy);begin dx=xx;dy=yy;update=1;tick();update=0;tick();end endtask
integer i,new_distance,old_distance;reg[11:0] a,b;
initial begin
 repeat(5)tick();rst=1;repeat(3)boundary();start=1;tick();start=0;tick();
 for(i=0;i<400000;i=i+1)begin update=i%33333==0;tick();end update=0;
 new_distance=1500-p;old_distance=1500-oldp;
 if(new_distance<120 || new_distance>170 || new_distance<4*old_distance)$fatal(1,"far target response new%0d old%0d",new_distance,old_distance);
 if(5*new_distance<4*(1500-v38p))$fatal(1,"far response lost more than 20 percent");
 $display("400ms far response: v39=%0dus v38=%0dus v37=%0dus",new_distance,1500-v38p,old_distance);
 force dut.I_measure_large=1'b1;repeat(2)tick();if(dut.S_speed_pan!=3 || dut.S_speed_tilt!=3)$fatal(1,"large target speed cap");
 release dut.I_measure_large;repeat(2)tick();
 a=p;b=t;measure(180,-180);boundary();if(p!=a||t!=b)$fatal(1,"approach damping");
 a=p;b=t;measure(180,-180);boundary();if(p!=a-1||t!=b-1)$fatal(1,"acceleration bound/recovery");
 a=p;b=t;measure(40,-40);measure(40,-40);boundary();if(p!=a-1||t!=b-1)$fatal(1,"near-target fine rate");
 a=p;b=t;boundary();if(p!=a||t!=b)$fatal(1,"near motion reused stale measurement");
 measure(8,-8);a=p;b=t;boundary();if(p!=a||t!=b)$fatal(1,"deadzone drift");
 for(i=0;i<10;i=i+1)begin measure(i%7-3,3-i%7);boundary();end
 if(p!=a||t!=b)$fatal(1,"noise caused centre hunting");
 measure(19,-19);boundary();if(p!=a||t!=b)$fatal(1,"hysteresis hold");measure(20,-20);boundary();
 a=p;b=t;measure(-100,100);boundary();if(p!=a||t!=b)$fatal(1,"reversal coasted");boundary();if(p!=a+1||t!=b+1)$fatal(1,"reverse ramp");
 valid=0;a=p;b=t;repeat(110000)tick();boundary();if(p!=a||t!=b)$fatal(1,"stale measurement moved");
 mode=0;repeat(20)tick();mode=3;sub=1;remote=1;tick();remote=0;tick();if(!dut.S_armed||dut.S_mode_stable!=3||state!=2)$fatal(1,"direct run delayed");
 valid=1;measure(500,-500);@(negedge clk);dut.S_pan_pulse_us=500;dut.S_tilt_pulse_us=500;boundary();if(p!=500||t!=500||state!=7)$fatal(1,"lower bounds");
 measure(-500,500);@(negedge clk);dut.S_pan_pulse_us=1900;dut.S_tilt_pulse_us=1850;boundary();if(p!=1900||t!=1850||state!=7)$fatal(1,"upper bounds");
 mode=4;sub=1;remote=1;tick();remote=0;tick();a=p;b=t;boundary();if(p!=a-5||t!=b-5)$fatal(1,"home speed changed");
 $display("PASS tb_v38_servo_dynamics:30Hz measurement/50Hz control,fast bounded motion,acceleration,damping,1us approach,noise hold,reversal braking,stale safety,direct state and hard limits");$finish;
end
initial begin #40000000;$fatal(1,"servo dynamics timeout");end
endmodule
