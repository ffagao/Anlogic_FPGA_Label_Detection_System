`timescale 1ns/1ps
module tb_v20_ae_chain;
reg pixel_clk=0; always #8.333 pixel_clk=~pixel_clk;
reg control_clk=0; always #21 control_clk=~control_clk;
reg rst_n=0,fs=0,valid=0;reg [39:0] raw4=0;
wire [7:0] luma;wire toggle,req,cfg_done,ae_done,ae_error,scl;
wire [15:0] exposure,gain;wire [71:0] debug_data;wire debug_toggle;
tri1 sda;
ae_raw_meter meter(pixel_clk,rst_n,fs,valid,raw4,luma,toggle);
ae_set controller(.I_lock(1'b0),.I_clk(control_clk),.I_rst(~rst_n),.I_btn(2'b11),
 .I_fps_60(1'b0),.I_frame_luma(luma),.I_luma_toggle(toggle),
 .I_ae_cfg_done(ae_done),.I_cam_cfg_done(cfg_done),.I_ae_error(ae_error),
 .O_ae_req(req),.O_ae(exposure),.O_ag(gain),
 .O_debug(debug_data),.O_debug_toggle(debug_toggle));
uicfgcs500_720p #(.CLK_DIV(15)) camera(
 .I_clk(control_clk),.I_rst_n(rst_n),.I_fps_60(1'b0),.I_ae_req(req),
 .I_ae(exposure),.I_ag(gain),.O_cam_scl(scl),.IO_cam_sda(sda),
 .O_cfg_done(cfg_done),.O_ae_cfg_done(ae_done),.O_ae_error(ae_error));
assign sda=(camera.u_i2c.IIC_S==3) ? 1'b0 : 1'bz;
integer requests=0,ae_bytes=0,measurements=0;
always @(posedge control_clk) if(rst_n && req) requests=requests+1;
always @(posedge camera.iic_req) if(cfg_done) ae_bytes=ae_bytes+1;
always @(toggle) if(rst_n) measurements=measurements+1;
task frame(input integer level);
integer x,y;reg [9:0] p;
begin
 @(negedge pixel_clk);fs=1;valid=0;
 @(negedge pixel_clk);fs=0;p=level*4;raw4={4{p}};
 for(y=0;y<720;y=y+1) begin
  for(x=0;x<320;x=x+1) begin
   @(negedge pixel_clk);valid=1;
   if(x%9==3) begin @(negedge pixel_clk);valid=0;end
  end
  @(negedge pixel_clk);valid=0;
  repeat(20) @(negedge pixel_clk);
 end
 if(luma!==level) $fatal(1,"chain metering error %0d expected %0d",luma,level);
end endtask
integer old_gain,old_exp,old_requests;
initial begin
 repeat(10) @(negedge control_clk);rst_n=1;
 // Real I2C initialization includes the 240000-cycle post-stream wait.
 wait(cfg_done);wait(ae_done);
 old_exp=exposure;
 repeat(6) frame(16);
 repeat(1000) @(negedge control_clk);
 if(exposure<=old_exp || requests<2 || ae_bytes<14) $fatal(1,"dark frames did not reach actual camera writes");
 old_gain=gain;old_requests=requests;
 repeat(6) frame(240);
 repeat(1000) @(negedge control_clk);
 if(gain>=old_gain || requests<=old_requests) $fatal(1,"bright frames did not reduce gain");
 if(measurements!=12 || ae_error) $fatal(1,"lost frame result or unexpected NACK");
 $display("PASS asynchronous RAW -> AE -> real camera config/I2C chain: frames=%0d requests=%0d AE bytes=%0d",measurements,requests,ae_bytes);
 $display("PASS tb_v20_ae_chain");$finish;
end
initial begin #100000000;$fatal(1,"timeout");end
endmodule
