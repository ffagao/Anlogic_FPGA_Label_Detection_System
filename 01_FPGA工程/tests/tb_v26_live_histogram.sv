`timescale 1ns/1ps
module tb_v26_live_histogram;
reg clk=0;always #5 clk=~clk;
reg rst=0,en=1,v=0,u=0,l=0;
reg [95:0] rgb=0;
wire ev,eu,el,bv,done;wire [95:0] eqrgb;
wire [7:0] bi;wire [17:0] bc;
wire ov,ou,ol;wire [95:0] out;
histogram_equalizer4 #(.WORDS_PER_FRAME(12800)) eq(
 .I_clk(clk),.I_rst_n(rst),.I_enable(en),.I_valid(v),.I_user(u),.I_last(l),.I_rgb(rgb),
 .O_valid(ev),.O_user(eu),.O_last(el),.O_rgb(eqrgb),
 .O_bin_valid(bv),.O_bin_index(bi),.O_bin_count(bc),.O_hist_done(done));
live_histogram_overlay4 #(.IMAGE_WIDTH(320),.PLOT_X(32),.PLOT_TOP(40),.PLOT_BOTTOM(136)) dut(
 .I_clk(clk),.I_rst_n(rst),.I_enable(en),.I_valid(ev),.I_user(eu),.I_last(el),.I_rgb(eqrgb),
 .I_bin_valid(bv),.I_bin_index(bi),.I_bin_count(bc),.I_hist_done(done),
 .O_valid(ov),.O_user(ou),.O_last(ol),.O_rgb(out));
integer f=0,checks=0,stats=0,x=0,y=0,sx,sy,i,k,h;
integer fd;reg [23:0] p,expected;
reg pv=0,pu=0,pl=0,pen=0;reg [95:0] prgb=0;
reg [10:0] px=0,py=0;
reg iv,iu,il;reg [95:0] irgb;
always @(posedge clk) begin
 iv=ev;iu=eu;il=el;irgb=eqrgb;
 if(rst) begin
  if(ev) begin
   if(eu) begin x=0;y=0;end
   sx=x;sy=y;
   if(x==316) begin x=0;y=y+1;end else x=x+4;
  end
  if(bv) stats=stats+1;
 end
 #1;
 if(rst) begin
  if(ov!==pv || ou!==pu || ol!==pl) $fatal(1,"overlay stream markers");
  if(ov) begin
   for(k=0;k<4;k=k+1) begin
    p=out[95-k*24-:24];expected=prgb[95-k*24-:24];
    if(pen && px+k>=20 && px+k<300 && py>=8 && py<160) begin
     expected={2'b0,expected[23:18],2'b0,expected[15:10],2'b0,expected[7:2]};
     if(px+k>=32 && px+k<288 && py>=40 && py<136) begin
      h=0;
      if(f==2) begin
       if((px+k-32)/4==16) h=96;
       if((px+k-32)/4==48) h=32;
      end
      if(f==3 && (px+k-32)/4==32) h=96;
      if(f==4 && (px+k-32)/4==0) h=96;
      if(h!=0 && py>=136-h) expected=24'h00e8ff;
      else if(py==40 || py==64 || py==88 || py==112) expected=24'h384048;
     end
     // Labels and axes are checked below; exclude them from pixel comparison.
     else if((py>=16 && py<30) || py>=136 || px+k==31) expected=p;
    end
    if(p!==expected) $fatal(1,"pixel frame=%0d x=%0d y=%0d got=%h expected=%h",f,px+k,py,p,expected);
    if(pen && px+k==32 && py==16 && p!==24'hffffff) $fatal(1,"INPUT Y label missing");
    if(pen && px+k==31 && py==80 && p!==24'hc0c0c0) $fatal(1,"axis missing");
    if(f==2) $fwrite(fd,"%0d %0d %0d\n",p[23:16],p[15:8],p[7:0]);
    checks=checks+1;
   end
  end
  pv=iv;pu=iu&&iv;pl=il&&iv;pen=en;prgb=irgb;px=sx;py=sy;
 end
end
task frame(input integer number,input integer pattern);
 integer n,q;
 begin
 f=number;
 for(n=0;n<12800;n=n+1) begin
  @(negedge clk);v=1;u=n==0;l=n%80==79;
  q=pattern==0 ? ((n/4)%4==3 ? 192 : 64) : pattern==1 ? 128 : 0;
  rgb={12{q[7:0]}};
  if(n%137==41) begin @(negedge clk);v=0;u=1;l=1;end
 end
 @(negedge clk);v=0;u=0;l=0;
 repeat(12000) @(negedge clk);
 if(en && !dut.pending) $fatal(1,"height builder failed frame=%0d",f);
 end
endtask
initial begin
 fd=$fopen("v26_histogram_preview.ppm","w");$fwrite(fd,"P3\n320 160\n255\n");
 repeat(5) @(negedge clk);rst=1;repeat(520) @(negedge clk);
 frame(1,0);
 for(i=0;i<64;i=i+1) begin
  h=i==16 ? 96 : i==48 ? 32 : 0;
  if(dut.heights[{!dut.active_bank,i[5:0]}]!==h) $fatal(1,"group/normalization bin=%0d",i);
 end
 frame(2,1);frame(3,2);frame(4,2);
 @(negedge clk);en=0;
 repeat(10) @(negedge clk);
 if(dut.active_valid || dut.pending) $fatal(1,"stale histogram after disable");
 frame(5,1);
 if(stats!=1024) $fatal(1,"equalizer histogram export count %0d",stats);
 $fclose(fd);
 $display("PASS reused 256 bins, 64 grouped heights, 3:1 normalization, flat black, frame commits, bubbles, labels, axes, four lanes and disabled bypass pixels=%0d",checks);
 $display("PASS tb_v26_live_histogram");$finish;
end
initial begin #3000000;$fatal(1,"overlay timeout");end
endmodule
