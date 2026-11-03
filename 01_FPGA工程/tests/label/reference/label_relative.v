// Centred box coordinates: +/-512 is half a box side. Ratios are Q10.
module label_relative_reference(input wire clk,rst_n,start,abort,
    input wire [11:0] bx,by,bw,bh,lx,ly,lw,lh,input wire [8:0] ba,la,
    output reg done,output reg signed [12:0] u,v,
    output reg [12:0] wr,hr,output reg [8:0] alpha);
    wire signed [11:0] c,s;
    label_trig trig(.angle(ba),.c(c),.s(s));
    wire signed [12:0] dx=$signed({1'b0,lx})-$signed({1'b0,bx});
    wire signed [12:0] dy=$signed({1'b0,ly})-$signed({1'b0,by});
    wire signed [13:0] xy=dx+dy;
    wire signed [12:0] ms=-s-c,mc=c-s;
    wire signed [26:0] k1=xy*c,k2=dx*ms,k3=dy*mc;
    wire signed [26:0] pu=k1-k3,pv=k1+k2;
    reg [2:0] state;reg [1:0] item;reg neg;
    reg div_start;reg [31:0] n;reg [15:0] d;
    wire div_done;wire [31:0] q;
    label_div div(.clk(clk),.rst_n(rst_n),.start(div_start),.abort(abort),.n(n),.d(d),.done(div_done),.q(q));
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin state<=0;item<=0;neg<=0;div_start<=0;n<=0;d<=1;done<=0;u<=0;v<=0;wr<=0;hr<=0;alpha<=0;end
        else begin
            done<=0;div_start<=0;
            if(abort) state<=0;
            else case(state)
            0:if(start) begin item<=0;alpha<=la>=ba?la-ba:la+360-ba;state<=1;end
            1:begin
                case(item)
                0:begin n<=pu<0?-pu:pu;d<=bw;neg<=pu<0;end
                1:begin n<=pv<0?-pv:pv;d<=bh;neg<=pv<0;end
                2:begin n<={10'd0,lw,10'd0};d<=bw;neg<=0;end
                default:begin n<={10'd0,lh,10'd0};d<=bh;neg<=0;end
                endcase
                state<=2;
            end
            2:begin div_start<=1;state<=3;end
            3:if(div_done) begin
                case(item)
                0:u<=neg?-$signed(q[12:0]):$signed(q[12:0]);
                1:v<=neg?-$signed(q[12:0]):$signed(q[12:0]);
                2:wr<=q[12:0];default:hr<=q[12:0];
                endcase
                if(item==3) begin done<=1;state<=0;end else begin item<=item+1'b1;state<=1;end
            end
            default:state<=0;
            endcase
        end
    end
endmodule
