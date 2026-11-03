`timescale 1ns/1ps
module tb_v39_uart_back_to_back;
reg clk=0;always #10 clk=~clk;
reg rst=0,rx=1;wire[3:0] mode;wire[11:0] action;wire toggle;
uart_switch_control #(.CLOCK_HZ(50000000),.BAUD(115200),.DEBOUNCE_CYCLES(4)) dut(clk,rst,rx,4'd0,mode,action,toggle);
integer events=0;reg previous=0;
always @(posedge clk)begin #1;if(rst && toggle!=previous)events=events+1;previous=toggle;end
task clocks(input integer n);begin repeat(n)@(negedge clk);end endtask
task send_byte(input[7:0] b,input good_stop);integer k;begin
 rx=0;clocks(434);for(k=0;k<8;k=k+1)begin rx=b[k];clocks(434);end
 rx=good_stop;clocks(434);
end endtask
task packet(input[7:0] op,lo,hi);begin
 send_byte(8'ha5,1);send_byte(op,1);send_byte(lo,1);send_byte(hi,1);send_byte(8'ha5^op^lo^hi,1);
end endtask
initial begin
 clocks(5);rst=1;clocks(20);
 packet(8'h10,8'h13,8'h06);
 if(mode!=3 || action!=12'h0e6 || events!=1)$fatal(1,"real-baud contiguous scene frame");
 // CRC=A5 is data, followed immediately by another A5 packet header.
 packet(8'h12,8'h12,0);
 if(mode!=1 || action!=12'hc42 || events!=2)$fatal(1,"contiguous CRC A5 confused header");
 packet(4,5,0);
 if(mode!=0 || action!=12'h805 || events!=3)$fatal(1,"back-to-back GOTO");
 send_byte(8'ha5,1);send_byte(8'h10,1);send_byte(8'h13,0);
 rx=1;clocks(434);
 if(mode!=0 || events!=3)$fatal(1,"framing error committed partial scene");
 packet(8'h12,8'h21,0);
 if(mode!=2 || action!=12'hc81 || events!=4)$fatal(1,"recovery after bad stop");
 send_byte(8'h0f,1);clocks(10);
 if(mode!=0 || events!=4)$fatal(1,"legacy mode compatibility after continuous stream");
 $display("PASS tb_v39_uart_back_to_back: 50MHz/115200 real divider,exact 8N1 no inter-byte gap,CRC A5,framing-error atomicity/recovery and legacy mode");$finish;
end
initial begin #10000000;$fatal(1,"continuous UART timeout");end
endmodule
