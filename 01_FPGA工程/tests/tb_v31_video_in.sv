`timescale 1ns/1ps
module tb_v31_video_in;
reg cam=0,ddr=0;
always #8.334 cam=~cam;
always #7.5 ddr=~ddr;
reg rst=0,v=0,u=0;
reg [127:0] data=0;
reg [23:0] bcd=0;
wire wr,wrbusy,active;
wire [24:0] addr;
wire [127:0] outdata;
wire [23:0] displayed;
wire [1:0] rp;
wire [8:0] level,burst;
wire [17:0] frame_count;
integer cycle=0,read_left=0;
wire ready=cycle%71<49;
wire readstart=read_left==0 && !wrbusy && cycle%389<3;
wire readbusy=read_left!=0 || readstart;
video_in dut(.I_rst_n(rst),.I_camera_clk(cam),.I_camera_frame_start(u),
 .I_camera_frame_bcd(bcd),.I_camera_valid(v),.I_camera_data(data),
 .I_mipi_rx_error(1'b0),.I_ddr_clk(ddr),.I_display_pause(1'b0),
 .I_video_out_rd_busy(readbusy),.O_video_out_frame_bcd(displayed),
 .O_video_in_wr_busy(wrbusy),.O_video_out_rp(rp),.O_ddr_user_wr_en(wr),
 .O_ddr_user_addr(addr),.O_ddr_user_wr_data(outdata),.I_ddr_user_ready(ready),
 .O_diag_fifo_level(level),.O_diag_burst_count(burst),
 .O_diag_burst_active(active),.O_diag_ddr_frame(frame_count));
always @(posedge ddr) begin
 if(!rst) begin cycle<=0;read_left<=0;end
 else begin
  cycle<=cycle+1;
  if(read_left>0) read_left<=read_left-1;
  else if(readstart) read_left<=240;
 end
end
reg [127:0] words[0:4095];
reg [24:0] addresses[0:4095];
reg [1:0] pointers[0:4095];
reg [23:0] identities[0:4095];
reg [17:0] counts[0:4095];
integer wrote=0,read=0,f,n,length,prev_length=0,peak=0;
integer lengths[0:7];
always @(posedge cam) begin
 if(rst && dut.S_camera_wr_en && dut.S_fifo_full) $fatal(1,"FIFO overflow");
end
always @(posedge ddr) begin
 if(rst) begin
  if(dut.S_fifo_rd_en && dut.u_camera_frame_fifo.empty_flag) $fatal(1,"FIFO underflow");
  if(level>peak) peak=level;
  if(wr) begin
   if(readbusy) $fatal(1,"read/write arbitration overlap");
   if(read>=wrote || outdata!==words[read] || addr!==addresses[read])
    $fatal(1,"word/address mismatch word=%0d got=%h@%h expected=%h@%h",read,outdata,addr,words[read],addresses[read]);
   if(rp!==pointers[read] || displayed!==identities[read] || frame_count!==counts[read])
    $fatal(1,"frame metadata mismatch word=%0d rp=%h id=%h count=%h expected=%h/%h/%h",read,rp,displayed,frame_count,pointers[read],identities[read],counts[read]);
   read=read+1;
  end
 end
end
initial begin
 lengths[0]=240;lengths[1]=477;lengths[2]=483;lengths[3]=720;
 lengths[4]=240;lengths[5]=477;lengths[6]=483;lengths[7]=720;
 repeat(6) @(negedge cam);rst=1;
 // Ignore startup pixels that precede the first frame marker.
 repeat(6) begin v=1;data=128'hbad;@(negedge cam);end
 v=0;repeat(10) @(negedge cam);
 for(f=0;f<8;f=f+1) begin
  length=lengths[f];bcd=24'h100+f;
  if(f[0]) begin
   u=1;@(negedge cam);u=0;
   // A later raw CSI identity must not change this pending image identity.
   bcd=24'hbad;
   repeat(9) @(negedge cam);
  end
  for(n=0;n<length;n=n+1) begin
   v=1;u=!f[0] && n==0;
   data={32'(f),32'(n),32'(~n),32'(f*1000+n)};
   words[wrote]=data;addresses[wrote]=(f%4)*7000000+n*8;
   pointers[wrote]=(f+2)%4;identities[wrote]=f>=2 ? 24'h100+f-2 : 24'd0;
   counts[wrote]=prev_length;wrote=wrote+1;
   @(negedge cam);
   v=0;u=0;repeat(1+n%3) @(negedge cam);
  end
  prev_length=length;
  v=0;u=0;repeat(500) @(negedge cam);
 end
 repeat(3000) @(negedge cam);
 if(read!=wrote || wrote!=3840) $fatal(1,"lost data %0d/%0d",read,wrote);
 // A global reset must clear data, markers and frame counts together.
 rst=0;repeat(6) @(negedge cam);
 if(wr || active || frame_count) $fatal(1,"reset did not clear writer");
 $display("PASS tagged DDR writer: words=%0d peak=%0d, preamble/aligned SOF, startup, bubbles, partial mode-transition frames, buffer wrap and frame identities",read,peak);
 $display("PASS tb_v31_video_in");$finish;
end
initial begin #3000000;$fatal(1,"video writer timeout");end
endmodule
