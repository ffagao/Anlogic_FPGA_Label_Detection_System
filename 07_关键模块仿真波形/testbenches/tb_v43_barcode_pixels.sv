`timescale 1ns/1ps
module tb_v43_barcode_pixels;
 reg clk=0,rst=0,de=0;reg [11:0] x=0,y=0;reg [23:0] rgb=24'hffffff;
 wire hit,candidate;wire [79:0] payload;wire [11:0] left,right,row;wire [15:0] skipped;
 integer xx,yy,k,pos,w;reg is_black;reg [8*37-1:0] runs="2112322213122122222221221132222331112";reg saw=0;
 always #5 clk=~clk;
 barcode_row_reader #(.WIDTH(1280),.HEIGHT(720),.ROI_L(512)) dut(.clk(clk),.rst_n(rst),.enable(1'b1),.capture_enable(1'b1),.de(de),.fresh_frame(de && x==0 && y==0),.x(x),.y(y),.rgb(rgb),.hit(hit),.candidate(candidate),.payload(payload),.left(left),.right(right),.row(row),.skipped_lines(skipped));
 always @(posedge clk) if(hit) begin if(payload[23:0]!==24'h100001)$fatal(1,"wrong payload %h",payload[23:0]);saw<=1;end
 initial begin
  repeat(4)@(negedge clk);rst=1;
  for(yy=0;yy<50;yy=yy+1)begin
   for(xx=0;xx<1280;xx=xx+1)begin
    @(negedge clk);x=xx;y=yy;de=1;is_black=0;pos=552;
    for(k=0;k<37;k=k+1)begin w=(runs[8*(36-k)+:8]-8'h30)*4;if(xx>=pos && xx<pos+w && k%2==0)is_black=1;pos=pos+w;end
    rgb=is_black?24'h000000:24'hffffff;
   end
   @(negedge clk);de=0;repeat(8)@(negedge clk);
  end
  repeat(100)@(negedge clk);if(!saw)$fatal(1,"no pixel decode");
  $display("PASS pixel-stream Code128C order 100001");$finish;
 end
endmodule
