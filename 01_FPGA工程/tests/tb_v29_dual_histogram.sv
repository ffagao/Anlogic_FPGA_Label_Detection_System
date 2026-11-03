`timescale 1ns/1ps
module tb_v27_dual_histogram;
reg clk=0;always #5 clk=~clk;
reg rst=0,en=1,v=0,u=0,l=0;reg [95:0] rgb=0;
wire ev,eu,el,bv,done;wire [95:0] eqrgb;
wire [7:0] bi;wire [17:0] bc,ac;
wire ov,ou,ol;wire [95:0] out;
histogram_equalizer4 #(.WORDS_PER_FRAME(25600)) eq(
 .I_clk(clk),.I_rst_n(rst),.I_enable(en),.I_valid(v),.I_user(u),.I_last(l),.I_rgb(rgb),
 .O_valid(ev),.O_user(eu),.O_last(el),.O_rgb(eqrgb),
 .O_bin_valid(bv),.O_bin_index(bi),.O_bin_count(bc),.O_hist_done(done),.O_after_count(ac));
live_histogram_overlay4 #(.IMAGE_WIDTH(640),.PLOT_X(32),.PLOT_TOP(40),.PLOT_BOTTOM(136)) dut(
 .I_clk(clk),.I_rst_n(rst),.I_enable(en),.I_valid(ev),.I_user(eu),.I_last(el),.I_rgb(eqrgb),
 .I_bin_valid(bv),.I_bin_index(bi),.I_bin_count(bc),.I_hist_done(done),.I_after_count(ac),
 .O_valid(ov),.O_user(ou),.O_last(ol),.O_rgb(out));
integer before_ref[0:3][0:63],after_ref[0:3][0:63];
integer inf=-1,outf=-1,iw=0,ow=0,lane,bin,jobs=0,group_sum=0,k,n,f,q,checks=0;
integer x=0,y=0,sx,sy,px=0,py=0,h,index,peak,i;
reg [23:0] p,expected;reg [95:0] prgb=0,irgb;reg pv=0,pu=0,pl=0,iv,iu,il,old_bank;
integer fd;
function integer luma(input [23:0] a);
 begin luma=(a[23:16]+2*a[15:8]+a[7:0])/4;end
endfunction
always @(posedge clk) begin
 if(rst) begin
  if(v) begin
   if(u) begin inf=inf+1;iw=0;end
   if(iw%4==0) begin lane=(iw/4)%4;bin=luma(rgb[95-lane*24-:24])/4;before_ref[inf][bin]=before_ref[inf][bin]+1;end
   iw=iw+1;
  end
  if(bv) begin
   group_sum=group_sum+bc;
   if(bi%4==3) begin
    if(group_sum!==before_ref[jobs][bi/4]) $fatal(1,"input count job=%0d bin=%0d got=%0d ref=%0d",jobs,bi/4,group_sum,before_ref[jobs][bi/4]);
    if(ac!==after_ref[jobs][bi/4]) $fatal(1,"actual clipped output count job=%0d bin=%0d got=%0d ref=%0d",jobs,bi/4,ac,after_ref[jobs][bi/4]);
    group_sum=0;
   end
   if(bi==255) jobs=jobs+1;
  end
 end
 iv=ev;iu=eu;il=el;irgb=eqrgb;
 if(ev) begin
  if(eu) begin outf=outf+1;ow=0;x=0;y=0;end
  if(ow%4==0) begin lane=(ow/4)%4;bin=luma(eqrgb[95-lane*24-:24])/4;after_ref[outf][bin]=after_ref[outf][bin]+1;end
  ow=ow+1;sx=x;sy=y;if(x==636) begin x=0;y=y+1;end else x=x+4;
 end
 #1;
 if(rst) begin
  if(ov!==pv || ou!==pu || ol!==pl) $fatal(1,"paired overlay markers");
  if(ov) begin
   for(k=0;k<4;k=k+1) begin
    p=out[95-k*24-:24];expected=prgb[95-k*24-:24];q=px+k;
    if((q>=20 && q<300 || q>=308 && q<588) && py>=8 && py<160) begin
     if((q>=32 && q<288 || q>=320 && q<576) && py>=40 && py<136) begin
      h=0;
      if(outf>0) begin
       peak=0;
       for(i=0;i<64;i=i+1) begin
        if(before_ref[outf-1][i]>peak) peak=before_ref[outf-1][i];
        if(after_ref[outf-1][i]>peak) peak=after_ref[outf-1][i];
       end
       index=(q-(q>=320 ? 320:32))/4;
       h=(q>=320 ? after_ref[outf-1][index]:before_ref[outf-1][index])*96/peak;
      end
      expected={2'b0,expected[23:18],2'b0,expected[15:10],2'b0,expected[7:2]};
      if(h>0 && py>=136-h) expected=q>=320 ? 24'hffb040:24'h00e8ff;
      else if(py==40 || py==64 || py==88 || py==112) expected=24'h384048;
     end
     else expected=p;
    end
    if(p!==expected) $fatal(1,"paired plot pixel frame=%0d x=%0d y=%0d got=%h expected=%h",outf,q,py,p,expected);
    if(outf==2) $fwrite(fd,"%0d %0d %0d\n",p[23:16],p[15:8],p[7:0]);
    checks=checks+1;
   end
  end
  pv=iv;pu=iu&&iv;pl=il&&iv;prgb=irgb;px=sx;py=sy;
 end
end
initial begin
 for(f=0;f<4;f=f+1) for(n=0;n<64;n=n+1) begin before_ref[f][n]=0;after_ref[f][n]=0;end
 fd=$fopen("v27_dual_histogram_preview.ppm","w");$fwrite(fd,"P3\n640 160\n255\n");
 repeat(5) @(negedge clk);rst=1;repeat(520) @(negedge clk);
 for(f=0;f<4;f=f+1) begin
  for(n=0;n<25600;n=n+1) begin
   @(negedge clk);v=1;u=n==0;l=n%160==159;
   q=(n/4)%4==3 ? 192:64;
   rgb=f==0 ? {12{q[7:0]}} : f==1 ? {24'hff0000,24'h00ff00,24'h0000ff,24'hffeedd} : f==2 ? 0 : {12{8'hff}};
   if(n%173==41) begin @(negedge clk);v=0;u=1;l=1;end
  end
  @(negedge clk);v=0;u=0;l=0;repeat(16000) @(negedge clk);
  if(!dut.pending) $fatal(1,"dual chart not ready");
 end
 if(jobs!=4 || checks!=409600) $fatal(1,"missing snapshots or pixels jobs=%0d pixels=%0d",jobs,checks);
 @(negedge clk);en=0;repeat(10) @(negedge clk);
 if(dut.pending || dut.active_valid) $fatal(1,"dual disable stale");
 $fclose(fd);$display("PASS paired same-frame actual input/output sampled histograms, RGB clipping, shared vertical scale, four-lane plotting and frame commits pixels=%0d",checks);
 $display("PASS tb_v27_dual_histogram");$finish;
end
initial begin #3000000;$fatal(1,"dual histogram timeout");end
endmodule
