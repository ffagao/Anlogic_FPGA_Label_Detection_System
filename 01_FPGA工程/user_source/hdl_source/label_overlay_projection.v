// Exact Q10 projections for the fixed 1280x720 raster and x>=512 video ROI.
// The hidden left panel provides time to prepare three origins each frame.
// One shared setup DSP replaces nine per-pixel DSP multipliers.
module label_overlay_projection(
    input wire clk,rst_n,de,input wire [11:0] x,y,
    input wire [11:0] bx,by,lx,ly,
    input wire signed [11:0] bc,bs,lc,ls,rc,rs,
    output wire signed [25:0] bp,bq,lp,lq,rp,rq,
    output reg ready,
    input wire I_zoom,input wire [11:0] I_src_x,tx,ty,
    input wire signed [11:0] I_src_y);
    wire zoom=I_zoom===1'b1;
    reg signed [23:0] pixel_p[0:2],pixel_q[0:2],line_p[0:2],line_q[0:2];
    wire signed [11:0] c[0:2],s[0:2];
    assign c[0]=bc;assign c[1]=lc;assign c[2]=rc;
    assign s[0]=bs;assign s[1]=ls;assign s[2]=rs;
    wire signed [23:0] step_p[0:2],step_q[0:2];
    genvar g;
    generate for(g=0;g<3;g=g+1) begin: raster
        assign step_p[g]=pixel_p[g]+(x==1279?line_p[g]:c[g]);
        assign step_q[g]=pixel_q[g]+(x==1279?line_q[g]:-s[g]);
    end endgenerate
    assign bp=pixel_p[0];assign bq=pixel_q[0];assign lp=pixel_p[1];assign lq=pixel_q[1];
    assign rp=pixel_p[2];assign rq=pixel_q[2];
    reg [1:0] state,rect;
    reg [2:0] product;
    reg signed [23:0] multiplied,p_part,q_part;
    reg signed [13:0] operand;
    reg signed [11:0] coefficient;
    reg [11:0] center_x,center_y;
    always @(*) begin
        center_x=rect==1?lx:((rect==2 && zoom)?tx:bx);
        center_y=rect==1?ly:((rect==2 && zoom)?ty:by);
        if(product>=4) operand=14'sd767;
        else if(zoom) begin
            if(product==0 || product==3)
                operand=($signed({2'b0,I_src_x})-$signed({2'b0,center_x}))<<<1;
            else operand=($signed({{2{I_src_y[11]}},I_src_y})-$signed({2'b0,center_y}))<<<1;
        end else operand=(product==0 || product==3)?14'sd512-$signed({2'b0,center_x}):-$signed({2'b0,center_y});
        coefficient=product[0]?s[rect]:c[rect];
    end
    wire signed [25:0] setup_product=operand*coefficient;
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=0;rect<=0;product<=0;multiplied<=0;p_part<=0;q_part<=0;ready<=0;
            for(i=0;i<3;i=i+1) begin pixel_p[i]<=0;pixel_q[i]<=0;line_p[i]<=0;line_q[i]<=0;end
        end else begin
            if(de && x==0 && y==0) begin state<=3;rect<=0;product<=0;ready<=0;end
            else case(state)
            3:state<=1;
            1:begin
                multiplied<=setup_product;state<=2;
            end
            2:begin
                case(product)
                0:p_part<=multiplied;
                1:pixel_p[rect]<=p_part+multiplied;
                2:q_part<=multiplied;
                3:pixel_q[rect]<=q_part-multiplied;
                4:line_p[rect]<=$signed(s[rect])-multiplied;
                5:line_q[rect]<=$signed(c[rect])+multiplied;
                endcase
                if(product==5) begin
                    product<=0;
                    if(rect==2) begin ready<=1;state<=0;end
                    else begin rect<=rect+1'b1;state<=1;end
                end else begin product<=product+1'b1;state<=1;end
            end
            default:;
            endcase
            if(ready && de && x>=512 && x<1280) begin
                for(i=0;i<3;i=i+1) begin
                    pixel_p[i]<=step_p[i];pixel_q[i]<=step_q[i];
                end
            end
        end
    end
endmodule
