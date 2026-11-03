`timescale 1ns/1ps
module tb_v32_control;
reg sys=0,pll100=0,pixel=0,camera=0;
always #5 pll100=~pll100;
always #10 sys=~sys;
always #6.667 pixel=~pixel;
always #21 camera=~camera;
reg rst=0,rx=1;
reg [3:0] switches=0;
wire [3:0] effective,hdmi;
wire [7:0] segments,digits;
wire tracking,motion,blue,fps60;
wire [1:0] ae_buttons;
v32_control_fixture dut(.I_sys_clk(sys),.S_100m_clk(pll100),.S_hdmi_pixel_clk(pixel),.S_24m_clk(camera),
 .S_rst_n(rst),.S_hdmi_rst_n(rst),.I_uart_rx(rx),.I_switch(switches),.I_button(4'b1010),
 .O_effective_switch(effective),.O_switch_hdmi(hdmi),.O_segment_n(segments),.O_digit_n(digits),
 .O_track(tracking),.O_motion(motion),.O_black(blue),.O_fps60(fps60),.O_ae_buttons(ae_buttons));
task send_byte(input [7:0] value,input integer bit_ns,input reg stop_ok);
 integer k;
 begin
  rx=0;#(bit_ns);
  for(k=0;k<8;k=k+1) begin rx=value[k];#(bit_ns);end
  rx=stop_ok;#(bit_ns);rx=1;
 end
endtask
task check_mode(input [3:0] wanted);
 begin
  #1000;
  if(effective!==wanted || hdmi!==wanted) $fatal(1,"mode mismatch effective=%h HDMI=%h expected=%h",effective,hdmi,wanted);
  if(fps60!==(wanted>=6) || blue!==(wanted==2) || motion!==(wanted==3) || tracking!==((wanted==1)||(wanted==4)||(wanted==5)))
   $fatal(1,"actual top-level mode routing mismatch mode=%h fps=%b blue=%b motion=%b track=%b",wanted,fps60,blue,motion,tracking);
  if(ae_buttons!==((wanted==1 || wanted==4) ? 2'b11 : 2'b10)) $fatal(1,"AE button routing mismatch");
 end
endtask
integer n;
initial begin
 repeat(10) @(negedge sys);rst=1;
 switches=5;#5500000;check_mode(5);
 for(n=0;n<16;n=n+1) begin
  send_byte(n,8680,1);check_mode(n);
 end
 // Includes 0A/0D as real mode commands, not ignored whitespace.
 send_byte(8'h0a,8500,1);check_mode(10);
 send_byte(8'h0d,8860,1);check_mode(13);
 send_byte(8'h02,8680,1);check_mode(2);
 send_byte(8'h10,8680,1);check_mode(2);
 send_byte(8'hff,8680,1);check_mode(2);
 send_byte(8'h32,8680,1);check_mode(2); // ASCII '2' is not the binary command.
 send_byte(8'h06,8680,1);send_byte(8'h01,8680,1);send_byte(8'h02,8680,1);check_mode(2);
 // False start, invalid stop and a held-low break must not create commands.
 rx=0;#1500;rx=1;#10000;check_mode(2);
 send_byte(8'h09,8680,0);#15000;check_mode(2);
 rx=0;#300000;rx=1;#10000;check_mode(2);
 send_byte(8'h04,8680,1);check_mode(4);
 #6000000;check_mode(4); // unchanged physical switches do not override PC mode.
 // Debounce a noisy local change, then let physical switches reclaim control.
 switches=3;#100000;switches=5;#100000;switches=3;#100000;switches=5;
 check_mode(4);
 switches=3;#5500000;check_mode(3);
 send_byte(8'h0f,8680,1);check_mode(15);
 rst=0;#200;rst=1;#5500000;check_mode(3);
 $display("PASS UART 115200 8N1: all 16 binary modes, +/-2%% baud, 0A/0D, invalid bytes/stop/break, source decode, HDMI CDC, AE routing, hold, debounce and local handover");
 $display("PASS tb_v32_control");$finish;
end
initial begin #60000000;$fatal(1,"control timeout");end
endmodule
