// Three video clocks, matching the existing hdmi_mixer RGB/HS/VS/DE delay.
// Full geometry/result snapshot at frame start; left 40% is a grouped panel.
module label_scene_overlay_v4_reference(
    input wire clk,rst_n,enable,de,input wire [11:0] x,y,
    input wire [1:0] state,result,input wire [3:0] cause,input wire [2:0] fail,
    input wire [1:0] size_fail,
    input wire locked,geometry,scene,reference_set,learn_failed,alarm,muted,
    input wire signed [12:0] du,dv,move_x,move_y,input wire signed [9:0] da,
    input wire [1:0] main_item,
    input wire [11:0] box_x,box_y,box_w,box_h,label_x,label_y,label_w,label_h,
    input wire [8:0] box_a,label_a,ta,input wire square,
    input wire signed [15:0] rp,rq,input wire [11:0] rhw,rhh,tx,ty,
    input wire [23:0] total,passes,fails,unknowns,
    input wire [2:0] background_status,input wire [3:0] background_progress,
    input wire [2:0] debug_code,input wire [11:0] debug_points,debug_bad_points,debug_fit_w,debug_fit_h,
    input wire debug_pixel_valid,debug_raw_pixel,debug_kept_pixel,
    output reg O_hit,output reg [23:0] O_color);
    reg [1:0] st,res,main;
    reg [3:0] why;reg [2:0] bad;
    reg [1:0] sizebad;
    reg lock,geom,scn,refset,learnbad,alrm,mute,sq;
    reg signed [12:0] uu,vv,mx,my;reg signed [9:0] aa;
    reg [11:0] bx,by,bw,bh,lx,ly,lw,lh,rw,rh,target_x,target_y;
    reg [8:0] ba,la,ra;
    reg signed [15:0] cp,cq;
    reg [23:0] nt,np,nf,nu;
    reg [2:0] bgst;reg [3:0] bgcount;
    reg [2:0] dbgcode;reg [11:0] dbgpoints,dbgbad,dbgfitw,dbgfit_h;
    wire fit_diagnostic=(res==3 || learnbad) && (why==9 || why==1 || why==2);
    reg [15:0] u_bcd,v_bcd,a_bcd;
    reg [1:0] fmt;reg [3:0] fc;reg [12:0] bin;reg [15:0] bcd,adj;
    wire [12:0] abs_in=du<0?-du:du,abs_v=vv<0?-vv:vv;
    wire [9:0] abs_a=aa<0?-aa:aa;
    wire [22:0] pct_in=({10'd0,abs_in}<<10)-({10'd0,abs_in}<<4)-({10'd0,abs_in}<<3);
    wire [22:0] pct_v=({10'd0,abs_v}<<10)-({10'd0,abs_v}<<4)-({10'd0,abs_v}<<3);
    wire [15:0] nxt={adj[14:0],bin[12]};
    integer i;
    function [7:0] hex_char;
        input [3:0] nibble;
        begin hex_char=nibble<10?8'h30+nibble:8'h41+nibble-10;end
    endfunction
    always @(*) begin
        adj=bcd;for(i=0;i<4;i=i+1) if(bcd[i*4+:4]>=5) adj[i*4+:4]=bcd[i*4+:4]+3;
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            st<=0;res<=0;why<=0;bad<=0;sizebad<=0;lock<=0;geom<=0;scn<=0;refset<=0;learnbad<=0;alrm<=0;mute<=0;sq<=0;main<=0;
            uu<=0;vv<=0;aa<=0;mx<=0;my<=0;bx<=0;by<=0;bw<=0;bh<=0;lx<=0;ly<=0;lw<=0;lh<=0;
            ba<=0;la<=0;ra<=0;cp<=0;cq<=0;rw<=0;rh<=0;target_x<=0;target_y<=0;
            nt<=0;np<=0;nf<=0;nu<=0;bgst<=0;bgcount<=0;u_bcd<=0;v_bcd<=0;a_bcd<=0;fmt<=0;fc<=0;bin<=0;bcd<=0;
            dbgcode<=0;dbgpoints<=0;dbgbad<=0;dbgfitw<=0;dbgfit_h<=0;
        end else if(de && x==0 && y==0) begin
            st<=state;res<=result;why<=cause;bad<=fail;sizebad<=size_fail;lock<=locked;geom<=geometry;scn<=scene;
            refset<=reference_set;learnbad<=learn_failed;alrm<=alarm;mute<=muted;sq<=square;main<=main_item;
            uu<=du;vv<=dv;aa<=da;mx<=move_x;my<=move_y;
            bx<=box_x;by<=box_y;bw<=box_w;bh<=box_h;ba<=box_a;
            lx<=label_x;ly<=label_y;lw<=label_w;lh<=label_h;la<=label_a;
            cp<=rp;cq<=rq;rw<=rhw;rh<=rhh;ra<=ta;target_x<=tx;target_y<=ty;
            nt<=total;np<=passes;nf<=fails;nu<=unknowns;
            bgst<=background_status;bgcount<=background_progress;
            dbgcode<=debug_code;dbgpoints<=debug_points;dbgbad<=debug_bad_points;dbgfitw<=debug_fit_w;dbgfit_h<=debug_fit_h;
            fmt<=1;fc<=0;bin<=pct_in>>10;bcd<=0;
        end else if(fmt!=0) begin
            bin<=bin<<1;bcd<=nxt;
            if(fc==12) begin fc<=0;bcd<=0;
                case(fmt)
                1:begin u_bcd<=nxt;bin<=pct_v>>10;fmt<=2;end
                2:begin v_bcd<=nxt;bin<=({3'd0,abs_a}<<2)+abs_a;fmt<=3;end
                default:begin a_bcd<=nxt;fmt<=0;end
                endcase
            end else fc<=fc+1'b1;
        end
    end
    reg [4:0] row;reg [4:0] char_column;
    reg [143:0] text_line;reg [23:0] text_color;
    reg [1:0] column;
    reg [11:0] line_start,origin_x,local_x,local_y;
    reg [5:0] cell_size;
    reg [3:0] glyph_x,glyph_y;
    integer layout_index;
    function [11:0] line_y;
        input [4:0] index;
        begin case(index)
        0:line_y=48;1:line_y=80;2:line_y=104;3:line_y=136;4:line_y=176;
        5:line_y=208;6:line_y=232;7:line_y=256;8:line_y=296;9:line_y=328;
        10:line_y=360;11:line_y=384;12:line_y=408;13:line_y=456;
        14:line_y=480;15:line_y=504;16:line_y=528;17:line_y=560;
        18:line_y=592;19:line_y=616;default:line_y=0;endcase end
    endfunction
    // 24-pixel cells reuse the 16-pixel font without a per-pixel divider.
    function [3:0] font24;
        input [4:0] position;
        begin case(position)
        0,1:font24=0;2:font24=1;3,4:font24=2;5:font24=3;
        6,7:font24=4;8:font24=5;9,10:font24=6;11:font24=7;
        12,13:font24=8;14:font24=9;15,16:font24=10;17:font24=11;
        18,19:font24=12;20:font24=13;21,22:font24=14;default:font24=15;endcase end
    endfunction
    wire signed [11:0] bc,bs,lc,ls,rc,rs;
    reg [11:0] badge_x,badge_y;
    wire [11:0] badge_height=res==2?(sizebad!=0?72:104):(res==3?56:40);
    wire badge_visible=lock && st==0 && res!=0 && !learnbad;
    wire badge_inside=badge_visible && x>=badge_x && x<badge_x+256 && y>=badge_y && y<badge_y+badge_height;
    reg badge_pixel,badge_border;
    reg [11:0] badge_dx,badge_dy;
    reg [2:0] badge_row;
    reg [2:0] badge_calc;
    reg [3:0] badge_bit;
    reg [10:0] badge_factor;
    reg [23:0] badge_term,badge_sum;
    reg signed [13:0] badge_left,badge_top,badge_below;
    wire [10:0] badge_abs_c=bc<0?-bc:bc,badge_abs_s=bs<0?-bs:bs;
    // Exact rotated vertical extent using a shared bit-serial adder, no DSP.
    always @(*) begin
        badge_left=$signed({2'b0,bx})-14'sd128;
        if(badge_left<528) badge_left=528;else if(badge_left>1008) badge_left=1008;
        badge_top=$signed({2'b0,by})-$signed({1'b0,badge_sum[23:11]})-$signed({2'b0,badge_height})-14'sd8;
        badge_below=$signed({2'b0,by})+$signed({1'b0,badge_sum[23:11]})+14'sd8;
        if(badge_top<32) badge_top=badge_below;
        if(badge_top>712-$signed({2'b0,badge_height})) badge_top=712-$signed({2'b0,badge_height});
        if(badge_top<32) badge_top=32;
        // Keep clear of the 80x80 logo at (1184,32).
        if(badge_top<112 && badge_left>920) badge_left=920;
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin badge_x<=528;badge_y<=32;badge_calc<=0;badge_bit<=0;badge_factor<=0;badge_term<=0;badge_sum<=0;end
        else if(de && x==0 && y==0) badge_calc<=1;
        else case(badge_calc)
        1:begin
            if(res==3) begin badge_x<=528;badge_y<=32;badge_calc<=0;end
            else begin badge_factor<=badge_abs_s;badge_term<={12'd0,bw};badge_sum<=0;badge_bit<=0;badge_calc<=2;end
        end
        2,4:begin
            if(badge_factor[0]) badge_sum<=badge_sum+badge_term;
            badge_factor<=badge_factor>>1;badge_term<=badge_term<<1;
            if(badge_bit==10) begin badge_calc<=badge_calc+1'b1;badge_bit<=0;end
            else badge_bit<=badge_bit+1'b1;
        end
        3:begin badge_factor<=badge_abs_c;badge_term<={12'd0,bh};badge_calc<=4;end
        5:begin badge_x<=badge_left[11:0];badge_y<=badge_top[11:0];badge_calc<=0;end
        default:;
        endcase
    end
    always @(*) begin
        column=0;
        row=31;line_start=0;origin_x=32;cell_size=24;
        for(layout_index=0;layout_index<20;layout_index=layout_index+1) begin
            if(y>=line_y(layout_index) && y<line_y(layout_index)+(layout_index==3?32:(layout_index==18?16:24))) begin
                row=layout_index;line_start=line_y(layout_index);
            end
        end
        if(y>=656 && y<672) begin row=x<256?20:21;line_start=656;end
        else if(y>=680 && y<696) begin row=x<256?22:23;line_start=680;end
        if(row==3) begin cell_size=32;origin_x=16;end
        else if(row==18 || row>=20) begin cell_size=16;if(row==21 || row==23) origin_x=256;end
        char_column=31;local_x=0;local_y=y-line_start;
        if(cell_size==32) begin
            if(x>=16) begin char_column=(x-16)>>5;local_x=(x-16)&31;end
        end else if(cell_size==16) begin
            if(x>=origin_x) begin char_column=(x-origin_x)>>4;local_x=(x-origin_x)&15;end
        end else for(layout_index=0;layout_index<18;layout_index=layout_index+1) begin
            if(x>=32+layout_index*24 && x<56+layout_index*24) begin
                char_column=layout_index;local_x=x-32-layout_index*24;
            end
        end
        if(cell_size==32) begin glyph_x=local_x[4:1];glyph_y=local_y[4:1];end
        else if(cell_size==24) begin glyph_x=font24(local_x[4:0]);glyph_y=font24(local_y[4:0]);end
        else begin glyph_x=local_x[3:0];glyph_y=local_y[3:0];end
        text_line="                  ";text_color=24'he0e0e0;
        case(row)
        0:begin text_line="LABEL REGION V5.3 ";text_color=24'h40ddff;end
        1:begin text_line=learnbad?"REF: SET FAILED   ":(refset?"REF: SET          ":"REF: REQUIRED     ");
            text_color=learnbad?24'hffb040:(refset?24'h60dfa0:24'hffdc60);end
        2:text_line=st==1?"STATE: CHECKING   ":(st==2?"STATE: LEARNING   ":(lock?"STATE: LOCKED     ":"STATE: READY      "));
        3:begin text_line=res==1?"RESULT: PASS      ":(res==2?"RESULT: FAIL      ":(res==3?"RESULT: UNKNOWN   ":"RESULT: --        "));
            text_color=res==1?24'h00ff40:(res==2?24'hff4040:24'hffff00);end
        4:text_line=sizebad!=0?"SIZE: CHECK FAILED":(geom?"LABEL: VALID      ":(res==3?"LABEL: INVALID    ":"LABEL: --         "));
        5,6:begin
            text_line=row==5?"DU: +000.0 PCT    ":"DV: +000.0 PCT    ";
            if(!geom) text_line=row==5?"DU: -- PCT        ":"DV: -- PCT        ";
            else begin
                text_line[111:104]=(row==5?uu<0:vv<0)?8'h2d:8'h2b;
                text_line[103:96]=8'h30+(row==5?u_bcd[15:12]:v_bcd[15:12]);
                text_line[95:88]=8'h30+(row==5?u_bcd[11:8]:v_bcd[11:8]);
                text_line[87:80]=8'h30+(row==5?u_bcd[7:4]:v_bcd[7:4]);
                text_line[71:64]=8'h30+(row==5?u_bcd[3:0]:v_bcd[3:0]);
            end
        end
        7:begin
            text_line=geom?"ANG:+00.0 DEG CW  ":"ANG: -- DEG       ";
            if(geom) begin text_line[111:104]=aa<0?8'h2d:8'h2b;
                text_line[103:96]=8'h30+a_bcd[11:8];text_line[95:88]=8'h30+a_bcd[7:4];text_line[79:72]=8'h30+a_bcd[3:0];
                text_line[31:24]=aa==0?8'h2d:8'h43;
                text_line[23:16]=aa<0?8'h43:(aa>0?8'h57:8'h20);text_line[15:8]=aa<0?8'h57:8'h20;end
        end
        8:begin
            if(res==2 && sizebad!=0) case(sizebad)
                1:text_line="CAUSE: BOX SIZE   ";2:text_line="CAUSE: LABEL SIZE ";default:text_line="CAUSE: BOTH SIZE  ";endcase
            else if(res==2) case(bad)
                1:text_line="CAUSE: U POSITION ";2:text_line="CAUSE: V POSITION ";4:text_line="CAUSE: TILT       ";default:text_line="CAUSE: MULTIPLE   ";endcase
            else if(res==3 || learnbad) case(why)
                1:text_line="CAUSE: NO LABEL   ";2:text_line="CAUSE: LABEL EDGE ";4:text_line="CAUSE: UNSTABLE   ";5:text_line="CAUSE: SIZE       ";
                6:text_line="CAUSE: NO FRAME   ";7:text_line="CAUSE: NO BOX     ";8:text_line="CAUSE: MULTI BOX  ";9:text_line="CAUSE: BOX EDGE   ";
                12:text_line="CAUSE: BG WAIT    ";13:text_line="CAUSE: BG INVALID ";
                14:text_line="CAUSE: BG FIRST   ";
                10:text_line="CAUSE: OUT OF ROI ";11:text_line="CAUSE: LEARN FIRST";default:text_line="CAUSE: INVALID    ";endcase
            else text_line="CAUSE: --         ";
        end
        9:begin
            if(sizebad!=0) case(sizebad)
                1:text_line="FIX: REPLACE BOX  ";2:text_line="FIX: REPLACE LABEL";default:text_line="FIX: REPLACE BOTH ";endcase
            else if(fit_diagnostic) case(dbgcode)
                1:text_line="FIT: QUEUE FULL   ";2:text_line="FIT: FEW POINTS   ";3:text_line="FIT: BAD EDGES    ";
                4:text_line=why==9?"FIT: BOX WIDTH    ":"FIT: LABEL WIDTH  ";
                5:text_line=why==9?"FIT: BOX HEIGHT   ":"FIT: LABEL HEIGHT ";
                6:text_line="FIT: MULTI REGION ";7:text_line="FIT: LOW COVERAGE ";default:text_line="FIT: DIAG PENDING ";endcase
            else text_line=main==1?"MAIN: U POSITION  ":(main==2?"MAIN: V POSITION  ":(main==3?"MAIN: TILT        ":"MAIN: --          "));
        end
        10:begin
            text_line=!fit_diagnostic?(!geom?"X: --             ":(!(bad[0] || bad[1]) || (mx<=1 && mx>=-1)?"X: OK             ":(mx<0?"X: MOVE LEFT      ":"X: MOVE RIGHT     "))):"PTS:000 BAD:000   ";
            if(sizebad!=0) text_line=sizebad[0]?"BOX: WRONG SIZE   ":"BOX: SIZE OK      ";
            if(fit_diagnostic) begin
                text_line[111:104]=hex_char(dbgpoints[11:8]);text_line[103:96]=hex_char(dbgpoints[7:4]);text_line[95:88]=hex_char(dbgpoints[3:0]);
                text_line[47:40]=hex_char(dbgbad[11:8]);text_line[39:32]=hex_char(dbgbad[7:4]);text_line[31:24]=hex_char(dbgbad[3:0]);
            end
        end
        11:begin
            text_line=!fit_diagnostic?(!geom?"Y: --             ":(!(bad[0] || bad[1]) || (my<=1 && my>=-1)?"Y: OK             ":(my<0?"Y: MOVE UP        ":"Y: MOVE DOWN      "))):(why==9?"BOX:000 X 000     ":"LBL:000 X 000     ");
            if(sizebad!=0) text_line=sizebad[1]?"LBL: WRONG SIZE   ":"LBL: SIZE OK      ";
            if(fit_diagnostic) begin
                text_line[111:104]=hex_char(dbgfitw[11:8]);text_line[103:96]=hex_char(dbgfitw[7:4]);text_line[95:88]=hex_char(dbgfitw[3:0]);
                text_line[63:56]=hex_char(dbgfit_h[11:8]);text_line[55:48]=hex_char(dbgfit_h[7:4]);text_line[47:40]=hex_char(dbgfit_h[3:0]);
            end
        end
        12:begin text_line=!geom?"A: --             ":(!bad[2]?"A: OK             ":(aa>0?"A: ROTATE CCW     ":"A: ROTATE CW      "));
            if(sizebad!=0) text_line="SWAP THEN K1      ";
            if(main==3) text_color=24'hff8000;end
        13,14,15,16:begin
            case(row) 13:text_line="TOTAL: 000000     ";14:text_line="PASS:  000000     ";15:text_line="FAIL:  000000     ";default:text_line="UNKN:  000000     ";endcase
            for(i=0;i<6;i=i+1) text_line[87-i*8-:8]=8'h30+(row==13?nt[23-i*4-:4]:(row==14?np[23-i*4-:4]:(row==15?nf[23-i*4-:4]:nu[23-i*4-:4])));
        end
        17:text_line=alrm?"SOUND: ALARM      ":(mute?"SOUND: MUTED      ":"SOUND: OFF        ");
        18:text_line="G BOX C LBL R OUT ";
        19:begin
            case(bgst)
            0:text_line="BG: EMPTY + K4    ";1:text_line="BG: LOCK WAIT     ";2:text_line="BG: STARTING      ";
            3:begin text_line="BG: CAPTURE 0/8   ";text_line[47:40]=8'h30+bgcount;end
            4:text_line="BG: READY LOCKED  ";default:text_line="BG: RETRY EMPTY K4";
            endcase
            text_color=bgst==4?24'h00ff40:24'hffff00;
        end
        20:text_line="K1 CHECK          ";21:text_line="K2 LEARN          ";22:text_line="K3 MUTE           ";23:text_line="K4 BG / CLEAR     ";
        default:;
        endcase
        // Cause and correction have distinct, high-contrast colors.
        if(row==8) text_color=(res==2 || learnbad)?24'hff8050:(res==3?24'hffd060:24'h8298ad);
        if(row==9) text_color=sizebad!=0?24'hfff060:(fit_diagnostic?24'hffb050:(main!=0?24'hffb050:24'h8298ad));
        if(row>=10 && row<=12) text_color=sizebad!=0?24'hfff060:(fit_diagnostic?24'hb0c8df:(geom && res==2?24'hfff060:24'h90c8bd));
        if(row==5 && geom && bad[0]) text_color=24'hffb050;
        if(row==6 && geom && bad[1]) text_color=24'hffb050;
        if(row==7 && geom && bad[2]) text_color=24'hffb050;
        if(row==13 || row==18 || row>=20) text_color=24'h9cb2c7;
        if(row==14) text_color=24'h60df90;
        if(row==15) text_color=24'hff8070;
        if(row==16) text_color=24'hffd060;
        if(row==17 && alrm) text_color=24'hffb050;
        badge_pixel=badge_inside;badge_border=0;badge_dx=0;badge_dy=0;badge_row=0;
        if(badge_inside) begin
            badge_dx=x-badge_x;badge_dy=y-badge_y;
            badge_border=badge_dx==0 || badge_dx==255 || badge_dy==0 || badge_dy==badge_height-1;
            text_line="                  ";char_column=31;glyph_x=0;glyph_y=0;
            text_color=res==1?24'h40ff80:(res==2?24'hff6050:24'hffdf50);
            if(badge_dx>=8 && badge_dx<248) begin
                if(badge_dy>=4 && badge_dy<36) begin
                    char_column=(badge_dx-8)>>5;glyph_x=((badge_dx-8)>>1)&15;glyph_y=(badge_dy-4)>>1;
                    text_line=res==1?"PASS              ":(res==2?"FAIL              ":"UNKNOWN           ");
                end else if(badge_dy>=40) begin
                    badge_row=((badge_dy-40)>>4)+1;
                    char_column=(badge_dx-8)>>4;glyph_x=(badge_dx-8)&15;glyph_y=(badge_dy-40)&15;
                    if(badge_row==1) begin
                        if(sizebad!=0) case(sizebad)
                            1:text_line="BOX SIZE          ";2:text_line="LABEL SIZE        ";default:text_line="BOTH SIZE         ";endcase
                        else if(res==2) case(bad)
                            1:text_line="U POSITION        ";2:text_line="V POSITION        ";4:text_line="TILT              ";default:text_line="MULTIPLE          ";endcase
                        else case(why)
                            1:text_line="NO LABEL          ";2:text_line="LABEL EDGE        ";4:text_line="UNSTABLE          ";6:text_line="NO FRAME          ";
                            7:text_line="NO BOX            ";8:text_line="MULTI BOX         ";9:text_line="BOX EDGE          ";10:text_line="OUT OF ROI        ";
                            11:text_line="LEARN FIRST       ";default:text_line="INVALID           ";endcase
                    end else begin
                        text_color=24'hfff060;
                        if(sizebad!=0) case(sizebad)
                            1:text_line="REPLACE BOX       ";2:text_line="REPLACE LABEL     ";default:text_line="REPLACE BOTH      ";endcase
                        else case(badge_row)
                            2:text_line=!(bad[0] || bad[1]) || (mx<=1 && mx>=-1)?"X: OK             ":(mx<0?"MOVE LEFT         ":"MOVE RIGHT        ");
                            3:text_line=!(bad[0] || bad[1]) || (my<=1 && my>=-1)?"Y: OK             ":(my<0?"MOVE UP           ":"MOVE DOWN         ");
                            4:text_line=!bad[2]?"A: OK             ":(aa>0?"ROTATE CCW        ":"ROTATE CW         ");
                            default:;
                        endcase
                    end
                end
            end
        end
    end
    label_trig bt(.angle(ba),.c(bc),.s(bs));label_trig lt(.angle(la),.c(lc),.s(ls));label_trig rt(.angle(ra),.c(rc),.s(rs));
    wire signed [12:0] xb=$signed({1'b0,x})-$signed({1'b0,bx}),yb=$signed({1'b0,y})-$signed({1'b0,by});
    wire signed [12:0] xl=$signed({1'b0,x})-$signed({1'b0,lx}),yl=$signed({1'b0,y})-$signed({1'b0,ly});
    wire signed [13:0] xy_b=xb+yb,xy_l=xl+yl;
    wire signed [12:0] bm=-bs-bc,bn=bc-bs,lm=-ls-lc,ln=lc-ls,rm=-rs-rc,rn=rc-rs;
    wire signed [26:0] bk1=xy_b*bc,bk2=xb*bm,bk3=yb*bn;
    wire signed [26:0] lk1=xy_l*lc,lk2=xl*lm,lk3=yl*ln;
    wire signed [26:0] rk1=xy_b*rc,rk2=xb*rm,rk3=yb*rn;
    reg signed [25:0] bp1,bq1,lp1,lq1,rp1,rq1;
    reg signed [15:0] bp2,bq2,lp2,lq2,pr2,qr2;
    reg [11:0] x1,y1,x2,y2;reg de1,de2,en1,en2,panel1,panel2;
    reg [143:0] text1;reg [23:0] color1,color2;
    reg [4:0] column1;reg [7:0] ascii;reg [3:0] font_row,font_col;
    reg [3:0] glyph_x1,glyph_y1;
    reg badge1,badge2,badge_edge1,badge_edge2;
    wire [15:0] font_bits;
    label_char_lib font(.I_char(ascii),.I_row(font_row),.O_row_bits(font_bits));
    function rect_edge;
        input signed [16:0] p,q;input [11:0] hw,hh;
        reg [16:0] ap,aq;
        begin ap=p<0?-p:p;aq=q<0?-q:q;
            rect_edge=(ap<=hw+1 && aq<=hh+1) && (ap+1>=hw || aq+1>=hh);end
    endfunction
    wire roi=x2>=512 && x2<=1279 && y2<=719 && (x2==512 || x2==1279 || y2==0 || y2==719);
    wire box_edge=rect_edge(bp2,bq2,bw>>1,bh>>1);
    wire actual_edge=rect_edge(lp2,lq2,lw>>1,lh>>1);
    wire ref_edge=rect_edge(pr2-cp,qr2-cq,rw,rh) || rect_edge(-pr2-cp,-qr2-cq,rw,rh) ||
                  (sq && (rect_edge(qr2-cp,-pr2-cq,rw,rh) || rect_edge(-qr2-cp,pr2-cq,rw,rh)));
    wire [11:0] left_x=lx<target_x?lx:target_x,right_x=lx>target_x?lx:target_x;
    wire [11:0] top_y=ly<target_y?ly:target_y,bottom_y=ly>target_y?ly:target_y;
    wire move_line=(y2==ly && x2>=left_x && x2<=right_x) || (x2==target_x && y2>=top_y && y2<=bottom_y);
    wire target_cross=(y2==target_y && x2+4>=target_x && x2<=target_x+4) ||
                      (x2==target_x && y2+4>=target_y && y2<=target_y+4);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            x1<=0;y1<=0;x2<=0;y2<=0;de1<=0;de2<=0;en1<=0;en2<=0;panel1<=0;panel2<=0;
            text1<=0;color1<=0;color2<=0;column1<=0;ascii<=32;font_row<=0;font_col<=0;glyph_x1<=0;glyph_y1<=0;
            badge1<=0;badge2<=0;badge_edge1<=0;badge_edge2<=0;
            bp1<=0;bq1<=0;lp1<=0;lq1<=0;rp1<=0;rq1<=0;bp2<=0;bq2<=0;lp2<=0;lq2<=0;pr2<=0;qr2<=0;
            O_hit<=0;O_color<=0;
        end else begin
            x1<=x;y1<=y;de1<=de;en1<=enable;panel1<=x<512;
            text1<=text_line;color1<=text_color;column1<=char_column;glyph_x1<=glyph_x;glyph_y1<=glyph_y;
            badge1<=badge_pixel;badge2<=badge1;badge_edge1<=badge_border;badge_edge2<=badge_edge1;
            bp1<=bk1-bk3;bq1<=bk1+bk2;
            lp1<=lk1-lk3;lq1<=lk1+lk2;
            rp1<=rk1-rk3;rq1<=rk1+rk2;
            x2<=x1;y2<=y1;de2<=de1;en2<=en1;panel2<=panel1;
            ascii<=(panel1 || badge1) && column1<18?text1[143-column1*8-:8]:8'h20;color2<=color1;font_row<=glyph_y1;font_col<=glyph_x1;
            bp2<=bp1>>>10;bq2<=bq1>>>10;lp2<=lp1>>>10;lq2<=lq1>>>10;pr2<=rp1>>>10;qr2<=rq1>>>10;
            O_hit<=0;O_color<=0;
            if(en2 && de2) begin
                if(roi) begin O_hit<=1;O_color<=24'hffffff;end
                if(scn && st==0 && res!=3 && !learnbad && sizebad==0) begin
                    if(box_edge) begin O_hit<=1;O_color<=24'h4080ff;end
                    if(refset && ref_edge) begin O_hit<=1;O_color<=24'h00ff40;end
                    if(geom && actual_edge) begin O_hit<=1;O_color<=res==2?24'hff4040:24'h00ffff;end
                    if(geom && (target_cross || (res==2 && (bad[0] || bad[1]) && move_line))) begin O_hit<=1;O_color<=24'hffff00;end
                end
                if(debug_pixel_valid && (x2[2:0]==0 || y2[2:0]==0)) begin
                    if(debug_kept_pixel) begin O_hit<=1;O_color<=debug_raw_pixel?24'h00ffff:24'h00ff40;end
                    else if(debug_raw_pixel) begin O_hit<=1;O_color<=24'hff4040;end
                end
                if(badge2) begin
                    O_hit<=1;O_color<=badge_edge2?(res==1?24'h40ff80:(res==2?24'hff6050:24'hffdf50)):24'h101c29;
                    if(font_bits[15-font_col]) O_color<=color2;
                end
                if(panel2) begin
                    O_hit<=1;
                    O_color<=(y2>=128 && y2<204)?24'h152a3d:((y2>=288 && y2<440)?24'h182838:24'h101c29);
                    if(x2>=24 && x2<488 && (y2==74 || y2==288 || y2==448 || y2==608 || y2==648)) O_color<=24'h34546d;
                    if(font_bits[15-font_col]) O_color<=color2;
                end
            end
        end
    end
endmodule
