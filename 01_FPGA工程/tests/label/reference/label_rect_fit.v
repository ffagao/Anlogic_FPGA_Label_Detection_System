// Minimum-area rectangle from full-resolution row endpoints. Coarse 2-degree
// search, then half-degree refinement; one shared projector, no frame rotation.
module label_rect_fit_reference #(parameter integer HEIGHT=720,BAD_POINT_FACTOR=5,REGION_VALIDATED=0)(
    input wire clk,rst_n,start,abort,
    input wire [4:0] edge_tolerance,input wire relaxed_box,label_mode,
    output reg [9:0] row_addr,input wire [11:0] left_x,right_x,
    output reg done,valid,output reg [11:0] cx,cy,w,h,
    output reg [8:0] angle,output reg square,
    output reg [31:0] area_pixels,
    output wire [11:0] points_count,bad_points_count);
    reg [3:0] state;
    reg [7:0] theta,best_theta;
    reg fine,verify;reg [3:0] refine;
    reg [7:0] refine_start;
    reg signed [23:0] pmin,pmax,qmin,qmax,bpmin,bpmax,bqmin,bqmax,pp,qq;
    reg signed [23:0] pmin2,pmax2,qmin2,qmax2;
    reg [31:0] best_area;
    reg [11:0] points,bad_points;
    assign points_count=points;
    assign bad_points_count=bad_points;
    wire signed [11:0] c,s;
    reg signed [12:0] pc,qc;
    label_trig trig(.angle({1'b0,theta}),.c(c),.s(s));
    wire signed [12:0] point_x=state==12?pc:((state==5)?$signed({1'b0,right_x}):$signed({1'b0,left_x}));
    wire signed [12:0] point_y=state==12?qc:$signed({1'b0,row_addr});
    wire signed [11:0] ss=state==12?-s:s;
    wire signed [13:0] xy=point_x+point_y;
    wire signed [12:0] ms=-ss-c,mc=c-ss;
    wire signed [26:0] k1=xy*c,k2=point_x*ms,k3=point_y*mc;
    wire signed [26:0] p=k1-k3,q=k1+k2;
    // Robust mode (historical port name relaxed_box) is used for box and label.
    // Discard an extreme only when its gap exceeds the trimming limit.
    // Preserve true corners and repeated extrema on clean/small rectangles.
    wire [23:0] edge_limit={9'd0,edge_tolerance,10'd0};
    // Keep isolated-outlier trimming at eight pixels for the wider label mode.
    wire [23:0] trim_limit=label_mode?24'd8192:edge_limit;
    wire [23:0] pmin_gap=pmin2-pmin,pmax_gap=pmax-pmax2;
    wire [23:0] qmin_gap=qmin2-qmin,qmax_gap=qmax-qmax2;
    wire signed [23:0] chosen_pmin=relaxed_box && pmin_gap>trim_limit?pmin2:pmin;
    wire signed [23:0] chosen_pmax=relaxed_box && pmax_gap>trim_limit?pmax2:pmax;
    wire signed [23:0] chosen_qmin=relaxed_box && qmin_gap>trim_limit?qmin2:qmin;
    wire signed [23:0] chosen_qmax=relaxed_box && qmax_gap>trim_limit?qmax2:qmax;
    wire [23:0] pd=chosen_pmax-chosen_pmin,qd=chosen_qmax-chosen_qmin;
    wire [13:0] pw=pd>>8,qw=qd>>8;
    wire [27:0] candidate_area=pw*qw;
    wire [23:0] ep0=pp-bpmin,ep1=bpmax-pp,eq0=qq-bqmin,eq1=bqmax-qq;
    wire signed [24:0] dp0={pp[23],pp}-{bpmin[23],bpmin},dp1={bpmax[23],bpmax}-{pp[23],pp};
    wire signed [24:0] dq0={qq[23],qq}-{bqmin[23],bqmin},dq1={bqmax[23],bqmax}-{qq[23],qq};
    wire signed [24:0] signed_limit={1'b0,edge_limit};
    wire outside_box=dp0< -signed_limit || dp1< -signed_limit || dq0< -signed_limit || dq1< -signed_limit;
    wire far_edge=relaxed_box?(outside_box || (dp0>signed_limit && dp1>signed_limit && dq0>signed_limit && dq1>signed_limit)):
                              (ep0>edge_limit && ep1>edge_limit && eq0>edge_limit && eq1>edge_limit);
    wire bad_ratio_ok=relaxed_box?bad_points*5<=(label_mode?points*3:points*2):bad_points*BAD_POINT_FACTOR<=points;
    wire [23:0] bpd=bpmax-bpmin,bqd=bqmax-bqmin;
    wire [11:0] bw=(bpd+1023)>>10,bh=(bqd+1023)>>10;
    task reset_extents;
        begin pmin<=24'sh7fffff;pmax<=-24'sh7fffff;qmin<=24'sh7fffff;qmax<=-24'sh7fffff;
              pmin2<=24'sh7fffff;pmax2<=-24'sh7fffff;qmin2<=24'sh7fffff;qmax2<=-24'sh7fffff;
              points<=0;bad_points<=0;row_addr<=0;end
    endtask
    task accumulate;
        begin
            if(pp<pmin) begin pmin2<=pmin;pmin<=pp;end else if(pp<pmin2) pmin2<=pp;
            if(pp>pmax) begin pmax2<=pmax;pmax<=pp;end else if(pp>pmax2) pmax2<=pp;
            if(qq<qmin) begin qmin2<=qmin;qmin<=qq;end else if(qq<qmin2) qmin2<=qq;
            if(qq>qmax) begin qmax2<=qmax;qmax<=qq;end else if(qq>qmax2) qmax2<=qq;
            points<=points+1'b1;
            if(verify && far_edge) bad_points<=bad_points+1'b1;
        end
    endtask
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin state<=0;done<=0;valid<=0;row_addr<=0;theta<=0;best_theta<=0;
            fine<=0;verify<=0;refine<=0;refine_start<=0;best_area<=32'hffffffff;
            cx<=0;cy<=0;w<=0;h<=0;angle<=0;square<=0;area_pixels<=0;
            bpmin<=0;bpmax<=0;bqmin<=0;bqmax<=0;pc<=0;qc<=0;pp<=0;qq<=0;
            reset_extents;
        end else begin
            done<=0;
            if(abort) begin state<=0;valid<=0;end
            else case(state)
            0:if(start) begin theta<=0;fine<=0;verify<=0;valid<=0;
                best_area<=32'hffffffff;reset_extents;state<=2;end
            2:state<=3;
            3:begin pp<=p;qq<=q;state<=4;end
            4:begin if(left_x<=right_x) accumulate;state<=5;end
            5:begin pp<=p;qq<=q;state<=6;end
            6:begin
                if(left_x<=right_x) accumulate;
                if(row_addr==HEIGHT-1) state<=7;
                else begin row_addr<=row_addr+1'b1;state<=2;end
            end
            7:state<=8;
            8:begin
                if(!verify && points>=16 && candidate_area<best_area) begin
                    best_area<=candidate_area;best_theta<=theta;
                    bpmin<=chosen_pmin;bpmax<=chosen_pmax;bqmin<=chosen_qmin;bqmax<=chosen_qmax;
                end
                // A connected, interior-bounded V5 region supplies the contour.
                // Local seams/notches are diagnostics, not a perfect-edge gate.
                if(verify) begin valid<=points>=16 && (REGION_VALIDATED || bad_ratio_ok);state<=11;end
                else if(!fine && theta<176) begin theta<=theta+4;reset_extents;state<=2;end
                else if(!fine) state<=9;
                else if(refine<8) begin
                    refine<=refine+1'b1;theta<=theta==179?0:theta+1'b1;reset_extents;state<=2;
                end else state<=10;
            end
            9:begin fine<=1;refine<=0;theta<=best_theta<4?best_theta+176:best_theta-4;
                reset_extents;state<=2;end
            10:begin theta<=best_theta;verify<=1;reset_extents;state<=2;end
            11:begin pc<=($signed(bpmin)+$signed(bpmax)+1024)>>>11;
                qc<=($signed(bqmin)+$signed(bqmax)+1024)>>>11;state<=12;end
            12:begin
                cx<=(p+512)>>>10;cy<=(q+512)>>>10;
                if(best_area==32'hffffffff) begin w<=0;h<=0;angle<=0;end
                else if(bw>=bh) begin w<=bw;h<=bh;angle<={1'b0,best_theta};end
                else begin w<=bh;h<=bw;angle<=best_theta+9'd180;end
                square<=bw*100<=bh*105 && bh*100<=bw*105;
                area_pixels<=bw*bh;state<=13;
            end
            13:begin done<=1;state<=0;end
            default:state<=0;
            endcase
        end
    end
endmodule
