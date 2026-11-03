`timescale 1ns/1ps
// Exercise the actual application wiring and keys. Inject detector observations;
// full-resolution detector pixels are covered separately by tb_region.
module tb_application_fusion;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,enable=0;reg [3:0] keys=15;
    reg observation=0,observation_valid=1;reg [3:0] reason=0;
    reg [11:0] bw=300,bh=200,lx=900,lw=80,lh=40;
    wire hit,lock,buzzer;wire [23:0] color;
    wire [7:0] sel,dig;
    integer lit_digits;
    label_application #(.KEY_DEBOUNCE(1),.KEY_HOLD(30),.CHECK_TIMEOUT(4000),.BEEP_CYCLES(100),.TONE_CYCLES(2),.SCAN_CYCLES(8)) dut(
        .I_clk(clk),.I_rst_n(rst_n),.I_enable(enable),.I_de(1'b0),.I_keys_n(keys),
        .I_x(12'd0),.I_y(12'd0),.I_rgb(24'd0),.I_frame_id(24'd0),.I_remote_action(3'd0),.I_imaging_locked(1'b1),
        .O_imaging_lock(lock),.O_hit(hit),.O_color(color),.O_buzzer_n(buzzer),.O_seg_sel(sel),.O_seg_dig(dig));
    task press_key;
        input integer key;
        begin @(negedge clk);keys[key]=0;repeat(8) @(negedge clk);
            keys[key]=1;repeat(8) @(negedge clk);end
    endtask
    task offer;
        begin
            if(!dut.detector.acquire) $fatal(1,"application did not request fresh observation");
            observation=1;@(negedge clk);observation=0;repeat(4) @(negedge clk);
        end
    endtask
    task finish_operation;
        integer n;
        begin n=0;while(dut.state!=0 && n<4500) begin @(negedge clk);n=n+1;end
            if(dut.state!=0) $fatal(1,"application stuck");repeat(30) @(negedge clk);end
    endtask
    initial begin
        // Geometry injection bypasses the independent background calibration test.
        force dut.bg_ready=1'b1;
        force dut.raw_sample=observation;force dut.raw_valid=observation_valid;force dut.raw_reason=reason;
        force dut.raw_bx=12'd900;force dut.raw_by=12'd360;force dut.raw_bw=bw;force dut.raw_bh=bh;
        force dut.raw_ba=9'd0;force dut.raw_bsquare=1'b0;
        force dut.raw_lx=lx;force dut.raw_ly=12'd360;force dut.raw_lw=lw;force dut.raw_lh=lh;
        force dut.raw_la=9'd0;force dut.raw_lsquare=1'b0;
        repeat(5) @(negedge clk);rst_n=1;enable=1;repeat(10) @(negedge clk);
        press_key(1);
        if(dut.state!=2) $fatal(1,"K2 did not start learning");
        lx=901;offer;lx=902;offer;
        if(dut.reference_set || dut.state!=2) $fatal(1,"learning completed before third observation");
        lx=913;offer;finish_operation;
        if(!dut.reference_set || dut.learn_failed || dut.label_x!=902 || dut.total!=0)
            $fatal(1,"application reference was not fused");
        lx=902;press_key(0);offer;offer;
        if(dut.state!=1) $fatal(1,"check completed before third observation");
        offer;finish_operation;
        if(dut.result!=1 || dut.total!=1 || dut.passes!=1) $fatal(1,"application PASS/counter mismatch");
        lw=104;lh=52;press_key(0);offer;offer;offer;finish_operation;
        if(dut.result!=2 || dut.size_fail!=2 || dut.geometry || dut.total!=2 || dut.fails!=1)
            $fatal(1,"label size flag was not wired to application");
        if(!dut.beeping) $fatal(1,"application FAIL was not wired to short alarm");
        lit_digits=0;repeat(150) begin @(negedge clk);if(sel!=255) lit_digits=lit_digits+1;end
        if(dut.beeping || !buzzer || lit_digits==0) $fatal(1,"application must stop sounding while retaining FAIL digits");
        lw=80;lh=40;bw=360;bh=240;press_key(0);offer;offer;offer;finish_operation;
        if(dut.result!=2 || dut.size_fail!=1 || dut.geometry || dut.total!=3 || dut.fails!=2)
            $fatal(1,"box size flag was not wired to application");
        bw=300;bh=200;press_key(0);observation_valid=0;reason=1;offer;finish_operation;
        if(dut.result!=3 || dut.cause!=1 || dut.size_fail!=0 || dut.total!=4 || dut.unknowns!=1)
            $fatal(1,"invalid observation/timeout was not wired to application");
        $display("PASS tb_application_fusion: actual K2/K1 wiring, three observations, median reference, independent sizes, timeout and one-count results");
        $finish;
    end
    initial begin #2000000;$fatal(1,"testbench timeout");end
endmodule
