// Official HX1P35A example wiring: active-low SEL and {dp,g,f,e,d,c,b,a} DIG.
// Results stay visible until the next operation. FAIL sounds once for 200 ms.
module label_result_io #(
    parameter integer BEEP_CYCLES=15000000,TONE_CYCLES=18750,SCAN_CYCLES=75000
)(input wire clk,rst_n,enable,locked,muted,input wire [1:0] result,
  output wire buzzer_n,beeping,output reg [7:0] seg_sel,seg_dig);
    localparam NB=BEEP_CYCLES<2?1:$clog2(BEEP_CYCLES+1);
    localparam NT=TONE_CYCLES<2?1:$clog2(TONE_CYCLES+1);
    localparam NS=SCAN_CYCLES<2?1:$clog2(SCAN_CYCLES+1);
    reg [NB-1:0] remaining;
    reg [NT-1:0] tone_count;
    reg tone,was_locked;
    reg [NS-1:0] scan_count;
    reg [2:0] digit;
    reg [7:0] pattern;
    always @(*) begin
        pattern=8'hff;
        case(result)
        1:case(digit) 3:pattern=8'h8c;2:pattern=8'h88;1,0:pattern=8'h92;default:;endcase // right-aligned PASS
        2:case(digit) 3:pattern=8'h8e;2:pattern=8'h88;1:pattern=8'hf9;0:pattern=8'hc7;default:;endcase // FAIL
        3:case(digit) 1:pattern=8'hc1;0:pattern=8'hc8;default:;endcase // full-height U/N approximation
        default:;
        endcase
    end
    assign beeping=enable && remaining!=0 && !muted;
    assign buzzer_n=!(beeping && tone);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin remaining<=0;tone_count<=0;tone<=0;was_locked<=0;end
        else begin
            // Remember the held result across mode exit; it is not a new FAIL.
            was_locked<=locked;
            if(!enable || !locked || result!=2 || muted) begin remaining<=0;tone_count<=0;tone<=0;end
            else if(!was_locked) begin remaining<=BEEP_CYCLES;tone_count<=0;tone<=0;end
            else if(remaining!=0) begin
                remaining<=remaining-1'b1;
                if(tone_count==TONE_CYCLES-1) begin tone_count<=0;tone<=~tone;end
                else tone_count<=tone_count+1'b1;
            end else begin tone_count<=0;tone<=0;end
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin scan_count<=0;digit<=0;seg_sel<=8'hff;seg_dig<=8'hff;end
        else if(!enable || !locked || result==0) begin scan_count<=0;digit<=0;seg_sel<=8'hff;seg_dig<=8'hff;end
        else begin
            if(scan_count==SCAN_CYCLES-1) begin scan_count<=0;digit<=digit==5?0:digit+1'b1;end
            else scan_count<=scan_count+1'b1;
            // Blank a clock before updating segments, then enable one digit.
            if(scan_count==0) begin seg_sel<=8'hff;seg_dig<=8'hff;end
            else if(scan_count==1) seg_dig<=pattern;
            else if(scan_count==2) seg_sel<=pattern==8'hff ? 8'hff : ~(8'b1<<digit);
        end
    end
endmodule
