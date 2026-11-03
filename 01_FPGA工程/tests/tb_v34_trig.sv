module tb_v34_trig;
reg clk=0;always #5 clk=~clk;reg [8:0] angle;wire signed [11:0] c,s,gc,gs;
label_trig_sync dut(clk,angle,c,s);label_trig ref_model(angle,gc,gs);
integer i;
initial begin
 for(i=0;i<512;i=i+1)begin @(negedge clk);angle=i;@(posedge clk);#1;if(c!==gc||s!==gs)$fatal(1,"trig code %d",i);end
 $display("PASS tb_v34_trig: all 512 codes exact");$finish;
end
endmodule
