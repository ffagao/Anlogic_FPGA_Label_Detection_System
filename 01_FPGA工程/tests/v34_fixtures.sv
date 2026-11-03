module v34_keys_fixture(input S_hdmi_pixel_clk,S_hdmi_rst_n,input [3:0] S_switch_hdmi_sync,S_servo_state,input S_color_key_dec,S_color_key_inc,S_algo_key_dec,S_algo_key_inc,output reg [3:0] S_algo_mode,output reg [2:0] S_track_color,output reg [1:0] S_track_shape,output reg S_learn_prepare,S_learn_start);
wire S_remote_valid=0;wire [1:0] S_remote_kind=0;wire [3:0] S_remote_value=0;
// BEGIN V25 KEY CONTROL (also compiled directly by the control regression).
    wire [3:0] S_algo_last = 4'd5;
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n)
            S_algo_mode <= 4'd0;
        else if(S_remote_valid && S_remote_kind==2 && S_switch_hdmi_sync==0)
            S_algo_mode<=S_remote_value;
        else if(S_switch_hdmi_sync == 4'b0000) begin
            if(S_algo_mode > S_algo_last)
                S_algo_mode <= 4'd0;
            else if(S_algo_key_dec && !S_algo_key_inc)
                S_algo_mode <= (S_algo_mode == 4'd0) ? S_algo_last : S_algo_mode - 4'd1;
            else if(S_algo_key_inc && !S_algo_key_dec)
                S_algo_mode <= (S_algo_mode == S_algo_last) ? 4'd0 : S_algo_mode + 4'd1;
        end
    end

    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_track_color <= 3'd0;
            S_track_shape <= 2'd1;
        end
        else if(S_remote_valid && S_remote_kind==0 &&
                (S_switch_hdmi_sync==1 || S_switch_hdmi_sync==3)) begin
            S_track_color<=S_remote_value[3:2]==3 ? 3'd5:{1'b0,S_remote_value[3:2]};
            S_track_shape<=S_remote_value[1:0];
        end
        else if(S_switch_hdmi_sync == 4'b0100)
            S_track_color <= 3'd5;
        else if(S_switch_hdmi_sync == 4'b0001 && S_track_color > 3'd2)
            S_track_color <= 3'd0;
        else if((S_switch_hdmi_sync == 4'b0001) ||
                ((S_switch_hdmi_sync == 4'b0011) &&
                 ((S_servo_state == 4'd1) || (S_servo_state == 4'd6)))) begin
            if(S_color_key_dec && !S_color_key_inc)
                S_track_color <= (S_track_color == 3'd5) ? 3'd0 :
                                 (S_track_color == 3'd2) ? ((S_switch_hdmi_sync == 4'd1) ? 3'd0 : 3'd5) : S_track_color + 3'd1;
            else if(S_color_key_inc && !S_color_key_dec)
                S_track_shape <= (S_track_shape == 2'd3) ? 2'd1 : S_track_shape + 2'd1;
        end
    end
    // END V25 KEY CONTROL
    // Learning is controlled by K1/K2 in the servo-centering mode.
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin S_learn_prepare<=0;S_learn_start<=0;end
        else begin
            S_learn_prepare<=0;S_learn_start<=0;
            if(S_switch_hdmi_sync==4'd4) begin
                S_learn_prepare<=S_color_key_dec || (S_remote_valid && S_remote_kind==2 && S_remote_value==3);
                S_learn_start<=(S_color_key_inc && !S_color_key_dec) ||
                    (S_remote_valid && S_remote_kind==2 && S_remote_value==4);
            end
        end
    end


endmodule
module v34_control_fixture(input I_sys_clk,S_100m_clk,S_hdmi_pixel_clk,S_24m_clk,S_rst_n,S_hdmi_rst_n,I_uart_rx,input [3:0] I_switch,output [3:0] O_effective_switch,O_switch_hdmi,output [7:0] O_segment_n,O_digit_n,output O_track,O_motion,O_black,O_fps60,O_ae_blocked);
reg S_track_enable_async,S_motion_enable_async,S_black_enable_async,S_fps60_switch_meta,S_fps60_switch_sync;
wire [1:0] S_label_result_hdmi=0;wire [3:0] S_switch_hdmi_sync;wire [7:0] S_mode_segment_n,S_mode_digit_n;
// BEGIN V32 SWITCH ROUTING
    wire [3:0] S_effective_switch;
    wire [11:0] S_uart_action_data;
    wire S_uart_action_toggle,S_remote_valid,S_remote_long;
    wire [1:0] S_remote_kind;
    wire [3:0] S_remote_value;
    reg [11:0] S_uart_action_bridge;
    reg S_uart_toggle_bridge;
    reg [3:0] S_uart_mode_bridge;
    wire [3:0] S_uart_mode_cam;
    wire S_remote_cam_valid,S_remote_cam_long;
    wire [1:0] S_remote_cam_kind;
    wire [3:0] S_remote_cam_value;
    reg [3:0] S_context_keys;
    reg S_scene_valid,S_scene_run;
    wire S_servo_context=S_remote_valid && S_remote_kind==3 &&
        (S_switch_hdmi_sync==3 || S_switch_hdmi_sync==4);
    wire [3:0] S_remote_keys=(S_remote_valid && S_remote_kind==1 && !S_remote_long ? S_remote_value:4'd0)|S_context_keys;
    // One destination clock qualifies servo mode before a contextual key,
    // or commits target colour/shape before arming an absolute scene.
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin S_context_keys<=0;S_scene_valid<=0;S_scene_run<=0;end
        else begin
            S_context_keys<=S_remote_valid && S_remote_kind==3 && !S_remote_long &&
                S_switch_hdmi_sync!=5 ? S_remote_value:4'd0;
            S_scene_valid<=S_remote_valid && S_remote_kind==0 && S_switch_hdmi_sync==3;
            S_scene_run<=S_remote_long;
        end
    end
    reg [2:0] S_label_remote_action;
    wire S_remote_ae_dec=S_remote_cam_valid && (S_remote_cam_kind==1 || S_remote_cam_kind==3) && !S_remote_cam_long &&
        (S_uart_mode_cam==0 || S_uart_mode_cam==2) && S_remote_cam_value[0];
    wire S_remote_ae_inc=S_remote_cam_valid && (S_remote_cam_kind==1 || S_remote_cam_kind==3) && !S_remote_cam_long &&
        (S_uart_mode_cam==0 || S_uart_mode_cam==2) && S_remote_cam_value[1];
    uart_action_bridge u_remote_hdmi(.I_clk(S_hdmi_pixel_clk),.I_rst_n(S_hdmi_rst_n),
        .I_mode(S_switch_hdmi_sync),.I_data(S_uart_action_data),.I_toggle(S_uart_action_toggle),
        .O_valid(S_remote_valid),.O_kind(S_remote_kind),.O_value(S_remote_value),.O_long(S_remote_long));
    always @(posedge S_100m_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin S_uart_action_bridge<=0;S_uart_toggle_bridge<=0;S_uart_mode_bridge<=0;end
        else begin S_uart_action_bridge<=S_uart_action_data;S_uart_toggle_bridge<=S_uart_action_toggle;S_uart_mode_bridge<=S_effective_switch;end
    end
    switch_state_sync u_remote_mode_cam(.I_clk(S_24m_clk),.I_rst_n(S_rst_n),.I_state(S_uart_mode_bridge),.O_state(S_uart_mode_cam));
    uart_action_bridge u_remote_cam(.I_clk(S_24m_clk),.I_rst_n(S_rst_n),
        .I_mode(S_uart_mode_cam),.I_data(S_uart_action_bridge),.I_toggle(S_uart_toggle_bridge),
        .O_valid(S_remote_cam_valid),.O_kind(S_remote_cam_kind),.O_value(S_remote_cam_value),.O_long(S_remote_cam_long));
    always @* begin
        S_label_remote_action=0;
        if(S_remote_valid && S_switch_hdmi_sync==5) begin
            if(S_remote_kind==2) S_label_remote_action=S_remote_value[2:0];
            else if(S_remote_kind==1 || S_remote_kind==3) begin
                if(S_remote_long) S_label_remote_action=5;
                else if(S_remote_value[3]) S_label_remote_action=1;
                else if(S_remote_value[1]) S_label_remote_action=2;
                else if(S_remote_value[0]) S_label_remote_action=3;
                else if(S_remote_value[2]) S_label_remote_action=4;
            end
        end
    end
    reg S_fps60_mode_sys,S_ae_buttons_blocked_sys;
    reg S_fps60_bridge_pll,S_ae_buttons_bridge_pll;
    reg S_ae_buttons_blocked_meta,S_ae_buttons_blocked_sync;
    uart_switch_control u_uart_switch_control (
        .I_clk(I_sys_clk),.I_rst_n(S_rst_n),.I_rx(I_uart_rx),
        .I_switch(I_switch),.O_switch(S_effective_switch),
        .O_action_data(S_uart_action_data),.O_action_toggle(S_uart_action_toggle)
    );
    switch_state_display u_switch_state_display (
        .I_clk(S_hdmi_pixel_clk),.I_rst_n(S_hdmi_rst_n),.I_state(S_switch_hdmi_sync),
        .I_result(S_label_result_hdmi),
        .O_segment_n(S_mode_segment_n),.O_digit_n(S_mode_digit_n)
    );
    switch_state_sync u_switch_state_sync (
        .I_clk(S_hdmi_pixel_clk),.I_rst_n(S_hdmi_rst_n),
        .I_state(S_effective_switch),.O_state(S_switch_hdmi_sync)
    );
    // Decode in the source clock first, so CDC mode enables are single-bit
    // registered signals even when several bits of the SW value change.
    always @(posedge I_sys_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_fps60_mode_sys<=0;S_ae_buttons_blocked_sys<=0;
            S_track_enable_async<=0;S_motion_enable_async<=0;S_black_enable_async<=0;
        end else begin
            S_fps60_mode_sys<=(S_effective_switch==4'b0000);
            S_ae_buttons_blocked_sys<=(S_effective_switch==4'b0001 || S_effective_switch==4'b0011 || S_effective_switch==4'b0100 || S_effective_switch==4'b0101);
            S_track_enable_async<=(S_effective_switch==4'b0001 || S_effective_switch==4'b0011 || S_effective_switch==4'b0100);
            S_motion_enable_async<=(S_effective_switch==4'b0010);
            S_black_enable_async<=1'b0;
        end
    end
    always @(posedge S_24m_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin S_ae_buttons_blocked_meta<=0;S_ae_buttons_blocked_sync<=0;end
        else begin S_ae_buttons_blocked_meta<=S_ae_buttons_bridge_pll;S_ae_buttons_blocked_sync<=S_ae_buttons_blocked_meta;end
    end
    always @(posedge S_100m_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin S_fps60_bridge_pll<=0;S_ae_buttons_bridge_pll<=0;end
        else begin S_fps60_bridge_pll<=S_fps60_mode_sys;S_ae_buttons_bridge_pll<=S_ae_buttons_blocked_sys;end
    end
    // END V32 SWITCH ROUTING
    always @(posedge S_24m_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_fps60_switch_meta <= 1'b0;
            S_fps60_switch_sync <= 1'b0;
        end
        else begin
            S_fps60_switch_meta <= S_fps60_bridge_pll;
            S_fps60_switch_sync <= S_fps60_switch_meta;
        end
    end

    wire S_color_key_dec_physical,S_color_key_inc_physical,S_algo_key_dec_physical,S_algo_key_inc_physical;

assign O_effective_switch=S_effective_switch;assign O_switch_hdmi=S_switch_hdmi_sync;
assign O_segment_n=S_mode_segment_n;assign O_digit_n=S_mode_digit_n;
assign O_track=S_track_enable_async;assign O_motion=S_motion_enable_async;assign O_black=S_black_enable_async;
assign O_fps60=S_fps60_switch_sync;assign O_ae_blocked=S_ae_buttons_blocked_sync;
endmodule
module v34_mux_fixture(input axi4s_video_aclk,I_rst_n,input [3:0] I_algo_mode,input [4:0] frame_starts,output [127:0] O_tdata,output O_tvalid,O_tuser,O_tlast);
reg [3:0] algo_mode_active;wire algo_mode_pending;wire edge_frame_red=I_algo_mode==4'd5;
wire switch_to_edge,select_edge;
wire switch_to_gray,select_gray;
wire switch_to_binary,select_binary;
wire switch_to_histogram,select_histogram;
wire switch_to_normal,select_normal;
wire [127:0] normal_O_tdata_128=128'd0;wire normal_O_tuser_128=frame_starts[0],normal_O_tvalid_128=1'b1;
wire [127:0] edge_O_tdata_128=128'd1;wire edge_O_tuser_128=frame_starts[1],edge_O_tvalid_128=1'b1;
wire [127:0] gray_O_tdata_128=128'd2;wire gray_O_tuser_128=frame_starts[2],gray_O_tvalid_128=1'b1;
wire [127:0] binary_O_tdata_128=128'd3;wire binary_O_tuser_128=frame_starts[3],binary_O_tvalid_128=1'b1;
wire [127:0] histogram_data_128=128'd4;wire histogram_user_128=frame_starts[4],histogram_valid_128=1'b1;
wire edge_O_tlast=1'b1,histogram_chart_last=1'b1,awb_O_tlast=1'b1;
    assign algo_mode_pending = (I_algo_mode != algo_mode_active);
    assign switch_to_edge=algo_mode_pending && (I_algo_mode==4'd1 || I_algo_mode==4'd5) &&
        (edge_frame_red==(I_algo_mode==4'd5)) && edge_O_tuser_128;
    assign switch_to_gray=algo_mode_pending && I_algo_mode==4'd2 && gray_O_tuser_128;
    assign switch_to_binary=algo_mode_pending && I_algo_mode==4'd3 && binary_O_tuser_128;
    assign switch_to_histogram=algo_mode_pending && I_algo_mode==4'd4 && histogram_user_128;
    assign switch_to_normal=algo_mode_pending && (I_algo_mode==0 || I_algo_mode>5) && normal_O_tuser_128;
    assign select_edge=switch_to_edge ? 1'b1 :
        (switch_to_gray || switch_to_binary || switch_to_histogram || switch_to_normal) ? 1'b0 : (algo_mode_active==4'd1 || algo_mode_active==4'd5);
    assign select_gray=switch_to_gray ? 1'b1 :
        (switch_to_edge || switch_to_binary || switch_to_histogram || switch_to_normal) ? 1'b0 : algo_mode_active==4'd2;
    assign select_binary=switch_to_binary ? 1'b1 :
        (switch_to_edge || switch_to_gray || switch_to_histogram || switch_to_normal) ? 1'b0 : algo_mode_active==4'd3;
    assign select_histogram=switch_to_histogram ? 1'b1 :
        (switch_to_edge || switch_to_gray || switch_to_binary || switch_to_normal) ? 1'b0 : algo_mode_active==4'd4;
    always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
        if(!I_rst_n) algo_mode_active<=0;
        else if(switch_to_edge || switch_to_gray || switch_to_binary || switch_to_histogram || switch_to_normal) algo_mode_active<=I_algo_mode;
    end
    assign O_tdata=select_edge ? edge_O_tdata_128 : select_gray ? gray_O_tdata_128 :
                   select_binary ? binary_O_tdata_128 : select_histogram ? histogram_data_128 : normal_O_tdata_128;
    assign O_tlast=select_edge ? edge_O_tlast : select_histogram ? histogram_chart_last : awb_O_tlast;
    assign O_tuser=select_edge ? edge_O_tuser_128 : select_gray ? gray_O_tuser_128 :
                   select_binary ? binary_O_tuser_128 : select_histogram ? histogram_user_128 : normal_O_tuser_128;
    assign O_tvalid=select_edge ? edge_O_tvalid_128 : select_gray ? gray_O_tvalid_128 :
                    select_binary ? binary_O_tvalid_128 : select_histogram ? histogram_valid_128 : normal_O_tvalid_128;


endmodule
module v34_histogram_pipeline_fixture(input axi4s_video_aclk,I_rst_n,input [95:0] awb_O_tdata,input awb_O_tvalid,awb_O_tuser,awb_O_tlast,output [127:0] histogram_data_128,output histogram_user_128,histogram_valid_128);
wire [3:0] I_algo_mode=4'd4,algo_mode_active=4'd4;
wire [95:0] histogram_rgb,histogram_chart_rgb;
wire histogram_valid,histogram_user,histogram_last,histogram_chart_valid,histogram_chart_user,histogram_chart_last;
wire histogram_bin_valid,histogram_done;wire [7:0] histogram_bin_index;
wire [17:0] histogram_bin_count,histogram_after_count;
    histogram_equalizer4 u_histogram_equalizer4 (
        .I_clk(axi4s_video_aclk), .I_rst_n(I_rst_n),
        .I_enable((I_algo_mode==3'd4) || (algo_mode_active==3'd4)),
        .I_valid(awb_O_tvalid), .I_user(awb_O_tuser), .I_last(awb_O_tlast),
        .I_rgb(awb_O_tdata), .O_rgb(histogram_rgb),
        .O_valid(histogram_valid), .O_user(histogram_user), .O_last(histogram_last),
        .O_bin_valid(histogram_bin_valid), .O_bin_index(histogram_bin_index),
        .O_bin_count(histogram_bin_count), .O_hist_done(histogram_done),
        .O_after_count(histogram_after_count)
    );
    live_histogram_overlay4 u_live_histogram_overlay4 (
        .I_clk(axi4s_video_aclk), .I_rst_n(I_rst_n),
        .I_enable((I_algo_mode==3'd4) || (algo_mode_active==3'd4)),
        .I_valid(histogram_valid), .I_user(histogram_user), .I_last(histogram_last),
        .I_rgb(histogram_rgb), .O_rgb(histogram_chart_rgb),
        .O_valid(histogram_chart_valid), .O_user(histogram_chart_user), .O_last(histogram_chart_last),
        .I_bin_valid(histogram_bin_valid), .I_bin_index(histogram_bin_index),
        .I_bin_count(histogram_bin_count), .I_hist_done(histogram_done),
        .I_after_count(histogram_after_count)
    );
    data_96bit_to_128bit u_histogram_data_96bit_to_128bit (
        .I_clk(axi4s_video_aclk), .I_rst_n(I_rst_n),
        .I_96b_frame_start(histogram_chart_user), .I_96b_valid(histogram_chart_valid),
        .I_96b_data(histogram_chart_rgb), .O_128b_frame_start(histogram_user_128),
        .O_128b_valid(histogram_valid_128), .O_128b_data(histogram_data_128)
    );


endmodule
module v37_edge_pipeline_fixture(input axi4s_video_aclk,I_rst_n,input [3:0] I_algo_mode,input [95:0] awb_O_tdata,input awb_O_tvalid,awb_O_tuser,awb_O_tlast,output [127:0] edge_O_tdata_128,output edge_O_tvalid_128,edge_O_tuser_128);
reg edge_frame_red;wire awb_O_tready=1'b1;wire [95:0] edge_O_tdata;wire edge_O_tlast,edge_O_tuser,edge_O_tvalid,edge_O_tready;
edge_detect_96 #(
    .IMG_WIDTH (1280),
    .IMG_HEIGHT(720),
    .EDGE_TH   (11'd80)
) u_edge_detect_96 (
    .I_clk   (axi4s_video_aclk),
    .I_rst_n (I_rst_n),
    .I_tlast (awb_O_tlast),
    .I_tuser (awb_O_tuser),
    .I_tdata (awb_O_tdata),
    .I_tvalid(awb_O_tvalid),
    .I_tready(awb_O_tready),
    .O_tlast (edge_O_tlast),
    .O_tuser (edge_O_tuser),
    .O_tdata (edge_O_tdata),
    .O_tvalid(edge_O_tvalid),
    .O_tready(edge_O_tready)
);

    // BEGIN V37 SHARED EDGE PAINT
    reg [95:0] awb_edge_aligned;
    always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
        if(!I_rst_n) begin awb_edge_aligned<=0;edge_frame_red<=0;end
        else begin
            awb_edge_aligned<=awb_O_tdata;
            if(awb_O_tvalid && awb_O_tuser) edge_frame_red<=I_algo_mode==4'd5;
        end
    end
    wire [95:0] edge_painted_data;
    genvar edge_pixel;
    generate for(edge_pixel=0;edge_pixel<4;edge_pixel=edge_pixel+1) begin: paint_edges
        assign edge_painted_data[edge_pixel*24+:24]=!edge_frame_red ? edge_O_tdata[edge_pixel*24+:24] :
            (|edge_O_tdata[edge_pixel*24+:24]) ? 24'hff0000 : awb_edge_aligned[edge_pixel*24+:24];
    end endgenerate
    // END V37 SHARED EDGE PAINT

    data_96bit_to_128bit u_edge_data_96bit_to_128bit(
        .I_clk              ( axi4s_video_aclk  ),
        .I_rst_n            ( I_rst_n           ),
	
        .I_96b_frame_start  ( edge_O_tuser	    ),
        .I_96b_valid        ( edge_O_tvalid 		),
        .I_96b_data         ( edge_painted_data	),
	
        .O_128b_frame_start ( edge_O_tuser_128  	),
        .O_128b_valid       ( edge_O_tvalid_128 	),
        .O_128b_data        ( edge_O_tdata_128  	)
    );


endmodule
module v38_remote_fixture(input I_sys_clk,S_100m_clk,S_hdmi_pixel_clk,S_24m_clk,S_rst_n,S_hdmi_rst_n,I_uart_rx,input [3:0] I_switch,physical_keys);
reg S_track_enable_async,S_motion_enable_async,S_black_enable_async,S_fps60_switch_meta,S_fps60_switch_sync;
reg [3:0] S_algo_mode;reg [2:0] S_track_color;reg [1:0] S_track_shape;reg S_learn_prepare,S_learn_start;
wire [3:0] S_switch_hdmi_sync,S_servo_state;wire [7:0] S_mode_segment_n,S_mode_digit_n;
wire [1:0] S_label_result_hdmi;wire [11:0] S_pan_pulse_us,S_tilt_pulse_us;
wire S_servo_measure_update=0,S_servo_measure_valid=0,S_servo_measure_large=0;wire signed [12:0] S_servo_measure_dx=0,S_servo_measure_dy=0;
wire O_servo_pan_pwm,O_servo_tilt_pwm,S_servo_buzzer_n;
// BEGIN V32 SWITCH ROUTING
    wire [3:0] S_effective_switch;
    wire [11:0] S_uart_action_data;
    wire S_uart_action_toggle,S_remote_valid,S_remote_long;
    wire [1:0] S_remote_kind;
    wire [3:0] S_remote_value;
    reg [11:0] S_uart_action_bridge;
    reg S_uart_toggle_bridge;
    reg [3:0] S_uart_mode_bridge;
    wire [3:0] S_uart_mode_cam;
    wire S_remote_cam_valid,S_remote_cam_long;
    wire [1:0] S_remote_cam_kind;
    wire [3:0] S_remote_cam_value;
    reg [3:0] S_context_keys;
    reg S_scene_valid,S_scene_run;
    wire S_servo_context=S_remote_valid && S_remote_kind==3 &&
        (S_switch_hdmi_sync==3 || S_switch_hdmi_sync==4);
    wire [3:0] S_remote_keys=(S_remote_valid && S_remote_kind==1 && !S_remote_long ? S_remote_value:4'd0)|S_context_keys;
    // One destination clock qualifies servo mode before a contextual key,
    // or commits target colour/shape before arming an absolute scene.
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin S_context_keys<=0;S_scene_valid<=0;S_scene_run<=0;end
        else begin
            S_context_keys<=S_remote_valid && S_remote_kind==3 && !S_remote_long &&
                S_switch_hdmi_sync!=5 ? S_remote_value:4'd0;
            S_scene_valid<=S_remote_valid && S_remote_kind==0 && S_switch_hdmi_sync==3;
            S_scene_run<=S_remote_long;
        end
    end
    reg [2:0] S_label_remote_action;
    wire S_remote_ae_dec=S_remote_cam_valid && (S_remote_cam_kind==1 || S_remote_cam_kind==3) && !S_remote_cam_long &&
        (S_uart_mode_cam==0 || S_uart_mode_cam==2) && S_remote_cam_value[0];
    wire S_remote_ae_inc=S_remote_cam_valid && (S_remote_cam_kind==1 || S_remote_cam_kind==3) && !S_remote_cam_long &&
        (S_uart_mode_cam==0 || S_uart_mode_cam==2) && S_remote_cam_value[1];
    uart_action_bridge u_remote_hdmi(.I_clk(S_hdmi_pixel_clk),.I_rst_n(S_hdmi_rst_n),
        .I_mode(S_switch_hdmi_sync),.I_data(S_uart_action_data),.I_toggle(S_uart_action_toggle),
        .O_valid(S_remote_valid),.O_kind(S_remote_kind),.O_value(S_remote_value),.O_long(S_remote_long));
    always @(posedge S_100m_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin S_uart_action_bridge<=0;S_uart_toggle_bridge<=0;S_uart_mode_bridge<=0;end
        else begin S_uart_action_bridge<=S_uart_action_data;S_uart_toggle_bridge<=S_uart_action_toggle;S_uart_mode_bridge<=S_effective_switch;end
    end
    switch_state_sync u_remote_mode_cam(.I_clk(S_24m_clk),.I_rst_n(S_rst_n),.I_state(S_uart_mode_bridge),.O_state(S_uart_mode_cam));
    uart_action_bridge u_remote_cam(.I_clk(S_24m_clk),.I_rst_n(S_rst_n),
        .I_mode(S_uart_mode_cam),.I_data(S_uart_action_bridge),.I_toggle(S_uart_toggle_bridge),
        .O_valid(S_remote_cam_valid),.O_kind(S_remote_cam_kind),.O_value(S_remote_cam_value),.O_long(S_remote_cam_long));
    always @* begin
        S_label_remote_action=0;
        if(S_remote_valid && S_switch_hdmi_sync==5) begin
            if(S_remote_kind==2) S_label_remote_action=S_remote_value[2:0];
            else if(S_remote_kind==1 || S_remote_kind==3) begin
                if(S_remote_long) S_label_remote_action=5;
                else if(S_remote_value[3]) S_label_remote_action=1;
                else if(S_remote_value[1]) S_label_remote_action=2;
                else if(S_remote_value[0]) S_label_remote_action=3;
                else if(S_remote_value[2]) S_label_remote_action=4;
            end
        end
    end
    reg S_fps60_mode_sys,S_ae_buttons_blocked_sys;
    reg S_fps60_bridge_pll,S_ae_buttons_bridge_pll;
    reg S_ae_buttons_blocked_meta,S_ae_buttons_blocked_sync;
    uart_switch_control u_uart_switch_control (
        .I_clk(I_sys_clk),.I_rst_n(S_rst_n),.I_rx(I_uart_rx),
        .I_switch(I_switch),.O_switch(S_effective_switch),
        .O_action_data(S_uart_action_data),.O_action_toggle(S_uart_action_toggle)
    );
    switch_state_display u_switch_state_display (
        .I_clk(S_hdmi_pixel_clk),.I_rst_n(S_hdmi_rst_n),.I_state(S_switch_hdmi_sync),
        .I_result(S_label_result_hdmi),
        .O_segment_n(S_mode_segment_n),.O_digit_n(S_mode_digit_n)
    );
    switch_state_sync u_switch_state_sync (
        .I_clk(S_hdmi_pixel_clk),.I_rst_n(S_hdmi_rst_n),
        .I_state(S_effective_switch),.O_state(S_switch_hdmi_sync)
    );
    // Decode in the source clock first, so CDC mode enables are single-bit
    // registered signals even when several bits of the SW value change.
    always @(posedge I_sys_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_fps60_mode_sys<=0;S_ae_buttons_blocked_sys<=0;
            S_track_enable_async<=0;S_motion_enable_async<=0;S_black_enable_async<=0;
        end else begin
            S_fps60_mode_sys<=(S_effective_switch==4'b0000);
            S_ae_buttons_blocked_sys<=(S_effective_switch==4'b0001 || S_effective_switch==4'b0011 || S_effective_switch==4'b0100 || S_effective_switch==4'b0101);
            S_track_enable_async<=(S_effective_switch==4'b0001 || S_effective_switch==4'b0011 || S_effective_switch==4'b0100);
            S_motion_enable_async<=(S_effective_switch==4'b0010);
            S_black_enable_async<=1'b0;
        end
    end
    always @(posedge S_24m_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin S_ae_buttons_blocked_meta<=0;S_ae_buttons_blocked_sync<=0;end
        else begin S_ae_buttons_blocked_meta<=S_ae_buttons_bridge_pll;S_ae_buttons_blocked_sync<=S_ae_buttons_blocked_meta;end
    end
    always @(posedge S_100m_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin S_fps60_bridge_pll<=0;S_ae_buttons_bridge_pll<=0;end
        else begin S_fps60_bridge_pll<=S_fps60_mode_sys;S_ae_buttons_bridge_pll<=S_ae_buttons_blocked_sys;end
    end
    // END V32 SWITCH ROUTING
    always @(posedge S_24m_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_fps60_switch_meta <= 1'b0;
            S_fps60_switch_sync <= 1'b0;
        end
        else begin
            S_fps60_switch_meta <= S_fps60_bridge_pll;
            S_fps60_switch_sync <= S_fps60_switch_meta;
        end
    end

    wire S_color_key_dec_physical,S_color_key_inc_physical,S_algo_key_dec_physical,S_algo_key_inc_physical;

wire S_color_key_dec=physical_keys[0]|S_remote_keys[0],S_color_key_inc=physical_keys[1]|S_remote_keys[1];
wire S_algo_key_dec=physical_keys[2]|S_remote_keys[2],S_algo_key_inc=physical_keys[3]|S_remote_keys[3];
// BEGIN V25 KEY CONTROL (also compiled directly by the control regression).
    wire [3:0] S_algo_last = 4'd5;
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n)
            S_algo_mode <= 4'd0;
        else if(S_remote_valid && S_remote_kind==2 && S_switch_hdmi_sync==0)
            S_algo_mode<=S_remote_value;
        else if(S_switch_hdmi_sync == 4'b0000) begin
            if(S_algo_mode > S_algo_last)
                S_algo_mode <= 4'd0;
            else if(S_algo_key_dec && !S_algo_key_inc)
                S_algo_mode <= (S_algo_mode == 4'd0) ? S_algo_last : S_algo_mode - 4'd1;
            else if(S_algo_key_inc && !S_algo_key_dec)
                S_algo_mode <= (S_algo_mode == S_algo_last) ? 4'd0 : S_algo_mode + 4'd1;
        end
    end

    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_track_color <= 3'd0;
            S_track_shape <= 2'd1;
        end
        else if(S_remote_valid && S_remote_kind==0 &&
                (S_switch_hdmi_sync==1 || S_switch_hdmi_sync==3)) begin
            S_track_color<=S_remote_value[3:2]==3 ? 3'd5:{1'b0,S_remote_value[3:2]};
            S_track_shape<=S_remote_value[1:0];
        end
        else if(S_switch_hdmi_sync == 4'b0100)
            S_track_color <= 3'd5;
        else if(S_switch_hdmi_sync == 4'b0001 && S_track_color > 3'd2)
            S_track_color <= 3'd0;
        else if((S_switch_hdmi_sync == 4'b0001) ||
                ((S_switch_hdmi_sync == 4'b0011) &&
                 ((S_servo_state == 4'd1) || (S_servo_state == 4'd6)))) begin
            if(S_color_key_dec && !S_color_key_inc)
                S_track_color <= (S_track_color == 3'd5) ? 3'd0 :
                                 (S_track_color == 3'd2) ? ((S_switch_hdmi_sync == 4'd1) ? 3'd0 : 3'd5) : S_track_color + 3'd1;
            else if(S_color_key_inc && !S_color_key_dec)
                S_track_shape <= (S_track_shape == 2'd3) ? 2'd1 : S_track_shape + 2'd1;
        end
    end
    // END V25 KEY CONTROL
    // Learning is controlled by K1/K2 in the servo-centering mode.
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin S_learn_prepare<=0;S_learn_start<=0;end
        else begin
            S_learn_prepare<=0;S_learn_start<=0;
            if(S_switch_hdmi_sync==4'd4) begin
                S_learn_prepare<=S_color_key_dec || (S_remote_valid && S_remote_kind==2 && S_remote_value==3);
                S_learn_start<=(S_color_key_inc && !S_color_key_dec) ||
                    (S_remote_valid && S_remote_kind==2 && S_remote_value==4);
            end
        end
    end


    servo_pan_tracker u_servo_pan_tracker (
        .I_clk          ( S_hdmi_pixel_clk ),
        .I_rst_n        ( S_hdmi_rst_n ),
        .I_mode         ( S_switch_hdmi_sync ),
        .I_zoom_active  ( 1'b0 ),
        .I_color        ( S_track_color ),
        .I_shape        ( S_track_shape ),
        .I_key_dec      ( S_algo_key_dec ),
        .I_key_inc      ( S_algo_key_inc ),
        .I_remote_valid((S_remote_valid && S_remote_kind==2 && (S_switch_hdmi_sync==3 || S_switch_hdmi_sync==4)) || S_scene_valid),
        .I_remote_state(S_scene_valid ? {2'b00,S_scene_run}:S_remote_value[2:0]),
        .I_remote_context(S_servo_context),
        .I_measure_update ( S_servo_measure_update ),
        .I_measure_valid  ( S_servo_measure_valid ),
        .I_measure_large  ( S_servo_measure_large ),
        .I_measure_dx     ( S_servo_measure_dx ),
        .I_measure_dy     ( S_servo_measure_dy ),
        .O_state          ( S_servo_state ),
        .O_pan_pulse_us   ( S_pan_pulse_us ),
        .O_tilt_pulse_us  ( S_tilt_pulse_us ),
        .O_pan_pwm      ( O_servo_pan_pwm ),
        .O_tilt_pwm     ( O_servo_tilt_pwm ),
        .O_buzzer_n     ( S_servo_buzzer_n )
    );


ae_set ae(.I_clk(S_24m_clk),.I_rst(!S_rst_n),.I_btn(2'b11),.I_fps_60(S_fps60_switch_sync),
 .I_frame_luma(8'd96),.I_luma_toggle(1'b0),.I_ae_cfg_done(1'b1),.I_ae_error(1'b0),.I_lock(1'b0),.O_locked(),
 .I_cam_cfg_done(1'b1),.O_ae_req(),.O_ae(),.O_ag(),.O_debug(),.O_debug_toggle(),
 .I_remote_dec(S_remote_ae_dec),.I_remote_inc(S_remote_ae_inc));
wire learned_valid;wire [3:0] learn_status;
target_color_learning learn_engine(.I_clk(S_hdmi_pixel_clk),.I_rst_n(S_hdmi_rst_n),
 .I_selected(S_track_color==5),.I_learn_enable(S_switch_hdmi_sync==4),.I_prepare(S_learn_prepare),.I_start(S_learn_start),
 .I_de(1'b0),.I_x(12'd0),.I_y(12'd0),.I_rgb(24'd0),.I_frame_id(24'd0),.O_valid(learned_valid),
 .O_status(learn_status),.O_rgb(),.O_generation(),.O_mask(),.O_preparing());
label_application lab(.I_clk(S_hdmi_pixel_clk),.I_rst_n(S_hdmi_rst_n),.I_enable(S_switch_hdmi_sync==5),
 .I_de(1'b0),.I_keys_n(4'hf),.I_x(12'd0),.I_y(12'd0),.I_rgb(24'd0),.I_frame_id(24'd0),.I_imaging_locked(1'b1),
 .I_remote_action(S_label_remote_action),.O_imaging_lock(),.O_hit(),.O_color(),.O_buzzer_n(),
 .O_seg_sel(),.O_seg_dig(),.O_display_result(S_label_result_hdmi));
endmodule
