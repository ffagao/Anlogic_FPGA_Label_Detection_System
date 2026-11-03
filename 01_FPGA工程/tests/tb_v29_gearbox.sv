`timescale 1ns/1ps
module tb_v29_gearbox;
reg clk=0;always #5 clk=~clk;
reg rst=0,v=0,u=0,last=0;reg [95:0] rgb=0;
wire ov,ou,ol;wire [127:0] data;
rgb96_to_128_v29 dut(.I_clk(clk),.I_rst_n(rst),.I_frame_start(u),.I_valid(v),.I_last(last),.I_data(rgb),.O_frame_start(ou),.O_valid(ov),.O_last(ol),.O_data(data));
reg [7:0] expected[0:8191];integer wrote=0,read=0,k,n,f,beats=0,lasts=0,starts=0;
always @(posedge clk) begin
 if(rst && v) begin
  for(k=0;k<12;k=k+1) expected[wrote+k]=rgb[95-k*8-:8];
  wrote=wrote+12;
 end
 #1;
 if(rst && ov) begin
  for(k=0;k<16;k=k+1) if(data[127-k*8-:8]!==expected[read+k])
   $fatal(1,"byte stream mismatch byte=%0d got=%h expected=%h",read+k,data[127-k*8-:8],expected[read+k]);
  if(ou!==(beats%48==0)) $fatal(1,"SOF misaligned beat=%0d",beats);
  if(ol) lasts=lasts+1;
  if(ou) starts=starts+1;
  read=read+16;beats=beats+1;
 end
 if(rst && ou && !ov) $fatal(1,"SOF without valid data");
end
initial begin
 repeat(5) @(negedge clk);rst=1;
 for(f=0;f<3;f=f+1) begin
  for(n=0;n<64;n=n+1) begin
   v=1;u=(n==0);last=(n%16==15);
   for(k=0;k<12;k=k+1) rgb[95-k*8-:8]=(f*67+n*12+k)%251;
   @(negedge clk);
   if(f<2 && n%13==4) begin v=0;u=0;last=0;repeat(1+n%3) @(negedge clk);end
  end
  v=0;u=0;last=0;repeat(5) @(negedge clk);
 end
 repeat(5) @(negedge clk);
 if(wrote!=read || wrote!=2304 || beats!=144 || starts!=3 || lasts!=12)
  $fatal(1,"counts bytes in=%0d out=%0d beats=%0d SOF=%0d EOL=%0d",wrote,read,beats,starts,lasts);
 $display("PASS shared Gaussian/ink byte gearbox: bubbles, 3 frames, SOF/EOL alignment, bytes=%0d",read);
 $display("PASS tb_v29_gearbox");$finish;
end
initial begin #100000;$fatal(1,"gearbox timeout");end
endmodule
