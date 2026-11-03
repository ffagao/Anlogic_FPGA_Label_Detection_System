`timescale 1ns/1ps
module tb_v25_histogram_continuous;
reg clk=0;always #5 clk=~clk;
reg rst=0,v=0,u=0,l=0;reg [95:0] rgb=0;
wire ov,ou,ol;wire [95:0] result;
histogram_equalizer4 #(.WORDS_PER_FRAME(16384)) dut(
 .I_clk(clk),.I_rst_n(rst),.I_enable(1'b1),.I_valid(v),.I_user(u),.I_last(l),.I_rgb(rgb),
 .O_valid(ov),.O_user(ou),.O_last(ol),.O_rgb(result),
 .O_bin_valid(),.O_bin_index(),.O_bin_count(),.O_hist_done());
reg ev=0,eu=0,el=0;reg [95:0] expected=0;
integer frame_no=0,checked=0;
always @(posedge clk) begin
 #1;
 if(rst) begin
  if(ov!==ev || ou!==eu || ol!==el) $fatal(1,"continuous markers");
  if(ov && result!==expected) $fatal(1,"shadow-table overwrite or mid-frame change frame=%0d got=%h expected=%h",frame_no,result,expected);
  if(ov) checked=checked+1;
 end
 ev=v;eu=u&&v;el=l&&v;
 expected=frame_no==3 ? {12{8'd4}} : rgb;
end
task frame(input integer n);
 integer i,y;
 begin
 @(negedge clk);frame_no=n;
 for(i=0;i<16384;i=i+1) begin
  v=1;u=i==0;l=i%320==319;
  y=n==1 ? 64+32*(i/4096) : n==3 ? 16 : 200;
  rgb={12{y[7:0]}};
  @(negedge clk);
 end
 v=0;u=0;l=0;
 repeat(500) @(negedge clk);
 end
endtask
initial begin
 repeat(5) @(negedge clk);rst=1;repeat(520) @(negedge clk);
 frame(1);frame(2);frame(3);frame(4);
 $display("PASS short blanking: each LUT committed atomically without overwriting pending table, pixels words=%0d",checked);
 $display("PASS tb_v25_histogram_continuous");$finish;
end
initial begin #2000000;$fatal(1,"continuous histogram timeout");end
endmodule
