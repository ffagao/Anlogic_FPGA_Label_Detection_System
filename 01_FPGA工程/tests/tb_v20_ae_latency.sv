`timescale 1ns/1ps
module tb_v20_ae_latency;
reg clk=0; always #5 clk=~clk;
reg rst_n=0,fs=0,valid=0; reg [39:0] raw4=0;
wire [7:0] luma; wire toggle;
ae_raw_meter meter(clk,rst_n,fs,valid,raw4,luma,toggle);
reg start=0, fps60=0; reg [7:0] frames=0; wire [15:0] ms;
osd_latency_ms latency(clk,rst_n,start,fps60,frames,ms);
reg ae_rst=1; reg [7:0] ae_luma=96; reg ae_toggle=0;
reg done=1, cam_done=1; wire req; wire [15:0] exposure,gain;
wire [71:0] debug_data; wire debug_toggle;
ae_set ae(.I_lock(1'b0),.I_clk(clk),.I_rst(ae_rst),.I_btn(2'b11),
 .I_fps_60(fps60),.I_frame_luma(ae_luma),.I_luma_toggle(ae_toggle),
 .I_ae_error(1'b0),.I_ae_cfg_done(done),.I_cam_cfg_done(cam_done),
 .O_ae_req(req),.O_ae(exposure),.O_ag(gain),
 .O_debug(debug_data),.O_debug_toggle(debug_toggle));
integer req_count=0,busy_count=0;
always @(posedge clk) begin
 if(ae_rst) begin done<=1;busy_count<=0; req_count<=0; end
 else if(req) begin
  if(!done) $fatal(1,"request while camera busy");
  done<=0;busy_count<=30;req_count<=req_count+1;
 end else if(busy_count>0) begin
  busy_count<=busy_count-1;
  if(busy_count==1) done<=1;
 end
end
task frame(input integer level,input integer bubble,input integer simultaneous,input integer roi_only);
integer x,y; reg old_toggle; reg [9:0] p;
begin
 old_toggle=toggle;
 @(negedge clk); fs=1;valid=simultaneous;p=level*4;raw4={4{p}};
 @(negedge clk); fs=0;valid=0;
 for(y=0;y<720;y=y+1) begin
  for(x=0;x<320;x=x+1) begin
   if(!(simultaneous && x==0 && y==0)) begin
    @(negedge clk);valid=1;
    p=(!roi_only || (x>=32 && x<=287 && y>=104 && y<=615)) ? level*4 : 0;
    raw4={4{p}};
    if(bubble && x%7==3) begin @(negedge clk); valid=0; end
   end
  end
  @(negedge clk);valid=0;
  repeat(5) @(negedge clk);
 end
 repeat(5) @(negedge clk);
 if(toggle===old_toggle || luma!==level) $fatal(1,"meter got %d expected %d toggle %b",luma,level,toggle);
 $display("PASS RAW meter Y=%0d bubbles=%0d simultaneous=%0d roi_only=%0d",level,bubble,simultaneous,roi_only);
end endtask
function [15:0] bcd(input integer n);
begin bcd={4'((n/1000)%10),4'((n/100)%10),4'((n/10)%10),4'(n%10)}; end
endfunction
task check_ms(input integer f,input integer rate);
integer expected;
begin
 @(negedge clk);frames={(4'(f/10)),(4'(f%10))};fps60=(rate==60);start=1;
 @(negedge clk);start=0;
 repeat(35) @(negedge clk);
 expected=(f*1000+rate/2)/rate;
 if(ms!==bcd(expected)) $fatal(1,"ms %h expected %h frames %0d fps %0d",ms,bcd(expected),f,rate);
end endtask
task sample(input integer level);
begin
 @(negedge clk);ae_luma=level;ae_toggle=~ae_toggle;
 repeat(100) @(negedge clk);
end endtask
integer i,old_exp,old_gain,old_req;
initial begin
 repeat(10) @(negedge clk);rst_n=1;
 frame(0,0,0,0); frame(64,1,1,1);frame(255,1,0,0);frame(96,0,1,0);
 // Abort before the ROI completes: no spurious update.
 @(negedge clk);fs=1;@(negedge clk);fs=0;
 repeat(2000) begin @(negedge clk);valid=1;end
 @(negedge clk);valid=0;
 frame(120,1,0,1);
 for(i=0;i<100;i=i+1) begin check_ms(i,30);check_ms(i,60);end
 $display("PASS all 200 latency estimates, including 00 and 99 frames");
 fps60=0;ae_rst=0; repeat(10) @(negedge clk);
 old_exp=exposure;
 repeat(12) sample(16);
 if(exposure<=old_exp || req_count==0) $fatal(1,"AE dark no exposure rise");
 repeat(100) sample(0);
 if(exposure!=3990 || gain!=191) $fatal(1,"AE dark limits %d %d",exposure,gain);
 repeat(70000) @(negedge clk);
 if(debug_data[27:16]!==12'h191) $fatal(1,"three-digit G snapshot missing: %h",debug_data[27:16]);
 old_req=req_count;repeat(8) sample(0);
 if(req_count!=old_req) $fatal(1,"AE limit repeated writes");
 old_gain=gain;repeat(10) sample(240);
 if(gain>=old_gain) $fatal(1,"AE bright gain not reduced");
 repeat(220) sample(240);
 if(gain!=16 || exposure!=32) $fatal(1,"AE bright limits %d %d",exposure,gain);
 old_req=req_count;repeat(10) sample(96);
 if(req_count!=old_req) $fatal(1,"AE deadband generated writes");
 repeat(35) sample(0);fps60=1;repeat(100) @(negedge clk);
 if(exposure>1990) $fatal(1,"AE 60 FPS exposure clamp");
 old_req=req_count;repeat(2000) @(negedge clk);
 if(req_count!=old_req) $fatal(1,"AE writes without fresh samples");
 // Real snapshot converter, including four fields and source count bytes.
 repeat(70000) @(negedge clk);
 if(debug_data[67:56]!==12'h000 || debug_data[55:44]!==12'h096 ||
    debug_data[43:28]!==bcd(exposure) || debug_data[27:16]!==bcd(gain)[11:0])
  $fatal(1,"AE snapshot conversion %h exp=%0d gain=%0d",debug_data,exposure,gain);
 $display("PASS AE dark/bright/limits/deadband/no-sample/60FPS/BCD snapshot requests=%0d",req_count);
 $display("PASS tb_v20_ae_latency");$finish;
end
initial begin #100000000; $fatal(1,"timeout");end
endmodule
