`timescale 1ns/1ps
module tb_servo_pan_tracker_modes;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg [3:0] mode = 4'b0000;
    reg key_dec = 1'b0;
    reg key_inc = 1'b0;
    wire pan_pwm;
    wire tilt_pwm;
    wire [3:0] servo_state;
    wire [11:0] pan_pulse_us;
    wire [11:0] tilt_pulse_us;
    wire buzzer_n;

    always #5 clk = ~clk;

    servo_pan_tracker #(.CLK_MHZ(1)) dut (
        .I_clk(clk),
        .I_rst_n(rst_n),
        .I_mode(mode),.I_zoom_active(1'b0),
        .I_color(3'd0),
        .I_shape(2'd1),
        .I_key_dec(key_dec),
        .I_key_inc(key_inc),
        .I_measure_update(1'b0),
        .I_measure_valid(1'b0),
        .I_measure_dx(13'sd0),
        .I_measure_dy(13'sd0),
        .O_pan_pwm(pan_pwm),
        .O_tilt_pwm(tilt_pwm),
        .O_state(servo_state),
        .O_pan_pulse_us(pan_pulse_us),
        .O_tilt_pulse_us(tilt_pulse_us),
        .O_buzzer_n(buzzer_n)
    );

    task wait_frame_boundaries;
        input integer count;
        integer i;
        begin
            for (i = 0; i < count; i = i + 1) begin
                wait (dut.S_frame_us == 15'd19999);
                @(posedge clk);
                #1;
            end
        end
    endtask

    initial begin
        repeat (4) @(negedge clk);
        rst_n = 1'b1;

        // Old manual-tilt mode is gone: 0110 has no servo output or tilt step.
        @(negedge clk);
        mode = 4'b0110;
        key_inc = 1'b1;
        wait_frame_boundaries(2);
        if (pan_pwm !== 1'b0 || tilt_pwm !== 1'b0 ||
            dut.S_tilt_target_us !== 12'd1500)
            $fatal(1, "FAIL: 0110 still drives or steps a servo");
        $display("PASS: 0110 does not drive or manually step servos");
        key_inc = 1'b0;

        // Auto tracking drives both PWM outputs in its reassigned mode 0100.
        @(negedge clk);
        mode = 4'b0011;
        wait_frame_boundaries(2);
        if (pan_pwm !== 1'b1 || tilt_pwm !== 1'b1)
            $fatal(1, "FAIL: 0100 does not enable both servo PWM outputs");
        $display("PASS: 0100 enables both servo PWM outputs");

        // Homing mode 0101 stays off until K4 (key_inc) starts the return.
        @(negedge clk);
        mode = 4'b0100;
        wait_frame_boundaries(2);
        if (pan_pwm !== 1'b0 || tilt_pwm !== 1'b0)
            $fatal(1, "FAIL: 0101 enabled PWM before K4");
        @(negedge clk);
        key_inc = 1'b1;
        @(negedge clk);
        key_inc = 1'b0;
        wait_frame_boundaries(1);
        if (pan_pwm !== 1'b1 || tilt_pwm !== 1'b1)
            $fatal(1, "FAIL: K4 did not enable homing PWM in 0101");
        $display("PASS: 0101 enables homing PWM after K4");

        $display("SIMULATION PASS");
        $finish;
    end

    initial begin
        #5000000;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
