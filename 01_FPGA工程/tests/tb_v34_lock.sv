`timescale 1ns/1ps
module tb_v34_lock;
reg clk=0;always #5 clk=~clk;reg rst=1,lock=0,done=1,error=0,toggle=0;
reg [7:0] luma=96;wire locked;wire [15:0] exposure,gain;wire req;
ae_set ae(.I_clk(clk),.I_rst(rst),.I_lock(lock),.O_locked(locked),.I_btn(2'b11),.I_fps_60(1'b0),
 .I_frame_luma(luma),.I_luma_toggle(toggle),.I_ae_cfg_done(done),.I_ae_error(error),.I_cam_cfg_done(1'b1),
 .O_ae_req(req),.O_ae(exposure),.O_ag(gain),.O_debug(),.O_debug_toggle());
reg fs=0,divdone=0;reg [19:0] rgain=20'h18000,bgain=20'h14000;
wire awblock;wire [19:0] red,blue;
v34_awb_lock_fixture wb(clk,!rst,lock,fs,divdone,rgain,bgain,awblock,red,blue);
task tick;begin @(negedge clk);end endtask
reg [15:0] saved_exp,saved_gain;
integer i;
initial begin
 repeat(4)tick();rst=0;repeat(4)tick();
 divdone=1;tick();divdone=0;if(red!==rgain||blue!==bgain)$fatal(1,"AWB running gains");
 lock=1;done=0;repeat(20)tick();if(locked)$fatal(1,"AE ack while I2C busy");
 fs=1;tick();fs=0;if(!awblock||red!==rgain||blue!==bgain)$fatal(1,"AWB lock resets preceding gains");
 done=1;repeat(12)tick();if(!locked)$fatal(1,"AE ack absent after quiet completed I2C");
 saved_exp=exposure;saved_gain=gain;luma=0;rgain=20'h28000;bgain=20'h20000;
 for(i=0;i<8;i=i+1)begin toggle=~toggle;divdone=1;repeat(12)tick();divdone=0;fs=1;tick();fs=0;end
 if(exposure!==saved_exp||gain!==saved_gain||red!==20'h18000||blue!==20'h14000)$fatal(1,"imaging changed while locked");
 error=1;tick();if(locked)$fatal(1,"I2C error retains lock ack");error=0;
 lock=0;tick();if(locked)$fatal(1,"AE unlock ack");
 fs=1;tick();fs=0;if(awblock||red!==20'h10000||blue!==20'h10000)$fatal(1,"AWB normal frame reset not restored");
 divdone=1;tick();if(red!==rgain||blue!==bgain)$fatal(1,"AWB resume");
 $display("PASS tb_v34_lock: I2C completion-qualified AE acknowledgment, frame-boundary AWB freeze, gain preservation and resume");$finish;
end
endmodule
