`timescale 1ns/1ps
module tb_uart_telemetry;
 reg clk=0,rst=0;wire tx;reg [7:0] data[0:35];integer i,j;reg [7:0] checksum;
 always #5 clk=~clk;
 uart_telemetry #(.CLOCK_HZ(1000),.BAUD(100),.REPORT_CYCLES(3000)) dut(
 .clk(clk),.rst_n(rst),.mode(4'd2),.region_valid(1'b1),.region_overflow(1'b0),.regions(5'd3),
 .fps_bcd(8'h30),.delay_bcd(8'h02),.capture_bcd(24'h001234),.display_bcd(24'h001232),.blocks_bcd(16'h0123),
 .label_valid(1'b1),.label_result(2'd2),.label_cause(4'd4),.label_passes(24'h000123),.label_fails(24'h000004),
 .label_unknowns(24'h000001),.barcode_valid(1'b1),.barcode_order(24'h100003),.barcode_count(24'h000006),.tx(tx));
 initial begin
  repeat(4)@(negedge clk);rst=1;
  for(i=0;i<36;i=i+1)begin
   @(negedge tx);repeat(5)@(posedge clk);
   if(tx!==0)$fatal(1,"bad start %0d",i);
   for(j=0;j<8;j=j+1)begin repeat(10)@(posedge clk);data[i][j]=tx;end
   repeat(10)@(posedge clk);if(tx!==1)$fatal(1,"bad stop %0d",i);
  end
  checksum=0;for(i=2;i<35;i=i+1)checksum=checksum^data[i];
  if(data[0]!=8'ha5 || data[1]!=8'h5a || data[2]!=2 || data[4]!=2 || data[5]!=8'h0d || data[6]!=3 ||
     data[7]!=8'h30 || data[8]!=8'h02 || data[9]!=0 || data[10]!=8'h12 || data[11]!=8'h34 ||
     data[12]!=0 || data[13]!=8'h12 || data[14]!=8'h32 || data[15]!=8'h01 || data[16]!=8'h23 ||
     data[17]!=2 || data[18]!=4 || data[19]!=0 || data[20]!=1 || data[21]!=8'h23 ||
     data[22]!=0 || data[23]!=0 || data[24]!=4 || data[25]!=0 || data[26]!=0 || data[27]!=1 ||
     data[28]!=8'h10 || data[29]!=0 || data[30]!=3 || data[31]!=0 || data[32]!=0 || data[33]!=6 ||
     checksum!=data[35])
     $fatal(1,"bad payload/checksum got=%h expected=%h",data[35],checksum);
  $display("PASS UART telemetry v2 8N1 framing and checksum");$finish;
 end
 initial begin #2000000;$fatal(1,"timeout");end
endmodule
