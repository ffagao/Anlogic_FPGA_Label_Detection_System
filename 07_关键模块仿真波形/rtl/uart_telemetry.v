// 115200 8N1, 10 Hz snapshots.
// Version 2 extends the original 18-byte motion/latency frame with label
// result, failure cause, PASS/FAIL/UNKNOWN counters and barcode data.
module uart_telemetry #(parameter integer CLOCK_HZ=75000000,BAUD=115200,REPORT_CYCLES=7500000)(
 input wire clk,rst_n,input wire [3:0] mode,input wire region_valid,region_overflow,
 input wire [4:0] regions,input wire [7:0] fps_bcd,delay_bcd,
 input wire [23:0] capture_bcd,display_bcd,input wire [15:0] blocks_bcd,
 input wire label_valid,input wire [1:0] label_result,input wire [3:0] label_cause,
 input wire [23:0] label_passes,label_fails,label_unknowns,
 input wire barcode_valid,input wire [23:0] barcode_order,barcode_count,
 output wire tx);
 localparam integer BAUD_DIV=(CLOCK_HZ+BAUD/2)/BAUD;
 localparam integer FRAME_BYTES=36;
 reg [31:0] period,baud_timer;reg [7:0] seq;
 reg [7:0] bytes[0:FRAME_BYTES-1];reg [5:0] index;reg [3:0] bit_index;reg [9:0] shift;
 reg busy;assign tx=busy?shift[0]:1'b1;
 wire [7:0] flags={4'd0,barcode_valid,label_valid,region_overflow,region_valid};
 wire [7:0] crc=8'h02 ^ seq ^ {4'd0,mode} ^ flags ^ {3'd0,regions} ^ fps_bcd ^ delay_bcd ^
   capture_bcd[23:16] ^ capture_bcd[15:8] ^ capture_bcd[7:0] ^
   display_bcd[23:16] ^ display_bcd[15:8] ^ display_bcd[7:0] ^
   blocks_bcd[15:8] ^ blocks_bcd[7:0] ^ {6'd0,label_result} ^ {4'd0,label_cause} ^
   label_passes[23:16] ^ label_passes[15:8] ^ label_passes[7:0] ^
   label_fails[23:16] ^ label_fails[15:8] ^ label_fails[7:0] ^
   label_unknowns[23:16] ^ label_unknowns[15:8] ^ label_unknowns[7:0] ^
   barcode_order[23:16] ^ barcode_order[15:8] ^ barcode_order[7:0] ^
   barcode_count[23:16] ^ barcode_count[15:8] ^ barcode_count[7:0];
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n)begin period<=0;baud_timer<=0;seq<=0;index<=0;bit_index<=0;shift<=10'h3ff;busy<=0;end
  else begin
   if(period<REPORT_CYCLES-1)period<=period+1'b1;
   else if(!busy)begin
    period<=0;bytes[0]<=8'ha5;bytes[1]<=8'h5a;bytes[2]<=8'h02;bytes[3]<=seq;
    bytes[4]<={4'd0,mode};bytes[5]<=flags;bytes[6]<={3'd0,regions};bytes[7]<=fps_bcd;bytes[8]<=delay_bcd;
    bytes[9]<=capture_bcd[23:16];bytes[10]<=capture_bcd[15:8];bytes[11]<=capture_bcd[7:0];
    bytes[12]<=display_bcd[23:16];bytes[13]<=display_bcd[15:8];bytes[14]<=display_bcd[7:0];
    bytes[15]<=blocks_bcd[15:8];bytes[16]<=blocks_bcd[7:0];
    bytes[17]<={6'd0,label_result};bytes[18]<={4'd0,label_cause};
    bytes[19]<=label_passes[23:16];bytes[20]<=label_passes[15:8];bytes[21]<=label_passes[7:0];
    bytes[22]<=label_fails[23:16];bytes[23]<=label_fails[15:8];bytes[24]<=label_fails[7:0];
    bytes[25]<=label_unknowns[23:16];bytes[26]<=label_unknowns[15:8];bytes[27]<=label_unknowns[7:0];
    bytes[28]<=barcode_order[23:16];bytes[29]<=barcode_order[15:8];bytes[30]<=barcode_order[7:0];
    bytes[31]<=barcode_count[23:16];bytes[32]<=barcode_count[15:8];bytes[33]<=barcode_count[7:0];
    bytes[34]<=8'd0;bytes[35]<=crc;
    seq<=seq+1'b1;index<=0;bit_index<=0;baud_timer<=0;shift<={1'b1,8'ha5,1'b0};busy<=1;
   end
   if(busy) begin
    if(baud_timer==BAUD_DIV-1)begin
     baud_timer<=0;
     if(bit_index==9)begin
      bit_index<=0;
      if(index==FRAME_BYTES-1)begin busy<=0;shift<=10'h3ff;end
      else begin index<=index+1'b1;shift<={1'b1,bytes[index+1'b1],1'b0};end
     end else begin bit_index<=bit_index+1'b1;shift<={1'b1,shift[9:1]};end
    end else baud_timer<=baud_timer+1'b1;
   end
  end
 end
endmodule
