// Inputs are already fused from three fresh observations. Each symmetry
// branch compares position AND angle as one coherent candidate.
module label_scene_controller_reference #(parameter integer TIMEOUT_CYCLES=300000000)(
    input wire clk,rst_n,enable,start,learn,ack,clear,sample,valid,
    input wire [3:0] reason,input wire signed [12:0] u,v,
    input wire [12:0] wr,hr,input wire [8:0] alpha,
    input wire [11:0] bx,by,bw,bh,lx,ly,lw,lh,
    input wire [8:0] ba,la,input wire bsquare,lsquare,
    output reg [1:0] state,result,output reg [3:0] cause,
    output reg [2:0] fail,output reg locked,geometry,reference_set,learn_failed,
    output reg [1:0] size_fail,
    output reg O_alarm,muted,
    output reg signed [12:0] ref_u,ref_v,du,dv,
    output reg [12:0] ref_wr,ref_hr,
    output reg [8:0] ref_alpha,output reg ref_square,ref_label_square,
    output reg [11:0] ref_bw,ref_bh,
    output reg signed [9:0] da,
    output reg [11:0] box_x,box_y,box_w,box_h,label_x,label_y,label_w,label_h,
    output reg [8:0] box_a,label_a,output reg box_square,scene,
    output reg [1:0] branch,output reg [1:0] main_item,
    output reg [23:0] total,passes,fails,unknowns);
    reg [28:0] timer;
    reg [11:0] ref_lw,ref_lh;
    reg [3:0] last_reason;reg saw_sample;
    reg [2:0] calc;
    reg [1:0] candidate;
    reg signed [12:0] cu,cv;
    reg signed [10:0] ca,delta_a;
    reg signed [13:0] delta_u,delta_v;
    reg [13:0] abs_u,abs_v;reg [9:0] abs_a;
    reg [27:0] cost_u,cost_v,cost_a,cost,best_cost;
    reg signed [12:0] best_u,best_v;
    reg signed [9:0] best_a;
    reg [2:0] best_fail;
    reg [1:0] best_branch,best_main;
    function size_matches;
        input [11:0] measured,reference;
        reg [11:0] difference;reg [19:0] error_scaled,limit_scaled;
        begin
            difference=measured>=reference?measured-reference:reference-measured;
            error_scaled=difference*100;limit_scaled=reference*15;
            size_matches=error_scaled<=limit_scaled;
        end
    endfunction
    wire wrong_box=!size_matches(bw,ref_bw) || !size_matches(bh,ref_bh);
    wire wrong_label=!size_matches(lw,ref_lw) || !size_matches(lh,ref_lh);
    function [23:0] inc;
        input [23:0] value;integer i;reg carry;
        begin inc=value;carry=1;for(i=0;i<6;i=i+1) if(carry) begin
            if(value[i*4+:4]==9) inc[i*4+:4]=0;
            else begin inc[i*4+:4]=value[i*4+:4]+1'b1;carry=0;end
        end end
    endfunction
    always @(*) begin
        case(candidate)
        0:begin cu=u;cv=v;ca=$signed({1'b0,alpha})-$signed({1'b0,ref_alpha});end
        1:begin cu=v;cv=-u;ca=$signed({1'b0,alpha})-$signed({1'b0,ref_alpha})-180;end
        2:begin cu=-u;cv=-v;ca=$signed({1'b0,alpha})-$signed({1'b0,ref_alpha});end
        default:begin cu=-v;cv=u;ca=$signed({1'b0,alpha})-$signed({1'b0,ref_alpha})-180;end
        endcase
        // Rectangle orientation modulo 180 degrees; square labels modulo 90.
        delta_a=ca;
        if(ca>180) delta_a=ca-360;else if(ca< -180) delta_a=ca+360;
        if(ref_label_square) begin
            if(delta_a>90) delta_a=delta_a-180;else if(delta_a< -90) delta_a=delta_a+180;
        end
        delta_u=$signed(cu)-$signed(ref_u);delta_v=$signed(cv)-$signed(ref_v);
        abs_u=delta_u<0?-delta_u:delta_u;abs_v=delta_v<0?-delta_v:delta_v;
        abs_a=delta_a<0?-delta_a:delta_a;
    end
    task latch_scene;
        begin box_x<=bx;box_y<=by;box_w<=bw;box_h<=bh;box_a<=ba;box_square<=bsquare;
            label_x<=lx;label_y<=ly;label_w<=lw;label_h<=lh;label_a<=la;scene<=1;end
    endtask
    task count_result;
        input [1:0] value;
        begin if(total!=24'h999999) begin total<=inc(total);
            case(value) 1:passes<=inc(passes);2:fails<=inc(fails);default:unknowns<=inc(unknowns);endcase
        end end
    endtask
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=0;result<=0;cause<=0;fail<=0;locked<=0;geometry<=0;reference_set<=0;learn_failed<=0;
            O_alarm<=0;muted<=0;timer<=0;last_reason<=6;saw_sample<=0;calc<=0;candidate<=0;
            size_fail<=0;ref_lw<=0;ref_lh<=0;
            ref_u<=0;ref_v<=0;ref_wr<=0;ref_hr<=0;ref_alpha<=0;ref_square<=0;ref_label_square<=0;
            ref_bw<=512;ref_bh<=256;du<=0;dv<=0;da<=0;branch<=0;main_item<=0;
            box_x<=0;box_y<=0;box_w<=0;box_h<=0;box_a<=0;box_square<=0;scene<=0;
            label_x<=0;label_y<=0;label_w<=0;label_h<=0;label_a<=0;
            total<=0;passes<=0;fails<=0;unknowns<=0;
            best_cost<=28'hfffffff;best_u<=0;best_v<=0;best_a<=0;best_fail<=0;best_branch<=0;best_main<=0;
            cost_u<=0;cost_v<=0;cost_a<=0;cost<=0;
        end else begin
            if(ack) begin O_alarm<=0;muted<=1;end
            if(!enable) begin state<=0;calc<=0;O_alarm<=0;end
            else if(state==0) begin
                if(clear) begin total<=0;passes<=0;fails<=0;unknowns<=0;end
                if(start || learn) begin
                    state<=learn?2:1;timer<=0;saw_sample<=0;last_reason<=6;calc<=0;
                    locked<=0;geometry<=0;result<=0;cause<=0;fail<=0;main_item<=0;
                    O_alarm<=0;muted<=0;learn_failed<=0;size_fail<=0;
                end
            end else begin
                timer<=timer+1'b1;
                if(timer==TIMEOUT_CYCLES-1) begin
                    state<=0;calc<=0;geometry<=0;
                    if(state==2) begin learn_failed<=1;cause<=saw_sample?last_reason:4'd6;end
                    else begin locked<=1;result<=3;cause<=saw_sample?last_reason:4'd6;count_result(3);end
                end else if(calc==0 && sample) begin
                    saw_sample<=1;last_reason<=valid?4'd4:reason;
                    if(valid) begin
                        if(state==2) begin
                            ref_u<=u;ref_v<=v;ref_wr<=wr;ref_hr<=hr;ref_alpha<=alpha;
                            ref_square<=bsquare;ref_label_square<=lsquare;ref_bw<=bw;ref_bh<=bh;
                            ref_lw<=lw;ref_lh<=lh;reference_set<=1;state<=0;latch_scene;
                        end else if(!reference_set) begin
                            state<=0;locked<=1;result<=3;cause<=11;count_result(3);
                        end else if(wrong_box || wrong_label) begin
                            size_fail<={wrong_label,wrong_box};state<=0;locked<=1;result<=2;geometry<=0;
                            O_alarm<=!ack && !muted;count_result(2);latch_scene;
                        end else begin calc<=1;candidate<=0;best_cost<=28'hfffffff;latch_scene;end
                    end
                end else case(calc)
                // Golden V5.3 arithmetic with only the intended 16px/4deg gate.
                1:begin cost_u<=abs_u*ref_bw*5;cost_v<=abs_v*ref_bh*5;cost_a<=abs_a*10240;calc<=2;end
                2:begin cost<=cost_u>cost_v?(cost_u>cost_a?cost_u:cost_a):(cost_v>cost_a?cost_v:cost_a);calc<=3;end
                3:begin
                    if(cost<best_cost) begin
                        best_cost<=cost;best_u<=delta_u;best_v<=delta_v;best_a<=delta_a;best_branch<=candidate;
                        best_fail<={cost_a>81920,cost_v>81920,cost_u>81920};
                        best_main<=cost<=81920?0:(cost_a>=cost_u && cost_a>=cost_v?3:(cost_v>cost_u?2:1));
                    end
                    if(candidate==(ref_square?3:2)) calc<=4;
                    else begin candidate<=ref_square?candidate+1'b1:2;calc<=1;end
                end
                4:begin
                    du<=best_u;dv<=best_v;da<=best_a;branch<=best_branch;main_item<=best_main;
                    fail<=best_fail;result<=best_fail?2:1;locked<=1;geometry<=1;
                    state<=0;calc<=0;cause<=0;O_alarm<=|best_fail && !ack && !muted;
                    count_result(best_fail?2:1);
                end
                default:;
                endcase
            end
        end
    end
endmodule
