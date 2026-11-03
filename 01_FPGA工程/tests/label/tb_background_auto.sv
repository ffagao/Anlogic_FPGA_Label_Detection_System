`timescale 1ns/1ps
module tb_background_auto;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,enable=0,de=0,ack=0;reg [3:0] keys=15;
    reg [11:0] x=0,y=0;reg [23:0] frame_id=0;
    wire lock,hit,buzzer;wire [23:0] color;wire [7:0] sel,dig;
    integer launches=0,i,j,f;
    label_application #(.KEY_DEBOUNCE(1),.KEY_HOLD(30),.CHECK_TIMEOUT(500),.BG_TIMEOUT(100000),
        .WIDTH(64),.HEIGHT(32),.ROI_L(32),.ROI_R(63),.ROI_T(0),.ROI_B(31)) dut(
        .I_clk(clk),.I_rst_n(rst_n),.I_enable(enable),.I_de(de),.I_keys_n(keys),.I_x(x),.I_y(y),
        .I_rgb(24'hd8d8d8),.I_frame_id(frame_id),.I_remote_action(3'd0),.I_imaging_locked(ack),.O_imaging_lock(lock),
        .O_hit(hit),.O_color(color),.O_buzzer_n(buzzer),.O_seg_sel(sel),.O_seg_dig(dig));
    always @(posedge clk) if(rst_n && dut.bg_start) launches=launches+1;
    task press_key;
        input integer key;
        begin @(negedge clk);keys[key]=0;repeat(8) @(negedge clk);
            keys[key]=1;repeat(8) @(negedge clk);end
    endtask
    task frames;
        begin
            for(f=0;f<11;f=f+1) begin
                for(j=0;j<32;j=j+1) for(i=0;i<64;i=i+1) begin
                    @(negedge clk);de=1;x=i;y=j;
                end
                @(negedge clk);de=0;frame_id=frame_id+1;
            end
            repeat(4) @(negedge clk);
            if(!dut.bg_ready || dut.bg_busy || dut.bg_status!=4 || dut.bg_progress!=8)
                $fatal(1,"single-key background calibration failed status=%d progress=%d",dut.bg_status,dut.bg_progress);
        end
    endtask
    initial begin
        repeat(4) @(negedge clk);rst_n=1;enable=1;repeat(10) @(negedge clk);
        press_key(0);if(dut.state!=0) $fatal(1,"checking allowed before background ready");
        press_key(3);
        if(!lock || !dut.bg_pending || dut.bg_busy || launches!=0) $fatal(1,"first K4 must request and await imaging lock");
        press_key(0);press_key(1);
        if(dut.state!=0) $fatal(1,"K1/K2 allowed during lock wait");
        ack=1;repeat(10) @(negedge clk);
        if(!dut.bg_busy || launches!=1) $fatal(1,"calibration did not start automatically after ack");
        press_key(0);press_key(1);if(dut.state!=0) $fatal(1,"K1/K2 allowed during capture");
        frames;
        press_key(3);frames;if(launches!=2) $fatal(1,"one-key recalibration did not launch exactly once");
        keys[3]=0;repeat(60) @(negedge clk);keys[3]=1;repeat(10) @(negedge clk);
        if(launches!=2 || !dut.bg_ready) $fatal(1,"long K4 must clear counts, not recalibrate");
        ack=0;press_key(3);repeat(100005) @(negedge clk);
        if(dut.bg_pending || dut.bg_status!=5 || launches!=2) $fatal(1,"lock timeout not reported");
        press_key(3);ack=1;repeat(10) @(negedge clk);frames;
        if(launches!=3) $fatal(1,"retry after lock timeout failed");
        press_key(3);repeat(100005) @(negedge clk);
        if(!dut.bg_failed || dut.bg_ready) $fatal(1,"missing-frame capture timeout not reported");
        press_key(3);frames;if(launches!=5) $fatal(1,"retry after capture failure failed");
        ack=0;press_key(3);enable=0;repeat(8) @(negedge clk);
        if(lock || dut.bg_pending || dut.bg_busy || dut.bg_ready) $fatal(1,"mode exit did not cancel calibration");
        enable=1;ack=1;repeat(10) @(negedge clk);
        if(dut.bg_busy || launches!=5) $fatal(1,"stale pending request restarted on mode entry");
        $display("PASS tb_background_auto: one K4, lock handshake, 3 settle + 8 fresh frames, operation interlock, recalibrate, hold-clear, timeouts/retries and cancellation");
        $finish;
    end
    initial begin #10000000;$fatal(1,"background test timeout");end
endmodule
