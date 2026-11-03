`timescale 1ns/1ps
module tb_region;
    localparam W=1280,H=720,CX=900,CY=360;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,enable=0,acquire=0,de=0;
    reg [11:0] x=0,y=0;reg [23:0] rgb=0,frame_id=0;
    wire sample,valid;wire [3:0] reason;
    wire [11:0] bx,by,bw,bh,lx,ly,lw,lh,pts,bad,fw,fh;
    wire [8:0] ba,la;wire bsquare,lsquare;wire [2:0] code;
    wire debug_valid,debug_raw,debug_keep;
    wire ref_sample,ref_valid,ref_bsquare,ref_lsquare,ref_debug_valid,ref_debug_raw,ref_debug_keep;
    wire [3:0] ref_reason;wire [2:0] ref_code;
    wire [11:0] ref_bx,ref_by,ref_bw,ref_bh,ref_lx,ref_ly,ref_lw,ref_lh,ref_pts,ref_bad,ref_fw,ref_fh;
    wire [8:0] ref_ba,ref_la;
    integer scenario=0,shift_x=0,shift_y=0,cosine=1024,sine=0;
    integer tag_dx=0,tag_dy=0;
    integer xx,yy,rx,ry,dx,dy,frames,timeout;
    reg [23:0] color;
    reg dde=0;reg [11:0] px=0,py=0;reg [23:0] prgb=0,pfid=0;
    always @(posedge clk) begin dde<=de;px<=x;py<=y;prgb<=rgb;pfid<=frame_id;end
    label_scene_detector_map #(.WIDTH(W),.HEIGHT(H),.ROI_L(512),.ROI_R(W-1),.ROI_B(H-1)) dut(
        .clk(clk),.rst_n(rst_n),.enable(enable),.acquire(acquire),.de(dde),.x(px),.y(py),.rgb(prgb),.frame_id(pfid),
        .background_valid(1'b1),.background_rgb(24'hdcdcdc),.sample(sample),.valid(valid),.reason(reason),
        .bx(bx),.by(by),.bw(bw),.bh(bh),.ba(ba),.bsquare(bsquare),.lx(lx),.ly(ly),.lw(lw),.lh(lh),.la(la),.lsquare(lsquare),
        .debug_code(code),.debug_points(pts),.debug_bad_points(bad),.debug_fit_w(fw),.debug_fit_h(fh),
        .debug_pixel_valid(debug_valid),.debug_raw_pixel(debug_raw),.debug_kept_pixel(debug_keep));
    label_scene_detector_map_reference #(.WIDTH(W),.HEIGHT(H),.ROI_L(512),.ROI_R(W-1),.ROI_B(H-1)) reference_detector(
        .clk(clk),.rst_n(rst_n),.enable(enable),.acquire(acquire),.de(dde),.x(px),.y(py),.rgb(prgb),.frame_id(pfid),
        .background_valid(1'b1),.background_rgb(24'hdcdcdc),.sample(ref_sample),.valid(ref_valid),.reason(ref_reason),
        .bx(ref_bx),.by(ref_by),.bw(ref_bw),.bh(ref_bh),.ba(ref_ba),.bsquare(ref_bsquare),
        .lx(ref_lx),.ly(ref_ly),.lw(ref_lw),.lh(ref_lh),.la(ref_la),.lsquare(ref_lsquare),
        .debug_code(ref_code),.debug_points(ref_pts),.debug_bad_points(ref_bad),.debug_fit_w(ref_fw),.debug_fit_h(ref_fh),
        .debug_pixel_valid(ref_debug_valid),.debug_raw_pixel(ref_debug_raw),.debug_kept_pixel(ref_debug_keep));
    always @(posedge clk) begin
        #1;
        if(rst_n && {sample,valid,reason,bx,by,bw,bh,ba,bsquare,lx,ly,lw,lh,la,lsquare,code,pts,bad,fw,fh,
                     debug_valid,debug_raw,debug_keep,dut.state,dut.maddr,dut.nx,dut.ny} !==
                    {ref_sample,ref_valid,ref_reason,ref_bx,ref_by,ref_bw,ref_bh,ref_ba,ref_bsquare,
                     ref_lx,ref_ly,ref_lw,ref_lh,ref_la,ref_lsquare,ref_code,ref_pts,ref_bad,ref_fw,ref_fh,
                     ref_debug_valid,ref_debug_raw,ref_debug_keep,reference_detector.state,reference_detector.maddr,
                     reference_detector.nx,reference_detector.ny}) $fatal(1,"cycle-exact V5.3 detector/reference mismatch");
    end
    wire relative_done;wire signed [12:0] relative_u,relative_v;
    wire [12:0] relative_wr,relative_hr;wire [8:0] relative_angle;
    label_relative relative_measure(.clk(clk),.rst_n(rst_n),.start(sample && valid),.abort(!enable),
        .bx(bx),.by(by),.bw(bw),.bh(bh),.ba(ba),.lx(lx),.ly(ly),.lw(lw),.lh(lh),.la(la),
        .done(relative_done),.u(relative_u),.v(relative_v),.wr(relative_wr),.hr(relative_hr),.alpha(relative_angle));

    wire overlay_hit;wire [23:0] overlay_color;
    label_scene_overlay_v4 overlay(.clk(clk),.rst_n(rst_n),.enable(enable),.de(de),.x(x),.y(y),
        .state(2'd0),.result(2'd0),.cause(4'd0),.fail(3'd0),.size_fail(2'd0),.locked(1'b0),.geometry(1'b0),.scene(1'b0),
        .reference_set(1'b0),.learn_failed(1'b0),.alarm(1'b0),.muted(1'b0),
        .du(13'sd0),.dv(13'sd0),.move_x(13'sd0),.move_y(13'sd0),.da(10'sd0),.main_item(2'd0),
        .box_x(bx),.box_y(by),.box_w(bw),.box_h(bh),.box_a(ba),.square(bsquare),
        .label_x(lx),.label_y(ly),.label_w(lw),.label_h(lh),.label_a(la),
        .ta(9'd0),.rp(16'sd0),.rq(16'sd0),.rhw(12'd0),.rhh(12'd0),.tx(12'd0),.ty(12'd0),
        .total(24'd0),.passes(24'd0),.fails(24'd0),.unknowns(24'd0),
        .background_status(3'd4),.background_progress(4'd8),.debug_code(code),
        .debug_points(pts),.debug_bad_points(bad),.debug_fit_w(fw),.debug_fit_h(fh),
        .debug_pixel_valid(debug_valid),.debug_raw_pixel(debug_raw),.debug_kept_pixel(debug_keep),
        .O_hit(overlay_hit),.O_color(overlay_color));
    reg observe=0;reg check1=0,check2=0,check3=0;
    reg [1:0] expected1=0,expected2=0,expected3=0;
    integer green=0,cyan=0;
    always @(posedge clk) begin
        check1<=observe && de && x>512 && x<W-1 && y>0 && y<H-1;
        check2<=check1;check3<=check2;
        expected1<=0;
        if(x[2:0]==0 || y[2:0]==0) begin
            if(dut.display_map[(y/8)*(W/8)+x/8]==2) expected1<=1;
            if(dut.display_map[(y/8)*(W/8)+x/8]==3) expected1<=2;
        end
        expected2<=expected1;expected3<=expected2;
    end
    always @(negedge clk) if(check3) begin
        if(expected3==1) begin
            if(!overlay_hit || overlay_color!==24'h00ff40) $fatal(1,"green diagnostic mask misaligned");
            green=green+1;
        end else if(expected3==2) begin
            if(!overlay_hit || overlay_color!==24'h00ffff) $fatal(1,"cyan diagnostic mask misaligned");
            cyan=cyan+1;
        end else if(overlay_hit) $fatal(1,"unexpected overlay outside diagnostic grid");
    end

    // Continuous video; the detector must acquire fresh frames itself.
    initial begin
        forever begin
            for(yy=0;yy<H;yy=yy+1) begin
                for(xx=0;xx<W;xx=xx+1) begin
                    @(negedge clk);x=xx;y=yy;de=1;
                    dx=xx-CX-shift_x;dy=yy-CY-shift_y;
                    rx=(dx*cosine+dy*sine)/1024;ry=(-dx*sine+dy*cosine)/1024;
                    color=24'hdcdcdc;
                    if(scenario!=1) begin
                        // Neutral cast shadow attached to the right side.
                        if(scenario==3 && rx>=120 && rx<144 && ry>=-96 && ry<105) color=24'h909090;
                        if(rx>=-120 && rx<120 && ry>=-100 && ry<100) begin
                            color=scenario==6?24'hb4a078:(scenario==10?24'hb4a08c:24'h8c643c);
                            // Eight-pixel dark seam crosses the whole box.
                            if((scenario==3 || scenario==4) && ry>=44 && ry<52) color=24'h282828;
                            if(scenario!=2 && scenario!=7 && rx>=tag_dx-40 && rx<tag_dx+40 && ry>=tag_dy-28 && ry<tag_dy+28) begin
                                color=scenario==6?24'hd2c8be:24'hf0f0f0;
                                if(scenario==3 && rx>tag_dx-25 && rx<tag_dx+25 && ry>tag_dy-15 && ry<tag_dy+15 && (rx%7<4)) color=24'h101010;
                                // Dense black print, continuous two-pixel white border.
                                if(scenario==4 && rx>=tag_dx-38 && rx<tag_dx+38 && ry>=tag_dy-26 && ry<tag_dy+26) color=24'h101010;
                            end
                            if(scenario==7 && ((rx>=-96 && rx< -32) || (rx>=32 && rx<96)) && ry>=-20 && ry<20) color=24'hf0f0f0;
                        end
                    end
                    if(scenario==5) begin
                        color=24'hdcdcdc;
                        if(((xx>=CX-160 && xx<CX-80) || (xx>=CX+80 && xx<CX+160)) && yy>=CY-80 && yy<CY+60) color=24'h8c643c;
                    end
                    // Small isolated warm speck must not form another box.
                    if(scenario==3 && xx>=600 && xx<604 && yy>=20 && yy<24) color=24'h8c643c;
                    rgb=color;
                end
                @(negedge clk);de=0;repeat(8) @(negedge clk);
            end
            frame_id=frame_id+1;repeat(100) @(negedge clk);
        end
    end

    task check_scene;
        input integer which,sx,sy,c,s,expected;
        integer wait_cycles,angle_error,expected_x,expected_y,rel_cycles;
        begin
            @(negedge clk);
            if(which!=8 && which!=9) begin
                enable=0;acquire=0;rst_n=0;repeat(4) @(negedge clk);
            end
            scenario=which==8?2:(which==9?1:which);shift_x=sx;shift_y=sy;cosine=c;sine=s;
            rst_n=1;enable=1;acquire=1;
            wait_cycles=0;
            while(!sample && wait_cycles<24000000) begin @(negedge clk);wait_cycles=wait_cycles+1;end
            if(!sample) $fatal(1,"timeout case=%0d state=%0d phase=%0d",which,dut.state,dut.phase);
            acquire=0;
            $display("REGION case=%0d shift=%0d,%0d valid=%b reason=%0d box=%0d,%0d %0dx%0d a=%0d label=%0d,%0d %0dx%0d a=%0d cycles=%0d",which,sx,sy,valid,reason,bx,by,bw,bh,ba,lx,ly,lw,lh,la,wait_cycles);
            if(expected==0) begin
                if(!valid) $fatal(1,"expected valid case=%0d reason=%0d code=%0d pts=%0d bad=%0d fit=%0dx%0d",which,reason,code,pts,bad,fw,fh);
                if(bx<CX-2+sx || bx>CX+2+sx || by<CY-2+sy || by>CY+2+sy || bw<236 || bw>244 || bh<196 || bh>204)
                    $fatal(1,"box geometry wrong");
                expected_x=CX+sx+(tag_dx*c-tag_dy*s)/1024;
                expected_y=CY+sy+(tag_dx*s+tag_dy*c)/1024;
                if(lx<expected_x-2 || lx>expected_x+2 || ly<expected_y-2 || ly>expected_y+2 || lw<76 || lw>84 || lh<52 || lh>60)
                    $fatal(1,"label geometry wrong");
                angle_error=$signed({1'b0,la})-$signed({1'b0,ba});
                if(angle_error>180) angle_error=angle_error-360;
                if(angle_error< -180) angle_error=angle_error+360;
                if(angle_error>3 || angle_error< -3) $fatal(1,"co-rotated label angle inconsistent");
                // Persistent filled maps must include the print at the centre,
                // and exclude the neutral shadow outside the box.
                if(dut.display_map[(expected_y/8)*(W/8)+expected_x/8]!==2'b11) $fatal(1,"label hole not filled in display map");
                rel_cycles=0;
                while(!relative_done && rel_cycles<500) begin @(negedge clk);rel_cycles=rel_cycles+1;end
                if(!relative_done || relative_u<tag_dx*1024/240-12 || relative_u>tag_dx*1024/240+12 ||
                   relative_v<tag_dy*1024/200-12 || relative_v>tag_dy*1024/200+12)
                    $fatal(1,"relative position changed u=%0d v=%0d tag=%0d,%0d",relative_u,relative_v,tag_dx,tag_dy);
                if(which==0) begin
                    observe=1;repeat((W+9)*H+110) @(negedge clk);observe=0;
                    repeat(4) @(negedge clk);
                    if(green==0 || cyan==0) $fatal(1,"persistent diagnostic colors missing");
                    $display("MASK persistent grid aligned green=%0d cyan=%0d",green,cyan);
                end
            end else if(valid || reason!=expected) $fatal(1,"wrong rejection expected=%0d got=%0d valid=%b",expected,reason,valid);
            if(which==8 && dut.display_map[(CY/8)*(W/8)+CX/8]==3) $fatal(1,"stale label diagnostic survived label removal");
            if((expected==1 || expected==2 || expected==7 || expected==8) && (pts!=0 || fw!=0 || fh!=0))
                $fatal(1,"old fitted dimensions leaked into missing/ambiguous-region diagnostics");
            if(which==9 && dut.display_ready) $fatal(1,"stale box diagnostic survived empty station");
            repeat(10) @(negedge clk);
        end
    endtask
    initial begin
        check_scene(10,0,0,1024,0,0);
        check_scene(0,0,0,1024,0,0);
        check_scene(8,0,0,1024,0,1);
        check_scene(9,0,0,1024,0,7);
        check_scene(3,-36,-28,1024,0,0);
        check_scene(3,36,28,1024,0,0);
        check_scene(4,0,0,1024,0,0);
        check_scene(6,0,0,1024,0,0);
        check_scene(3,0,0,1002,213,0);
        check_scene(3,0,0,887,512,0);
        check_scene(1,0,0,1024,0,7);
        check_scene(2,0,0,1024,0,1);
        check_scene(5,0,0,1024,0,8);
        check_scene(7,0,0,1024,0,2);
        check_scene(0,-300,0,1024,0,10);
        tag_dx=36;tag_dy=-24;
        check_scene(3,-36,20,1002,213,0);
        $display("PASS tb_region: voting, seams, neutral shadows, white border, print, translation, rotation, empty/no-label/multi-region rejection");
        $finish;
    end
endmodule
