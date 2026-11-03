`timescale 1ns/1ps
module tb_v26_histogram_commit;
reg clk=0;always #5 clk=~clk;
reg rst=0,en=1,v=0,u=0,bv=0,done=0;
reg [7:0] bi=0;reg [17:0] bc=0;
wire ov,ou,ol;wire [95:0] rgb;
live_histogram_overlay4 dut(.I_clk(clk),.I_rst_n(rst),.I_enable(en),
 .I_valid(v),.I_user(u),.I_last(1'b0),.I_rgb(96'h804020804020804020804020),
 .I_bin_valid(bv),.I_bin_index(bi),.I_bin_count(bc),.I_hist_done(done),
 .O_valid(ov),.O_user(ou),.O_last(ol),.O_rgb(rgb));
integer expected[0:63];integer i,j,peak,sum,q;reg bank;
task snapshot(input integer zero);
 begin
 for(j=0;j<256;j=j+1) begin
  @(negedge clk);bv=1;bi=j;bc=zero ? 0 : (j*17+5)%101;
 end
 @(negedge clk);bv=0;done=1;
 @(negedge clk);done=0;
 end
endtask
task sof;
 begin
 @(negedge clk);v=1;u=1;
 @(negedge clk);v=0;u=0;
 repeat(3) @(negedge clk);
 end
endtask
initial begin
 peak=0;
 for(i=0;i<64;i=i+1) begin
  sum=0;for(q=0;q<4;q=q+1) sum=sum+((4*i+q)*17+5)%101;
  expected[i]=sum;if(sum>peak) peak=sum;
 end
 for(i=0;i<64;i=i+1) expected[i]=expected[i]*96/peak;
 repeat(5) @(negedge clk);rst=1;
 snapshot(0);
 // Starting a video frame during normalization must retain the old display.
 sof();if(dut.active_valid) $fatal(1,"partial table became visible");
 repeat(1900) @(negedge clk);
 if(!dut.pending || dut.active_valid) $fatal(1,"pending/active isolation");
 bank=!dut.active_bank;
 for(i=0;i<64;i=i+1)
  if(dut.heights[{bank,i[5:0]}]!==expected[i]) $fatal(1,"64-bin reference mismatch bin=%0d",i);
 // A completed shadow table must survive further offered statistics.
 snapshot(1);repeat(1900) @(negedge clk);
 for(i=0;i<64;i=i+1)
  if(dut.heights[{bank,i[5:0]}]!==expected[i]) $fatal(1,"pending snapshot overwritten");
 sof();if(!dut.active_valid || dut.active_bank!==bank || dut.pending) $fatal(1,"frame commit");
 snapshot(1);repeat(1900) @(negedge clk);
 if(!dut.pending || dut.active_bank!==bank) $fatal(1,"mid-frame bank changed");
 for(i=0;i<64;i=i+1) begin
  if(dut.heights[{!bank,i[5:0]}]!==0) $fatal(1,"zero-count divide protection");
  if(dut.heights[{bank,i[5:0]}]!==expected[i]) $fatal(1,"active table overwritten");
 end
 sof();if(dut.active_bank===bank || dut.pending) $fatal(1,"second frame commit");
 @(negedge clk);en=0;repeat(3) @(negedge clk);en=1;
 repeat(3) @(negedge clk);
 if(dut.active_valid || dut.pending) $fatal(1,"reenable stale display");
 $display("PASS all 64 independent normalized references, busy-frame isolation, pending protection, zero-count guard and reenable");
 $display("PASS tb_v26_histogram_commit");$finish;
end
initial begin #200000;$fatal(1,"commit timeout");end
endmodule
