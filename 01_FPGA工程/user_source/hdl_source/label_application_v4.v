module label_application #(
    parameter integer KEY_DEBOUNCE=1500000,KEY_HOLD=75000000,CHECK_TIMEOUT=300000000,BG_TIMEOUT=375000000,
    BEEP_CYCLES=15000000,TONE_CYCLES=18750,SCAN_CYCLES=75000,
    WIDTH=1280,HEIGHT=720,ROI_L=512,ROI_R=1279,ROI_T=0,ROI_B=719
)(input wire I_clk,I_rst_n,I_enable,I_de,input wire [3:0] I_keys_n,
  input wire [11:0] I_x,I_y,input wire [23:0] I_rgb,I_frame_id,
  input wire I_imaging_locked,input wire [2:0] I_remote_action,output reg O_imaging_lock,
  output wire O_hit,output wire [23:0] O_color,output wire O_buzzer_n,
  output wire [7:0] O_seg_sel,O_seg_dig,output wire [1:0] O_display_result,
  output wire [1:0] O_status_result,output wire [3:0] O_status_cause,
  output wire [23:0] O_status_passes,O_status_fails,O_status_unknowns,
  output wire O_barcode_valid,output wire [23:0] O_barcode_order,O_barcode_count,
  input wire I_zoom_supported,I_zoom_active,
  input wire [11:0] I_zoom_src_x,input wire signed [11:0] I_zoom_src_y,
  output wire O_zoom_request,output wire [11:0] O_zoom_src_x,
  output wire signed [11:0] O_zoom_src_y);
    wire [2:0] press_physical;
    wire clear_physical,background_physical;
    reg [2:0] remote_press;reg remote_clear,remote_background;
    wire [2:0] press;
    wire clear=clear_physical|remote_clear;
    wire raw_sample;
    always @* begin
        remote_press=0;remote_clear=0;remote_background=0;
        case(I_remote_action)
            1:remote_background=1;
            2:remote_press[1]=1;
            3:remote_press[0]=1;
            4:remote_press[2]=1;
            5:remote_clear=1;
            default:;
        endcase
    end
    wire [3:0] reason;
    wire raw_valid;
    wire [3:0] raw_reason;
    wire [11:0] raw_bx,raw_by,raw_bw,raw_bh,raw_lx,raw_ly,raw_lw,raw_lh;
    wire [8:0] raw_ba,raw_la;wire raw_bsquare,raw_lsquare;
    wire [1:0] state,result;
    wire [11:0] fbx,fby,fbw,fbh,flx,fly,flw,flh;
    wire [8:0] fba,fla;wire fbs,fls,fvalid,fsample,fbusy;wire [3:0] freason;
    wire learning=(state==2);
    wire [11:0] bx=learning?fbx:raw_bx,by=learning?fby:raw_by,bw=learning?fbw:raw_bw,bh=learning?fbh:raw_bh;
    wire [11:0] lx=learning?flx:raw_lx,ly=learning?fly:raw_ly,lw=learning?flw:raw_lw,lh=learning?flh:raw_lh;
    wire [8:0] ba=learning?fba:raw_ba,la=learning?fla:raw_la;
    wire bsquare=learning?fbs:raw_bsquare,lsquare=learning?fls:raw_lsquare;
    assign reason=learning?freason:raw_reason;
    wire valid=learning?fvalid:raw_valid;
    wire observation=learning?fsample:raw_sample;
    wire [2:0] debug_code;
    wire [11:0] debug_points,debug_bad_points,debug_fit_w,debug_fit_h;
    wire debug_pixel_valid,debug_raw_pixel,debug_kept_pixel;
    wire sample;
    wire signed [12:0] u,v;
    wire [12:0] wr,hr;wire [8:0] alpha;
    wire [3:0] cause;wire [2:0] fail;wire [1:0] size_fail;
    wire locked,geometry,reference_set,learn_failed,alarm,muted;
    assign O_display_result=I_enable && locked ? result : 2'd0;
    assign O_status_result=I_enable && locked ? result : 2'd0;
    assign O_status_cause=I_enable && locked ? cause : 4'd0;
    wire signed [12:0] ref_u,ref_v,du,dv;
    wire [12:0] ref_wr,ref_hr;wire [8:0] ref_alpha;
    wire ref_square,ref_label_square;
    wire [11:0] ref_bw,ref_bh;
    wire signed [9:0] da;
    wire [11:0] box_x,box_y,box_w,box_h,label_x,label_y,label_w,label_h;
    wire [8:0] box_a,label_a;wire box_square,scene;
    wire [1:0] branch,main_item;
    wire [23:0] total,passes,fails,unknowns;
    assign O_status_passes=passes;
    assign O_status_fails=fails;
    assign O_status_unknowns=unknowns;
    wire scan_active,scan_ticket,scan_hit;wire [23:0] scan_color;
    wire label_hit;wire [23:0] label_color;wire auto_pending;
    reg relative_busy;
    // Background calibration is removed.  Detection is now based on the
    // current frame's colour and geometry and is ready immediately.
    wire background_key=1'b0;
    wire bg_ready=I_enable;
    wire bg_busy=1'b0;
    wire bg_failed=1'b0;
    wire [3:0] bg_progress=4'd8;
    wire [23:0] bg_rgb=24'd0;
    reg [11:0] dx,dy;reg [23:0] drgb,dfid;reg dde;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin O_imaging_lock<=0;
            dx<=0;dy<=0;drgb<=0;dfid<=0;dde<=0;end
        else begin
            dx<=I_x;dy<=I_y;drgb<=I_rgb;dfid<=I_frame_id;dde<=I_de;
            O_imaging_lock<=I_enable && I_imaging_locked;
        end
    end
    wire [2:0] bg_status=I_enable?3'd4:3'd0;
    wire allow_operation=I_enable && !background_key;
    label_keys #(.DEBOUNCE_CYCLES(KEY_DEBOUNCE),.HOLD_CYCLES(KEY_HOLD)) keys(
        .I_clk(I_clk),.I_rst_n(I_rst_n),.I_enable(I_enable),.I_keys_n(I_keys_n),.O_press(press_physical),.O_clear(clear_physical),.O_background(background_physical));
    label_scene_detector_map #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.ROI_L(ROI_L),.ROI_R(ROI_R),.ROI_T(ROI_T),.ROI_B(ROI_B)) detector(.clk(I_clk),.rst_n(I_rst_n),.enable(I_enable),.acquire(state!=0 && !relative_busy && !fbusy && !raw_sample && !fsample),
        .de(dde),.x(dx),.y(dy),.rgb(drgb),.frame_id(dfid),.background_valid(bg_ready),.background_rgb(bg_rgb),
        .sample(raw_sample),.valid(raw_valid),.reason(raw_reason),.bx(raw_bx),.by(raw_by),.bw(raw_bw),.bh(raw_bh),.ba(raw_ba),.bsquare(raw_bsquare),
        .lx(raw_lx),.ly(raw_ly),.lw(raw_lw),.lh(raw_lh),.la(raw_la),.lsquare(raw_lsquare),
        .debug_code(debug_code),.debug_points(debug_points),.debug_bad_points(debug_bad_points),
        .debug_fit_w(debug_fit_w),.debug_fit_h(debug_fit_h),
        .debug_pixel_valid(debug_pixel_valid),.debug_raw_pixel(debug_raw_pixel),.debug_kept_pixel(debug_kept_pixel));
    label_observation_fusion fusion(.clk(I_clk),.rst_n(I_rst_n),.enable(I_enable && learning),
        .sample(raw_sample),.valid(raw_valid),.reason(raw_reason),
        .bx(raw_bx),.by(raw_by),.bw(raw_bw),.bh(raw_bh),.ba(raw_ba),.bsquare(raw_bsquare),
        .lx(raw_lx),.ly(raw_ly),.lw(raw_lw),.lh(raw_lh),.la(raw_la),.lsquare(raw_lsquare),
        .busy(fbusy),.O_sample(fsample),.O_valid(fvalid),.O_reason(freason),
        .O_bx(fbx),.O_by(fby),.O_bw(fbw),.O_bh(fbh),.O_ba(fba),.O_bsquare(fbs),
        .O_lx(flx),.O_ly(fly),.O_lw(flw),.O_lh(flh),.O_la(fla),.O_lsquare(fls));
    wire relative_done;reg delayed_invalid;
    label_relative relative(.clk(I_clk),.rst_n(I_rst_n),.start(observation && valid),
        .abort(!I_enable),
        .bx(bx),.by(by),.bw(bw),.bh(bh),.ba(ba),.lx(lx),.ly(ly),.lw(lw),.lh(lh),.la(la),
        .done(relative_done),.u(u),.v(v),.wr(wr),.hr(hr),.alpha(alpha));
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin delayed_invalid<=0;relative_busy<=0;end
        else begin
            delayed_invalid<=observation && !valid;
            if(!I_enable || relative_done) relative_busy<=0;
            else if(observation && valid) relative_busy<=1;
        end
    end
    assign sample=relative_done || delayed_invalid;
    label_scene_controller #(.TIMEOUT_CYCLES(CHECK_TIMEOUT)) controller(
        .clk(I_clk),.rst_n(I_rst_n),.enable(I_enable && !scan_active),.auto_mode(I_enable),
        .start(press[0] && allow_operation),.learn(press[1] && allow_operation),.ack(press[2]),.clear(clear),
        .sample(sample),.valid(valid),.reason(reason),.u(u),.v(v),.wr(wr),.hr(hr),.alpha(alpha),
        .bx(bx),.by(by),.bw(bw),.bh(bh),.ba(ba),.bsquare(bsquare),
        .lx(lx),.ly(ly),.lw(lw),.lh(lh),.la(la),.lsquare(lsquare),
        .state(state),.result(result),.cause(cause),.fail(fail),.size_fail(size_fail),.locked(locked),.geometry(geometry),
        .reference_set(reference_set),.learn_failed(learn_failed),.O_alarm(alarm),.muted(muted),
        .ref_u(ref_u),.ref_v(ref_v),.ref_wr(ref_wr),.ref_hr(ref_hr),.ref_alpha(ref_alpha),
        .ref_square(ref_square),.ref_label_square(ref_label_square),.ref_bw(ref_bw),.ref_bh(ref_bh),
        .du(du),.dv(dv),.da(da),.box_x(box_x),.box_y(box_y),.box_w(box_w),.box_h(box_h),.box_a(box_a),.box_square(box_square),
        .label_x(label_x),.label_y(label_y),.label_w(label_w),.label_h(label_h),.label_a(label_a),.scene(scene),
        .branch(branch),.main_item(main_item),.total(total),.passes(passes),.fails(fails),.unknowns(unknowns),.O_auto_pending(auto_pending));
    label_barcode_session barcode_session(.clk(I_clk),.rst_n(I_rst_n),.enable(I_enable),.de(I_de),.x(I_x),.y(I_y),.rgb(I_rgb),
        .pass_locked(locked && result==1),.new_cycle(auto_pending),
        .start_scan(background_physical || remote_background),.exit_scan(press[0] || press[1]),.clear_count(clear),
        .active(scan_active),.ticket(scan_ticket),.hit(scan_hit),.color(scan_color),
        .O_done(O_barcode_valid),.O_order(O_barcode_order),.O_count(O_barcode_count));
    assign O_hit=scan_active?scan_hit:label_hit;
    assign O_color=scan_active?scan_color:label_color;
    // The label-only zoom and its target geometry engine are removed.  Keep
    // the legacy ports driven low so the surrounding wrapper stays compatible.
    assign press=press_physical|remote_press;
    assign O_zoom_request=1'b0;
    assign O_zoom_src_x=12'd0;
    assign O_zoom_src_y=12'sd0;
    wire signed [15:0] rp=16'sd0,rq=16'sd0;
    wire [11:0] rhw=12'd0,rhh=12'd0,tx=12'd0,ty=12'd0;
    wire [8:0] ta=9'd0;
    wire signed [12:0] move_x=13'sd0,move_y=13'sd0;
    wire beeping;
    label_result_io #(.BEEP_CYCLES(BEEP_CYCLES),.TONE_CYCLES(TONE_CYCLES),.SCAN_CYCLES(SCAN_CYCLES)) result_io(
        .clk(I_clk),.rst_n(I_rst_n),.enable(I_enable),.locked(locked),.result(result),.muted(muted),
        .buzzer_n(O_buzzer_n),.beeping(beeping),.seg_sel(O_seg_sel),.seg_dig(O_seg_dig));
    label_scene_overlay_v4 overlay(.clk(I_clk),.rst_n(I_rst_n),.enable(I_enable),.de(I_de),.x(I_x),.y(I_y),
        .background_status(bg_status),.background_progress(bg_progress),
        .state(state),.result(result),.cause(cause),.fail(fail),.size_fail(size_fail),.locked(locked),.geometry(geometry),.scene(scene),
        .reference_set(reference_set),.learn_failed(learn_failed),.alarm(beeping),.muted(muted),
        .du(du),.dv(dv),.da(da),.main_item(main_item),.move_x(move_x),.move_y(move_y),
        .box_x(box_x),.box_y(box_y),.box_w(box_w),.box_h(box_h),.box_a(box_a),.square(ref_square),
        .label_x(label_x),.label_y(label_y),.label_w(label_w),.label_h(label_h),.label_a(label_a),
        .rp(rp),.rq(rq),.rhw(rhw),.rhh(rhh),.ta(ta),.tx(tx),.ty(ty),
        .total(total),.passes(passes),.fails(fails),.unknowns(unknowns),
        .debug_code(debug_code),.debug_points(debug_points),.debug_bad_points(debug_bad_points),
        .debug_fit_w(debug_fit_w),.debug_fit_h(debug_fit_h),
        .debug_pixel_valid(debug_pixel_valid),.debug_raw_pixel(debug_raw_pixel),.debug_kept_pixel(debug_kept_pixel),
        .O_hit(label_hit),.O_color(label_color),.I_angle_zoom(I_zoom_active),
        .I_zoom_src_x(12'd0),.I_zoom_src_y(12'sd0));
endmodule

