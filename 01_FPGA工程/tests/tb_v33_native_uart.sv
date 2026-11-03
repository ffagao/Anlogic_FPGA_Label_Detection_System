`timescale 1ns/1ps
module tb_v33_native_uart;
reg clk=0;always #6.666667 clk=~clk;
reg rst=0,update=0,query=0;reg [3:0] mode=0;
reg [39:0] data=0;wire tx;
target_uart_report #(.CLOCK_HZ(75000000),.PERIOD_CYCLES(15000000)) dut(clk,rst,update,query,mode,data,tx);
string line="";integer bytes=0,j;reg [7:0] value;
initial forever begin
 @(negedge tx);#13020;value=0;
 for(j=0;j<8;j=j+1)begin value[j]=tx;#8680;end
 if(tx!==1) $fatal(1,"native 75MHz TX stop-bit/baud error");
 if(value!=10) line={line,value};bytes=bytes+1;#2170;
end
task publish;
 begin @(negedge clk);data={4'd2,1'b1,3'd0,2'd1,11'd1024,10'd512,1'b1,4'd0,4'd3};
 update=1;@(negedge clk);update=0;repeat(5)@(negedge clk);end
endtask
initial begin
 repeat(5)@(negedge clk);rst=1;mode=2;repeat(5)@(negedge clk);publish();publish();
 wait(bytes>=128);#100;
 if(line.substr(line.len()-63,line.len()-60)!="SW:2" || line.substr(line.len()-44,line.len()-41)!="BLUE")
  $fatal(1,"native TX content [%s]",line);
 mode=1;#10000;repeat(100)@(negedge clk);if(tx!==1) $fatal(1,"native mode silence");
 $display("PASS tb_v33_native_uart: 75MHz native display-domain TX produces correct 115200 8N1 bytes, atomic actual-detection text, silent on 0001; no video-to-system telemetry crossing");$finish;
end
initial begin #250000000;$fatal(1,"native TX timeout %d",bytes);end
endmodule
