`timescale 1ns/1ps
module tb_v37_result_display;
reg clk=0;always #5 clk=~clk;reg rst=0;reg[3:0] mode=5;reg[1:0] raw_result=0;reg locked=0;
wire[1:0] result;wire[7:0] seg,dig;
label_application #(.KEY_DEBOUNCE(1)) app(.I_clk(clk),.I_rst_n(rst),.I_enable(mode==5),.I_de(1'b0),.I_keys_n(4'hf),
 .I_x(12'd0),.I_y(12'd0),.I_rgb(24'd0),.I_frame_id(24'd0),.I_remote_action(3'd0),.I_imaging_locked(1'b0),
 .O_imaging_lock(),.O_hit(),.O_color(),.O_buzzer_n(),.O_seg_sel(),.O_seg_dig(),.O_display_result(result));
switch_state_display dut(clk,rst,mode,result,seg,dig);
integer r,n,j,seen;reg[7:0] expected,active;
function [7:0] glyph(input integer value,index);begin
 glyph=8'hff;
 if(index<4)glyph=mode[3-index]?8'hf9:8'hc0;
 else if(mode==5)case(value)
 1:case(index)4:glyph=8'h8c;5:glyph=8'h88;6,7:glyph=8'h92;endcase
 2:case(index)4:glyph=8'h8e;5:glyph=8'h88;6:glyph=8'hf9;7:glyph=8'hc7;endcase
 3:case(index)4:glyph=8'hc1;5:glyph=8'hc8;endcase
 endcase
end endfunction
task fullscan(input integer value);begin
 wait(dut.scan==0);repeat(3)@(negedge clk);seen=0;
 repeat(131072)begin @(negedge clk);
  if(dig!=8'hff)begin
   active=~dig;if((active & (active-8'd1))!=0)$fatal(1,"multiple enabled digits");
   for(j=0;j<8;j=j+1)if(!dig[j])begin
    expected=glyph(value,j);if(seg!==expected)$fatal(1,"glyph/order result%d digit%d got%h expected%h",value,j,seg,expected);
    seen=seen|(1<<j);
   end
  end
  if(dut.scan[13:0]==1 && dig!=8'hff)$fatal(1,"digit blanking absent");
 end
 if((seen&15)!=15)$fatal(1,"mode digits missing");
 if(mode==5 && value==1 && seen!=255)$fatal(1,"PASS digits missing");
 if(mode==5 && value==2 && seen!=255)$fatal(1,"FAIL digits missing");
 if(mode==5 && value==3 && seen!=63)$fatal(1,"UN digits missing");
 if((mode!=5 || value==0) && seen!=15)$fatal(1,"idle result not blank");
end endtask
initial begin
 repeat(5)@(negedge clk);rst=1;
 force app.controller.result=raw_result;force app.controller.locked=locked;
 fullscan(0);locked=1;
 for(r=1;r<=3;r=r+1)begin raw_result=r;repeat(3)@(negedge clk);if(result!=r)$fatal(1,"application result route");fullscan(r);end
 // Change held result mid-scan: the current frame must keep one word.
 raw_result=1;wait(dut.scan==17'h1ffff);@(negedge clk);wait(dut.scan==17'h8003);raw_result=2;
 while(dut.scan<17'h1fffe)begin @(negedge clk);for(j=4;j<8;j=j+1)if(!dig[j] && seg!==glyph(1,j))$fatal(1,"mixed result snapshot");end
 fullscan(2);mode=3;repeat(3)@(negedge clk);if(result!=0)$fatal(1,"result leaked after mode exit");fullscan(0);
 mode=5;locked=0;fullscan(0);
 $display("PASS tb_v37_result_display: application result to one 8-digit scanner,0101+PASS/FAIL/UN,blank idle,mode exit,polarity,blanking and coherent words");$finish;
end
initial begin #30000000;$fatal(1,"result display timeout");end
endmodule
