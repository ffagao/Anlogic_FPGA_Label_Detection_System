`timescale 1ns/1ps
module tb_v40_live_zoom_pixels;
reg ddr=0,pixel=0;always #7.5 ddr=~ddr;always #6.6665 pixel=~pixel;
reg rst=0,vs=0,de=0,request=0;reg [1:0] bank=1;
reg [11:0] origin_x=721;reg signed [11:0] origin_y=-160;
reg [23:0] frame_id=24'h100001;
wire rd,rd_busy,view;
wire [24:0] addr;wire [23:0] rgb,display_id;wire [11:0] vx;wire signed [11:0] vy;
reg valid=0;reg [127:0] data=0;
integer dc=0;wire ready=dc%37<29;wire camera_busy=dc%947<24;
video_out dut(.I_rst_n(rst),.I_ddr_clk(ddr),.O_video_out_rd_busy(rd_busy),
 .I_video_in_wr_busy(camera_busy),.I_video_out_rp(bank),.I_video_out_frame_bcd(frame_id),
 .I_zoom_enable(request),.I_zoom_src_x(origin_x),.I_zoom_src_y(origin_y),
 .O_zoom_active(view),.O_zoom_src_x(vx),.O_zoom_src_y(vy),
 .O_display_frame_bcd(display_id),.O_display_frame_toggle(),
 .O_ddr_user_rd_en(rd),.O_ddr_user_addr(addr),.I_ddr_user_ready(ready),
 .I_ddr_user_rd_valid(valid),.I_ddr_user_rd_data(data),
 .I_dsi_clk(pixel),.I_video_vsync(vs),.I_video_rd_en(de),.O_vdieo_data(rgb));
function automatic [23:0] colour(input integer px,py,b);
 begin colour=(px==911 && py==360)?24'hffffff:{8'(px),8'(py),8'(px^py^(b*53))};end
endfunction
function automatic [127:0] beat(input [24:0] address);
 integer b,base,byte_id,pix,j;reg [23:0] c;
 begin
  b=address>=21000000?3:(address>=14000000?2:(address>=7000000?1:0));
  base=b*7000000;beat=0;
  for(j=0;j<16;j=j+1)begin
   byte_id=(address-base)*2+j;pix=byte_id/3;c=colour(pix%1280,pix/1280,b);
   case(byte_id%3) 0:beat[127-j*8-:8]=c[23:16];1:beat[127-j*8-:8]=c[15:8];2:beat[127-j*8-:8]=c[7:0];endcase
  end
 end
endfunction
reg [23:0] responses=0;reg [24:0] addresses[0:23];integer j;
always @(posedge ddr) begin
 if(!rst)begin dc<=0;responses<=0;valid<=0;data<=0;end
 else begin
  dc<=dc+1;responses<={responses[22:0],rd};addresses[0]<=addr;
  for(j=1;j<24;j=j+1)addresses[j]<=addresses[j-1];
  valid<=responses[23];if(responses[23])data<=beat(addresses[23]);
  if(dut.S_fifo_reserved>511)$fatal(1,"FIFO reservation overflow");
 end
end
integer xx=0,yy=0,f=0,checked=0;reg checking=0,gold_zoom=0;
reg test_done=0,test_finish_enable=1;
integer gold_x,gold_y,gold_bank;reg [23:0] gold_id;
reg [1:0] vp=0;reg [23:0] expected_pixels[0:1];integer xp[0:1],yp[0:1];
function automatic [23:0] expected(input integer px,py);
 integer sx,sy;
 begin
  sx=gold_x+(px-512)/2;sy=gold_y+py/2;
  if(gold_zoom)begin
   if(px<512 || sx>=1280 || sy<0 || sy>=720)expected=0;
   else expected=colour(sx,sy,gold_bank);
  end else expected=colour(px,py,gold_bank);
 end
endfunction
always @(posedge pixel)begin
 vp<={vp[0],de};expected_pixels[0]<=expected(xx,yy);expected_pixels[1]<=expected_pixels[0];
 xp[0]<=xx;yp[0]<=yy;xp[1]<=xp[0];yp[1]<=yp[0];
 #1;
 if(rst && checking && vp[1])begin
  if(rgb!==expected_pixels[1])
   $fatal(1,"RGB/packing error f%0d at%0d,%0d got%h expected%h phase%0d view%b",f,xp[1],yp[1],rgb,expected_pixels[1],dut.S_fifo_rd_cnt,view);
  if(dut.S_read_fault)$fatal(1,"unexpected read underflow");
  checked=checked+1;
 end
end
task tick;begin @(negedge pixel);end endtask
task scan;
 integer row,col;
 begin
  gold_zoom=request;gold_x=request?origin_x-1:origin_x;gold_y=$signed(origin_y);gold_bank=bank;gold_id=frame_id;
  vs=1;repeat(20)tick();vs=0;repeat(600)tick();
  if(view!==gold_zoom || (view && (vx!=gold_x+1 || vy!=gold_y)))$fatal(1,"frame packet not committed");
  checking=1;
  for(row=0;row<720;row=row+1)begin
   yy=row;
   for(col=0;col<1280;col=col+1)begin
    xx=col;de=1;
    if(f==1 && row==123 && col==777)begin origin_x=1081;origin_y=539;bank=3;frame_id=24'h100003;end
    if(f==4 && row==600 && col==777)request=0;
    tick();
   end
   de=0;repeat(370)tick();
  end
  repeat(10)tick();checking=0;
  repeat(30*1650)tick();
  if(dut.S_frame_read_count!=(gold_zoom?54000:172800))$fatal(1,"frame read count wrong %d",dut.S_frame_read_count);
  if(display_id!==gold_id)$fatal(1,"live bank/frame identity mismatch: %h expected %h",display_id,gold_id);
 end
endtask
initial begin
 repeat(10)tick();rst=1;repeat(20)tick();
 scan();
 request=1;bank=2;frame_id=24'h100002;
 f=1;scan();f=2;scan();f=3;scan();
 bank=0;frame_id=24'h100004;f=4;scan();
 bank=1;frame_id=24'h100005;f=5;scan();
 bank=2;frame_id=24'h100006;f=6;scan();
 if(view)$fatal(1,"normal view did not restore");
 if(checked!=7*1280*720)$fatal(1,"pixel coverage wrong %d",checked);
 test_done=1;wait(test_finish_enable);
 $display("PASS tb_v40_live_zoom_pixels: seven full frames at actual 75MHz HDMI/66.67MHz DDR, every RGB byte, frame-atomic crop/bank/ID, live bank changes, repeated acquisition ID, edge padding, stalls, original-view restoration; checked=%0d",checked);$finish;
end
initial begin #180000000;$fatal(1,"pixel test timeout");end
endmodule
