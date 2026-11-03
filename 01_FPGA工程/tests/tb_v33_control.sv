`timescale 1ns/1ps
module tb_v33_control;
reg clk=0;always #5 clk=~clk;
reg rst=0;reg [3:0] mode=1,servo=1;
reg k1=0,k2=0,k3=0,k4=0,remote=0;reg [15:0] command=0;
wire [3:0] algo;wire [2:0] colour;wire [1:0] shape;
wire prepare,start,pause_track,start_track;
v33_keys_fixture dut(clk,rst,mode,servo,k1,k2,k3,k4,remote,command,algo,colour,shape,prepare,start,pause_track,start_track);
integer starts=0,prepares=0;
always @(posedge clk) begin if(start) starts=starts+1;if(prepare) prepares=prepares+1;end
task send(input [15:0] value);
 begin @(negedge clk);command=value;remote=1;@(negedge clk);remote=0;repeat(3)@(negedge clk);end
endtask
task key(input integer value);
 begin @(negedge clk);k1=value==1;k2=value==2;k3=value==3;k4=value==4;
 @(negedge clk);k1=0;k2=0;k3=0;k4=0;repeat(3)@(negedge clk);end
endtask
integer i;
initial begin
 repeat(4)@(negedge clk);rst=1;
 key(3);key(4);if(starts || prepares) $fatal(1,"preset K3/K4 changed behaviour");
 send(16'h0301);if(colour!=5 || starts!=1) $fatal(1,"UART teach must select CUSTOM before start");
 key(3);key(4);if(starts!=2 || prepares!=1) $fatal(1,"CUSTOM local teach keys");
 send(16'h0300);if(prepares!=2) $fatal(1,"UART prepare");
 send(16'h0203);if(shape!=3) $fatal(1,"UART shape");
 mode=4;servo=3;send(16'h0102);send(16'h0201);
 if(colour!=5 || shape!=3) $fatal(1,"UART changed running target selection");
 @(negedge clk);command=16'h0500;remote=1;#1;if(!pause_track || start_track) $fatal(1,"remote pause");
 @(negedge clk);command=16'h0501;#1;if(pause_track || !start_track) $fatal(1,"remote start");
 @(negedge clk);remote=0;servo=1;send(16'h0102);send(16'h0201);
 if(colour!=2 || shape!=1) $fatal(1,"UART paused selection");
 mode=0;send(16'h0301);if(starts!=2 || colour!=2) $fatal(1,"learning command in wrong mode");
 mode=1;for(i=0;i<6;i=i+1)key(1);if(colour!=2) $fatal(1,"six colour cycle");
 mode=0;key(4);if(algo!=1) $fatal(1,"algorithm key regression");
 $display("PASS tb_v33_control: actual extracted top-level local/remote selection, one-clock CUSTOM teach ordering, preserved preset keys, running selection lock, pause/start gating, mode guards");$finish;
end
initial begin #100000;$fatal(1,"control timeout");end
endmodule
