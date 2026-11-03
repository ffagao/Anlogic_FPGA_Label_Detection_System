`timescale 1ns/1ps
module tb_v35_ref_edges;
reg signed [15:0] p,q,cx,cy;reg [11:0] hw,hh;reg square;wire got;
v35_ref_fixture d(p,q,cx,cy,hw,hh,square,got);
function old_edge;input signed [16:0] x,y;input [11:0] w,h;reg [16:0] ax,ay;
begin ax=x<0?-x:x;ay=y<0?-y:y;old_edge=(ax<=w+1&&ay<=h+1)&&(ax+1>=w||ay+1>=h);end endfunction
wire expected=old_edge($signed({p[15],p})-$signed({cx[15],cx}),$signed({q[15],q})-$signed({cy[15],cy}),hw,hh)||
old_edge(-$signed({p[15],p})-$signed({cx[15],cx}),-$signed({q[15],q})-$signed({cy[15],cy}),hw,hh)||
(square&&(old_edge($signed({q[15],q})-$signed({cx[15],cx}),-$signed({p[15],p})-$signed({cy[15],cy}),hw,hh)||old_edge(-$signed({q[15],q})-$signed({cx[15],cx}),$signed({p[15],p})-$signed({cy[15],cy}),hw,hh)));
integer i,j,seed=3517,hits=0;
initial begin
 for(i=0;i<4096;i=i+1)begin
  cx=$random(seed);cy=$random(seed);hw=$random(seed);hh=$random(seed);square=i[0];
  case(i%16)0:begin hw=0;hh=0;end 1:begin hw=1;hh=2;end 2:begin hw=4095;hh=4095;end 3:begin cx=-32768;cy=32767;end 4:begin cx=32767;cy=-32768;end endcase
  for(j=0;j<128;j=j+1)begin
   case(j%4)
    0:begin p=$random(seed);q=$random(seed);end
    1:begin p=cx+hw-3+(j%8);q=cy+(j%7)-3;end
    2:begin p=-cx-hw-3+(j%8);q=-cy+(j%7)-3;end
    3:begin p=-cy-hh-3+(j%8);q=cx+(j%7)-3;end
   endcase
   #1;if(got!==expected)$fatal(1,"reference mismatch p%0d q%0d cp%0d cq%0d hw%0d hh%0d sq%b got%b exp%b",p,q,cx,cy,hw,hh,square,got,expected);
   if(got)hits=hits+1;
  end
 end
 if(hits<10000)$fatal(1,"insufficient edge coverage %0d",hits);
 $display("PASS tb_v35_ref_edges: 524288 full signed-range/border cases, hits=%d",hits);$finish;
end
endmodule
