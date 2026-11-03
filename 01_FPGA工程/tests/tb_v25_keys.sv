`timescale 1ns/1ps
module tb_v25_keys;
reg clk=0;always #5 clk=~clk;
reg rst=0;reg [3:0] mode=0,servo=1;
reg k1=0,k2=0,k3=0,k4=0;
wire [3:0] algorithm;wire [2:0] colour;wire [1:0] shape;
reg [3:0] raw_buttons=4'b1111;wire [1:0] ae_buttons;
v25_ae_key_route ae_route(mode,raw_buttons,ae_buttons);
v25_key_control_fixture dut(clk,rst,mode,servo,k1,k2,k3,k4,algorithm,colour,shape);
task press(input integer key);
 begin
 @(negedge clk);k1=key==1;k2=key==2;k3=key==3;k4=key==4;
 @(negedge clk);k1=0;k2=0;k3=0;k4=0;
 end
endtask
integer i;
initial begin
 repeat(5) @(negedge clk);rst=1;
 for(i=1;i<=9;i=i+1) begin press(4);if(algorithm!==i%9) $fatal(1,"0000 nine-algorithm cycle"); end
 press(3);if(algorithm!=8) $fatal(1,"histogram reverse wrap");
 mode=6;repeat(2) @(negedge clk);if(algorithm!=0) $fatal(1,"60FPS histogram clamp");
 for(i=1;i<=6;i=i+1) begin press(4);if(algorithm!==i%6) $fatal(1,"60FPS six-algorithm cycle"); end
 mode=1;
 for(i=1;i<=6;i=i+1) begin press(1);if(colour!==i%6) $fatal(1,"six-colour cycle");end
 for(i=0;i<3;i=i+1) begin press(2);if(shape!==(i+1)%3+1) $fatal(1,"three-shape cycle");end
 mode=4;servo=3;press(1);press(2);
 if(colour!=0 || shape!=1) $fatal(1,"running tracking changed selection");
 servo=1;press(1);press(2);if(colour!=1 || shape!=2) $fatal(1,"paused selection");
 servo=6;press(1);press(2);if(colour!=2 || shape!=3) $fatal(1,"lost selection");
 raw_buttons=4'b1110;mode=0;#1;if(ae_buttons!=2'b10) $fatal(1,"K1 AE routing");
 mode=1;#1;if(ae_buttons!=2'b11) $fatal(1,"K1 selects colour and also changes AE target");
 raw_buttons=4'b1101;#1;if(ae_buttons!=2'b11) $fatal(1,"K2 selects shape and also changes AE target");
 mode=4;#1;if(ae_buttons!=2'b11) $fatal(1,"tracking AE keys not masked");
 mode=6;#1;if(ae_buttons!=2'b01) $fatal(1,"60FPS K2 AE routing");
 $display("PASS real top-level controls: 9/6 algorithms, 6 colours, 3 shapes, tracking selection lock");
 $display("PASS tb_v25_keys");$finish;
end
endmodule
