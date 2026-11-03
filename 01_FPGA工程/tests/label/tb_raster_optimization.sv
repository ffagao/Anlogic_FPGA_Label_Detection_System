`timescale 1ns/1ps
module tb_raster_optimization;
    reg clk=0;always #5 clk=~clk;reg rst_n=0;
    reg  enable=0;
    reg  de=0;
    reg [11:0] x=0;
    reg [11:0] y=0;
    reg [1:0] state=0;
    reg [1:0] result=0;
    reg [3:0] cause=0;
    reg [2:0] fail=0;
    reg [1:0] size_fail=0;
    reg  locked=0;
    reg  geometry=0;
    reg  scene=0;
    reg  reference_set=0;
    reg  learn_failed=0;
    reg  alarm=0;
    reg  muted=0;
    reg signed [12:0] du=0;
    reg signed [12:0] dv=0;
    reg signed [12:0] move_x=0;
    reg signed [12:0] move_y=0;
    reg signed [9:0] da=0;
    reg [1:0] main_item=0;
    reg [11:0] box_x=0;
    reg [11:0] box_y=0;
    reg [11:0] box_w=0;
    reg [11:0] box_h=0;
    reg [11:0] label_x=0;
    reg [11:0] label_y=0;
    reg [11:0] label_w=0;
    reg [11:0] label_h=0;
    reg [8:0] box_a=0;
    reg [8:0] label_a=0;
    reg [8:0] ta=0;
    reg  square=0;
    reg signed [15:0] rp=0;
    reg signed [15:0] rq=0;
    reg [11:0] rhw=0;
    reg [11:0] rhh=0;
    reg [11:0] tx=0;
    reg [11:0] ty=0;
    reg [23:0] total=0;
    reg [23:0] passes=0;
    reg [23:0] fails=0;
    reg [23:0] unknowns=0;
    reg [2:0] background_status=0;
    reg [3:0] background_progress=0;
    reg [2:0] debug_code=0;
    reg [11:0] debug_points=0;
    reg [11:0] debug_bad_points=0;
    reg [11:0] debug_fit_w=0;
    reg [11:0] debug_fit_h=0;
    reg  debug_pixel_valid=0;
    reg  debug_raw_pixel=0;
    reg  debug_kept_pixel=0;
    wire  dut_O_hit;
    wire  ref_O_hit;
    wire [23:0] dut_O_color;
    wire [23:0] ref_O_color;
    label_scene_overlay_v4 dut_overlay(.clk(clk),.rst_n(rst_n),.enable(enable),.de(de),.x(x),.y(y),.state(state),.result(result),.cause(cause),.fail(fail),.size_fail(size_fail),.locked(locked),.geometry(geometry),.scene(scene),.reference_set(reference_set),.learn_failed(learn_failed),.alarm(alarm),.muted(muted),.du(du),.dv(dv),.move_x(move_x),.move_y(move_y),.da(da),.main_item(main_item),.box_x(box_x),.box_y(box_y),.box_w(box_w),.box_h(box_h),.label_x(label_x),.label_y(label_y),.label_w(label_w),.label_h(label_h),.box_a(box_a),.label_a(label_a),.ta(ta),.square(square),.rp(rp),.rq(rq),.rhw(rhw),.rhh(rhh),.tx(tx),.ty(ty),.total(total),.passes(passes),.fails(fails),.unknowns(unknowns),.background_status(background_status),.background_progress(background_progress),.debug_code(debug_code),.debug_points(debug_points),.debug_bad_points(debug_bad_points),.debug_fit_w(debug_fit_w),.debug_fit_h(debug_fit_h),.debug_pixel_valid(debug_pixel_valid),.debug_raw_pixel(debug_raw_pixel),.debug_kept_pixel(debug_kept_pixel),.O_hit(dut_O_hit),.O_color(dut_O_color));
    label_scene_overlay_v4_reference ref_overlay(.clk(clk),.rst_n(rst_n),.enable(enable),.de(de),.x(x),.y(y),.state(state),.result(result),.cause(cause),.fail(fail),.size_fail(size_fail),.locked(locked),.geometry(geometry),.scene(scene),.reference_set(reference_set),.learn_failed(learn_failed),.alarm(alarm),.muted(muted),.du(du),.dv(dv),.move_x(move_x),.move_y(move_y),.da(da),.main_item(main_item),.box_x(box_x),.box_y(box_y),.box_w(box_w),.box_h(box_h),.label_x(label_x),.label_y(label_y),.label_w(label_w),.label_h(label_h),.box_a(box_a),.label_a(label_a),.ta(ta),.square(square),.rp(rp),.rq(rq),.rhw(rhw),.rhh(rhh),.tx(tx),.ty(ty),.total(total),.passes(passes),.fails(fails),.unknowns(unknowns),.background_status(background_status),.background_progress(background_progress),.debug_code(debug_code),.debug_points(debug_points),.debug_bad_points(debug_bad_points),.debug_fit_w(debug_fit_w),.debug_fit_h(debug_fit_h),.debug_pixel_valid(debug_pixel_valid),.debug_raw_pixel(debug_raw_pixel),.debug_kept_pixel(debug_kept_pixel),.O_hit(ref_O_hit),.O_color(ref_O_color));
    reg measure_start=0,measure_abort=0;
    wire new_done,old_done;wire signed [12:0] new_u,new_v,old_u,old_v;
    wire [12:0] new_wr,new_hr,old_wr,old_hr;wire [8:0] new_alpha,old_alpha;
    label_relative new_relative(.clk(clk),.rst_n(rst_n),.start(measure_start),.abort(measure_abort),
        .bx(box_x),.by(box_y),.bw(box_w),.bh(box_h),.ba(box_a),.lx(label_x),.ly(label_y),
        .lw(label_w),.lh(label_h),.la(label_a),.done(new_done),.u(new_u),.v(new_v),.wr(new_wr),.hr(new_hr),.alpha(new_alpha));
    label_relative_reference old_relative(.clk(clk),.rst_n(rst_n),.start(measure_start),.abort(measure_abort),
        .bx(box_x),.by(box_y),.bw(box_w),.bh(box_h),.ba(box_a),.lx(label_x),.ly(label_y),
        .lw(label_w),.lh(label_h),.la(label_a),.done(old_done),.u(old_u),.v(old_v),.wr(old_wr),.hr(old_hr),.alpha(old_alpha));
    integer frame,pixel,k,t,new_seen,old_seen,seed=32'h55ca,compared=0;
    function integer random_range;
        input integer lo,hi;reg [31:0] value;
        begin value=$random(seed);random_range=lo+value%(hi-lo+1);end
    endfunction
    always @(posedge clk) begin
        #1;
        if(rst_n && {dut_O_hit,dut_O_color}!=={ref_O_hit,ref_O_color})
            $fatal(1,"raster overlay differs frame=%0d input=%0d,%0d",frame,x,y);
        if(rst_n && de && x>=512 && x<1280 && !dut_overlay.projection_ready)
            $fatal(1,"frame origin not ready before visible ROI");
    end
    initial begin
        repeat(5) @(negedge clk);rst_n=1;enable=1;
        for(frame=0;frame<12;frame=frame+1) begin
            box_x=frame==9?4095:(frame==10?0:random_range(550,1200));
            box_y=frame==9?4095:(frame==10?0:random_range(60,660));
            label_x=frame==8?0:box_x-20;label_y=frame==8?4095:box_y+16;
            box_w=300;box_h=200;label_w=80;label_h=40;
            box_a=frame==0?0:(frame==1?180:(frame==2?359:random_range(0,359)));
            label_a=(box_a+16)%360;ta=(box_a+12)%360;
            state=0;scene=1;reference_set=1;geometry=1;locked=1;result=frame%3+1;
            fail=5;main_item=3;du=61;dv=-33;da=16;move_x=-18;move_y=10;
            square=frame%2;size_fail=frame==7?2:0;cause=frame%3==2?7:0;
            rp=-50;rq=20;rhw=40;rhh=20;tx=box_x;ty=box_y;total=frame+1;passes=1;fails=2;unknowns=3;background_status=4;
            for(pixel=0;pixel<1280*720;pixel=pixel+1) begin
                @(negedge clk);de=1;x=pixel%1280;y=pixel/1280;
                compared=compared+1;
                if(pixel%1280==1279 && pixel/1280%31==7) begin
                    @(negedge clk);de=0;repeat(2) @(negedge clk);
                end
            end
            @(negedge clk);de=0;repeat(8) @(negedge clk);
            $display("RASTER frame=%0d box=%0d,%0d angle=%0d label_angle=%0d",frame,box_x,box_y,box_a,label_a);
        end
        for(k=0;k<320;k=k+1) begin
            @(negedge clk);box_x=random_range(0,4095);box_y=random_range(0,4095);
            label_x=random_range(0,4095);label_y=random_range(0,4095);
            box_w=random_range(1,1500);box_h=random_range(1,1000);
            label_w=random_range(0,4095);label_h=random_range(0,4095);
            box_a=random_range(0,359);label_a=random_range(0,359);measure_start=1;
            @(negedge clk);measure_start=0;new_seen=0;old_seen=0;t=0;
            while((!new_seen || !old_seen) && t<250) begin
                @(negedge clk);if(new_done)new_seen=1;if(old_done)old_seen=1;t=t+1;
            end
            if(!new_seen || !old_seen || {new_u,new_v,new_wr,new_hr,new_alpha}!=={old_u,old_v,old_wr,old_hr,old_alpha})
                $fatal(1,"shared relative multiplier differs case %0d",k);
            if(k%17==0) begin
                measure_start=1;@(negedge clk);measure_start=0;measure_abort=1;
                @(negedge clk);measure_abort=0;repeat(5) @(negedge clk);
                if(new_done || old_done) $fatal(1,"aborted relative calculation returned stale result");
            end
        end
        $display("PASS tb_raster_optimization: %0d valid pixels exactly match V5.4 overlay including angles, bounds and DE gaps; 320 shared-multiply measurements plus abort/restart match",compared);
        $finish;
    end
    initial begin #500000000;$fatal(1,"raster optimization test timeout");end
endmodule

