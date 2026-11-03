// V42: camera-side pixels, before any display overlay. Numeric Code 128 C.
// Payload: exactly six numeric digits containing the unique order number.
module barcode_row_reader #(
    parameter WIDTH=1920,HEIGHT=1080,ROI_L=512,SCAN_STEP=8,SCAN_OFFSET=4
)(input wire clk,rst_n,enable,capture_enable,de,fresh_frame,
  input wire [11:0] x,y,input wire [23:0] rgb,
  output reg hit,candidate,output reg [79:0] payload,
  output reg [11:0] left,right,row,
  output reg [15:0] skipped_lines);
    // One sampled scan line; decoded in the following seven video rows.
    (* ram_style="block" *) reg [11:0] runs[0:2047];
    reg [10:0] wr,rd;
    reg [11:0] count;
    reg [10:0] run_width;
    reg previous_black,collecting,ready,flush;
    reg [11:0] sampled_y;
    reg [11:0] ram_q;
    reg [4:0] state;
    reg [11:0] decoded_y,cursor,start_x,stop_x;
    reg [10:0] history[0:6];
    reg [3:0] filled;
    reg [2:0] chunk,norm_index;
    reg [13:0] total;
    reg [17:0] pattern;
    reg [2:0] quant_q;
    reg [17:0] measured_q;
    reg norm_bad,locked;
    reg [3:0] data_index,add_left;
    reg [6:0] checksum,add_code;
    reg [1:0] finish;
    reg [79:0] data;
    wire [9:0] luma_sum={2'b0,rgb[23:16]}+{1'b0,rgb[15:8],1'b0}+{2'b0,rgb[7:0]};
    wire [7:0] luma=luma_sum[9:2];
    reg [7:0] threshold,line_min,line_max;
    wire [8:0] midpoint={1'b0,line_min}+{1'b0,line_max};
    wire black=luma<threshold;
    wire accept=state==0 && ready;
    integer i;
    always @(posedge clk) ram_q<=runs[rd];
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin wr<=0;count<=0;run_width<=0;previous_black<=0;
            collecting<=0;ready<=0;flush<=0;sampled_y<=0;skipped_lines<=0;
            threshold<=110;line_min<=255;line_max<=0;end
        else begin
            if(accept) ready<=0;
            if(de && x>=ROI_L) begin
                if(x==ROI_L) begin line_min<=luma;line_max<=luma;end
                else begin if(luma<line_min) line_min<=luma;if(luma>line_max) line_max<=luma;end
                if(x==WIDTH-1 && line_max-line_min>=32) threshold<=midpoint[8:1];
            end
            if(!enable || fresh_frame) begin collecting<=0;ready<=0;flush<=0;end
            else if(flush) begin
                runs[wr]<={previous_black,run_width};count<=wr+1'b1;ready<=1;flush<=0;
            end else if(capture_enable && de && x==ROI_L && y%SCAN_STEP==SCAN_OFFSET) begin
                if(state==0 && !ready) begin wr<=0;run_width<=1;previous_black<=black;
                    collecting<=1;sampled_y<=y;end
                else begin collecting<=0;skipped_lines<=skipped_lines+1'b1;end
            end else if(collecting && de) begin
                if(black!=previous_black) begin
                    runs[wr]<={previous_black,run_width};wr<=wr+1'b1;
                    previous_black<=black;run_width<=1;
                end else run_width<=run_width+1'b1;
                if(x==WIDTH-1) begin collecting<=0;flush<=1;end
            end
        end
    end
    wire [17:0] width22=history[norm_index+1'b1]*6'd22;
    wire [17:0] total3=total*4'd3,total5=total*4'd5,total7=total*4'd7;
    wire [2:0] quant=width22<total3?3'd1:(width22<total5?3'd2:(width22<total7?3'd3:3'd4));
    wire [17:0] ideal=total*quant_q;
    wire [17:0] measured=history[norm_index+1'b1]*4'd11;
    wire [17:0] error=measured_q>ideal?measured_q-ideal:ideal-measured_q;
    wire [13:0] sum6={3'd0,history[1]}+history[2]+history[3]+history[4]+history[5]+history[6];
    wire [7:0] symbol;
    barcode_code128_pattern lookup(.pattern(pattern),.symbol(symbol));
    wire [7:0] added={1'b0,checksum}+{1'b0,add_code};
    wire [3:0] pair_hi=symbol/10,pair_lo=symbol%10;
    wire [13:0] final_scaled=ram_q[10:0]*4'd11;
    wire [14:0] final_error=final_scaled>{total,1'b0}?final_scaled-{total,1'b0}:{total,1'b0}-final_scaled;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=0;rd<=0;decoded_y<=0;cursor<=0;start_x<=0;stop_x<=0;
            filled<=0;chunk<=0;norm_index<=0;total<=0;pattern<=0;norm_bad<=0;quant_q<=0;measured_q<=0;
            locked<=0;data_index<=0;checksum<=0;add_left<=0;add_code<=0;
            finish<=0;data<=0;hit<=0;candidate<=0;payload<=0;left<=0;right<=0;row<=0;
            for(i=0;i<7;i=i+1) history[i]<=0;
        end else begin
            hit<=0;candidate<=0;
            if(!enable || fresh_frame) begin state<=0;locked<=0;finish<=0;end
            else case(state)
            0:if(ready) begin rd<=0;cursor<=ROI_L;decoded_y<=sampled_y;filled<=0;chunk<=0;
                locked<=0;finish<=0;state<=1;end
            1:state<=2;
            2:begin
                cursor<=cursor+ram_q[10:0];
                for(i=0;i<6;i=i+1) history[i]<=history[i+1];
                history[6]<=ram_q[10:0];
                if(filled<7) filled<=filled+1'b1;
                if(finish==1) begin
                    if(ram_q[11] && {final_error,1'b0}<=total) finish<=2;
                    else begin finish<=0;locked<=0;end
                    state<=8;
                end else if(finish==2) begin
                    if(!ram_q[11] && ram_q[10:0]*11>=total*10) begin
                        hit<=1;payload<=data;left<=start_x;right<=stop_x;row<=decoded_y;
                    end
                    finish<=0;locked<=0;state<=8;
                end else if(!ram_q[11] && filled>=6 && (!locked || chunk==5)) begin
                    chunk<=0;state<=3;
                end else begin if(locked) chunk<=chunk+1'b1;state<=8;end
            end
            3:begin total<=sum6;norm_index<=0;pattern<=0;norm_bad<=0;state<=4;end
            4:begin
                // Break the two serial DSP/comparison cones at the quantizer.
                quant_q<=quant;measured_q<=measured;state<=7;
            end
            7:begin
                pattern<={pattern[14:0],quant_q};
                if({error,1'b0}>total || total<16) norm_bad<=1;
                if(norm_index==5) state<=5;else norm_index<=norm_index+1'b1;
                if(norm_index!=5) state<=4;
            end
            5:begin
                state<=8;
                if(norm_bad || symbol==255) begin locked<=0;chunk<=0;end
                else if(!locked) begin
                    if(symbol==105 && history[0]*11>=total*10) begin
                        locked<=1;data<=0;data_index<=0;checksum<=2;
                        start_x<=cursor-total;candidate<=1;left<=cursor-total;
                        right<=cursor+total*12;row<=decoded_y;
                    end
                end else if(data_index<3) begin
                    if(symbol<100) begin
                        data<={data[71:0],pair_hi,pair_lo};
                        data_index<=data_index+1'b1;add_code<=symbol[6:0];
                        add_left<=data_index+1'b1;state<=6;
                    end else locked<=0;
                end else if(data_index==3) begin
                    if(symbol==checksum) data_index<=11;else locked<=0;
                end else if(symbol==106) begin finish<=1;stop_x<=cursor+(total*2)/11;end
                else locked<=0;
            end
            6:begin
                checksum<=added>=103?added-103:added;
                if(add_left==1) state<=8;else add_left<=add_left-1'b1;
            end
            8:if(rd+1>=count) state<=0;else begin rd<=rd+1'b1;state<=1;end
            default:state<=0;
            endcase
        end
    end
endmodule
