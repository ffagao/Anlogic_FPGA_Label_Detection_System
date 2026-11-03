`timescale 1ns/1ps
module tb_v21_gain_table;
reg clk=0; always #5 clk=~clk;
reg [6:0] index=0;
wire [15:0] value;
SC500GainTbl dut(.I_clk(clk),.I_rstn(1'b1),.I(index),.O(value));
task check(input [6:0] idx,input [15:0] expected);
begin
 @(negedge clk); index=idx; @(negedge clk);
 if(value!==expected) $fatal(1,"gain index %0d expected %h got %h",idx,expected,value);
end endtask
initial begin
 check(0,16'h0320); check(31,16'h033f);
 check(32,16'h0720); check(63,16'h073f);
 check(64,16'h0f20); check(73,16'h0f29);
 check(74,16'h0f2a); check(95,16'h0f3f);
 check(96,16'h1f20); check(127,16'h1f3f);
 $display("PASS SC500CS analog gain table spans 1.0x through 15.75x");
 $display("PASS tb_v21_gain_table"); $finish;
end
initial begin #10000; $fatal(1,"timeout"); end
endmodule
