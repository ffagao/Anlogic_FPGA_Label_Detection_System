`timescale 1ns/1ps
module tb_v39_tracking_loop;
reg clk=0;always #5 clk=~clk;reg rst=0,start=0,update=0;
reg signed[12:0] e_new=400,e_old=400;
wire[11:0] p_new,p_old;
servo_pan_tracker #(.CLK_MHZ(1)) dut(.I_clk(clk),.I_rst_n(rst),.I_mode(4'd3),.I_zoom_active(1'b0),.I_color(3'd0),.I_shape(2'd1),.I_key_dec(1'b0),.I_key_inc(start),.I_measure_update(update),.I_measure_valid(1'b1),.I_measure_dx(e_new),.I_measure_dy(13'd0),.O_pan_pulse_us(p_new),.I_remote_valid(1'b0),.I_remote_state(3'd0),.I_remote_context(1'b0),.I_measure_large(1'b1));
servo_pan_tracker_v38_baseline #(.CLK_MHZ(1)) old(.I_clk(clk),.I_rst_n(rst),.I_mode(4'd3),.I_zoom_active(1'b0),.I_color(3'd0),.I_shape(2'd1),.I_key_dec(1'b0),.I_key_inc(start),.I_measure_update(update),.I_measure_valid(1'b1),.I_measure_dx(e_old),.I_measure_dy(13'd0),.O_pan_pulse_us(p_old),.I_remote_valid(1'b0),.I_remote_state(3'd0));
real physical_new=1500,physical_old=1500,actual_new,actual_old;
integer qn1=400,qn2=400,qo1=400,qo2=400,i,min_new=400,min_old=400,late_new=0,late_old=0,samples=0;
initial begin
 repeat(5)@(negedge clk);rst=1;repeat(65000)@(negedge clk);start=1;@(negedge clk);start=0;
 // Independent first-order mechanical plant, 10 pixels/us sensitivity,
 // camera 30Hz, two camera frames of measurement transport delay.
 for(i=0;i<1600000;i=i+1)begin
  @(negedge clk);update=0;
  if(i%20000==0)begin
   physical_new=physical_new+0.55*(p_new-physical_new);physical_old=physical_old+0.55*(p_old-physical_old);
   actual_new=400+10*(physical_new-1500);actual_old=400+10*(physical_old-1500);
   if(actual_new<min_new)min_new=$rtoi(actual_new);if(actual_old<min_old)min_old=$rtoi(actual_old);
   if(i>1000000)begin late_new=late_new+$rtoi(actual_new<0?-actual_new:actual_new);late_old=late_old+$rtoi(actual_old<0?-actual_old:actual_old);samples=samples+1;end
  end
  if(i%33333==0)begin
   e_new=qn2;e_old=qo2;qn2=qn1;qo2=qo1;
   qn1=$rtoi(actual_new);qo1=$rtoi(actual_old);
   if(qn1>600)qn1=600;if(qn1< -600)qn1=-600;if(qo1>600)qo1=600;if(qo1< -600)qo1=-600;
   update=1;
  end
 end
 $display("CLOSED LOOP: v39 overshoot=%0dpx lateMean=%0dpx; v38 overshoot=%0dpx lateMean=%0dpx",-min_new,late_new/samples,-min_old,late_old/samples);
 if(min_new< -60 || min_new<min_old/2 || late_new/samples>12)$fatal(1,"near-target delayed closed loop did not improve");
 $display("PASS tb_v39_tracking_loop: real RTL controllers with independent delayed near-target mechanical plant");$finish;
end
initial begin #20000000;$fatal(1,"tracking plant timeout");end
endmodule
