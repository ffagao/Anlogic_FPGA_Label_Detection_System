// One manually started Code 128 C scan for the last completed PASS.
module label_barcode_session(
 input wire clk,rst_n,enable,de,input wire [11:0] x,y,input wire [23:0] rgb,
 input wire pass_locked,new_cycle,start_scan,exit_scan,clear_count,
 output reg active,output reg ticket,output wire hit,output wire [23:0] color
 ,output wire O_done,output wire [23:0] O_order,output wire [23:0] O_count
);
 reg seen_pass,done;reg [23:0] order,confirmed,counter;reg first_hit;
 wire decoder_hit,candidate;wire [79:0] payload;
 wire [11:0] left,right,row;wire [15:0] skipped;
 barcode_row_reader #(.WIDTH(1280),.HEIGHT(720),.ROI_L(512)) reader(
  .clk(clk),.rst_n(rst_n),.enable(enable && active && !done),.capture_enable(1'b1),
  .de(de),.fresh_frame(de && x==0 && y==0),.x(x),.y(y),.rgb(rgb),
  .hit(decoder_hit),.candidate(candidate),.payload(payload),.left(left),.right(right),.row(row),.skipped_lines(skipped));
 function [23:0] inc_bcd;
  input [23:0] value;reg [23:0] t;integer i;reg carry;
  begin t=value;carry=1;for(i=0;i<6;i=i+1) if(carry) begin
    if(t[i*4+:4]==9) t[i*4+:4]=0;else begin t[i*4+:4]=t[i*4+:4]+1'b1;carry=0;end
  end inc_bcd=(value==24'h999999) ? value : t;end
 endfunction
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin active<=0;ticket<=0;seen_pass<=0;done<=0;order<=0;counter<=0;first_hit<=0;confirmed<=0;end
  else begin
   seen_pass<=pass_locked;
   if(clear_count) counter<=0;
   if(!enable) begin active<=0;ticket<=0;seen_pass<=0;done<=0;first_hit<=0;end
   else if(exit_scan) begin active<=0;ticket<=0;done<=0;first_hit<=0;end
   else begin
    if(new_cycle && !active) ticket<=0;
    if(pass_locked && !seen_pass) ticket<=1;
    if(start_scan && ticket && !active) begin active<=1;done<=0;first_hit<=0;end
    if(active && !done && decoder_hit) begin
     if(first_hit && confirmed==payload[23:0]) begin
      order<=payload[23:0];done<=1;ticket<=0;counter<=inc_bcd(counter);first_hit<=0;
     end else begin confirmed<=payload[23:0];first_hit<=1;end
    end
   end
  end
 end
 assign O_done=done;
 assign O_order=order;
 assign O_count=counter;
 reg [3:0] idx;reg [143:0] product,brand,owner;
 always @* begin
  idx=0;product="UNKNOWN           ";brand="UNKNOWN           ";owner="UNKNOWN           ";
  case(order)
   24'h100001:begin idx=1;product="SENSOR-A          ";brand="NOVA              ";owner="ALICE             ";end
   24'h100002:begin idx=2;product="CONTROL-B         ";brand="NOVA              ";owner="BOB               ";end
   24'h100003:begin idx=3;product="MOTOR-C           ";brand="NOVA              ";owner="CAROL             ";end
   24'h100004:begin idx=4;product="RELAY-D           ";brand="NOVA              ";owner="DAVID             ";end
   24'h100005:begin idx=5;product="PUMP-E            ";brand="ORBIT             ";owner="ERIN              ";end
   24'h100006:begin idx=6;product="VALVE-F           ";brand="ORBIT             ";owner="FRANK             ";end
   24'h100007:begin idx=7;product="FAN-G             ";brand="ORBIT             ";owner="ALICE             ";end
   24'h100008:begin idx=8;product="DRIVE-H           ";brand="VECTOR            ";owner="BOB               ";end
   24'h100009:begin idx=9;product="METER-I           ";brand="VECTOR            ";owner="CAROL             ";end
   24'h100010:begin idx=10;product="FILTER-J          ";brand="VECTOR            ";owner="DAVID             ";end
   default:;
  endcase
 end
 reg [191:0] line;reg [4:0] line_no,col;reg [7:0] character;integer j;
 always @* begin
  line_no=y>=80 && y<320?(y-80)>>5:31;col=x>=32 && x<416?(x-32)>>4:31;
  line="                        ";
  case(line_no)
   0:line="BARCODE: SCANNING       ";
   1:begin line="ORDER: ------           ";if(done) for(j=0;j<6;j=j+1) line[135-j*8-:8]=8'h30+order[23-j*4-:4];end
   2:begin line="PRODUCT ID: ---         ";if(done && idx!=0) begin line[95:88]="0";line[87:80]=idx==10?"1":"0";line[79:72]=8'h30+(idx==10?0:idx);end end
   3:if(done) line={"NAME: ",product};
   4:if(done) line={"BRAND:",brand};
   5:if(done) line=idx!=0?"DATE: 2026-10-28        ":"DATE: UNKNOWN           ";
   6:if(done) line={"OWNER:",owner};
   7:begin line="SCANNED: 000000         ";for(j=0;j<6;j=j+1) line[119-j*8-:8]=8'h30+counter[23-j*4-:4];end
   default:;
  endcase
  if(line_no==0 && done) line="BARCODE: READ OK        ";
  character=col<24?line[191-col*8-:8]:8'h20;
 end
 wire [15:0] glyph;label_char_lib font(.I_char(character),.I_row(y[3:0]),.O_row_bits(glyph));
 reg [2:0] panel_pipe,pixel_pipe;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin panel_pipe<=0;pixel_pipe<=0;end
  else begin panel_pipe<={panel_pipe[1:0],enable && active && de && x<512};
   pixel_pipe<={pixel_pipe[1:0],glyph[15-x[3:0]] && col<24 && line_no<8};end
 end
 assign hit=panel_pipe[2];assign color=pixel_pipe[2]?24'h40ffb0:24'h101c29;
endmodule
