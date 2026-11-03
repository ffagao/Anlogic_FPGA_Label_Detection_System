`timescale 1ns/1ps
module tb_v27_spatial;
localparam W=32,H=8,F=6;
reg clk=0;always #5 clk=~clk;
reg rst=0,en=1,v=0,u=0;reg [95:0] rgb=0;
wire ov,ou,ol;wire [95:0] gaussian,ink;
spatial_filter4 #(.IMAGE_WIDTH(W),.IMAGE_HEIGHT(H)) dut(
 .I_clk(clk),.I_rst_n(rst),.I_enable(en),.I_valid(v),.I_user(u),.I_rgb(rgb),
 .O_valid(ov),.O_user(ou),.O_last(ol),.O_gaussian(gaussian),.O_ink(ink));
reg [23:0] images[0:F-1][0:H-1][0:W-1];
integer f,x,y,c,dy,dx,s,weight,xx,yy,got_frame=-1,ox=0,oy=0,checks=0,k,mag,gx,gy,a[0:8];
reg [23:0] eg,ei,p;integer val;
function integer lum(input [23:0] q);
 begin lum=(q[23:16]+2*q[15:8]+q[7:0])/4;end
endfunction
always @(posedge clk) begin
 #1;
 if(rst && ov) begin
  if(ou) begin
   if(got_frame>=0 && (oy!=H || ox!=0)) $fatal(1,"previous frame incomplete %0d %0d",ox,oy);
   got_frame=got_frame+1;ox=0;oy=0;
  end
  if(got_frame<0 || got_frame>=F || oy>=H) $fatal(1,"unexpected output frame/row");
  if(ol!==(ox==W-4)) $fatal(1,"EOL misaligned");
  for(k=0;k<4;k=k+1) begin
   eg=0;
   for(c=0;c<3;c=c+1) begin
    s=0;
    for(dy=-1;dy<=1;dy=dy+1) for(dx=-1;dx<=1;dx=dx+1) begin
     xx=ox+k+dx;yy=oy+dy;
     if(xx<0) xx=0;if(xx>=W) xx=W-1;if(yy<0) yy=0;if(yy>=H) yy=H-1;
     weight=(dx==0 ? 2:1)*(dy==0 ? 2:1);
     p=images[got_frame][yy][xx];s=s+weight*p[23-c*8-:8];
     a[(dy+1)*3+dx+1]=lum(p);
    end
    eg[23-c*8-:8]=(s+8)/16;
   end
   gx=-a[0]+a[2]-2*a[3]+2*a[5]-a[6]+a[8];
   gy=-a[0]-2*a[1]-a[2]+a[6]+2*a[7]+a[8];
   mag=(gx<0 ? -gx:gx)+(gy<0 ? -gy:gy);
   ei=images[got_frame][oy][ox+k];
   for(c=0;c<3;c=c+1) begin
    val=ei[23-c*8-:8];ei[23-c*8-:8]=mag>=256 ? val/4 : mag>=96 ? val/2 : val;
   end
   if(gaussian[95-k*24-:24]!==eg) $fatal(1,"Gaussian frame=%0d x=%0d y=%0d got=%h ref=%h",got_frame,ox+k,oy,gaussian[95-k*24-:24],eg);
   if(ink[95-k*24-:24]!==ei) $fatal(1,"ink frame=%0d x=%0d y=%0d got=%h ref=%h",got_frame,ox+k,oy,ink[95-k*24-:24],ei);
   checks=checks+1;
  end
  if(ox==W-4) begin ox=0;oy=oy+1;end else ox=ox+4;
 end
end
integer n,ix,iy;
initial begin
 for(f=0;f<F;f=f+1) for(y=0;y<H;y=y+1) for(x=0;x<W;x=x+1) begin
  if(f==0) images[f][y][x]=24'hffffff;
  else if(f==1) images[f][y][x]={8'(x*7),8'(y*31),8'((x+y)*5)};
  else if(f==2) images[f][y][x]=(x+y)%2 ? 24'h204080 : 24'he0c0a0;
  else if(f==3) images[f][y][x]=(x==0 || x==W-1 || y==0 || y==H-1) ? 24'hffffff : 0;
  else if(f==4) images[f][y][x]=x<W/2 ? 24'h202020 : 24'hc0c0c0;
  else images[f][y][x]=24'h607080;
 end
 repeat(5) @(negedge clk);rst=1;
 for(n=0;n<F;n=n+1) begin
  for(iy=0;iy<H;iy=iy+1) for(ix=0;ix<W;ix=ix+4) begin
   v=1;u=ix==0 && iy==0;
   rgb={images[n][iy][ix],images[n][iy][ix+1],images[n][iy][ix+2],images[n][iy][ix+3]};
   @(negedge clk);
   if(n>=2 && ix==12) begin v=0;u=1;repeat(3) @(negedge clk);end
  end
  v=0;u=0;
  if(n==1) repeat(3) @(negedge clk);
  if(n>=2) repeat(50) @(negedge clk);
 end
 repeat(50) @(negedge clk);
 if(checks!=W*H*F || got_frame!=F-1 || oy!=H) $fatal(1,"lost pixels %0d frame=%0d y=%0d",checks,got_frame,oy);
 en=0;repeat(10) @(negedge clk);if(ov) $fatal(1,"disabled filter valid");
 $display("PASS centered full-RGB 3x3 Gaussian and Sobel ink: all pixels, replicated borders, constant/gradient/checker/edge scenes, zero/short blanking and bubbles pixels=%0d",checks);
 $display("PASS tb_v27_spatial");$finish;
end
initial begin #100000;$fatal(1,"spatial timeout");end
endmodule
