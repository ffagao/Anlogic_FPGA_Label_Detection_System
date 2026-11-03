`timescale 1ns/1ps
// Exercise the real spatial/packing/write-FIFO chain with independent clocks.
// The next CSI header can precede the previous processed frame's final row.
module tb_v31_spatial_ddr #(parameter H=8,F=6);
localparam W=1280,WORDS_PER_FRAME=W*H*3/16;
reg cam=0,ddr=0;
always #8.334 cam=~cam;
always #7.5 ddr=~ddr;
reg rst=0,v=0,u=0,csi=0;
reg [95:0] rgb=0;
reg [23:0] frame_id=0;
wire sv,su,sl,pv,pu,pl;
wire [95:0] gaussian,ink;
wire [127:0] packed_data;
reg ink_mode=0;
spatial_filter4 #(.IMAGE_WIDTH(W),.IMAGE_HEIGHT(H)) spatial(
 .I_clk(cam),.I_rst_n(rst),.I_enable(1'b1),.I_valid(v),.I_user(u),.I_rgb(rgb),
 .O_valid(sv),.O_user(su),.O_last(sl),.O_gaussian(gaussian),.O_ink(ink));
rgb96_to_128_v29 packer(.I_clk(cam),.I_rst_n(rst),
 .I_frame_start(su),.I_valid(sv),.I_last(sl),.I_data(ink_mode ? ink : gaussian),
 .O_frame_start(pu),.O_valid(pv),.O_last(pl),.O_data(packed_data));
wire wr_busy,wr_en;
wire [24:0] addr;
wire [127:0] data;
wire [1:0] rp;
wire [23:0] displayed_id;
wire [8:0] level,burst;
wire active;
wire [17:0] last_frame_count;
integer cycles=0,read_left=0;
wire ready=(cycles%97<83) && (cycles%13!=1);
// video_out includes its combinational read trigger in its busy output.
wire read_start=read_left==0 && !wr_busy && cycles%557<4;
wire read_busy=read_left!=0 || read_start;
video_in writer(.I_rst_n(rst),.I_camera_clk(cam),.I_camera_frame_start(pu),
`ifdef V30_BASELINE
 .I_camera_fifo_reset_start(csi),
`endif
 .I_camera_frame_bcd(frame_id),.I_camera_valid(pv),.I_camera_data(packed_data),
 .I_mipi_rx_error(1'b0),.I_ddr_clk(ddr),.I_display_pause(1'b0),
 .I_video_out_rd_busy(read_busy),.O_video_out_frame_bcd(displayed_id),
 .O_video_in_wr_busy(wr_busy),.O_video_out_rp(rp),.O_ddr_user_wr_en(wr_en),
 .O_ddr_user_addr(addr),.O_ddr_user_wr_data(data),.I_ddr_user_ready(ready),
 .O_diag_fifo_level(level),.O_diag_burst_count(burst),
 .O_diag_burst_active(active),.O_diag_ddr_frame(last_frame_count));
always @(posedge ddr) begin
 if(!rst) begin cycles<=0;read_left<=0;end
 else begin
  cycles<=cycles+1;
  if(read_left!=0) read_left<=read_left-1;
  else if(read_start) read_left<=240;
 end
end
reg [127:0] expected[0:F*WORDS_PER_FRAME-1];
integer written=0,read=0,headers=0,overlaps=0,peak=0;
integer got_frame,offset;
reg [24:0] expected_addr;
always @(posedge cam) begin
 if(rst && pv) begin
  if(written>=F*WORDS_PER_FRAME) $fatal(1,"extra packed word");
  expected[written]=packed_data;written=written+1;
 end
 if(rst && csi && sv) overlaps=overlaps+1;
end
always @(posedge ddr) begin
 if(rst) begin
`ifndef V30_BASELINE
  if(writer.S_fifo_rd_en && writer.u_camera_frame_fifo.empty_flag)
   $fatal(1,"write FIFO underflow");
`endif
  if(level>peak) peak=level;
  if(wr_en) begin
   if(read>=written) $fatal(1,"write without input word %0d",read);
   if(data!==expected[read])
    $fatal(1,"DDR bytes lost/reordered at word=%0d frame=%0d got=%h expected=%h CSI headers=%0d",read,read/WORDS_PER_FRAME,data,expected[read],headers);
   got_frame=read/WORDS_PER_FRAME;offset=(read%WORDS_PER_FRAME)*8;
   expected_addr=(got_frame%4)*7000000+offset;
   if(addr!==expected_addr) $fatal(1,"DDR address mismatch word=%0d got=%h expected=%h",read,addr,expected_addr);
   if(read_busy) $fatal(1,"write pipeline overlaps read arbitration");
   read=read+1;
  end
 end
end
integer f,y,x,lane,n;
task header;
 begin csi=1;headers=headers+1;@(negedge cam);csi=0;end
endtask
initial begin
 repeat(6) @(negedge cam);rst=1;
 header();repeat(80) @(negedge cam);
 for(f=0;f<F;f=f+1) begin
  frame_id=f;ink_mode=f[0];
  for(y=0;y<H;y=y+1) begin
   for(x=0;x<W;x=x+4) begin
    v=1;u=(x==0 && y==0);
    for(lane=0;lane<4;lane=lane+1)
     rgb[95-lane*24-:24]={8'(f*37+x+lane),8'(y*29+f*13),8'(x/4+f*47)};
    @(negedge cam);
   end
   v=0;u=0;
   if(y<H-1) repeat(500) @(negedge cam);
  end
  // Reproduce a raw header while the delayed spatial tail is still pending.
  // Sweep its phase to exercise whole-word and RGB byte alignment failures.
  repeat(f*7) @(negedge cam);
  if(f<F-1) header();
  repeat(800) @(negedge cam);
 end
 repeat(3000) @(negedge cam);
 if(written!=F*WORDS_PER_FRAME || read!=written)
  $fatal(1,"incomplete DDR frames input=%0d output=%0d expected=%0d",written,read,F*WORDS_PER_FRAME);
 if(last_frame_count!=WORDS_PER_FRAME) $fatal(1,"DDR frame counter %h",last_frame_count);
 $display("PASS spatial -> pack -> vendor async FIFO -> DDR: words=%0d frames=%0d peak=%0d headers=%0d, 60/66.667MHz, stalls, alternating Gaussian/ink and early CSI headers",read,F,peak,headers);
 $display("PASS tb_v31_spatial_ddr");$finish;
end
initial begin #100000000;$fatal(1,"spatial DDR timeout input=%0d output=%0d",written,read);end
endmodule
