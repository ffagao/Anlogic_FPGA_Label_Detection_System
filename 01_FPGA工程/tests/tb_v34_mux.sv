`timescale 1ns/1ps
module tb_v34_mux;
reg clk=0;always #5 clk=~clk;reg rst=0;reg [3:0] mode=0;reg [4:0] starts=0;
wire [127:0] data;wire valid,user,last;
v34_mux_fixture dut(clk,rst,mode,starts,data,valid,user,last);
task tick;begin @(negedge clk);end endtask
integer m,prev;
initial begin
 repeat(4)tick();rst=1;tick();prev=0;
 for(m=1;m<6;m=m+1)begin
  mode=m;repeat(4)tick();if(data!==(prev==5?1:prev) || user)$fatal(1,"mode switched before frame boundary");
  starts=m==5?2:(1<<m);#1;if(data!==(m==5?1:m) || !user)$fatal(1,"target first pixel not selected mode%d data%d",m,data);
  tick();starts=0;repeat(2)tick();if(data!==(m==5?1:m))$fatal(1,"active stream not retained");prev=m;
 end
 mode=0;repeat(4)tick();if(data!==1)$fatal(1,"normal premature");starts=1;#1;if(data!==0||!user)$fatal(1,"normal first pixel");tick();starts=0;
 mode=5;force dut.edge_frame_red=0;starts=2;#1;if(data!==0||user)$fatal(1,"wrong edge frame accepted");tick();starts=0;release dut.edge_frame_red;tick();
 starts=2;#1;if(data!==1||!user)$fatal(1,"matching red edge frame rejected");tick();starts=0;
 $display("PASS tb_v34_mux: every retained algorithm switches atomically at its own frame start");$finish;
end
endmodule
