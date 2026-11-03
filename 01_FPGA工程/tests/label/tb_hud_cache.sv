`timescale 1ns/1ps
module tb_hud_cache;
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
    integer k,r,c,n,seed=32'hfc55,compared=0,rows;
    reg [143:0] expected;
    initial begin
        repeat(5) @(negedge clk);rst_n=1;enable=1;
        for(k=0;k<80;k=k+1) begin
            @(negedge clk);de=0;x=0;y=0;
            state=k%3;result=k%4;locked=1;geometry=k%2;scene=1;reference_set=k%2;learn_failed=k%5==0;
            fail=k%8;size_fail=k%4;main_item=k%4;
            cause=k%16;
            if(k>=32 && k<48) begin result=3;cause=k%3==0?1:(k%3==1?2:9);end
            debug_code=k%8;debug_points=(k*127)&4095;debug_bad_points=(k*211)&4095;
            debug_fit_w=(k*43)&4095;debug_fit_h=(k*73)&4095;
            du=k%2?-4096:4095;dv=k%3?-333:1024;da=k%3?-23:0;
            move_x=k%2?-127:128;move_y=k%3?-64:0;square=k%2;
            box_x=900;box_y=360;box_w=300;box_h=200;label_x=910;label_y=355;label_w=80;label_h=40;
            box_a=k*3;label_a=k*3+8;ta=k*3;rp=-40;rq=12;rhw=40;rhh=20;tx=900;ty=360;
            total=24'h129999-k;passes=24'h001234+k;fails=24'h000056+k;unknowns=24'h999900+k;
            alarm=k%2;muted=k%3==0;background_status=4;background_progress=k%9;
            @(negedge clk);de=1;
            @(negedge clk);de=0;
            repeat(1200) @(negedge clk);
            if(dut_overlay.fill_pending || dut_overlay.filling || dut_overlay.fmt!=0) $fatal(1,"HUD fill timeout");
            for(r=0;r<24;r=r+1) begin
                @(negedge clk);x=r==21 || r==23?256:32;
                y=r>=20?(r<22?656:680):ref_overlay.line_y(r);
                #1;expected=ref_overlay.text_line;
                case(r)
                    19:expected="BG: BYPASS LIVE   ";
                    20:expected="K1 AUTO CHECK     ";
                    21:expected="K2 LEARN          ";
                    22:expected="K3 MUTE           ";
                    23:expected="K4 CLEAR          ";
                    default:;
                endcase
                for(c=0;c<18;c=c+1) begin
                    if(dut_overlay.text_cache[1+r*18+c]!==expected[143-c*8-:8])
                        $fatal(1,"HUD byte mismatch scenario=%0d panel=%0d col=%0d got=%h expected=%h",k,r,c,dut_overlay.text_cache[1+r*18+c],expected[143-c*8-:8]);
                    compared=compared+1;
                end
            end
            if(dut_overlay.badge_visible) begin
                rows=result==2?(size_fail!=0?3:5):(result==3?2:1);
                for(r=0;r<rows;r=r+1) begin
                    @(negedge clk);x=ref_overlay.badge_x+8;y=ref_overlay.badge_y+(r==0?4:40+(r-1)*16);
                    #1;expected=ref_overlay.text_line;
                    for(c=0;c<18;c=c+1) begin
                        if(dut_overlay.text_cache[1+(24+r)*18+c]!==expected[143-c*8-:8])
                            $fatal(1,"HUD badge byte mismatch scenario=%0d line=%0d col=%0d",k,r,c);
                        compared=compared+1;
                    end
                end
            end
            if(dut_overlay.text_cache[0]!==8'h20) $fatal(1,"HUD blank entry changed");
        end
        $display("PASS tb_hud_cache: %0d cached message bytes match V5.4 across 80 state/diagnostic/size/number/direction/background snapshots",compared);
        $finish;
    end
    initial begin #5000000;$fatal(1,"HUD cache test timeout");end
endmodule

