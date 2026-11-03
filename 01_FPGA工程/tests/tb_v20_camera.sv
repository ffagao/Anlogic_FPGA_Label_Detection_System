`timescale 1ns/1ps
module tb_v20_camera;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,fps60=0,req=0,ack_enable=1;
reg [15:0] exposure=3000,gain=80;
wire scl,cfg_done,ae_done,ae_error;tri1 sda;
uicfgcs500_720p #(.CLK_DIV(15)) dut(
 .I_clk(clk),.I_rst_n(rst_n),.I_fps_60(fps60),.I_ae_req(req),
 .I_ae(exposure),.I_ag(gain),.O_cam_scl(scl),.IO_cam_sda(sda),
 .O_cfg_done(cfg_done),.O_ae_cfg_done(ae_done),.O_ae_error(ae_error));
// Slave responds during each master's ACK phase. Test bytes are captured
// at the real I2C request interface; this is not a physical sensor model.
assign sda=(ack_enable && dut.u_i2c.IIC_S==3) ? 1'b0 : 1'bz;
reg [23:0] writes[0:511];integer n=0;
always @(posedge clk) if(dut.iic_req && !dut.iic_busy) begin end
always @(posedge dut.iic_req) begin
 writes[n]={dut.wr_data[15:8],dut.wr_data[23:16],dut.wr_data[31:24]};
 if(dut.wr_data[7:0]!=8'h6c) $fatal(1,"bad camera address");
 n=n+1;
end
task wait_done;
begin wait(!ae_done);wait(ae_done);repeat(10) @(negedge clk);end
endtask
integer first;
initial begin
 repeat(10) @(negedge clk);rst_n=1;
 wait(cfg_done);repeat(10) @(negedge clk);
 if(ae_error) $fatal(1,"false ACK error at initialization");
 if(writes[n-3]!==24'h3e030b || writes[n-2]!==24'h010001 ||
    writes[n-1]!==24'h302d00)
  $fatal(1,"manual gain control must be enabled before stream-on: %h %h %h",
   writes[n-3],writes[n-2],writes[n-1]);
 $display("PASS SC500CS manual gain enable precedes stream-on");
 first=n;exposure=16'h0456;gain=16;
 @(negedge clk);req=1;@(negedge clk);req=0;wait_done();
 if(n-first!=7 || writes[first]!==24'h3e0000 ||
    writes[first+1]!==24'h3e0145 || writes[first+2]!==24'h3e0260 ||
    writes[first+3]!==24'h3e0803 || writes[first+4]!==24'h3e0920 ||
    writes[first+5]!==24'h3e0600 || writes[first+6]!==24'h3e0780)
  $fatal(1,"AE register sequence wrong n=%0d first=%0d",n,first);
 if(ae_error) $fatal(1,"false AE ACK error");
 $display("PASS real I2C master + camera AE table: 3e00/01/02/08/09");
 first=n;gain=143;
 @(negedge clk);req=1;@(negedge clk);req=0;wait_done();
 if(n-first!=7 || writes[first+3]!==24'h3e081f || writes[first+4]!==24'h3e093f ||
    writes[first+5]!==24'h3e0600 || writes[first+6]!==24'h3e0780)
  $fatal(1,"maximum analog gain did not reach SC500CS 1f/3f: %h %h",writes[first+3],writes[first+4]);
 $display("PASS maximum analog gain command writes 3e08=1f, 3e09=3f");
 first=n;gain=191;
 @(negedge clk);req=1;@(negedge clk);req=0;wait_done();
 if(n-first!=7 || writes[first+3]!==24'h3e081f || writes[first+4]!==24'h3e093f ||
    writes[first+5]!==24'h3e0601 || writes[first+6]!==24'h3e07c0)
  $fatal(1,"G=191 did not map to 15.75x analog plus 3x digital gain");
 $display("PASS G=191 maps digital gain 3x at 3e06=01, 3e07=c0");
 gain=16;
 exposure=3000; first=n;fps60=1;wait_done();
 if(n-first!=9 || writes[first+1]!==24'h3e017c || writes[first+2]!==24'h3e0260 ||
    writes[first+7]!==24'h320e03 || writes[first+8]!==24'h320fe8)
  $fatal(1,"60 FPS safe exposure/VTS sequence wrong n=%0d first=%0d",n,first);
 $display("PASS 60 FPS writes clamped exposure 1990 before VTS=1000");
 first=n;fps60=0;wait_done();
 if(n-first!=9 || writes[first+7]!==24'h320e07 || writes[first+8]!==24'h320fd0)
  $fatal(1,"30 FPS VTS sequence wrong");
 $display("PASS 30 FPS VTS=2000 restore");
 ack_enable=0;
 @(negedge clk);req=1;@(negedge clk);req=0;wait_done();
 if(!ae_error) $fatal(1,"NACK not exposed");
 ack_enable=1;
 @(negedge clk);req=1;@(negedge clk);req=0;wait_done();
 if(!ae_error) $fatal(1,"NACK history not sticky");
 $display("PASS NACK detection and sticky fault history");
 $display("PASS tb_v20_camera");$finish;
end
initial begin #20000000; $fatal(1,"timeout");end
endmodule
