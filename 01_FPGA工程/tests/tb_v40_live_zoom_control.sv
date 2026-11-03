`timescale 1ns/1ps
module tb_v40_live_zoom_control;
reg clk=0;always #5 clk=~clk;
reg rst=0,en=1,support=1,active=0,fs=0,trigger=0,bg=0,clear=0;
reg [2:0] keys=0;reg [11:0] lx=1000,ly=20;
wire request,background;wire [2:0] press;wire [11:0] sx;wire signed [11:0] sy;
label_zoom_control dut(.clk(clk),.rst_n(rst),.enable(en),.supported(support),
 .view_active(active),.frame_start(fs),.trigger(trigger),.label_x(lx),.label_y(ly),
 .press_in(keys),.background_in(bg),.clear_in(clear),.press_out(press),
 .background_out(background),.request(request),.source_x(sx),.source_y(sy));
task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
task zoom;
begin trigger=1;tick();trigger=0;active=1;
 if(!request || sx!=808 || sy!=-160)$fatal(1,"live crop trigger failed");end
endtask
initial begin
 repeat(3)tick();rst=1;tick();zoom();
 lx=1100;ly=500;repeat(10)begin fs=1;tick();fs=0;tick();end
 if(!request || sx!=808 || sy!=-160)$fatal(1,"locked crop changed without detection");
 keys=4;#1;if(press!=4)$fatal(1,"K3 mute not passed through");tick();keys=0;
 if(!request)$fatal(1,"K3 exited live zoom");
 keys=1;#1;if(press[0])$fatal(1,"check ran on zoomed pixels");tick();keys=0;
 if(request)$fatal(1,"next check did not request original view immediately");
 trigger=1;tick();trigger=0;if(request)$fatal(1,"old target completion reopened zoom during restoration");
 fs=1;#1;if(press[0])$fatal(1,"operation before actual original view");tick();fs=0;
 active=0;repeat(3)tick();if(press[0])$fatal(1,"operation before original-view frame boundary");
 fs=1;#1;if(press!=1)$fatal(1,"pending check not dispatched");tick();fs=0;tick();
 if(press || dut.restoring)$fatal(1,"check repeated");
 lx=1000;ly=20;zoom();keys=1;tick();keys=0;bg=1;tick();bg=0;
 active=0;fs=1;#1;if(!background || press[0])$fatal(1,"latest operation was not background");tick();fs=0;tick();
 zoom();clear=1;tick();clear=0;active=0;fs=1;#1;
 if(background || press[1:0])$fatal(1,"clear should exit without an image operation");tick();fs=0;tick();
 zoom();keys=2;tick();keys=0;en=0;tick();en=1;active=0;fs=1;#1;
 if(press || background || request)$fatal(1,"mode exit retained pending work");tick();fs=0;
 support=0;keys=3;bg=1;#1;if(press!=3 || !background)$fatal(1,"legacy passthrough failed");
 $display("PASS tb_v40_live_zoom_control: fixed crop, live-video request held, mute, one-shot original-view check, latest operation, clear/mode cancellation and legacy passthrough");$finish;
end
endmodule
