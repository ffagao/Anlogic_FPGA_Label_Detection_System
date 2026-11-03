`timescale 1ns/1ps
module edge_compare #(parameter W=1280,H=720,N=1000000)(output reg done=0);
reg clk=0;always #5 clk=~clk;reg rst=0,v=0,sof=0,eol=0,ready=0;reg [95:0] data=0;
wire dl,du,dv,dr,rl,ru,rv,rr;wire [95:0] dd,rd;
edge_detect_96 #(W,H) d(clk,rst,eol,sof,data,v,ready,dl,du,dd,dv,dr);
edge_detect_96_reference #(W,H) r(clk,rst,eol,sof,data,v,ready,rl,ru,rd,rv,rr);
integer i,n=0,seed=182+W;
always @(posedge clk)begin #1;if(rst && {dl,du,dd,dv,dr}!=={rl,ru,rd,rv,rr})$fatal(1,"edge differs W=%d cycle=%d",W,i);end
initial begin
 repeat(3)@(negedge clk);rst=1;
 for(i=0;i<N;i=i+1)begin
  @(negedge clk);v=($random(seed)&7)!=0;ready=$random(seed);data={$random(seed),$random(seed),$random(seed)};
  sof=(n==0);eol=(n%(W/4)==W/4-1);
  if(i%450001==450000)begin rst=0;v=0;n=0;end else if(!rst)rst=1;
  if(v)begin n=n+1;if(n==W/4*H)n=0;end
 end
 @(negedge clk);v=0;sof=0;eol=0;repeat(3)@(negedge clk);done=1;
end
endmodule
module tb_v34_edge_ram;
wire a,b;edge_compare full(a);edge_compare #(8,4,12000) short_frame(b);
initial begin wait(a&&b);$display("PASS tb_v34_edge_ram: full-width stream, gaps, resets, small-frame collisions, identical beat latency");$finish;end
endmodule
