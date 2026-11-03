`timescale 1ns/1ps
// Full raster + short blanking exceeds the throughput required by 60FPS.
module tb_v34_histogram60;
reg clk=0;always #8.333 clk=~clk;
reg rst=0,v=0,u=0,last=0;reg [95:0] rgb=0;
wire [127:0] packed_data;wire packed_user,packed_valid;
v34_histogram_pipeline_fixture dut(clk,rst,rgb,v,u,last,packed_data,packed_user,packed_valid);
byte reference_bytes[$];byte expected_byte;
integer i,j,x,y,f,level,words=0,frames=0,jobs=0,histogram_bins_count=0;
always @(posedge clk) begin
 if(rst)begin
  if(dut.histogram_chart_valid)
   for(j=0;j<12;j=j+1)reference_bytes.push_back(dut.histogram_chart_rgb[95-j*8-:8]);
  if(dut.histogram_done)jobs=jobs+1;
  if(dut.histogram_bin_valid)histogram_bins_count=histogram_bins_count+1;
  #1;
  if(packed_user)frames=frames+1;
  if(packed_valid)begin
   if(reference_bytes.size()<16)$fatal(1,"histogram packer reads beyond source bytes");
   for(i=0;i<16;i=i+1)begin
    expected_byte=reference_bytes.pop_front();
    if(packed_data[127-i*8-:8]!==expected_byte)$fatal(1,"histogram/plot byte order word%d byte%d",words,i);
   end
   words=words+1;
  end
 end
end
task tick;begin @(negedge clk);end endtask
initial begin
 repeat(5)tick();rst=1;repeat(600)tick();
 for(f=0;f<3;f=f+1)begin
  for(y=0;y<720;y=y+1)begin
   for(x=0;x<320;x=x+1)begin
    v=1;u=(x==0 && y==0);last=(x==319);
    level=32+((x+f*53)%192);rgb={12{level[7:0]}};tick();
   end
   v=0;u=0;last=0;repeat(8)tick();
  end
  repeat(1024)tick();
 end
 repeat(10000)tick();
 if(words!=518400 || frames!=3 || reference_bytes.size()!=0 || jobs<2 || histogram_bins_count<512)
  $fatal(1,"60FPS stress coverage words%d frames%d bytes%d jobs%d histogram_bins_count%d",words,frames,reference_bytes.size(),jobs,histogram_bins_count);
 $display("PASS tb_v34_histogram60: 3 full 1280x720 frames, 518400 DDR words, chart+equalizer byte order and ongoing LUT updates at >60FPS throughput");$finish;
end
initial begin #50000000;$fatal(1,"histogram throughput timeout");end
endmodule
