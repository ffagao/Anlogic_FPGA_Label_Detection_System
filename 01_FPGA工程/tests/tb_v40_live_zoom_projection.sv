`timescale 1ns/1ps
module tb_v40_live_zoom_projection;
reg clk=0;always #5 clk=~clk;
reg rst=0,de=0,zoom=0;reg [11:0] x=0,y=0,sx=708;reg signed [11:0] sy=170;
wire signed [25:0] bp,bq,lp,lq,rp,rq;wire ready;
label_overlay_projection dut(.clk(clk),.rst_n(rst),.de(de),.x(x),.y(y),
 .bx(12'd800),.by(12'd350),.lx(12'd900),.ly(12'd350),.tx(12'd880),.ty(12'd330),
 .bc(12'sd1024),.bs(12'sd0),.lc(12'sd724),.ls(-12'sd724),.rc(12'sd0),.rs(12'sd1024),
 .bp(bp),.bq(bq),.lp(lp),.lq(lq),.rp(rp),.rq(rq),.ready(ready),
 .I_zoom(zoom),.I_src_x(sx),.I_src_y(sy));
integer f,xx,yy,dx,dy,ax,ay,rx,ry,checked=0;
initial begin
 repeat(4)@(negedge clk);rst=1;
 for(f=0;f<4;f=f+1)begin
  zoom=f!=0;sx=f==2?12'd1081:12'd708;sy=f==3?-12'sd160:12'sd170;
  for(yy=0;yy<720;yy=yy+1)for(xx=0;xx<1280;xx=xx+1)begin
   @(negedge clk);de=1;x=xx;y=yy;#1;
   if(xx>=512)begin
    if(!ready)$fatal(1,"projection not ready");
    if(zoom)begin
     dx=xx-512+2*(sx-800);dy=yy+2*($signed(sy)-350);
     ax=xx-512+2*(sx-900);ay=yy+2*($signed(sy)-350);
     rx=xx-512+2*(sx-880);ry=yy+2*($signed(sy)-330);
    end else begin dx=xx-800;dy=yy-350;ax=xx-900;ay=yy-350;rx=dx;ry=dy;end
    if(bp!==dx*1024 || bq!==dy*1024 ||
       lp!==(ax-ay)*724 || lq!==(ax+ay)*724 ||
       rp!==ry*1024 || rq!==-rx*1024)
       $fatal(1,"projection mismatch frame%0d at%0d,%0d got %d/%d/%d/%d/%d/%d",f,xx,yy,bp,bq,lp,lq,rp,rq);
    checked=checked+1;
   end
  end
  @(negedge clk);de=0;repeat(20)@(negedge clk);
 end
 if(checked!=4*768*720)$fatal(1,"raster coverage incomplete");
 $display("PASS tb_v40_live_zoom_projection: full-raster normal and 2x exact projection, negative crop Y, right-edge crop and unique theoretical centre; pixels=%0d",checked);$finish;
end
initial begin #60000000;$fatal(1,"projection timeout");end
endmodule
