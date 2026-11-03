`timescale 1ns/1ps
module tb_size_fusion;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,enable=0,start=0,learn=0,ack=0,clear=0;
    reg raw_sample=0,raw_valid=1;reg [3:0] raw_reason=0;
    reg [11:0] bx=900,by=360,bw=300,bh=200,lx=900,ly=360,lw=80,lh=40;
    reg [8:0] ba=0,la=0;reg bsquare=0,lsquare=0;
    wire fs,fv,busy;wire [3:0] fr;
    wire [11:0] fx,fy,fw,fh,flx,fly,flw,flh;
    wire [8:0] fa,fla;wire fbs,fls;
    wire rd;wire signed [12:0] u,v;wire [12:0] wr,hr;wire [8:0] alpha;
    reg delayed_invalid=0;
    wire [1:0] state,result,size_fail;wire [3:0] cause;wire [2:0] fail;
    wire locked,geometry,reference_set,learn_failed,alarm,muted;
    wire signed [12:0] ref_u,ref_v,du,dv;
    wire [12:0] ref_wr,ref_hr;wire [8:0] ref_alpha;
    wire ref_square,ref_label_square;wire [11:0] ref_bw,ref_bh;
    wire signed [9:0] da;
    wire [11:0] box_x,box_y,box_w,box_h,label_x,label_y,label_w,label_h;
    wire [8:0] box_a,label_a;wire box_square,scene;
    wire [1:0] branch,main_item;wire [23:0] total,passes,fails,unknowns;
    reg de=0;reg [11:0] ox=0,oy=0;wire ohit;wire [23:0] ocolor;
    integer ncheck=0,npass=0,nfail=0,nunknown=0;
    label_observation_fusion fusion(.clk(clk),.rst_n(rst_n),.enable(enable && state!=0),
        .sample(raw_sample),.valid(raw_valid),.reason(raw_reason),
        .bx(bx),.by(by),.bw(bw),.bh(bh),.ba(ba),.bsquare(bsquare),.lx(lx),.ly(ly),.lw(lw),.lh(lh),.la(la),.lsquare(lsquare),
        .busy(busy),.O_sample(fs),.O_valid(fv),.O_reason(fr),.O_bx(fx),.O_by(fy),.O_bw(fw),.O_bh(fh),
        .O_ba(fa),.O_bsquare(fbs),.O_lx(flx),.O_ly(fly),.O_lw(flw),.O_lh(flh),.O_la(fla),.O_lsquare(fls));
    label_relative relative_measure(.clk(clk),.rst_n(rst_n),.start(fs && fv),.abort(!enable),
        .bx(fx),.by(fy),.bw(fw),.bh(fh),.ba(fa),.lx(flx),.ly(fly),.lw(flw),.lh(flh),.la(fla),
        .done(rd),.u(u),.v(v),.wr(wr),.hr(hr),.alpha(alpha));
    always @(posedge clk) delayed_invalid<=fs && !fv;
    label_scene_controller #(.TIMEOUT_CYCLES(2000)) controller(
        .clk(clk),.rst_n(rst_n),.enable(enable),.auto_mode(1'b0),.start(start),.learn(learn),.ack(ack),.clear(clear),
        .sample(rd || delayed_invalid),.valid(fv),.reason(fr),.u(u),.v(v),.wr(wr),.hr(hr),.alpha(alpha),
        .bx(fx),.by(fy),.bw(fw),.bh(fh),.ba(fa),.bsquare(fbs),.lx(flx),.ly(fly),.lw(flw),.lh(flh),.la(fla),.lsquare(fls),
        .state(state),.result(result),.cause(cause),.fail(fail),.size_fail(size_fail),.locked(locked),.geometry(geometry),
        .reference_set(reference_set),.learn_failed(learn_failed),.O_alarm(alarm),.muted(muted),
        .ref_u(ref_u),.ref_v(ref_v),.ref_wr(ref_wr),.ref_hr(ref_hr),.ref_alpha(ref_alpha),
        .ref_square(ref_square),.ref_label_square(ref_label_square),.ref_bw(ref_bw),.ref_bh(ref_bh),
        .du(du),.dv(dv),.da(da),.box_x(box_x),.box_y(box_y),.box_w(box_w),.box_h(box_h),.box_a(box_a),.box_square(box_square),
        .label_x(label_x),.label_y(label_y),.label_w(label_w),.label_h(label_h),.label_a(label_a),.scene(scene),
        .branch(branch),.main_item(main_item),.total(total),.passes(passes),.fails(fails),.unknowns(unknowns));
    label_scene_overlay_v4 overlay(.clk(clk),.rst_n(rst_n),.enable(enable),.de(de),.x(ox),.y(oy),
        .state(state),.result(result),.cause(cause),.fail(fail),.size_fail(size_fail),.locked(locked),.geometry(geometry),.scene(scene),
        .reference_set(reference_set),.learn_failed(learn_failed),.alarm(alarm),.muted(muted),
        .du(du),.dv(dv),.da(da),.main_item(main_item),.move_x(13'sd0),.move_y(13'sd0),
        .box_x(box_x),.box_y(box_y),.box_w(box_w),.box_h(box_h),.box_a(box_a),.square(ref_square),
        .label_x(label_x),.label_y(label_y),.label_w(label_w),.label_h(label_h),.label_a(label_a),
        .ta(9'd0),.rp(16'sd0),.rq(16'sd0),.rhw(12'd0),.rhh(12'd0),.tx(12'd0),.ty(12'd0),
        .total(total),.passes(passes),.fails(fails),.unknowns(unknowns),.background_status(3'd4),.background_progress(4'd8),
        .debug_code(3'd0),.debug_points(12'd0),.debug_bad_points(12'd0),.debug_fit_w(12'd0),.debug_fit_h(12'd0),
        .debug_pixel_valid(1'b0),.debug_raw_pixel(1'b0),.debug_kept_pixel(1'b0),.O_hit(ohit),.O_color(ocolor));
    function [23:0] bcd_count;
        input integer n;integer i,t;
        begin t=n;bcd_count=0;for(i=0;i<6;i=i+1) begin bcd_count[i*4+:4]=t%10;t=t/10;end end
    endfunction
    task defaults;
        begin bx=900;by=360;bw=300;bh=200;lx=900;ly=360;lw=80;lh=40;ba=0;la=0;bsquare=0;lsquare=0;raw_valid=1;raw_reason=0;end
    endtask
    task begin_op;
        input integer learning;
        begin
            @(negedge clk);start=!learning;learn=learning;
            @(negedge clk);start=0;learn=0;
        end
    endtask
    task offer;
        begin @(negedge clk);raw_sample=1;@(negedge clk);raw_sample=0;end
    endtask
    task three;
        begin offer;offer;offer;end
    endtask
    task wait_idle;
        integer t;
        begin t=0;while(state!=0 && t<2400) begin @(negedge clk);t=t+1;end
            if(state!=0) $fatal(1,"controller did not finish");repeat(5) @(negedge clk);end
    endtask
    task assert_counts;
        begin
            if(total!==bcd_count(ncheck) || passes!==bcd_count(npass) || fails!==bcd_count(nfail) || unknowns!==bcd_count(nunknown))
                $fatal(1,"result counted incorrectly total=%h pass=%h fail=%h unknown=%h",total,passes,fails,unknowns);
        end
    endtask
    task expect_result;
        input integer expected,expected_size,expected_fail;
        begin
            wait_idle;
            if(result!==expected || size_fail!==expected_size || fail!==expected_fail || !locked)
                $fatal(1,"wrong result=%0d size=%b fail=%b cause=%0d expected=%0d/%0d/%0d",result,size_fail,fail,cause,expected,expected_size,expected_fail);
            ncheck=ncheck+1;
            if(expected==1) npass=npass+1;else if(expected==2) nfail=nfail+1;else nunknown=nunknown+1;
            assert_counts;
            repeat(20) @(negedge clk);assert_counts;
            $display("CHECK %0d result=%0d size=%b fail=%b du=%0d dv=%0d angle=%0d",ncheck,result,size_fail,fail,du,dv,da);
        end
    endtask
    task learn_standard;
        begin begin_op(1);three;wait_idle;
            if(!reference_set || learn_failed) $fatal(1,"learning failed");assert_counts;end
    endtask
    task expect_line;
        input integer row;input [143:0] expected;
        begin
            @(negedge clk);de=1;ox=0;oy=0;
            @(negedge clk);ox=32;oy=overlay.line_y(row);
            #1;if(overlay.text_line!==expected) $fatal(1,"OSD row=%0d actual=%s expected=%s",row,overlay.text_line,expected);
            @(negedge clk);de=0;
        end
    endtask
    task save_panel;
        input [511:0] filename;
        integer handle,pixel,px;reg [23:0] rgb;
        begin
            @(negedge clk);de=0;ox=0;oy=0;repeat(4) @(negedge clk);
            handle=$fopen(filename,"w");if(!handle) $fatal(1,"cannot create panel preview");
            $fwrite(handle,"P3\n512 720\n255\n");
            for(pixel=0;pixel<1280*720+2;pixel=pixel+1) begin
                @(negedge clk);de=pixel<1280*720;ox=pixel%1280;oy=pixel/1280;
                @(posedge clk);#1;
                if(pixel>=2) begin
                    px=(pixel-2)%1280;
                    if(px<512) begin
                        if(!ohit) $fatal(1,"panel did not cover left-side pixel");
                        if(px==0 && (pixel-2)/1280==100 && ocolor!==24'h101c29) $fatal(1,"panel background color missing");
                        rgb=ocolor;$fwrite(handle,"%0d %0d %0d\n",rgb[23:16],rgb[15:8],rgb[7:0]);
                    end
                end
            end
            $fclose(handle);@(negedge clk);de=0;
        end
    endtask
    initial begin
        repeat(4) @(negedge clk);rst_n=1;enable=1;
        begin_op(0);three;expect_result(3,0,0);
        if(cause!=11) $fatal(1,"missing reference not reported");
        begin_op(1);lx=900;offer;lx=902;offer;lx=904;offer;wait_idle;
        if(ref_u!=6 || label_x!=902) $fatal(1,"learning did not use median centre: u=%0d x=%0d",ref_u,label_x);
        assert_counts;
        defaults;learn_standard;

        // Third observation alone would be outside the position threshold.
        begin_op(0);lx=906;offer;lx=906;offer;lx=917;offer;expect_result(1,0,0);
        if(label_x!=906) $fatal(1,"detection did not use median centre");
        save_panel("panel_pass.ppm");
        begin_op(0);lx=915;offer;lx=916;offer;lx=917;offer;expect_result(1,0,0);
        defaults;lx=913;begin_op(0);three;expect_result(1,0,0);
        defaults;lx=916;begin_op(0);three;expect_result(1,0,0);
        defaults;lx=917;begin_op(0);three;expect_result(2,0,1);
        defaults;lx=884;begin_op(0);three;expect_result(1,0,0);
        defaults;lx=883;begin_op(0);three;expect_result(2,0,1);
        defaults;ly=376;begin_op(0);three;expect_result(1,0,0);
        defaults;ly=377;begin_op(0);three;expect_result(2,0,2);
        defaults;ly=344;begin_op(0);three;expect_result(1,0,0);
        defaults;ly=343;begin_op(0);three;expect_result(2,0,2);
        defaults;la=7;begin_op(0);three;expect_result(1,0,0);
        defaults;la=8;begin_op(0);three;expect_result(1,0,0);
        defaults;la=9;begin_op(0);three;expect_result(2,0,4);
        defaults;la=352;begin_op(0);three;expect_result(1,0,0);
        defaults;la=351;begin_op(0);three;expect_result(2,0,4);
        defaults;la=16;begin_op(0);three;expect_result(2,0,4);
        expect_line(8,"CAUSE: TILT       ");
        if(overlay.text_color!=24'hff8050) $fatal(1,"cause must be highlighted orange");
        save_panel("panel_tilt.ppm");
        defaults;la=16;lx=920;begin_op(0);three;expect_result(2,0,5);
        expect_line(8,"CAUSE: MULTIPLE   ");
        if(main_item!=3) $fatal(1,"dominant angle lost on multiple faults");

        defaults;bw=360;bh=240;begin_op(0);three;expect_result(2,1,0);
        if(geometry || !alarm) $fatal(1,"size failure must suppress geometric correction and alarm");
        expect_line(8,"CAUSE: BOX SIZE   ");expect_line(9,"FIX: REPLACE BOX  ");
        expect_line(10,"BOX: WRONG SIZE   ");expect_line(11,"LBL: SIZE OK      ");expect_line(12,"SWAP THEN K1      ");
        save_panel("panel_size.ppm");
        ack=1;@(negedge clk);ack=0;@(negedge clk);
        if(alarm || !muted) $fatal(1,"mute failed");
        defaults;bw=240;bh=160;begin_op(0);three;expect_result(2,1,0);
        if(!alarm) $fatal(1,"next size failure did not rearm alarm");
        defaults;lw=104;lh=52;begin_op(0);three;expect_result(2,2,0);
        expect_line(8,"CAUSE: LABEL SIZE ");expect_line(9,"FIX: REPLACE LABEL");
        defaults;lw=56;lh=28;begin_op(0);three;expect_result(2,2,0);
        defaults;bw=360;bh=240;lw=96;lh=48;begin_op(0);three;expect_result(2,3,0);
        expect_line(8,"CAUSE: BOTH SIZE  ");expect_line(9,"FIX: REPLACE BOTH ");
        defaults;bw=345;bh=230;begin_op(0);three;expect_result(1,0,0);
        defaults;lw=92;lh=46;begin_op(0);three;expect_result(1,0,0);
        defaults;bw=346;begin_op(0);three;expect_result(2,1,0);
        defaults;lw=93;begin_op(0);three;expect_result(2,2,0);

        // Motion/invalidation restarts the three-observation window.
        defaults;begin_op(0);offer;bx=940;lx=940;offer;offer;
        repeat(40) @(negedge clk);if(state==0) $fatal(1,"moving observations were fused");
        offer;expect_result(1,0,0);
        defaults;begin_op(0);offer;raw_valid=0;raw_reason=2;offer;raw_valid=1;offer;offer;
        repeat(40) @(negedge clk);if(state==0) $fatal(1,"invalid observation did not reset fusion");
        offer;expect_result(1,0,0);
        defaults;begin_op(0);raw_valid=0;raw_reason=1;offer;expect_result(3,0,0);
        if(cause!=1) $fatal(1,"invalid detection reason lost");
        save_panel("panel_unknown.ppm");
        defaults;begin_op(1);raw_valid=0;raw_reason=2;offer;wait_idle;
        if(!learn_failed || ref_u!=0 || ref_bw!=300 || controller.ref_lw!=80) $fatal(1,"failed learning destroyed reference");
        assert_counts;

        // Rectangle wrap and square-axis ambiguity must not average to 90deg.
        defaults;begin_op(1);ba=359;la=359;offer;ba=0;la=0;offer;ba=1;la=1;offer;wait_idle;
        if(fa!=0 || fla!=0 || ref_alpha!=0) $fatal(1,"angle wrap fusion incorrect ba=%0d la=%0d",fa,fla);
        defaults;bh=298;bsquare=1;begin_op(1);offer;ba=180;offer;ba=0;offer;wait_idle;
        if(fa!=0 || !ref_square || ref_alpha!=0) $fatal(1,"square-axis fusion incorrect");
        defaults;learn_standard;
        begin_op(0);three;expect_result(1,0,0);
        clear=1;@(negedge clk);clear=0;@(negedge clk);ncheck=0;npass=0;nfail=0;nunknown=0;assert_counts;
        if(!reference_set || ref_bw!=300) $fatal(1,"counter clear lost reference");
        $display("PASS tb_size_fusion: median learning/checking, wrap/symmetry, 16-pixel/4-degree signed boundaries, independent sizes/OSD, faults, invalid/motion reset, counters and alarm");
        $finish;
    end
endmodule
