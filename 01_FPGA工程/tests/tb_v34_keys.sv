`timescale 1ns/1ps
module tb_v34_keys;
reg clk=0;always #5 clk=~clk;reg rst=0;
reg [3:0] mode=0,state=1;reg k1=0,k2=0,k3=0,k4=0;
wire [3:0] algorithm;wire [2:0] colour;wire [1:0] shape;wire prepare,start;
v34_keys_fixture dut(clk,rst,mode,state,k1,k2,k3,k4,algorithm,colour,shape,prepare,start);
task tick;begin @(negedge clk);end endtask
task key(input integer k);begin {k4,k3,k2,k1}=1<<k;tick();{k4,k3,k2,k1}=0;tick();end endtask
integer i;
initial begin
 repeat(4)tick();rst=1;tick();
 for(i=1;i<=6;i=i+1)begin key(3);if(algorithm!==(i%6))$fatal(1,"60FPS algorithms");end
 key(2);if(algorithm!=5)$fatal(1,"algorithm reverse wrap");
 mode=6;repeat(2)tick();key(3);if(algorithm!=5)$fatal(1,"unnormalized invalid mode accepted algorithm key");
 mode=0;key(3);if(algorithm!=0)$fatal(1,"algorithm wrap");
 mode=1;for(i=1;i<=9;i=i+1)begin key(0);if(colour!==(i%3))$fatal(1,"RGB-only loop");end
 k3=1;tick();if(prepare)$fatal(1,"0001 learning still enabled");k3=0;tick();
 k4=1;tick();if(start)$fatal(1,"0001 learning still enabled");k4=0;tick();
 key(1);if(shape!=2)$fatal(1,"CIRCLE");key(1);if(shape!=3)$fatal(1,"TRIANGLE");key(1);if(shape!=1)$fatal(1,"RECT wrap");
 mode=4;repeat(2)tick();if(colour!=5)$fatal(1,"home did not select learning model");
 k1=1;tick();if(!prepare||start)$fatal(1,"home K1 prepare");k1=0;tick();
 k2=1;tick();if(!start||prepare)$fatal(1,"home K2 start");k2=0;tick();
 k1=1;k2=1;tick();if(!prepare||start)$fatal(1,"prepare priority");k1=0;k2=0;tick();
 mode=3;repeat(2)tick();if(colour!=5)$fatal(1,"learned colour not retained for tracking");
 key(0);if(colour!=0)$fatal(1,"tracking CUSTOM wrap");key(0);key(0);key(0);if(colour!=5)$fatal(1,"tracking CUSTOM inaccessible");
 state=2;key(0);if(colour!=5)$fatal(1,"active tracking colour changed");
 mode=1;repeat(2)tick();if(colour!=0)$fatal(1,"0001 retained CUSTOM");
 mode=5;key(0);key(1);key(2);key(3);
 if(colour!=0||shape!=1||algorithm!=0||prepare||start)$fatal(1,"label keys leaked");
 $display("PASS tb_v34_keys: 0000 algorithms, RGB-only 0001, home K1/K2 learning, tracking CUSTOM and label isolation");$finish;
end
endmodule
