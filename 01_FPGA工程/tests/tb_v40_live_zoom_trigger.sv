`timescale 1ns/1ps
module tb_v40_live_zoom_trigger;
reg clk=0;always #5 clk=~clk;
reg rst=0,en=0,td=0,geometry=1,reference_set=1;
reg [1:0] result=2,size_bad=0;reg [2:0] bad=0;
wire request;wire [11:0] sx;wire signed [11:0] sy;
label_application app(.I_clk(clk),.I_rst_n(rst),.I_enable(en),.I_de(1'b0),
 .I_keys_n(4'hf),.I_x(12'd0),.I_y(12'd0),.I_rgb(24'd0),.I_frame_id(24'd0),
 .I_imaging_locked(1'b1),.I_remote_action(3'd0),.I_zoom_supported(1'b1),.I_zoom_active(1'b0),
 .I_zoom_src_x(12'd0),.I_zoom_src_y(12'sd0),
 .O_zoom_request(request),.O_zoom_src_x(sx),.O_zoom_src_y(sy));
task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
task check(input bit expected);
 begin en=0;tick();en=1;tick();td=1;tick();td=0;
  if(request!==expected)$fatal(1,"trigger policy wrong result%0d bad%b size%b geometry%b reference%b",result,bad,size_bad,geometry,reference_set);
  if(expected && (sx!=808 || sy!=170))$fatal(1,"wrong label-centred crop");
 end
endtask
integer i;
initial begin
 force app.state=0;force app.locked=1;force app.target_done=td;
 force app.result=result;force app.fail=bad;force app.size_fail=size_bad;
 force app.geometry=geometry;force app.reference_set=reference_set;
 force app.label_x=1000;force app.label_y=350;
 repeat(3)tick();rst=1;
 for(i=0;i<8;i=i+1)begin bad=i;check(i==4);end
 bad=4;result=1;check(0);result=3;check(0);result=2;
 size_bad=1;check(0);size_bad=0;geometry=0;check(0);geometry=1;
 reference_set=0;check(0);
 $display("PASS tb_v40_live_zoom_trigger: only committed angle-only FAIL triggers; PASS/UNKNOWN/position/mixed/size/invalid geometry/no reference rejected");$finish;
end
endmodule
