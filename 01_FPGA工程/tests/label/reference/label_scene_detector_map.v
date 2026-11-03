// V5 fixed white station: 8x8 pixel voting, connected regions, hole fill,
// eroded box interior, and full-resolution boundary refinement.
module label_scene_detector_map_reference #(
    parameter integer WIDTH=1280,HEIGHT=720,ROI_L=512,ROI_R=1279,ROI_T=0,ROI_B=719,
    parameter integer MIN_COMPONENT=32
)(input wire clk,rst_n,enable,acquire,de,
  input wire [11:0] x,y,input wire [23:0] rgb,frame_id,
  input wire background_valid,input wire [23:0] background_rgb,
  output reg sample,valid,output reg [3:0] reason,
  output reg [11:0] bx,by,bw,bh,lx,ly,lw,lh,
  output reg [8:0] ba,la,output reg bsquare,lsquare,
  output reg [2:0] debug_code,
  output reg [11:0] debug_points,debug_bad_points,debug_fit_w,debug_fit_h,
  output wire debug_pixel_valid,debug_raw_pixel,debug_kept_pixel);
    localparam MW=WIDTH/8,MH=HEIGHT/8,MT=MW*MH;
    reg [5:0] state;
    reg phase,flood;
    reg [23:0] last_id;
    reg video_seen;reg [23:0] video_id;
    wire fresh=!video_seen || frame_id!=video_id;
    wire in_roi=x>=ROI_L && x<=ROI_R && y>=ROI_T && y<=ROI_B;
    wire [7:0] r=rgb[23:16],g=rgb[15:8],b=rgb[7:0];
    wire [7:0] dr=r>=background_rgb[23:16]?r-background_rgb[23:16]:background_rgb[23:16]-r;
    wire [7:0] dg=g>=background_rgb[15:8]?g-background_rgb[15:8]:background_rgb[15:8]-g;
    wire [7:0] db=b>=background_rgb[7:0]?b-background_rgb[7:0]:background_rgb[7:0]-b;
    wire [9:0] bg_delta={2'b0,dr}+{2'b0,dg}+{2'b0,db};
    wire [8:0] warmth={1'b0,r}-{1'b0,b};
    // Relative warmth excludes neutral dark shadows and warm white paper.
    wire brown_color=r>=35 && {1'b0,r}+16>=g && {1'b0,g}>={1'b0,b}+3 &&
                     {1'b0,r}>={1'b0,b}+12 && {warmth,4'b0000}>=({5'd0,r}<<1)+{5'd0,r};
    wire brown=background_valid && in_roi && brown_color && bg_delta>=55;
    wire [7:0] hi=r>g?(r>b?r:b):(g>b?g:b),lo=r<g?(r<b?r:b):(g<b?g:b);
    wire [9:0] lum={2'b0,r}+{1'b0,g,1'b0}+{2'b0,b};
    wire white=in_roi && lum>=480 && {1'b0,hi}-{1'b0,lo}<=({1'b0,hi}>>2)+12 && !brown_color;

    reg pix_de,pix_brown,pix_white;
    reg [11:0] px,py;
    wire begin_vote=state==0 && acquire && fresh && background_valid && de && x==0 && y==0;
    wire label_vote=state==43 && frame_id!=last_id && de && x==0 && y==0;
    wire refine_begin=state==19 && frame_id!=last_id && de && x==0 && y==0;
    wire [13:0] pixel_addr=(y>>3)*MW+(x>>3);
    wire [13:0] vote_addr=(py>>3)*MW+(px>>3);
    (* ram_style="block" *) reg [6:0] columns[0:MW-1];
    reg [6:0] col_q;reg [3:0] horizontal;
    (* ram_style="block" *) reg interior[0:16383];
    reg interior_q;
    wire vote_pixel=phase?(pix_white && interior_q):pix_brown;
    wire [6:0] votes=(py[2:0]==0?7'd0:col_q)+horizontal+vote_pixel;
    wire vote_write=state==1 && pix_de && px[2:0]==7 && py[2:0]==7;
    wire vote_keep=votes>=(phase?8:16);
    always @(posedge clk) begin
        col_q<=columns[x>>3];interior_q<=interior[pixel_addr];
        if(state==1 && pix_de && px[2:0]==7) columns[px>>3]<=votes;
    end

    reg [11:0] bl,br,wl,wr;
    reg clipped;reg [20:0] support;
    (* ram_style="block" *) reg [47:0] rows[0:HEIGHT-1];
    reg [47:0] row_q;wire [9:0] row_addr;
    reg row_write;reg [9:0] row_write_addr;
    always @(posedge clk) begin
        row_q<=rows[row_addr];
        if(row_write) rows[row_write_addr]<={bl,br,wl,wr};
    end

    // 00 empty, 01 unvisited candidate (or exterior flood), 10 retained,
    // 11 one-cell non-cascading guard. Storage is reused for box and label.
    (* ram_style="block" *) reg [1:0] mask[0:16383];
    reg [13:0] maddr;reg [1:0] mask_q;
    reg erase;
    reg [13:0] scan_addr;reg [7:0] scan_x,current_x,nx;
    reg [6:0] scan_y,current_y,ny;
    reg [2:0] neighbour;
    (* ram_style="block" *) reg [15:0] queue[0:16383];
    reg [14:0] head,tail,component_count;
    reg [15:0] queue_q;
    reg queue_write;reg [13:0] queue_addr;reg [15:0] queue_data;
    reg [1:0] components;
    wire [13:0] replay_addr=queue_q[14:8]*MW+queue_q[7:0];
    wire guard_write=state==26 && mask_q==0;
    wire fill_write=state==35;
    wire mask_write=vote_write || erase || state==15 || guard_write || fill_write;
    wire [13:0] mask_waddr=vote_write?vote_addr:(state==15?replay_addr:maddr);
    wire [1:0] mask_wdata=vote_write?(vote_keep?2'b01:2'b00):
                          (erase?(flood?2'b01:2'b00):
                          (guard_write?2'b11:(fill_write?(mask_q==1?2'b00:2'b10):2'b10)));
    wire [13:0] mask_raddr=((state==20 || refine_begin) && de)?pixel_addr:maddr;
    always @(posedge clk) begin
        mask_q<=mask[mask_raddr];
        if(mask_write) mask[mask_waddr]<=mask_wdata;
        queue_q<=queue[head[13:0]];
        if(queue_write) queue[queue_addr]<=queue_data;
    end
    wire neighbour_ok=neighbour==0?current_x>0:
                       neighbour==1?current_x<MW-1:
                       neighbour==2?current_y>0:
                       neighbour==3?current_y<MH-1:
                       neighbour==4?(current_x>0 && current_y>0):
                       neighbour==5?(current_x<MW-1 && current_y>0):
                       neighbour==6?(current_x>0 && current_y<MH-1):(current_x<MW-1 && current_y<MH-1);
    wire guard_ok=neighbour==0?(scan_x>ROI_L/8 && scan_y>ROI_T/8):
                  neighbour==1?scan_y>ROI_T/8:
                  neighbour==2?(scan_x<ROI_R/8 && scan_y>ROI_T/8):
                  neighbour==3?scan_x>ROI_L/8:
                  neighbour==4?scan_x<ROI_R/8:
                  neighbour==5?(scan_x>ROI_L/8 && scan_y<ROI_B/8):
                  neighbour==6?scan_y<ROI_B/8:(scan_x<ROI_R/8 && scan_y<ROI_B/8);
    wire perimeter=scan_x==0 || scan_x==MW-1 || scan_y==0 || scan_y==MH-1;
    reg [2:0] kx,ky;reg inside_cell;
    wire kernel_ok=scan_x>=ROI_L/8+2 && scan_x+2<=ROI_R/8 &&
                   scan_y>=ROI_T/8+2 && scan_y+2<=ROI_B/8;
    always @(posedge clk) if(state==41) interior[scan_addr]<=inside_cell;

    // Independent read port keeps diagnostic masks visible while idle.
    (* ram_style="block" *) reg [1:0] display_map[0:16383];
    reg [1:0] display_q;reg display_ready;
    always @(posedge clk) begin
        display_q<=display_map[pixel_addr];
        if(fill_write && (!phase || mask_q!=1))
            display_map[scan_addr]<=phase?2'b11:(mask_q==1?2'b00:2'b10);
    end
    assign debug_pixel_valid=enable && background_valid && display_ready && pix_de;
    assign debug_kept_pixel=display_q[1];
    assign debug_raw_pixel=display_q[0] || (pix_brown && !display_q[1]);

    reg fit_start;
    wire fit_done,fit_valid,fit_square;
    wire [11:0] fit_x,fit_y,fit_w,fit_h,fit_points,fit_bad;
    wire [8:0] fit_angle;wire [31:0] fit_area;
    label_rect_fit_reference #(.HEIGHT(HEIGHT),.BAD_POINT_FACTOR(4),.REGION_VALIDATED(1)) fitter(
        .clk(clk),.rst_n(rst_n),.start(fit_start),.abort(!enable),
        .edge_tolerance(phase?5'd16:5'd8),.relaxed_box(1'b1),.label_mode(phase),
        .row_addr(row_addr),.left_x(phase?row_q[23:12]:row_q[47:36]),
        .right_x(phase?row_q[11:0]:row_q[35:24]),.done(fit_done),.valid(fit_valid),
        .cx(fit_x),.cy(fit_y),.w(fit_w),.h(fit_h),.angle(fit_angle),.square(fit_square),
        .area_pixels(fit_area),.points_count(fit_points),.bad_points_count(fit_bad));
    task reset_scan;
        begin scan_addr<=0;scan_x<=0;scan_y<=0;maddr<=0;end
    endtask
    task advance_scan;
        begin scan_addr<=scan_addr+1'b1;maddr<=scan_addr+1'b1;
            if(scan_x==MW-1) begin scan_x<=0;scan_y<=scan_y+1'b1;end else scan_x<=scan_x+1'b1;end
    endtask
    task invalid_scene;
        input [3:0] why;
        begin valid<=0;reason<=why;sample<=1;state<=0;end
    endtask
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=0;phase<=0;flood<=0;sample<=0;valid<=0;reason<=0;last_id<=0;
            video_seen<=0;video_id<=0;pix_de<=0;pix_brown<=0;pix_white<=0;px<=0;py<=0;
            horizontal<=0;bl<=4095;br<=0;wl<=4095;wr<=0;clipped<=0;support<=0;
            row_write<=0;row_write_addr<=0;maddr<=0;erase<=0;scan_addr<=0;scan_x<=0;scan_y<=0;
            current_x<=0;current_y<=0;nx<=0;ny<=0;neighbour<=0;head<=0;tail<=0;
            component_count<=0;components<=0;queue_write<=0;queue_addr<=0;queue_data<=0;
            kx<=0;ky<=0;inside_cell<=0;display_ready<=0;fit_start<=0;
            bx<=0;by<=0;bw<=0;bh<=0;ba<=0;bsquare<=0;lx<=0;ly<=0;lw<=0;lh<=0;la<=0;lsquare<=0;
            debug_code<=0;debug_points<=0;debug_bad_points<=0;debug_fit_w<=0;debug_fit_h<=0;
        end else begin
            sample<=0;fit_start<=0;erase<=0;queue_write<=0;row_write<=0;
            pix_de<=de;pix_brown<=brown;pix_white<=white;px<=x;py<=y;
            if(!enable) video_seen<=0;
            else if(de && x==0 && y==0) begin video_seen<=1;video_id<=frame_id;end
            if(state==20 && pix_de && px==WIDTH-1) begin row_write<=1;row_write_addr<=py[9:0];end
            if(!enable) begin state<=0;valid<=0;display_ready<=0;end
            else if(!background_valid) begin display_ready<=0;if(state!=0) invalid_scene(14);end
            else case(state)
            0:if(begin_vote) begin state<=1;phase<=0;flood<=0;last_id<=frame_id;valid<=0;horizontal<=0;display_ready<=0;end
            1:if(pix_de) begin
                if(px[2:0]==0) horizontal<=vote_pixel;
                else if(px[2:0]==7) horizontal<=0;
                else horizontal<=horizontal+vote_pixel;
                if(px==WIDTH-1 && py==HEIGHT-1) begin reset_scan;components<=0;flood<=0;state<=22;end
            end
            2:state<=3;
            3:if(mask_q==1 || mask_q==3) begin
                erase<=1;queue_write<=1;queue_addr<=0;queue_data<={1'b0,scan_y,scan_x};
                head<=0;tail<=1;component_count<=mask_q==1?1:0;state<=5;
            end else state<=4;
            4:if(scan_addr==MT-1) begin
                if(components==0) begin debug_code<=2;debug_points<=0;debug_bad_points<=0;debug_fit_w<=0;debug_fit_h<=0;invalid_scene(phase?1:7);end
                else if(components>1) begin debug_code<=6;debug_points<=0;debug_bad_points<=0;debug_fit_w<=0;debug_fit_h<=0;invalid_scene(phase?2:8);end
                else begin reset_scan;flood<=1;state<=31;end
            end else begin advance_scan;state<=2;end
            5:state<=14;
            14:state<=6;
            6:begin current_x<=queue_q[7:0];current_y<=queue_q[14:8];neighbour<=0;state<=7;end
            7:if(neighbour_ok) begin
                case(neighbour)
                0:begin nx<=current_x-1'b1;ny<=current_y;maddr<=current_y*MW+current_x-1'b1;end
                1:begin nx<=current_x+1'b1;ny<=current_y;maddr<=current_y*MW+current_x+1'b1;end
                2:begin nx<=current_x;ny<=current_y-1'b1;maddr<=(current_y-1'b1)*MW+current_x;end
                3:begin nx<=current_x;ny<=current_y+1'b1;maddr<=(current_y+1'b1)*MW+current_x;end
                4:begin nx<=current_x-1'b1;ny<=current_y-1'b1;maddr<=(current_y-1'b1)*MW+current_x-1'b1;end
                5:begin nx<=current_x+1'b1;ny<=current_y-1'b1;maddr<=(current_y-1'b1)*MW+current_x+1'b1;end
                6:begin nx<=current_x-1'b1;ny<=current_y+1'b1;maddr<=(current_y+1'b1)*MW+current_x-1'b1;end
                default:begin nx<=current_x+1'b1;ny<=current_y+1'b1;maddr<=(current_y+1'b1)*MW+current_x+1'b1;end
                endcase
                state<=8;
            end else state<=11;
            8:state<=9;
            9:begin
                if(flood?mask_q==0:(mask_q==1 || mask_q==3)) begin
                    if(tail==16384) begin debug_code<=1;invalid_scene(phase?2:9);end
                    else begin queue_write<=1;queue_addr<=tail[13:0];queue_data<={1'b0,ny,nx};
                        tail<=tail+1'b1;component_count<=component_count+(!flood && mask_q==3?0:1);erase<=1;state<=10;end
                end else state<=10;
            end
            10:state<=11;
            11:if(neighbour<(phase && !flood?7:3)) begin neighbour<=neighbour+1'b1;state<=7;end
                else if(head+1==tail) state<=12;
                else begin head<=head+1'b1;state<=5;end
            12:if(flood) begin maddr<=scan_addr;state<=33;end
                else if(component_count>=(phase?6:MIN_COMPONENT) && components<3) begin
                    components<=components+1'b1;head<=0;state<=13;
                end else begin maddr<=scan_addr;state<=4;end
            13:state<=15;
            15:if(head+1==tail) begin maddr<=scan_addr;state<=4;end
                else begin head<=head+1'b1;state<=13;end
            22:state<=23;
            23:if(mask_q==1) begin neighbour<=0;state<=24;end else state<=30;
            24:if(guard_ok) begin
                case(neighbour)
                0:maddr<=scan_addr-MW-1;1:maddr<=scan_addr-MW;2:maddr<=scan_addr-MW+1;
                3:maddr<=scan_addr-1'b1;4:maddr<=scan_addr+1'b1;
                5:maddr<=scan_addr+MW-1;6:maddr<=scan_addr+MW;default:maddr<=scan_addr+MW+1;
                endcase
                state<=25;
            end else state<=27;
            25:state<=26;
            26:state<=27;
            27:if(neighbour<7) begin neighbour<=neighbour+1'b1;state<=24;end else state<=30;
            30:if(scan_addr==MT-1) begin reset_scan;components<=0;flood<=0;state<=2;end
                else begin advance_scan;state<=22;end
            31:state<=32;
            32:if(perimeter && mask_q==0) begin
                erase<=1;queue_write<=1;queue_addr<=0;queue_data<={1'b0,scan_y,scan_x};
                head<=0;tail<=1;component_count<=1;state<=5;
            end else state<=33;
            33:if(scan_addr==MT-1) begin reset_scan;state<=34;end
                else begin advance_scan;state<=31;end
            34:state<=35;
            35:state<=36;
            36:if(scan_addr==MT-1) begin
                    flood<=0;display_ready<=1;
                    if(phase) state<=19;else begin reset_scan;state<=37;end
                end else begin advance_scan;state<=34;end
            37:begin kx<=0;ky<=0;inside_cell<=kernel_ok;state<=38;end
            38:if(kernel_ok) begin maddr<=(scan_y+ky-2)*MW+scan_x+kx-2;state<=39;end
                else state<=41;
            39:state<=40;
            40:begin
                if(!mask_q[1]) inside_cell<=0;
                if(kx==4 && ky==4) state<=41;
                else begin if(kx==4) begin kx<=0;ky<=ky+1'b1;end else kx<=kx+1'b1;state<=38;end
            end
            41:state<=42;
            42:if(scan_addr==MT-1) state<=19;
                else begin advance_scan;state<=37;end
            19:if(refine_begin) begin
                last_id<=frame_id;bl<=4095;br<=0;wl<=4095;wr<=0;clipped<=0;support<=0;state<=20;
            end
            20:if(pix_de) begin
                if(px==0) begin bl<=4095;br<=0;wl<=4095;wr<=0;end
                if(!phase && pix_brown && mask_q[1]) begin
                    if(bl==4095) bl<=px;br<=px;support<=support+1'b1;
                    if(px==ROI_L || px==ROI_R || py==ROI_T || py==ROI_B) clipped<=1;
                end
                if(phase && pix_white && mask_q[1] && interior_q) begin
                    if(wl==4095) wl<=px;wr<=px;support<=support+1'b1;
                end
                if(px==WIDTH-1 && py==HEIGHT-1) state<=21;
            end
            21:if(clipped) invalid_scene(10);
                else begin fit_start<=1;state<=16;end
            16:if(fit_done) begin
                debug_points<=fit_points;debug_bad_points<=fit_bad;debug_fit_w<=fit_w;debug_fit_h<=fit_h;
                if(!fit_valid) debug_code<=2;
                else if(fit_w<(phase?32:64)) debug_code<=4;
                else if(fit_h<(phase?24:48)) debug_code<=5;
                else if(!phase && support<(fit_area>>2)) debug_code<=7;
                else debug_code<=0;
                if(!fit_valid || fit_w<(phase?32:64) || fit_h<(phase?24:48) ||
                   (!phase && support<(fit_area>>2))) invalid_scene(phase?2:9);
                else if(!phase) begin bx<=fit_x;by<=fit_y;bw<=fit_w;bh<=fit_h;ba<=fit_angle;bsquare<=fit_square;
                    phase<=1;state<=43;end
                else begin lx<=fit_x;ly<=fit_y;lw<=fit_w;lh<=fit_h;la<=fit_angle;lsquare<=fit_square;state<=18;end
            end
            43:if(label_vote) begin horizontal<=0;last_id<=frame_id;state<=1;end
            18:begin valid<=1;reason<=0;sample<=1;state<=0;end
            default:state<=0;
            endcase
        end
    end
endmodule
