`timescale 1ns/1ps
module tb_v32_zoom_alarm;
reg clk=0;always #5 clk=~clk;
reg rst=0,zoom=0,dec=0;
reg [3:0] mode=2;
wire buzzer,pan,tilt;
servo_pan_tracker #(.CLK_MHZ(1)) dut(.I_clk(clk),.I_rst_n(rst),.I_mode(mode),.I_zoom_active(zoom),
 .I_color(3'd0),.I_shape(2'd1),.I_key_dec(dec),.I_key_inc(1'b0),
 .I_measure_update(1'b0),.I_measure_valid(1'b0),.I_measure_dx(13'sd0),.I_measure_dy(13'sd0),
 .O_pan_pwm(pan),.O_tilt_pwm(tilt),.O_state(),.O_pan_pulse_us(),.O_tilt_pulse_us(),.O_buzzer_n(buzzer));
integer n,toggles=0,last_edge=0;
reg previous;
initial begin
 repeat(5) @(negedge clk);rst=1;repeat(10) @(negedge clk);
 if(!buzzer) $fatal(1,"alarm without zoom");
 zoom=1;previous=0;
 for(n=1;n<=600000;n=n+1) begin
  @(negedge clk);
  if(buzzer!=previous) begin
   if(n-last_edge!=250) $fatal(1,"tone half-period %0d",n-last_edge);
   toggles=toggles+1;last_edge=n;previous=buzzer;
  end
  if(pan || tilt) $fatal(1,"zoom must not drive servo PWM");
  if(n==100000) dec=1;
 end
 if(toggles!=2400) $fatal(1,"continuous alarm stopped after duration counter: toggles=%0d",toggles);
 zoom=0;#1;if(!buzzer) $fatal(1,"alarm after zoom exit");
 repeat(10) @(negedge clk);zoom=1;#1;if(buzzer) $fatal(1,"alarm not restarted");
 mode=3;#1;if(!buzzer) $fatal(1,"alarm after mode exit");
 mode=0;repeat(500) @(negedge clk);if(!buzzer) $fatal(1,"stale zoom flag sounded outside mode2");
 rst=0;#1;if(!buzzer) $fatal(1,"alarm in reset");
 $display("PASS shared 2kHz buzzer: continuous for 600ms-equivalent, no 500ms cutoff, zoom/mode exit, buttons, restart and no servo movement");
 $display("PASS tb_v32_zoom_alarm");$finish;
end
initial begin #10000000;$fatal(1,"alarm timeout");end
endmodule
