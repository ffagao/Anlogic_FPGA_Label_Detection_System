`timescale 1ns/1ps
module tb_v25_histogram;
reg clk=0; always #5 clk=~clk;
reg rst=0,en=1,v=0,u=0,l=0;
reg [95:0] rgb=0;
wire ov,ou,ol; wire [95:0] out;
histogram_equalizer4 #(.WORDS_PER_FRAME(256)) dut(
 .I_clk(clk),.I_rst_n(rst),.I_enable(en),.I_valid(v),.I_user(u),.I_last(l),.I_rgb(rgb),
 .O_valid(ov),.O_user(ou),.O_last(ol),.O_rgb(out),
 .O_bin_valid(),.O_bin_index(),.O_bin_count(),.O_hist_done());
integer kind=0,checks=0,j,k;
reg ev=0,eu=0,el=0; reg [95:0] ergb=0; integer ek=0;
function integer mapped(input integer y);
 integer q;
 begin
 q=y<96 ? 0 : y<128 ? 85 : y<160 ? 170 : 255;
 mapped=(3*q+y)/4;
 end
endfunction
function [23:0] reference_pixel(input [23:0] p);
 integer y,d,r,g,b;
 begin
 y=(p[23:16]+2*p[15:8]+p[7:0])/4; d=mapped(y)-y;
 r=p[23:16]+d;g=p[15:8]+d;b=p[7:0]+d;
 if(r<0) r=0; if(r>255) r=255;
 if(g<0) g=0; if(g>255) g=255;
 if(b<0) b=0; if(b>255) b=255;
 reference_pixel={r[7:0],g[7:0],b[7:0]};
 end
endfunction
always @(posedge clk) begin
 #1;
 if(rst) begin
   if(ov!==ev || ou!==eu || ol!==el) $fatal(1,"valid/SOF/EOL alignment");
   if(ov && ek!=2 && out!==ergb) $fatal(1,"histogram RGB got=%h expected=%h kind=%0d",out,ergb,ek);
   if(ov) checks=checks+1;
 end
 ev=v;eu=u&&v;el=l&&v;ek=kind;
 ergb=kind==1 ? {reference_pixel(rgb[95:72]),reference_pixel(rgb[71:48]),reference_pixel(rgb[47:24]),reference_pixel(rgb[23:0])} : rgb;
end
task frame(input integer pattern,input integer check_kind);
 integer i,y;
 begin
 kind=check_kind;
 for(i=0;i<256;i=i+1) begin
  @(negedge clk); v=1;u=i==0;l=(i%16)==15;
  y=64+(i/64)*32;
  if(pattern==0) rgb={12{y[7:0]}};
  else if(pattern==1) rgb={24'h5a646e,24'hff0000,24'h00ff00,24'h0000ff};
  else rgb={12{8'd200}};
  if(i%7==3) begin @(negedge clk);v=0;u=1;l=1;rgb=96'h123456789abcdef012345678; end
 end
 @(negedge clk);v=0;u=0;l=0;
 repeat(12000) @(negedge clk);
 if(!dut.lut_pending || dut.state!=1) $fatal(1,"LUT builder did not finish in blanking");
 end
endtask
initial begin
 repeat(5) @(negedge clk);rst=1;
 repeat(520) @(negedge clk);
 frame(0,0);
 for(k=0;k<256;k=k+1) begin
  if(dut.map0[{!dut.active_bank,k[7:0]}]!==mapped(k)) $fatal(1,"CDF LUT bin=%0d got=%d expected=%d",k,dut.map0[{!dut.active_bank,k[7:0]}],mapped(k));
 end
 frame(0,1);
 frame(1,1);
 frame(2,2);
 frame(2,0);
 @(negedge clk);en=0;
 repeat(5) @(negedge clk);
 if(dut.active_valid) $fatal(1,"stale mapping after disable");
 $display("PASS histogram CDF-min reference for all 256 LUT entries");
 $display("PASS four-lane RGB offset/clipping, flat-scene bypass, bubbles, SOF/EOL and atomic LUT swap checks=%0d",checks);
 $display("PASS tb_v25_histogram");$finish;
end
initial begin #2000000;$fatal(1,"histogram timeout");end
endmodule
