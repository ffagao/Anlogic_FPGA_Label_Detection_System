`timescale 1ns/1ps
module tb_v43_barcode;
 reg clk=0,rst=0,en=0,de=0,pass=0,nextbox=0,key=0,exitkey=0,clear=0;
 reg [11:0] x=0,y=0;reg [23:0] rgb=24'hffffff;
 wire active,ticket,hit;wire [23:0] color;
 always #5 clk=~clk;
 label_barcode_session dut(.clk(clk),.rst_n(rst),.enable(en),.de(de),.x(x),.y(y),.rgb(rgb),
 .pass_locked(pass),.new_cycle(nextbox),.start_scan(key),.exit_scan(exitkey),.clear_count(clear),
 .active(active),.ticket(ticket),.hit(hit),.color(color));
 task tick;begin @(negedge clk);end endtask
 task pulse_key;begin tick();key=1;tick();key=0;tick();end endtask
 task inject(input [23:0] n);begin
  tick();force dut.decoder_hit=1;force dut.payload={56'd0,n};tick();release dut.decoder_hit;release dut.payload;tick();
 end endtask
 initial begin
  repeat(4)tick();rst=1;en=1;repeat(4)tick();pulse_key();if(active)$fatal(1,"scan allowed without PASS");
  pass=1;tick();pass=0;repeat(4)tick();if(!ticket)$fatal(1,"PASS ticket missing");
  pulse_key();if(!active)$fatal(1,"scan did not start");
  inject(24'h100001);if(dut.done)$fatal(1,"single read accepted");
  inject(24'h100002);if(dut.done)$fatal(1,"mismatched read accepted");
  inject(24'h100001);inject(24'h100001);
  if(!dut.done || dut.order!=24'h100001 || dut.counter!=1 || dut.idx!=1)$fatal(1,"matching scan/lookup/count failed");
  inject(24'h100001);if(dut.counter!=1)$fatal(1,"duplicate counted");
  exitkey=1;tick();exitkey=0;tick();pulse_key();if(active)$fatal(1,"reused PASS ticket");
  pass=1;tick();pass=0;tick();nextbox=1;tick();nextbox=0;tick();if(ticket)$fatal(1,"new box did not cancel ticket");
  $display("PASS tb_v43_barcode session gate, matching reads, lookup and count");$finish;
 end
 initial begin #100000;$fatal(1,"timeout");end
endmodule
