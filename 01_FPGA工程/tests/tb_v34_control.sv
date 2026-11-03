`timescale 1ns/1ps
module tb_v34_control;
reg sys=0,pll=0,hdmi=0,cam=0;
always #5 sys=~sys;always #3.5 pll=~pll;always #6.667 hdmi=~hdmi;always #20.833 cam=~cam;
reg rst=0,rx=1;reg [3:0] sw=0;
wire [3:0] effective,video_mode;wire [7:0] seg,dig;wire track,motion,black,fps,blocked;
v34_control_fixture dut(sys,pll,hdmi,cam,rst,rst,rx,sw,effective,video_mode,seg,dig,track,motion,black,fps,blocked);
defparam dut.u_uart_switch_control.CLOCK_HZ=1600;
defparam dut.u_uart_switch_control.BAUD=100;
defparam dut.u_uart_switch_control.DEBOUNCE_CYCLES=4;
task tick;begin @(negedge sys);end endtask
task verify(input integer raw);
integer m;
begin
 repeat(30)tick();m=raw<6?raw:0;
 if(effective!==m || video_mode!==m || fps!==(m==0) || blocked!==((m==1)||(m==3)||(m==4)||(m==5)) ||
    track!==((m==1)||(m==3)||(m==4)) || motion!==(m==2) || black!==1'b0)
    $fatal(1,"mode routing raw%0h effective%0h video%0h fps%b blocked%b",raw,effective,video_mode,fps,blocked);
end endtask
task send(input [7:0] b);integer n;
begin
 rx=0;repeat(16)tick();
 for(n=0;n<8;n=n+1)begin rx=b[n];repeat(16)tick();end
 rx=1;repeat(20)tick();
end endtask
integer k;
initial begin
 repeat(5)tick();rst=1;
 for(k=1;k<16;k=k+1)begin sw=k;verify(k);end
 sw=1;verify(1);sw=0;verify(0);
 for(k=0;k<16;k=k+1)begin send(k);verify(k);end
 send(4);verify(4);send(8'hf4);verify(4);
 send(8'ha5);verify(4);send(6);verify(6);
 sw=2;verify(2);
 $display("PASS tb_v34_control: all physical/UART codes, invalid fallback, only 0000 at 60FPS, label key ownership and physical override");$finish;
end
initial begin #1000000;$fatal(1,"control timeout");end
endmodule
