module servo_pan_tracker_v38_baseline #(
    parameter integer CLK_MHZ = 75
)(
    input wire I_clk,
    input wire I_rst_n,
    input wire [3:0] I_mode,
    input wire I_zoom_active,
    input wire [2:0] I_color,
    input wire [1:0] I_shape,
    input wire I_key_dec,
    input wire I_key_inc,
    input wire I_measure_update,
    input wire I_measure_valid,
    input wire signed [12:0] I_measure_dx,
    input wire signed [12:0] I_measure_dy,
    output reg O_pan_pwm,
    output reg O_tilt_pwm,
    output reg [3:0] O_state,
    output wire [11:0] O_pan_pulse_us,
    output wire [11:0] O_tilt_pulse_us,
    output wire O_buzzer_n,
    input wire I_remote_valid,input wire [2:0] I_remote_state
);
    localparam [11:0] P_NEUTRAL_US=12'd1500, P_MIN_US=12'd500, P_MAX_US=12'd1900;
    localparam [3:0] ST_IDLE=0, ST_PAUSED=1, ST_SEARCH=2, ST_TRACKING=3,
                     ST_CENTERED=4, ST_TEMP_LOST=5, ST_LOST=6, ST_LIMIT=7, ST_HOLD=8;
    reg [6:0] S_us_div;
    reg [14:0] S_frame_us;
    reg [3:0] S_mode_sample, S_mode_stable;
    reg [2:0] S_color_seen;
    reg [1:0] S_shape_seen;
    reg [11:0] S_pan_target_us, S_tilt_target_us;
    reg [11:0] S_pan_pulse_us, S_tilt_pulse_us;
    reg S_armed, S_lost, S_seen_target, S_adjusting;
    reg S_adjusting_tilt;
    reg S_home_active, S_returning, S_home_cancelled;
    reg [19:0] S_age_us;
    reg [18:0] S_beep_remaining_us;
    reg [7:0] S_beep_half_us;
    reg S_beep_level;
    wire S_us_tick = (S_us_div == CLK_MHZ-1);
    wire S_pan_mode = (I_mode == 4'b0011) && (S_mode_stable == 4'b0011);
    wire S_color_changed = (I_color != S_color_seen) || (I_shape != S_shape_seen);
    wire [12:0] S_abs_dx = I_measure_dx[12] ? -I_measure_dx : I_measure_dx;

    wire [12:0] S_abs_dy = I_measure_dy[12] ? -I_measure_dy : I_measure_dy;

    wire S_remote_valid=(I_remote_valid===1'b1);
    reg signed [4:0] S_command_pan,S_command_tilt,S_rate_pan,S_rate_tilt;
    reg [12:0] S_previous_dx,S_previous_dy;
    reg S_previous_valid;
    function [3:0] F_speed;
        input [12:0] error,previous;
        input history;
        reg [3:0] speed;
        begin
            if(error>=320) speed=8;
            else if(error>=192) speed=6;
            else if(error>=96) speed=4;
            else if(error>=48) speed=2;
            else speed=1;
            if(history && error<192 && previous>error+13'd16 && speed>2) speed=2;
            F_speed=speed;
        end
    endfunction
    function signed [4:0] F_ramp;
        input signed [4:0] current,target;
        reg [4:0] cm,tm,nm;
        begin
            cm=current[4]?-current:current;tm=target[4]?-target:target;
            if(target==0 || (current!=0 && current[4]!=target[4])) F_ramp=0;
            else begin
                nm=cm>=tm ? tm : (cm+2>tm ? tm : cm+2);
                F_ramp=target[4] ? -$signed(nm) : $signed(nm);
            end
        end
    endfunction
    wire [3:0] S_speed_pan=F_speed(S_abs_dx,S_previous_dx,S_previous_valid);
    wire [3:0] S_speed_tilt=F_speed(S_abs_dy,S_previous_dy,S_previous_valid);
    wire S_measure_fresh = I_measure_valid && (S_age_us < 20'd100000);
    wire S_run=S_pan_mode && S_armed && S_seen_target && S_measure_fresh &&
                    !I_key_dec && !S_color_changed && !S_remote_valid;
    wire signed [4:0] S_next_rate_pan=S_run ? F_ramp(S_rate_pan,S_command_pan):5'sd0;
    wire signed [4:0] S_next_rate_tilt=S_run ? F_ramp(S_rate_tilt,S_command_tilt):5'sd0;
    assign O_pan_pulse_us=S_pan_pulse_us;
    assign O_tilt_pulse_us=S_tilt_pulse_us;
    // Board buzzer C12 is active low; cancel sound on pause or mode/colour exit.
    wire S_zoom_alarm = 1'b0;
    wire S_beep_enabled = S_zoom_alarm || (S_pan_mode && !I_key_dec &&
                           !S_color_changed && S_beep_remaining_us!=19'd0);
    assign O_buzzer_n = !I_rst_n || !S_beep_enabled || S_beep_level;

    // The board example drives its buzzer with alternating levels.
    // 250 us per half-cycle gives 2 kHz, with no generated clock domain.
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_beep_half_us<=0;
            S_beep_level<=0;
        end
        else if(!S_beep_enabled) begin
            S_beep_half_us<=0;
            S_beep_level<=0;
        end
        else if(S_us_tick) begin
            if(S_beep_half_us == 8'd249) begin
                S_beep_half_us<=0;
                S_beep_level<=~S_beep_level;
            end
            else S_beep_half_us<=S_beep_half_us+8'd1;
        end
    end

    function [11:0] F_limit;
        input signed [13:0] I_value;
        begin
            if(I_value < 14'sd500) F_limit=P_MIN_US;
            else if(I_value > 14'sd1900) F_limit=P_MAX_US;
            else F_limit=I_value[11:0];
        end
    endfunction
    function [11:0] F_tilt_limit;
        input signed [13:0] I_value;
        begin
            if(I_value < 14'sd500) F_tilt_limit=12'd500;
            else if(I_value > 14'sd1850) F_tilt_limit=12'd1850;
            else F_tilt_limit=I_value[11:0];
        end
    endfunction
    function [11:0] F_slew;
        input [11:0] I_current, I_target;
        input [2:0] I_step;
        begin
            if(I_target > I_current + I_step) F_slew=I_current+I_step;
            else if(I_current > I_target + I_step) F_slew=I_current-I_step;
            else F_slew=I_target;
        end
    endfunction

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_us_div<=0;S_frame_us<=0;S_mode_sample<=0;S_mode_stable<=0;
            S_pan_pulse_us<=P_NEUTRAL_US;S_tilt_pulse_us<=P_NEUTRAL_US;
            S_rate_pan<=0;S_rate_tilt<=0;O_pan_pwm<=0;O_tilt_pwm<=0;
        end else begin
            if(S_remote_valid) begin S_mode_sample<=I_mode;S_mode_stable<=I_mode;end
            if(!S_run) begin S_rate_pan<=0;S_rate_tilt<=0;end
            if(S_us_tick) begin
                S_us_div<=0;
                if(S_frame_us==19999) begin
                    S_frame_us<=0;S_mode_sample<=I_mode;
                    S_mode_stable<=(S_remote_valid || I_mode==S_mode_sample)?I_mode:4'd0;
                    O_pan_pwm<=(S_remote_valid || I_mode==S_mode_sample) &&
                        (I_mode==3 || (I_mode==4 && S_home_active));
                    O_tilt_pwm<=(S_remote_valid || I_mode==S_mode_sample) &&
                        (I_mode==3 || (I_mode==4 && S_home_active));
                    if(S_run) begin
                        S_rate_pan<=S_next_rate_pan;S_rate_tilt<=S_next_rate_tilt;
                        S_pan_pulse_us<=F_limit($signed({2'b0,S_pan_pulse_us})+
                            $signed({{9{S_next_rate_pan[4]}},S_next_rate_pan}));
                        S_tilt_pulse_us<=F_tilt_limit($signed({2'b0,S_tilt_pulse_us})+
                            $signed({{9{S_next_rate_tilt[4]}},S_next_rate_tilt}));
                    end
                    if(I_mode==4 && I_mode==S_mode_sample && S_returning && !I_key_dec && !S_remote_valid) begin
                        S_pan_pulse_us<=F_slew(S_pan_pulse_us,S_pan_target_us,3'd5);
                        S_tilt_pulse_us<=F_slew(S_tilt_pulse_us,S_tilt_target_us,3'd5);
                    end
                end else begin
                    S_frame_us<=S_frame_us+1'b1;
                    if(S_frame_us==S_pan_pulse_us-1'b1) O_pan_pwm<=0;
                    if(S_frame_us==S_tilt_pulse_us-1'b1) O_tilt_pwm<=0;
                end
            end else S_us_div<=S_us_div+1'b1;
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_pan_target_us<=P_NEUTRAL_US; S_tilt_target_us<=P_NEUTRAL_US;
            S_color_seen<=0; S_shape_seen<=0; S_armed<=0; S_lost<=0;
            S_home_active<=0; S_returning<=0; S_home_cancelled<=0;
            S_seen_target<=0; S_adjusting<=0; S_adjusting_tilt<=0; S_age_us<=0;
            S_beep_remaining_us<=0;S_command_pan<=0;S_command_tilt<=0;
            S_previous_dx<=0;S_previous_dy<=0;S_previous_valid<=0;
        end
        else begin
            S_color_seen<=I_color; S_shape_seen<=I_shape;
            if(S_us_tick && (S_beep_remaining_us != 19'd0))
                S_beep_remaining_us<=S_beep_remaining_us-19'd1;
            if(S_remote_valid) begin
                S_beep_remaining_us<=0;S_lost<=0;S_seen_target<=0;S_age_us<=0;
                S_adjusting<=0;S_adjusting_tilt<=0;S_command_pan<=0;S_command_tilt<=0;S_previous_valid<=0;
                S_pan_target_us<=S_pan_pulse_us;S_tilt_target_us<=S_tilt_pulse_us;
                if(I_mode==3) begin
                    S_armed<=I_remote_state==1;S_home_active<=0;S_returning<=0;S_home_cancelled<=0;
                end else begin
                    S_armed<=0;
                    if(I_remote_state<=2) begin
                        S_home_active<=I_remote_state!=0;S_returning<=I_remote_state==1;
                        S_home_cancelled<=I_remote_state==2;
                        if(I_remote_state==1) begin S_pan_target_us<=P_NEUTRAL_US;S_tilt_target_us<=P_NEUTRAL_US;end
                    end
                end
            end else if(!S_pan_mode || S_color_changed) begin
                S_command_pan<=0;S_command_tilt<=0;S_previous_valid<=0;
                S_beep_remaining_us<=0;
                S_armed<=0; S_lost<=0; S_seen_target<=0; S_adjusting<=0;
                S_adjusting_tilt<=0; S_age_us<=0;
                if((I_mode == S_mode_stable) && (I_mode == 4'b0100)) begin
                    S_pan_target_us<=P_NEUTRAL_US;
                    S_tilt_target_us<=P_NEUTRAL_US;
                    if(I_key_dec) begin
                        S_returning<=0;
                        S_home_cancelled<=1;
                    end
                    else if(I_key_inc) begin
                        S_returning<=1;
                        S_home_active<=1;
                        S_home_cancelled<=0;
                    end
                    else if((S_pan_pulse_us == P_NEUTRAL_US) &&
                            (S_tilt_pulse_us == P_NEUTRAL_US)) begin
                        S_returning<=0;
                        S_home_cancelled<=0;
                    end
                end
                else begin
                    S_returning<=0;
                    S_home_active<=0;
                    S_home_cancelled<=0;
                    if(S_armed || S_color_changed)
                        S_pan_target_us<=S_pan_pulse_us;
                    if(S_armed || S_color_changed)
                        S_tilt_target_us<=S_tilt_pulse_us;
                end
            end
            else if(I_key_dec) begin
                S_command_pan<=0;S_command_tilt<=0;S_previous_valid<=0;
                S_beep_remaining_us<=0;
                // Pause wins even if both keys are pressed together.
                S_armed<=0; S_lost<=0; S_seen_target<=0; S_adjusting<=0;
                S_adjusting_tilt<=0; S_age_us<=0;
                S_pan_target_us<=S_pan_pulse_us;
                S_tilt_target_us<=S_tilt_pulse_us;
            end
            else if(I_key_inc && !S_armed) begin
                S_command_pan<=0;S_command_tilt<=0;S_previous_valid<=0;
                S_beep_remaining_us<=0;
                S_armed<=1; S_lost<=0; S_seen_target<=0; S_adjusting<=0;
                S_adjusting_tilt<=0; S_age_us<=0;
                S_pan_target_us<=S_pan_pulse_us;
                S_tilt_target_us<=S_tilt_pulse_us;
            end
            else if(S_armed) begin
                if(I_measure_update && I_measure_valid) begin
                    S_age_us<=0; S_seen_target<=1;
                    S_previous_dx<=S_abs_dx;S_previous_dy<=S_abs_dy;S_previous_valid<=1;
                    S_pan_target_us<=S_pan_pulse_us;S_tilt_target_us<=S_tilt_pulse_us;
                    if(S_abs_dx<=12) begin S_adjusting<=0;S_command_pan<=0;end
                    else if(S_adjusting || S_abs_dx>=20) begin
                        S_adjusting<=1;
                        S_command_pan<=I_measure_dx[12] ? $signed({1'b0,S_speed_pan}):-$signed({1'b0,S_speed_pan});
                    end else S_command_pan<=0;
                    if(S_abs_dy<=12) begin S_adjusting_tilt<=0;S_command_tilt<=0;end
                    else if(S_adjusting_tilt || S_abs_dy>=20) begin
                        S_adjusting_tilt<=1;
                        S_command_tilt<=I_measure_dy[12] ? -$signed({1'b0,S_speed_tilt}):$signed({1'b0,S_speed_tilt});
                    end else S_command_tilt<=0;
                end
                else begin
                    if(!S_measure_fresh) begin
                        S_command_pan<=0;S_command_tilt<=0;S_previous_valid<=0;
                        S_pan_target_us<=S_pan_pulse_us;
                        S_adjusting<=0;
                        S_tilt_target_us<=S_tilt_pulse_us;
                        S_adjusting_tilt<=0;
                    end
                    if(S_us_tick) begin
                        if(S_age_us == 20'd999999) begin
                            // Enter LOST once per explicit start, then sound for 500 ms.
                            S_beep_remaining_us<=19'd500000;
                            S_age_us<=20'd1000000;
                            S_armed<=0; S_lost<=1; S_adjusting<=0;
                            S_adjusting_tilt<=0;
                            S_pan_target_us<=S_pan_pulse_us;
                            S_tilt_target_us<=S_tilt_pulse_us;
                        end
                        else S_age_us<=S_age_us+20'd1;
                    end
                end
            end
        end
    end

    always @* begin
        O_state=ST_IDLE;
        if((I_mode == 4'b0100) && (S_mode_stable == 4'b0100)) begin
            if(S_returning) O_state=4'd10;
            else if((S_pan_pulse_us == P_NEUTRAL_US) &&
                    (S_tilt_pulse_us == P_NEUTRAL_US)) O_state=4'd11;
            else if(S_home_cancelled) O_state=4'd12;
            else O_state=4'd9;
        end
        else if(S_pan_mode) begin
            if(S_lost) O_state=ST_LOST;
            else if(!S_armed) O_state=ST_PAUSED;
            else if(!S_seen_target) O_state=ST_SEARCH;
            else if(!S_measure_fresh) O_state=ST_TEMP_LOST;
            else if(!S_adjusting && !S_adjusting_tilt)
                O_state=((S_abs_dx<=13'd12) && (S_abs_dy<=13'd12)) ? ST_CENTERED : ST_HOLD;
            else if(((S_pan_pulse_us == P_MIN_US) && !I_measure_dx[12]) ||
                    ((S_pan_pulse_us == P_MAX_US) && I_measure_dx[12]) ||
                    ((S_tilt_pulse_us == 12'd500) && I_measure_dy[12]) ||
                    ((S_tilt_pulse_us == 12'd1850) && !I_measure_dy[12])) O_state=ST_LIMIT;
            else O_state=ST_TRACKING;
        end
    end
endmodule