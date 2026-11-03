// Geometry is computed between frames, not per pixel. Produces reference
// projection offsets for all symmetric outlines and a screen-space move arrow.
module label_target(input wire clk,rst_n,start,
    input wire signed [12:0] ru,rv,input wire [12:0] rw,rh,
    input wire [8:0] ra,ba,input wire [1:0] branch,
    input wire [11:0] bx,by,bw,bh,lx,ly,
    output reg done,output reg signed [15:0] rp,rq,
    output reg [11:0] hw,hh,tx,ty,output reg [8:0] ta,
    output reg signed [12:0] move_x,move_y);
    reg [3:0] state;
    wire signed [11:0] rc,rs,bc,bs;
    label_trig_sync rt(.clk(clk),.angle(ra),.c(rc),.s(rs));
    label_trig_sync bt(.clk(clk),.angle(ba),.c(bc),.s(bs));
    reg signed [25:0] px,py;
    reg signed [15:0] ux,vy,sx,sy;
    wire [9:0] sum_angle=ba+ra;
    reg signed [15:0] a0,a1;reg signed [12:0] b0,b1;
    wire signed [28:0] product0=a0*b0,product1=a1*b1;
    always @(*) begin
        a0=0;a1=0;b0=0;b1=0;
        case(state)
        1:begin a0=ru;a1=rv;b0=$signed({1'b0,bw});b1=$signed({1'b0,bh});end
        2:begin a0=$signed({1'b0,rw});a1=$signed({1'b0,rh});b0=$signed({1'b0,bw});b1=$signed({1'b0,bh});end
        3:begin a0=ux;a1=vy;b0=rc;b1=rs;end
        4:begin a0=vy;a1=ux;b0=rc;b1=rs;end
        6:begin a0=sx;a1=sy;b0=bc;b1=bs;end
        7:begin a0=sy;a1=sx;b0=bc;b1=bs;end
        default:;
        endcase
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin state<=0;done<=0;rp<=0;rq<=0;hw<=0;hh<=0;tx<=0;ty<=0;ta<=0;
            move_x<=0;move_y<=0;px<=0;py<=0;ux<=0;vy<=0;sx<=0;sy<=0;end
        else begin done<=0;
            case(state)
            0:if(start) begin ta<=sum_angle>=360?sum_angle-360:sum_angle;state<=1;end
            1:begin px<=product0;py<=product1;state<=2;end
            2:begin ux<=px>>>10;vy<=py>>>10;hw<=product0>>>11;hh<=product1>>>11;state<=3;end
            3:begin rp<=($signed(product0)+$signed(product1))>>>10;state<=4;end
            4:begin rq<=($signed(product0)-$signed(product1))>>>10;state<=5;end
            5:begin
                case(branch)
                0:begin sx<=ux;sy<=vy;end
                1:begin sx<=-vy;sy<=ux;end
                2:begin sx<=-ux;sy<=-vy;end
                default:begin sx<=vy;sy<=-ux;end
                endcase
                state<=6;end
            6:begin tx<=$signed({1'b0,bx})+(($signed(product0)-$signed(product1))>>>10);state<=7;end
            7:begin ty<=$signed({1'b0,by})+(($signed(product0)+$signed(product1))>>>10);state<=8;end
            8:begin move_x<=$signed({1'b0,tx})-$signed({1'b0,lx});
                move_y<=$signed({1'b0,ty})-$signed({1'b0,ly});done<=1;state<=0;end
            default:state<=0;
            endcase
        end
    end
endmodule
