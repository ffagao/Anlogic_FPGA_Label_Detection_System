`timescale 1ns/1ps
module tb_v36_reentry;
reg clk=0;always #10 clk=~clk;
reg rst=0,rx=1;reg[3:0] sw=0;wire[3:0] mode;
uart_switch_control dut(clk,rst,rx,sw,mode);
integer bad,m,checks=0;
task verify(input integer expect_mode);begin
 repeat(8)@(negedge clk);
 if(mode!==expect_mode)$fatal(1,"mode mismatch got=%h expected=%h raw=%h stable=%h UART=%h",mode,expect_mode,sw,dut.sw_stable,dut.state);
 checks=checks+1;
end endtask
task send(input[7:0] b);integer n;begin
 rx=0;repeat(434)@(negedge clk);
 for(n=0;n<8;n=n+1)begin rx=b[n];repeat(434)@(negedge clk);end
 rx=1;repeat(468)@(negedge clk);
end endtask
task physical(input[3:0] v);begin sw=v;repeat(250020)@(negedge clk);end endtask
initial begin
 repeat(5)@(negedge clk);rst=1;repeat(10)@(negedge clk);
 for(bad=6;bad<16;bad=bad+1)for(m=1;m<6;m=m+1)begin send(bad);verify(0);send(m);verify(m);end
 $display("PASS UART: all 6..F invalid codes -> all 1..5 valid modes at 50MHz/115200");
 for(bad=6;bad<16;bad=bad+1)for(m=1;m<6;m=m+1)begin physical(bad);verify(0);physical(m);verify(m);end
 $display("PASS physical: all 6..F invalid codes -> all 1..5 valid modes at real 250000-cycle debounce");
 for(bad=6;bad<16;bad=bad+1)begin physical(bad);verify(0);send(5);verify(5);physical(1);verify(1);send(bad);verify(0);physical(2);verify(2);end
 $display("PASS mixed ownership invalid/valid reentry; %0d checkpoints",checks);$finish;
end
initial begin #1000000000;$fatal(1,"timeout");end
endmodule
