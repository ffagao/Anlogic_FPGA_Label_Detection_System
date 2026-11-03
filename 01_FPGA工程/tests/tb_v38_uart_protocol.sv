`timescale 1ns/1ps
module tb_v38_uart_protocol;
reg clk=0;always #5 clk=~clk;reg rst=0,rx=1;reg[3:0] sw=0;wire[3:0] mode;wire[11:0] action;wire toggle;
uart_switch_control #(1600,100,4,64) dut(clk,rst,rx,sw,mode,action,toggle);
integer events=0,m,n,before_events;reg last_toggle=0;reg[3:0] saved_mode;
always @(posedge clk)begin #1;if(rst&&toggle!=last_toggle)events=events+1;last_toggle=toggle;end
task tick;begin @(negedge clk);end endtask
task send(input[7:0] b);integer k;begin rx=0;repeat(16)tick();for(k=0;k<8;k=k+1)begin rx=b[k];repeat(16)tick();end rx=1;repeat(20)tick();end endtask
task frame(input[7:0] op,lo,hi,crc);begin send(8'ha5);send(op);send(lo);send(hi);send(crc);repeat(5)tick();end endtask
task packet(input[7:0] op,lo,hi);begin frame(op,lo,hi,8'ha5^op^lo^hi);end endtask
task unchanged;begin if(mode!==saved_mode || events!=before_events)$fatal(1,"invalid packet acted mode%h events%0d expected%h/%0d",mode,events,saved_mode,before_events);end endtask
initial begin
 repeat(5)tick();rst=1;repeat(10)tick();
 for(m=0;m<16;m=m+1)begin send(m);if(mode!==(m<6?m:0))$fatal(1,"legacy mode %h",m);end
 packet(1,3,0);if(mode!=3)$fatal(1,"framed mode");
 before_events=events;send(8'ha5);send(4);send(8'h31);send(0);if(events!=before_events)$fatal(1,"partial packet not atomic");send(8'h90);if(action!==12'h8c1 || events!=before_events+1)$fatal(1,"GOTO payload");
 packet(2,8,0);before_events=events;packet(2,8,0);if(events!=before_events)$fatal(1,"held key repeated");packet(2,0,0);packet(2,8,0);if(events!=before_events+1)$fatal(1,"key release/repress");
 for(m=1;m<=8;m=m<<1)begin before_events=events;packet(3,m,0);if(events!=before_events+1 || action[3:0]!=m || action[11:10]!=1)$fatal(1,"click key %0d",m);end
 packet(1,5,0);packet(3,8,1);if(action!==12'h568)$fatal(1,"long K4 action");
 saved_mode=mode;before_events=events;
 frame(4,8'h31,0,8'h91);unchanged;
 packet(4,8'h31,1);unchanged;packet(4,8'h32,0);unchanged;packet(4,8'h11,0);unchanged;packet(4,8'h60,0);unchanged;
 packet(3,8'h80,0);unchanged;packet(3,1,1);unchanged;
 for(m=16;m<32;m=m+1)begin packet(m,8'h03,8'hff);unchanged;end
 for(m=0;m<=5;m=m+1)begin packet(4,m,0);if(mode!=0 || action[3:0]!=m)$fatal(1,"algorithm GOTO");end
 for(m=0;m<2;m=m+1)begin packet(4,8'h30+m,0);if(mode!=3 || action[3:0]!=m)$fatal(1,"track GOTO");end
 for(m=0;m<5;m=m+1)begin packet(4,8'h40+m,0);if(mode!=4 || action[3:0]!=m)$fatal(1,"home GOTO");end
 for(m=0;m<6;m=m+1)begin packet(4,8'h50+m,0);if(mode!=5 || action[3:0]!=m)$fatal(1,"label GOTO");end
 send(8'ha5);send(4);repeat(80)tick();send(2);if(mode!=2)$fatal(1,"partial frame timeout recovery");
 // An invalid checksum equal to A5 is also accepted as the next header.
 frame(4,8'h31,0,8'ha5);send(1);send(3);send(0);send(8'ha7);if(mode!=3)$fatal(1,"A5 resynchronization");
 sw=1;repeat(20)tick();if(mode!=1)$fatal(1,"physical takeover");packet(4,8'h31,0);repeat(20)tick();if(mode!=3)$fatal(1,"stable DIP overwrote UART");
 $display("PASS tb_v38_uart_protocol: legacy/framed modes,atomic XOR packets,all key masks,hold/release,longK4,valid GOTO table,reserved commands ignored,timeouts,resync and physical takeover");$finish;
end
initial begin #10000000;$fatal(1,"UART protocol timeout");end
endmodule
