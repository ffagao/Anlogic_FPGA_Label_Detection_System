`timescale 1ns/1ps
module tb_v37_rededge_stream;
reg clk=0;always #5 clk=~clk;reg rst=0,v=0,user=0,last=0;reg[3:0] mode=1;reg[95:0] rgb=0;
wire[127:0] data;wire valid,sof;
v37_edge_pipeline_fixture dut(clk,rst,mode,rgb,v,user,last,data,valid,sof);
wire[95:0] ref_edge;wire rv,ru;
edge_detect_96_reference refdet(clk,rst,last,user,rgb,v,1'b1,,ru,ref_edge,rv,);
reg[95:0] source_q;reg red_q=0;reg[95:0] expected;
byte unsigned bytes_q[$];byte unsigned value;
integer p,k,b,words=0,frames=0,red_pixels=0,background_pixels=0;
always @(posedge clk)begin
 source_q<=rgb;if(v&&user)red_q<=mode==5;
 #1;
 if(!rst)begin bytes_q.delete();end
 else begin
  if(rv)begin
   for(p=0;p<4;p=p+1)begin
    expected[95-p*24-:24]=red_q ? ((|ref_edge[95-p*24-:24]) ? 24'hff0000:source_q[95-p*24-:24]):ref_edge[95-p*24-:24];
    if(red_q && (|ref_edge[95-p*24-:24]))red_pixels=red_pixels+1;
    if(red_q && !(|ref_edge[95-p*24-:24]))background_pixels=background_pixels+1;
   end
   for(b=0;b<12;b=b+1)bytes_q.push_back(expected[95-b*8-:8]);
  end
  if(sof)frames=frames+1;
  if(valid)begin
   if(bytes_q.size()<16)$fatal(1,"edge pack underrun");
   for(k=0;k<16;k=k+1)begin value=bytes_q.pop_front();if(data[127-k*8-:8]!==value)$fatal(1,"red/white packed pixel mismatch word%0d byte%0d got%h expected%h",words,k,data[127-k*8-:8],value);end
   words=words+1;
  end
 end
end
integer f,y,x;reg[23:0] a0,a1,a2,a3;
task tick;begin @(negedge clk);end endtask
function[23:0] colour(input integer xx,yy,ff);begin
 colour=((xx/32+yy/24+ff)&1) ? {8'h20,8'hc0,8'h40}:{8'he0,8'h20,8'h20};
end endfunction
initial begin
 repeat(5)tick();rst=1;repeat(3)tick();
 for(f=0;f<6;f=f+1)begin
  mode=f[0]?5:1;
  for(y=0;y<720;y=y+1)begin
   for(x=0;x<1280;x=x+4)begin
    v=1;user=(x==0&&y==0);last=(x==1276);
    rgb={colour(x,y,f),colour(x+1,y,f),colour(x+2,y,f),colour(x+3,y,f)};
    tick();
    if(x==640&&y==180)mode=mode==5?1:5;
   end
   v=0;user=0;last=0;repeat(2)tick();
  end
  repeat(10)tick();
 end
 v=0;user=0;last=0;repeat(12)tick();
 if(words!=1036800 || frames!=6 || bytes_q.size()!=0 || red_pixels==0 || background_pixels==0)$fatal(1,"edge stream coverage words%0d frames%0d queue%0d red%0d bg%0d",words,frames,bytes_q.size(),red_pixels,background_pixels);
 $display("PASS tb_v37_rededge_stream:6 full frames at >60FPS input throughput,shared detector/packer,RGB byte order,white EDGE,red overlay,original nonedge pixels and midframe selection held");$finish;
end
initial begin #25000000;$fatal(1,"red edge timeout");end
endmodule
