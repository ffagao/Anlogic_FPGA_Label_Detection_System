`timescale 1ns/1ps
module tb_v35_controller_scale;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0;
    reg  f_enable=0;
    reg  f_sample=0;
    reg  f_valid=0;
    reg [3:0] f_reason=0;
    reg [11:0] f_bx=0;
    reg [11:0] f_by=0;
    reg [11:0] f_bw=0;
    reg [11:0] f_bh=0;
    reg [11:0] f_lx=0;
    reg [11:0] f_ly=0;
    reg [11:0] f_lw=0;
    reg [11:0] f_lh=0;
    reg [8:0] f_ba=0;
    reg [8:0] f_la=0;
    reg  f_bsquare=0;
    reg  f_lsquare=0;
    wire  f_dut_busy;
    wire  f_ref_busy;
    wire  f_dut_O_sample;
    wire  f_ref_O_sample;
    wire  f_dut_O_valid;
    wire  f_ref_O_valid;
    wire [3:0] f_dut_O_reason;
    wire [3:0] f_ref_O_reason;
    wire [11:0] f_dut_O_bx;
    wire [11:0] f_ref_O_bx;
    wire [11:0] f_dut_O_by;
    wire [11:0] f_ref_O_by;
    wire [11:0] f_dut_O_bw;
    wire [11:0] f_ref_O_bw;
    wire [11:0] f_dut_O_bh;
    wire [11:0] f_ref_O_bh;
    wire [11:0] f_dut_O_lx;
    wire [11:0] f_ref_O_lx;
    wire [11:0] f_dut_O_ly;
    wire [11:0] f_ref_O_ly;
    wire [11:0] f_dut_O_lw;
    wire [11:0] f_ref_O_lw;
    wire [11:0] f_dut_O_lh;
    wire [11:0] f_ref_O_lh;
    wire [8:0] f_dut_O_ba;
    wire [8:0] f_ref_O_ba;
    wire [8:0] f_dut_O_la;
    wire [8:0] f_ref_O_la;
    wire  f_dut_O_bsquare;
    wire  f_ref_O_bsquare;
    wire  f_dut_O_lsquare;
    wire  f_ref_O_lsquare;
    reg  r_start=0;
    reg  r_abort=0;
    reg [4:0] r_edge_tolerance=0;
    reg  r_relaxed_box=0;
    reg  r_label_mode=0;
    wire [9:0] r_dut_row_addr;
    wire [9:0] r_ref_row_addr;
    wire [11:0] r_left_x;
    wire [11:0] r_right_x;
    wire  r_dut_done;
    wire  r_ref_done;
    wire  r_dut_valid;
    wire  r_ref_valid;
    wire [11:0] r_dut_cx;
    wire [11:0] r_ref_cx;
    wire [11:0] r_dut_cy;
    wire [11:0] r_ref_cy;
    wire [11:0] r_dut_w;
    wire [11:0] r_ref_w;
    wire [11:0] r_dut_h;
    wire [11:0] r_ref_h;
    wire [8:0] r_dut_angle;
    wire [8:0] r_ref_angle;
    wire  r_dut_square;
    wire  r_ref_square;
    wire [31:0] r_dut_area_pixels;
    wire [31:0] r_ref_area_pixels;
    wire [11:0] r_dut_points_count;
    wire [11:0] r_ref_points_count;
    wire [11:0] r_dut_bad_points_count;
    wire [11:0] r_ref_bad_points_count;
    reg  c_enable=0;
    reg  c_start=0;
    reg  c_learn=0;
    reg  c_ack=0;
    reg  c_clear=0;
    reg  c_sample=0;
    reg  c_valid=0;
    reg [3:0] c_reason=0;
    reg signed [12:0] c_u=0;
    reg signed [12:0] c_v=0;
    reg [12:0] c_wr=0;
    reg [12:0] c_hr=0;
    reg [8:0] c_alpha=0;
    reg [11:0] c_bx=0;
    reg [11:0] c_by=0;
    reg [11:0] c_bw=0;
    reg [11:0] c_bh=0;
    reg [11:0] c_lx=0;
    reg [11:0] c_ly=0;
    reg [11:0] c_lw=0;
    reg [11:0] c_lh=0;
    reg [8:0] c_ba=0;
    reg [8:0] c_la=0;
    reg  c_bsquare=0;
    reg  c_lsquare=0;
    wire [1:0] c_dut_state;
    wire [1:0] c_ref_state;
    wire [1:0] c_dut_result;
    wire [1:0] c_ref_result;
    wire [3:0] c_dut_cause;
    wire [3:0] c_ref_cause;
    wire [2:0] c_dut_fail;
    wire [2:0] c_ref_fail;
    wire  c_dut_locked;
    wire  c_ref_locked;
    wire  c_dut_geometry;
    wire  c_ref_geometry;
    wire  c_dut_reference_set;
    wire  c_ref_reference_set;
    wire  c_dut_learn_failed;
    wire  c_ref_learn_failed;
    wire [1:0] c_dut_size_fail;
    wire [1:0] c_ref_size_fail;
    wire  c_dut_O_alarm;
    wire  c_ref_O_alarm;
    wire  c_dut_muted;
    wire  c_ref_muted;
    wire signed [12:0] c_dut_ref_u;
    wire signed [12:0] c_ref_ref_u;
    wire signed [12:0] c_dut_ref_v;
    wire signed [12:0] c_ref_ref_v;
    wire signed [12:0] c_dut_du;
    wire signed [12:0] c_ref_du;
    wire signed [12:0] c_dut_dv;
    wire signed [12:0] c_ref_dv;
    wire [12:0] c_dut_ref_wr;
    wire [12:0] c_ref_ref_wr;
    wire [12:0] c_dut_ref_hr;
    wire [12:0] c_ref_ref_hr;
    wire [8:0] c_dut_ref_alpha;
    wire [8:0] c_ref_ref_alpha;
    wire  c_dut_ref_square;
    wire  c_ref_ref_square;
    wire  c_dut_ref_label_square;
    wire  c_ref_ref_label_square;
    wire [11:0] c_dut_ref_bw;
    wire [11:0] c_ref_ref_bw;
    wire [11:0] c_dut_ref_bh;
    wire [11:0] c_ref_ref_bh;
    wire signed [9:0] c_dut_da;
    wire signed [9:0] c_ref_da;
    wire [11:0] c_dut_box_x;
    wire [11:0] c_ref_box_x;
    wire [11:0] c_dut_box_y;
    wire [11:0] c_ref_box_y;
    wire [11:0] c_dut_box_w;
    wire [11:0] c_ref_box_w;
    wire [11:0] c_dut_box_h;
    wire [11:0] c_ref_box_h;
    wire [11:0] c_dut_label_x;
    wire [11:0] c_ref_label_x;
    wire [11:0] c_dut_label_y;
    wire [11:0] c_ref_label_y;
    wire [11:0] c_dut_label_w;
    wire [11:0] c_ref_label_w;
    wire [11:0] c_dut_label_h;
    wire [11:0] c_ref_label_h;
    wire [8:0] c_dut_box_a;
    wire [8:0] c_ref_box_a;
    wire [8:0] c_dut_label_a;
    wire [8:0] c_ref_label_a;
    wire  c_dut_box_square;
    wire  c_ref_box_square;
    wire  c_dut_scene;
    wire  c_ref_scene;
    wire [1:0] c_dut_branch;
    wire [1:0] c_ref_branch;
    wire [1:0] c_dut_main_item;
    wire [1:0] c_ref_main_item;
    wire [23:0] c_dut_total;
    wire [23:0] c_ref_total;
    wire [23:0] c_dut_passes;
    wire [23:0] c_ref_passes;
    wire [23:0] c_dut_fails;
    wire [23:0] c_ref_fails;
    wire [23:0] c_dut_unknowns;
    wire [23:0] c_ref_unknowns;
    integer fused_count=0,k,j,t,seed=32'h2174,base_ba,base_la,delta,reference_size,measured_size;
    integer db,dl,square,wrapped,old_ok,new_ok;
    integer rect_width=16;reg rect_noise=0;
    reg [12:0] logo_addr=0;wire [14:0] original_addr=(logo_addr/80)*320+(logo_addr%80)*2;
    wire [24:0] logo_pixel,original_pixel;
    label_logo_half_rom logo(.I_clk(clk),.I_addr(logo_addr),.O_pixel(logo_pixel));
    anlogic_logo_rom original_logo(.I_addr(original_addr),.O_pixel(original_pixel));
    assign r_left_x=512+(rect_noise && r_dut_row_addr%5==1?1:0);
    assign r_right_x=r_left_x+rect_width-1;
    label_observation_fusion f_dut(
        .clk(clk),.rst_n(rst_n),.enable(f_enable),.sample(f_sample),.valid(f_valid),.reason(f_reason),.bx(f_bx),.by(f_by),.bw(f_bw),.bh(f_bh),.lx(f_lx),.ly(f_ly),.lw(f_lw),.lh(f_lh),.ba(f_ba),.la(f_la),.bsquare(f_bsquare),.lsquare(f_lsquare),.busy(f_dut_busy),.O_sample(f_dut_O_sample),.O_valid(f_dut_O_valid),.O_reason(f_dut_O_reason),.O_bx(f_dut_O_bx),.O_by(f_dut_O_by),.O_bw(f_dut_O_bw),.O_bh(f_dut_O_bh),.O_lx(f_dut_O_lx),.O_ly(f_dut_O_ly),.O_lw(f_dut_O_lw),.O_lh(f_dut_O_lh),.O_ba(f_dut_O_ba),.O_la(f_dut_O_la),.O_bsquare(f_dut_O_bsquare),.O_lsquare(f_dut_O_lsquare));
    label_observation_fusion_reference f_ref(
        .clk(clk),.rst_n(rst_n),.enable(f_enable),.sample(f_sample),.valid(f_valid),.reason(f_reason),.bx(f_bx),.by(f_by),.bw(f_bw),.bh(f_bh),.lx(f_lx),.ly(f_ly),.lw(f_lw),.lh(f_lh),.ba(f_ba),.la(f_la),.bsquare(f_bsquare),.lsquare(f_lsquare),.busy(f_ref_busy),.O_sample(f_ref_O_sample),.O_valid(f_ref_O_valid),.O_reason(f_ref_O_reason),.O_bx(f_ref_O_bx),.O_by(f_ref_O_by),.O_bw(f_ref_O_bw),.O_bh(f_ref_O_bh),.O_lx(f_ref_O_lx),.O_ly(f_ref_O_ly),.O_lw(f_ref_O_lw),.O_lh(f_ref_O_lh),.O_ba(f_ref_O_ba),.O_la(f_ref_O_la),.O_bsquare(f_ref_O_bsquare),.O_lsquare(f_ref_O_lsquare));
    label_rect_fit #(.HEIGHT(16),.REGION_VALIDATED(1)) r_dut(
        .clk(clk),.rst_n(rst_n),.start(r_start),.abort(r_abort),.edge_tolerance(r_edge_tolerance),.relaxed_box(r_relaxed_box),.label_mode(r_label_mode),.row_addr(r_dut_row_addr),.left_x(r_left_x),.right_x(r_right_x),.done(r_dut_done),.valid(r_dut_valid),.cx(r_dut_cx),.cy(r_dut_cy),.w(r_dut_w),.h(r_dut_h),.angle(r_dut_angle),.square(r_dut_square),.area_pixels(r_dut_area_pixels),.points_count(r_dut_points_count),.bad_points_count(r_dut_bad_points_count));
    label_rect_fit_reference #(.HEIGHT(16),.REGION_VALIDATED(1)) r_ref(
        .clk(clk),.rst_n(rst_n),.start(r_start),.abort(r_abort),.edge_tolerance(r_edge_tolerance),.relaxed_box(r_relaxed_box),.label_mode(r_label_mode),.row_addr(r_ref_row_addr),.left_x(r_left_x),.right_x(r_right_x),.done(r_ref_done),.valid(r_ref_valid),.cx(r_ref_cx),.cy(r_ref_cy),.w(r_ref_w),.h(r_ref_h),.angle(r_ref_angle),.square(r_ref_square),.area_pixels(r_ref_area_pixels),.points_count(r_ref_points_count),.bad_points_count(r_ref_bad_points_count));
    label_scene_controller #(.TIMEOUT_CYCLES(128)) c_dut(
        .clk(clk),.rst_n(rst_n),.enable(c_enable),.auto_mode(1'b0),.start(c_start),.learn(c_learn),.ack(c_ack),.clear(c_clear),.sample(c_sample),.valid(c_valid),.reason(c_reason),.u(c_u),.v(c_v),.wr(c_wr),.hr(c_hr),.alpha(c_alpha),.bx(c_bx),.by(c_by),.bw(c_bw),.bh(c_bh),.lx(c_lx),.ly(c_ly),.lw(c_lw),.lh(c_lh),.ba(c_ba),.la(c_la),.bsquare(c_bsquare),.lsquare(c_lsquare),.state(c_dut_state),.result(c_dut_result),.cause(c_dut_cause),.fail(c_dut_fail),.locked(c_dut_locked),.geometry(c_dut_geometry),.reference_set(c_dut_reference_set),.learn_failed(c_dut_learn_failed),.size_fail(c_dut_size_fail),.O_alarm(c_dut_O_alarm),.muted(c_dut_muted),.ref_u(c_dut_ref_u),.ref_v(c_dut_ref_v),.du(c_dut_du),.dv(c_dut_dv),.ref_wr(c_dut_ref_wr),.ref_hr(c_dut_ref_hr),.ref_alpha(c_dut_ref_alpha),.ref_square(c_dut_ref_square),.ref_label_square(c_dut_ref_label_square),.ref_bw(c_dut_ref_bw),.ref_bh(c_dut_ref_bh),.da(c_dut_da),.box_x(c_dut_box_x),.box_y(c_dut_box_y),.box_w(c_dut_box_w),.box_h(c_dut_box_h),.label_x(c_dut_label_x),.label_y(c_dut_label_y),.label_w(c_dut_label_w),.label_h(c_dut_label_h),.box_a(c_dut_box_a),.label_a(c_dut_label_a),.box_square(c_dut_box_square),.scene(c_dut_scene),.branch(c_dut_branch),.main_item(c_dut_main_item),.total(c_dut_total),.passes(c_dut_passes),.fails(c_dut_fails),.unknowns(c_dut_unknowns));
    label_scene_controller_v34_baseline #(.TIMEOUT_CYCLES(128)) c_ref(
        .clk(clk),.rst_n(rst_n),.enable(c_enable),.start(c_start),.learn(c_learn),.ack(c_ack),.clear(c_clear),.sample(c_sample),.valid(c_valid),.reason(c_reason),.u(c_u),.v(c_v),.wr(c_wr),.hr(c_hr),.alpha(c_alpha),.bx(c_bx),.by(c_by),.bw(c_bw),.bh(c_bh),.lx(c_lx),.ly(c_ly),.lw(c_lw),.lh(c_lh),.ba(c_ba),.la(c_la),.bsquare(c_bsquare),.lsquare(c_lsquare),.state(c_ref_state),.result(c_ref_result),.cause(c_ref_cause),.fail(c_ref_fail),.locked(c_ref_locked),.geometry(c_ref_geometry),.reference_set(c_ref_reference_set),.learn_failed(c_ref_learn_failed),.size_fail(c_ref_size_fail),.O_alarm(c_ref_O_alarm),.muted(c_ref_muted),.ref_u(c_ref_ref_u),.ref_v(c_ref_ref_v),.du(c_ref_du),.dv(c_ref_dv),.ref_wr(c_ref_ref_wr),.ref_hr(c_ref_ref_hr),.ref_alpha(c_ref_ref_alpha),.ref_square(c_ref_ref_square),.ref_label_square(c_ref_ref_label_square),.ref_bw(c_ref_ref_bw),.ref_bh(c_ref_ref_bh),.da(c_ref_da),.box_x(c_ref_box_x),.box_y(c_ref_box_y),.box_w(c_ref_box_w),.box_h(c_ref_box_h),.label_x(c_ref_label_x),.label_y(c_ref_label_y),.label_w(c_ref_label_w),.label_h(c_ref_label_h),.box_a(c_ref_box_a),.label_a(c_ref_label_a),.box_square(c_ref_box_square),.scene(c_ref_scene),.branch(c_ref_branch),.main_item(c_ref_main_item),.total(c_ref_total),.passes(c_ref_passes),.fails(c_ref_fails),.unknowns(c_ref_unknowns));
    always @(posedge clk) begin
        #1;
        if(rst_n) begin
        if({f_dut_busy,f_dut_O_sample,f_dut_O_valid,f_dut_O_reason,f_dut_O_bsquare,f_dut_O_lsquare}!=={f_ref_busy,f_ref_O_sample,f_ref_O_valid,f_ref_O_reason,f_ref_O_bsquare,f_ref_O_lsquare}) $fatal(1,"f cycle-exact output mismatch");
        if(f_dut_O_sample && f_dut_O_valid) begin
            fused_count=fused_count+1;
            if({f_dut_O_bx,f_dut_O_by,f_dut_O_bw,f_dut_O_bh,f_dut_O_lx,f_dut_O_ly,f_dut_O_lw,f_dut_O_lh,f_dut_O_ba,f_dut_O_la}!=={f_ref_O_bx,f_ref_O_by,f_ref_O_bw,f_ref_O_bh,f_ref_O_lx,f_ref_O_ly,f_ref_O_lw,f_ref_O_lh,f_ref_O_ba,f_ref_O_la}) $fatal(1,"fused geometry differs");
        end
        if({r_dut_row_addr,r_dut_done,r_dut_valid,r_dut_cx,r_dut_cy,r_dut_w,r_dut_h,r_dut_angle,r_dut_square,r_dut_area_pixels,r_dut_points_count,r_dut_bad_points_count}!=={r_ref_row_addr,r_ref_done,r_ref_valid,r_ref_cx,r_ref_cy,r_ref_w,r_ref_h,r_ref_angle,r_ref_square,r_ref_area_pixels,r_ref_points_count,r_ref_bad_points_count}) $fatal(1,"r cycle-exact output mismatch");
        if({c_dut_state,c_dut_result,c_dut_cause,c_dut_fail,c_dut_locked,c_dut_geometry,c_dut_reference_set,c_dut_learn_failed,c_dut_size_fail,c_dut_O_alarm,c_dut_muted,c_dut_ref_u,c_dut_ref_v,c_dut_du,c_dut_dv,c_dut_ref_wr,c_dut_ref_hr,c_dut_ref_alpha,c_dut_ref_square,c_dut_ref_label_square,c_dut_ref_bw,c_dut_ref_bh,c_dut_da,c_dut_box_x,c_dut_box_y,c_dut_box_w,c_dut_box_h,c_dut_label_x,c_dut_label_y,c_dut_label_w,c_dut_label_h,c_dut_box_a,c_dut_label_a,c_dut_box_square,c_dut_scene,c_dut_branch,c_dut_main_item,c_dut_total,c_dut_passes,c_dut_fails,c_dut_unknowns}!=={c_ref_state,c_ref_result,c_ref_cause,c_ref_fail,c_ref_locked,c_ref_geometry,c_ref_reference_set,c_ref_learn_failed,c_ref_size_fail,c_ref_O_alarm,c_ref_muted,c_ref_ref_u,c_ref_ref_v,c_ref_du,c_ref_dv,c_ref_ref_wr,c_ref_ref_hr,c_ref_ref_alpha,c_ref_ref_square,c_ref_ref_label_square,c_ref_ref_bw,c_ref_ref_bh,c_ref_da,c_ref_box_x,c_ref_box_y,c_ref_box_w,c_ref_box_h,c_ref_label_x,c_ref_label_y,c_ref_label_w,c_ref_label_h,c_ref_box_a,c_ref_label_a,c_ref_box_square,c_ref_scene,c_ref_branch,c_ref_main_item,c_ref_total,c_ref_passes,c_ref_fails,c_ref_unknowns}) $fatal(1,"c cycle-exact output mismatch");
        end
    end
    function integer random_range;
        input integer lo,hi;reg [31:0] value;
        begin value=$random(seed);random_range=lo+value%(hi-lo+1);end
    endfunction
    task offer_fusion;
        begin @(negedge clk);f_sample=1;@(negedge clk);f_sample=0;end
    endtask
    initial begin
        repeat(5) @(negedge clk);rst_n=1;
        // Every half-size Logo pixel, including all transparent pixels.
        for(k=0;k<6400;k=k+1) begin
            @(negedge clk);logo_addr=k;
            @(posedge clk);#2;if(logo_pixel!==original_pixel) $fatal(1,"lossless Logo mismatch at %0d",k);
        end
        // Exhaust all possible normalized angle differences at the removed wrap.
        for(square=0;square<2;square=square+1)
        for(db=-180;db<=180;db=db+1)
        for(dl=-180;dl<=180;dl=dl+1) if(!square || (dl>=-90 && dl<=90)) begin
            wrapped=dl-db;
            if(wrapped>180) wrapped=wrapped-360;else if(wrapped< -180) wrapped=wrapped+360;
            if(square) begin if(wrapped>90) wrapped=wrapped-180;else if(wrapped< -90) wrapped=wrapped+180;end
            old_ok=db>=-3 && db<=3 && wrapped>=-3 && wrapped<=3;
            new_ok=db>=-3 && db<=3 && dl-db>=-3 && dl-db<=3;
            if(old_ok!=new_ok) $fatal(1,"angle predicate not equivalent");
        end
        // Every representable reference size, at and just outside both boundaries.
        for(reference_size=0;reference_size<4096;reference_size=reference_size+1)
        for(j=0;j<6;j=j+1) begin
            delta=reference_size*15/100;
            case(j)
            0:measured_size=reference_size;
            1:measured_size=reference_size+delta;
            2:measured_size=reference_size+delta+1;
            3:measured_size=reference_size-delta;
            4:measured_size=reference_size-delta-1;
            default:measured_size=random_range(0,4095);
            endcase
            if(measured_size>=0 && measured_size<=4095 &&
               c_dut.size_matches(measured_size,reference_size)!==c_ref.size_matches(measured_size,reference_size))
                $fatal(1,"size arithmetic differs %0d/%0d",measured_size,reference_size);
        end
        // Stable/jittered windows, wraps, square flags, invalidations and resets.
        f_enable=1;
        for(k=0;k<240;k=k+1) begin
            if(k%13==0) begin @(negedge clk);f_enable=0;@(negedge clk);f_enable=1;end
            base_ba=random_range(0,359);base_la=random_range(0,359);
            f_bsquare=random_range(0,1);f_lsquare=random_range(0,1);
            f_bw=random_range(50,1200);f_bh=random_range(30,700);f_lw=random_range(16,200);f_lh=random_range(8,100);
            for(j=0;j<5;j=j+1) begin
                @(negedge clk);
                f_bx=800+k%50+random_range(-2,2);f_by=350+random_range(-2,2);
                f_lx=830+k%50+random_range(-2,2);f_ly=355+random_range(-2,2);
                f_ba=(base_ba+random_range(-1,1)+360)%360;
                f_la=(base_la+random_range(-1,1)+360)%360;
                f_valid=(k%11!=0 || j!=1);f_reason=2;
                offer_fusion;
            end
            repeat(15) @(negedge clk);
        end
        if(fused_count<100) $fatal(1,"too few valid differential fusion windows");
        @(negedge clk);f_enable=0;
        // Controller learning, exact gates, size mismatch, invalid/timeout, clear/mute.
        c_enable=1;c_wr=273;c_hr=205;c_bx=900;c_by=360;c_lx=900;c_ly=360;
        for(k=0;k<4096;k=k+1) begin
            @(negedge clk);
            c_bw=c_ref_ref_bw;c_bh=c_ref_ref_bh;c_lw=80;c_lh=40;
            if(k%20==0)begin
                case((k/20)%5)0:begin c_bw=4095;c_bh=4095;end 1:begin c_bw=1;c_bh=1;end 2:begin c_bw=0;c_bh=0;end 3:begin c_bw=512;c_bh=256;end default:begin c_bw=300;c_bh=200;end endcase
            end
            c_ba=k%360;c_la=k%360;
            c_bsquare=(k/20)%2;c_lsquare=(k/40)%2;
            c_u=random_range(-4096,4095);c_v=random_range(-4096,4095);c_alpha=random_range(0,359);
            if(k%20!=0) begin
                c_u=$signed(c_ref_ref_u)+random_range(-70,70);
                c_v=$signed(c_ref_ref_v)+random_range(-70,70);
                c_alpha=(c_ref_ref_alpha+random_range(-10,10)+360)%360;
                case(k%9) 1:c_bw=346;2:c_lw=93;3:begin c_bw=255;c_lw=68;end 4:c_bh=231;5:c_lh=47;default:;endcase
            end
            c_start=k%20!=0;c_learn=k%20==0;c_ack=k%17==0;
            @(negedge clk);c_start=0;c_learn=0;c_ack=0;
            c_valid=k%19!=0 || k%20==0;c_reason=1;c_sample=1;
            @(negedge clk);c_sample=0;
            t=0;while(c_dut_state!=0 && t<150) begin @(negedge clk);t=t+1;end
            if(c_dut_state!=0) $fatal(1,"controller hung");
            if(k%23==0) begin c_clear=1;@(negedge clk);c_clear=0;end
            repeat(2) @(negedge clk);
        end
        c_enable=0;
        // Real fitter cycles, square boundary, narrow contours and small edge noise.
        r_edge_tolerance=8;r_relaxed_box=1;
        for(k=0;k<24;k=k+1) begin
            @(negedge clk);rect_width=k<8?12+k:random_range(8,400);rect_noise=k%2;r_label_mode=k%2;r_start=1;
            @(negedge clk);r_start=0;t=0;
            while(!r_dut_done && t<10000) begin @(negedge clk);t=t+1;end
            if(!r_dut_done) $fatal(1,"fitter hung");
            repeat(3) @(negedge clk);
        end
        $display("PASS tb_v35_controller_scale: 6400 lossless Logo pixels, exhaustive angle gate, all size boundaries, %0d fused windows, 4096 full-range controllers against v34 and 24 real fitter runs",fused_count);
        $finish;
    end
    initial begin #30000000;$fatal(1,"equivalence test timeout");end
endmodule

