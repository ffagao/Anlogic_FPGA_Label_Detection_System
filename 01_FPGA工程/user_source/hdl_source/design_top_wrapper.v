

module design_top_wrapper (
    input wire        I_sys_clk,
    input wire        I_rst_n,
      
    output wire       O_cam_scl,
    inout  wire       IO_cam_sda,
    output wire       O_cam_24m,
    output wire       O_cam_rst,
      
    inout wire [3:0]  I_button,
    input wire [3:0]  I_switch,
    input wire        I_uart_rx,
    output wire       O_uart_tx,
    output wire [7:0] O_segment_n,
    output wire [7:0] O_digit_n,

    output wire       O_servo_pan_pwm,
    output wire       O_servo_tilt_pwm,
    output wire       O_buzzer_n,
    output wire       O_screen_pwm,
    output wire       O_tmds_ch0_p,
    output wire       O_tmds_ch1_p,
    output wire       O_tmds_ch2_p,
    output wire       O_tmds_clk_p,

    inout wire        IO_rx_clk_pad_n, 
    inout wire        IO_rx_clk_pad_p, 
    inout wire[3:0]   IO_rx_data_pad_n,
    inout wire[3:0]   IO_rx_data_pad_p,

    output wire[12:0] ddr_addr,
    output wire[ 1:0] ddr_ba,
    output wire[ 0:0] ddr_cke,
    output wire[ 0:0] ddr_odt,
    output wire[ 0:0] ddr_cs_n,
    output wire       ddr_ras_n,
    output wire       ddr_cas_n,
    output wire       ddr_we_n,
    output wire[ 0:0] ddr_ck_p,
    output wire[ 0:0] ddr_ck_n,
    inout wire[1:0]   ddr_dm,
    inout wire[15:0]  ddr_dq,
    inout wire[1:0]   ddr_dqs_p,
    inout wire[1:0]   ddr_dqs_n   
);


    wire        	S_100m_clk;
    wire        	S_24m_clk;
    wire        	S_aux_50m_clk;
	wire        	S_10m_clk;
		
	wire        	S_pll_lock;
    wire        	S_rst_n;
	
	wire [15:0] 	S_ae;
    wire [15:0] 	S_ag;
    wire 			S_cam_cfg_done;
    wire 			S_ae_cfg_done;
    wire 			S_ae_req; 

    wire [3:0] S_switch_hdmi_sync;
    reg S_learn_prepare,S_learn_start;
    wire S_label_enable_hdmi=(S_switch_hdmi_sync==4'd5);
    reg S_label_enable_csi_meta,S_label_enable_csi;
    wire S_label_imaging_lock,S_ae_locked,S_color_locked;
    wire [1:0] S_label_result_hdmi;
    wire [1:0] S_label_status_result_hdmi;
    wire [3:0] S_label_status_cause_hdmi;
    wire [23:0] S_label_status_passes_hdmi,S_label_status_fails_hdmi,S_label_status_unknowns_hdmi;
    wire S_barcode_valid_hdmi;
    wire [23:0] S_barcode_order_hdmi,S_barcode_count_hdmi;
    wire S_label_zoom_request_hdmi;
    wire [11:0] S_label_zoom_src_x,S_label_zoom_view_x;
    wire signed [11:0] S_label_zoom_src_y,S_label_zoom_view_y;
    reg S_image_lock_cam_meta,S_image_lock_cam;
    reg S_image_lock_csi_meta,S_image_lock_csi;
    reg S_ae_locked_meta,S_ae_locked_hdmi,S_color_locked_meta,S_color_locked_hdmi;
    wire S_servo_buzzer_n,S_label_buzzer_n;
    wire [7:0] S_mode_segment_n,S_mode_digit_n;
    assign O_segment_n=S_mode_segment_n;
    assign O_digit_n=S_mode_digit_n;
    assign O_buzzer_n=S_label_enable_hdmi ? S_label_buzzer_n : S_servo_buzzer_n;

    wire            S_algo_key_dec;
    wire            S_algo_key_inc;
    wire            S_color_key_dec;
    wire            S_color_key_inc;
    reg             S_fps60_switch_meta;
    reg             S_fps60_switch_sync;
    reg [3:0]       S_algo_mode;
    reg [2:0]       S_track_color; // BLUE, RED, GREEN, CUSTOM (code 5)
    reg [1:0]       S_track_shape; // 1 RECT, 2 CIRCLE, 3 TRIANGLE
    reg [3:0]       S_algo_mode_csi_meta;
    reg [3:0]       S_algo_mode_csi;
    wire            S_servo_measure_update, S_servo_measure_valid, S_servo_measure_large;
    wire signed [12:0] S_servo_measure_dx, S_servo_measure_dy;
    wire [3:0]      S_servo_state;
    wire [11:0]     S_pan_pulse_us, S_tilt_pulse_us;
    wire            S_servo_test_mode;
    reg             S_track_enable_async;
    reg             S_track_enable_csi_meta;
    reg             S_track_enable_csi;
    reg             S_track_enable_hdmi_meta;
    reg             S_track_enable_hdmi;
    reg             S_motion_enable_async;
    reg             S_motion_enable_csi_meta;
    reg             S_motion_enable_csi;
    reg             S_motion_enable_hdmi_meta;
    reg             S_motion_enable_hdmi;
    reg             S_black_enable_async;
    reg             S_black_enable_csi_meta;
    reg             S_black_enable_csi;
    reg             S_black_enable_hdmi_meta;
    reg             S_black_enable_hdmi;

    wire            S_black_valid_csi;
    wire [11:0]     S_black_left_csi;
    wire [11:0]     S_black_right_csi;
    wire [11:0]     S_black_top_csi;
    wire [11:0]     S_black_bottom_csi;
    wire            S_black_toggle_csi;
    reg             S_black_valid_meta_hdmi;
    reg             S_black_valid_sync_hdmi;
    reg [11:0]      S_black_left_meta_hdmi;
    reg [11:0]      S_black_left_sync_hdmi;
    reg [11:0]      S_black_right_meta_hdmi;
    reg [11:0]      S_black_right_sync_hdmi;
    reg [11:0]      S_black_top_meta_hdmi;
    reg [11:0]      S_black_top_sync_hdmi;
    reg [11:0]      S_black_bottom_meta_hdmi;
    reg [11:0]      S_black_bottom_sync_hdmi;
    reg             S_black_toggle_meta_hdmi;
    reg             S_black_toggle_sync_hdmi;
    wire            S_zoom_request_hdmi;
    wire            S_zoom_active_hdmi;

    // Camera-frame counter. Keep the counter in BCD so the HDMI OSD can
    // render it directly without a large binary-to-decimal divider.
    reg [3:0]       S_cap_frame_d0_csi;
    reg [3:0]       S_cap_frame_d1_csi;
    reg [3:0]       S_cap_frame_d2_csi;
    reg [3:0]       S_cap_frame_d3_csi;
    reg [3:0]       S_cap_frame_d4_csi;
    reg [3:0]       S_cap_frame_d5_csi;
    reg             S_cap_frame_toggle_csi;
    wire [23:0]     S_cap_frame_bcd_csi;
    reg [23:0]      S_cap_frame_bcd_meta;
    reg [23:0]      S_cap_frame_bcd_sync;
    reg             S_cap_frame_toggle_meta;
    reg             S_cap_frame_toggle_sync;
    reg             S_cap_frame_toggle_sync_d;
    reg [23:0]      S_cap_frame_bcd_hdmi;

    // Actual camera FPS, measured over a one-second window using the
    // board's 50 MHz system-clock reference.
    reg             S_fps_frame_toggle_meta_sys;
    reg             S_fps_frame_toggle_sync_sys;
    reg             S_fps_frame_toggle_sync_d_sys;
    reg [25:0]      S_fps_second_count_sys;
    reg [3:0]       S_fps_work_d0_sys;
    reg [3:0]       S_fps_work_d1_sys;
    reg [7:0]       S_fps_bcd_sys;
    reg             S_fps_update_toggle_sys;
    reg [7:0]       S_fps_bcd_meta_hdmi;
    reg [7:0]       S_fps_bcd_sync_hdmi;
    reg             S_fps_update_toggle_meta_hdmi;
    reg             S_fps_update_toggle_sync_hdmi;
    reg             S_fps_update_toggle_sync_d_hdmi;
    reg [7:0]       S_fps_bcd_hdmi;

    // Camera-frame identity selected by the DDR display reader.
    wire [23:0]     S_video_out_frame_bcd_ddr;
    wire [23:0]     S_display_frame_bcd_ddr;
    wire            S_display_frame_toggle_ddr;
    reg [23:0]      S_display_frame_bcd_meta_hdmi;
    reg [23:0]      S_display_frame_bcd_sync_hdmi;
    reg             S_display_frame_toggle_meta_hdmi;
    reg             S_display_frame_toggle_sync_hdmi;
    reg             S_display_frame_toggle_sync_d_hdmi;
    reg [23:0]      S_display_frame_bcd_hdmi;
    wire [7:0]      S_delay_frames_bcd_hdmi;

    function [7:0] F_bcd2_increment;
        input [7:0] I_bcd;
        begin
            if(I_bcd[3:0] == 4'd9) begin
                F_bcd2_increment[3:0] = 4'd0;
                if(I_bcd[7:4] == 4'd9)
                    F_bcd2_increment[7:4] = 4'd0;
                else
                    F_bcd2_increment[7:4] = I_bcd[7:4] + 4'd1;
            end
            else begin
                F_bcd2_increment[3:0] = I_bcd[3:0] + 4'd1;
                F_bcd2_increment[7:4] = I_bcd[7:4];
            end
        end
    endfunction

    // Subtract the low two decimal digits modulo 100.  The physical video
    // pipeline is only a few frames deep, so two digits fully cover the useful
    // delay range while also handling the 99-to-00 counter rollover.
    function [7:0] F_bcd2_sub_mod100;
        input [7:0] I_newer;
        input [7:0] I_older;
        reg [3:0] S_ones;
        reg [3:0] S_tens_base;
        begin
            if(I_newer[3:0] >= I_older[3:0]) begin
                S_ones = I_newer[3:0] - I_older[3:0];
                S_tens_base = I_newer[7:4];
            end
            else begin
                S_ones = I_newer[3:0] + 4'd10 - I_older[3:0];
                if(I_newer[7:4] == 4'd0)
                    S_tens_base = 4'd9;
                else
                    S_tens_base = I_newer[7:4] - 4'd1;
            end

            if(S_tens_base >= I_older[7:4])
                F_bcd2_sub_mod100[7:4] = S_tens_base - I_older[7:4];
            else
                F_bcd2_sub_mod100[7:4] = S_tens_base + 4'd10 - I_older[7:4];
            F_bcd2_sub_mod100[3:0] = S_ones;
        end
    endfunction
	
	wire        	S_csi_rx_clk;  
    wire        	S_hs_rx_valid;  
    wire[15:0]  	S_hs_rx_data;   
	wire[1:0]   	S_lane_error;
	
	wire        	S_csi_frame_start;       
	wire        	S_csi_frame_end;         
	wire        	S_csi_valid;             
	wire[31:0]  	S_csi_data;  
		
	wire        	S_raw10_frame_start; 
	wire        	S_raw10_frame_end;   
	wire        	S_raw10_valid;       
	wire [39:0] 	S_raw10_data;
		
	wire 			S_axis_tlast;  
	wire 			S_axis_tuser;  
	wire [39:0]		S_axis_tdata;  
	wire 			S_axis_tvalid; 
	
	wire [39:0]		S_raw_tdata ;
	wire			S_raw_tlast ;
	wire 			S_raw_tvalid;
	wire 			S_raw_tuser ;
	
	wire			S_ISP_O_tready;
	wire [127:0]	S_ISP_O_tdata ;
	wire 			S_ISP_O_tlast ;
	wire 			S_ISP_O_tuser ;
	wire 			S_ISP_O_tvalid; 
	wire [71:0] S_ae_debug;
    wire S_ae_debug_toggle;
    wire S_ae_error;
	wire [7:0]    S_frame_luma;
	wire          S_luma_toggle;
	

    wire        S_ddr_clk;
    wire        S_hdmi_pixel_clk;
    wire        S_hdmi_serial_clk;
    wire        S_hdmi_rst_n;
    wire        S_video_out_rst_n;


    wire        S_vi_128b_frame_start;
    wire        S_vi_128b_valid;      
    wire[127:0] S_vi_128b_data;    
    
    wire        S_video_out_rd_busy;
    wire        S_video_in_wr_busy; 
    wire[1:0]   S_video_out_rp;     

    wire        S_ddr_user_wr_en;       
    wire        S_ddr_user_rd_en;       
    wire[24:0]  S_ddr_user_addr;        
    wire[127:0] S_ddr_user_wr_data;     
    wire        S_ddr_user_ready;       
    wire        S_ddr_user_rd_valid;    
    wire[127:0] S_ddr_user_rd_data;     

    wire        S_vi_ddr_wr_en;   
    wire[24:0]  S_vi_ddr_wr_addr; 
    wire[127:0] S_vi_ddr_wr_data;
    wire        S_vi_ddr_wr_ready;
    wire[9:0]   S_diag_in_line,S_diag_spatial_line;
    wire[8:0]   S_diag_pack_line,S_diag_fifo_level,S_diag_burst_count;
    wire[17:0]  S_diag_in_frame,S_diag_spatial_frame,S_diag_pack_frame,S_diag_ddr_frame;
    wire[2:0]   S_diag_line_error,S_diag_frame_error;
    wire        S_diag_burst_active;
    reg [9:0]   S_diag_in_line_meta,S_diag_in_line_sync,S_diag_spatial_line_meta,S_diag_spatial_line_sync;
    reg [8:0]   S_diag_pack_line_meta,S_diag_pack_line_sync,S_diag_fifo_level_meta,S_diag_fifo_level_sync;
    reg [8:0]   S_diag_burst_count_meta,S_diag_burst_count_sync;
    reg [17:0]  S_diag_in_frame_meta,S_diag_in_frame_sync,S_diag_spatial_frame_meta,S_diag_spatial_frame_sync;
    reg [17:0]  S_diag_pack_frame_meta,S_diag_pack_frame_sync,S_diag_ddr_frame_meta,S_diag_ddr_frame_sync;
    reg [2:0]   S_diag_line_error_meta,S_diag_line_error_sync,S_diag_frame_error_meta,S_diag_frame_error_sync;
    reg [1:0]   S_diag_burst_active_sync;

    wire        S_vo_ddr_rd_en;   
    wire[24:0]  S_vo_ddr_rd_addr; 
    wire        S_vo_ddr_rd_ready;
    wire        S_vo_dbg_fifo_rst;
    wire        S_vo_dbg_ddr_rd_valid;
    wire        S_vo_dbg_fifo_rd_en;
    wire        S_vo_dbg_fifo_empty;

    wire        S_init_calib_complete; 
    wire[24:0]  S_mc_app_addr;          
    wire[2:0]   S_mc_app_cmd;           
    wire        S_mc_app_en;            
    wire[127:0] S_mc_app_wdf_data;      
    wire        S_mc_app_wdf_end;       
    wire[15:0]  S_mc_app_wdf_mask;      
    wire        S_mc_app_wdf_wren;      
    wire[127:0] S_mc_app_rd_data;       
    wire        S_mc_app_rd_data_end;   
    wire        S_mc_app_rd_data_valid; 
    wire        S_mc_app_rdy;           
    wire        S_mc_app_wdf_rdy;       
    wire        S_mc_dbg_fifo_afull;
    wire        S_mc_dbg_app_rdy;
    wire        S_mc_dbg_wdf_rdy;
    wire        S_mc_dbg_cmd_pop;

    wire        S_hdmi_vsync;
    wire        S_hdmi_hsync;
    wire        S_hdmi_de;
    wire        S_hdmi_user;
    wire        S_hdmi_last;
    wire        S_video_out_vsync;
    wire        S_hdmi_window_rd_en;
    wire        S_hdmi_out_vsync;
    wire        S_hdmi_out_hsync;
    wire        S_hdmi_out_de;
    wire[23:0]  S_hdmi_out_data;

    wire[23:0]  S_video_rd_data;
    reg         S_dbg_raw_seen;
    reg         S_dbg_isp_seen;
    reg         S_dbg_ddr_wr_seen;
    reg         S_dbg_ddr_rd_seen;
    reg         S_dbg_cam_cfg_seen;
    reg         S_dbg_hs_seen;
    reg         S_dbg_csi_seen;
    reg         S_dbg_raw10_seen;
    reg         S_dbg_isp_fs_seen;
    reg         S_dbg_isp_valid_seen;
    reg         S_dbg_ddr_req_seen;
    reg         S_dbg_ddr_ready_seen;
    reg [1:0]   S_dbg_raw_seen_sync;
    reg [1:0]   S_dbg_isp_seen_sync;
    reg [1:0]   S_dbg_ddr_wr_seen_sync;
    reg [1:0]   S_dbg_ddr_rd_seen_sync;
    reg [1:0]   S_dbg_cam_cfg_seen_sync;
    reg [1:0]   S_dbg_hs_seen_sync;
    reg [1:0]   S_dbg_csi_seen_sync;
    reg [1:0]   S_dbg_raw10_seen_sync;
    reg [1:0]   S_dbg_isp_fs_seen_sync;
    reg [1:0]   S_dbg_isp_valid_seen_sync;
    reg [1:0]   S_dbg_ddr_req_seen_sync;
    reg [1:0]   S_dbg_ddr_ready_seen_sync;
    reg         S_dbg_video_nonzero_seen;
    reg         S_dbg_rd_req_seen;
    reg         S_dbg_rd_valid_seen;
    reg         S_dbg_rd_nonzero_seen;
    reg [1:0]   S_dbg_rd_req_seen_sync;
    reg [1:0]   S_dbg_rd_valid_seen_sync;
    reg [1:0]   S_dbg_rd_nonzero_seen_sync;
    reg         S_dbg_mc_init_seen;
    reg         S_dbg_mc_app_rdy_seen;
    reg         S_dbg_mc_wdf_rdy_seen;
    reg         S_dbg_mc_cmd_pop_seen;
    reg [1:0]   S_dbg_mc_init_seen_sync;
    reg [1:0]   S_dbg_mc_app_rdy_seen_sync;
    reg [1:0]   S_dbg_mc_wdf_rdy_seen_sync;
    reg [1:0]   S_dbg_mc_cmd_pop_seen_sync;
    wire[3:0]   S_hdmi_debug_status;
    wire        S_lane_error_any;


    always @(posedge S_24m_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin S_image_lock_cam_meta<=0;S_image_lock_cam<=0;end
        else begin S_image_lock_cam_meta<=S_label_imaging_lock;S_image_lock_cam<=S_image_lock_cam_meta;end
    end
    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_image_lock_csi_meta<=0;S_image_lock_csi<=0;
            S_label_enable_csi_meta<=0;S_label_enable_csi<=0;
        end else begin
            S_image_lock_csi_meta<=S_label_imaging_lock;S_image_lock_csi<=S_image_lock_csi_meta;
            S_label_enable_csi_meta<=S_label_enable_hdmi;S_label_enable_csi<=S_label_enable_csi_meta;
        end
    end
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_ae_locked_meta<=0;S_ae_locked_hdmi<=0;S_color_locked_meta<=0;S_color_locked_hdmi<=0;
        end else begin
            S_ae_locked_meta<=S_ae_locked;S_ae_locked_hdmi<=S_ae_locked_meta;
            S_color_locked_meta<=S_color_locked;S_color_locked_hdmi<=S_color_locked_meta;
        end
    end

    assign O_screen_pwm = 1'b1;
    assign S_video_out_vsync = ~S_hdmi_vsync;
	
	
    assign S_rst_n 		= S_pll_lock;
    assign S_hdmi_rst_n = S_pll_lock;

    assign S_cap_frame_bcd_csi = {S_cap_frame_d5_csi,
                                  S_cap_frame_d4_csi,
                                  S_cap_frame_d3_csi,
                                  S_cap_frame_d2_csi,
                                  S_cap_frame_d1_csi,
                                  S_cap_frame_d0_csi};
    assign S_delay_frames_bcd_hdmi =
        F_bcd2_sub_mod100(S_cap_frame_bcd_hdmi[7:0],
                          S_display_frame_bcd_hdmi[7:0]);

    // Count frames at the camera/raw input. The six decimal digits wrap
    // naturally from 999999 back to 000000.
    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_cap_frame_d0_csi     <= 4'd0;
            S_cap_frame_d1_csi     <= 4'd0;
            S_cap_frame_d2_csi     <= 4'd0;
            S_cap_frame_d3_csi     <= 4'd0;
            S_cap_frame_d4_csi     <= 4'd0;
            S_cap_frame_d5_csi     <= 4'd0;
            S_cap_frame_toggle_csi <= 1'b0;
        end
        else if(S_raw10_frame_start) begin
            S_cap_frame_toggle_csi <= ~S_cap_frame_toggle_csi;
            if(S_cap_frame_d0_csi == 4'd9) begin
                S_cap_frame_d0_csi <= 4'd0;
                if(S_cap_frame_d1_csi == 4'd9) begin
                    S_cap_frame_d1_csi <= 4'd0;
                    if(S_cap_frame_d2_csi == 4'd9) begin
                        S_cap_frame_d2_csi <= 4'd0;
                        if(S_cap_frame_d3_csi == 4'd9) begin
                            S_cap_frame_d3_csi <= 4'd0;
                            if(S_cap_frame_d4_csi == 4'd9) begin
                                S_cap_frame_d4_csi <= 4'd0;
                                if(S_cap_frame_d5_csi == 4'd9)
                                    S_cap_frame_d5_csi <= 4'd0;
                                else
                                    S_cap_frame_d5_csi <= S_cap_frame_d5_csi + 4'd1;
                            end
                            else
                                S_cap_frame_d4_csi <= S_cap_frame_d4_csi + 4'd1;
                        end
                        else
                            S_cap_frame_d3_csi <= S_cap_frame_d3_csi + 4'd1;
                    end
                    else
                        S_cap_frame_d2_csi <= S_cap_frame_d2_csi + 4'd1;
                end
                else
                    S_cap_frame_d1_csi <= S_cap_frame_d1_csi + 4'd1;
            end
            else
                S_cap_frame_d0_csi <= S_cap_frame_d0_csi + 4'd1;
        end
    end

    // The BCD bus remains stable for a complete camera frame. Delay the
    // toggle one extra HDMI clock before accepting the synchronized bus.
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_cap_frame_bcd_meta      <= 24'd0;
            S_cap_frame_bcd_sync      <= 24'd0;
            S_cap_frame_toggle_meta   <= 1'b0;
            S_cap_frame_toggle_sync   <= 1'b0;
            S_cap_frame_toggle_sync_d <= 1'b0;
            S_cap_frame_bcd_hdmi      <= 24'd0;
        end
        else begin
            S_cap_frame_bcd_meta      <= S_cap_frame_bcd_csi;
            S_cap_frame_bcd_sync      <= S_cap_frame_bcd_meta;
            S_cap_frame_toggle_meta   <= S_cap_frame_toggle_csi;
            S_cap_frame_toggle_sync   <= S_cap_frame_toggle_meta;
            S_cap_frame_toggle_sync_d <= S_cap_frame_toggle_sync;
            if(S_cap_frame_toggle_sync != S_cap_frame_toggle_sync_d)
                S_cap_frame_bcd_hdmi <= S_cap_frame_bcd_sync;
        end
    end

    // Transfer the identity of the camera frame actually selected for HDMI.
    // The toggle changes on each display frame and allows the multi-bit BCD bus
    // to settle before it is committed to the OSD copy.
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_display_frame_bcd_meta_hdmi      <= 24'd0;
            S_display_frame_bcd_sync_hdmi      <= 24'd0;
            S_display_frame_toggle_meta_hdmi   <= 1'b0;
            S_display_frame_toggle_sync_hdmi   <= 1'b0;
            S_display_frame_toggle_sync_d_hdmi <= 1'b0;
            S_display_frame_bcd_hdmi           <= 24'd0;
        end
        else begin
            S_display_frame_bcd_meta_hdmi      <= S_display_frame_bcd_ddr;
            S_display_frame_bcd_sync_hdmi      <= S_display_frame_bcd_meta_hdmi;
            S_display_frame_toggle_meta_hdmi   <= S_display_frame_toggle_ddr;
            S_display_frame_toggle_sync_hdmi   <= S_display_frame_toggle_meta_hdmi;
            S_display_frame_toggle_sync_d_hdmi <= S_display_frame_toggle_sync_hdmi;
            if(S_display_frame_toggle_sync_hdmi !=
               S_display_frame_toggle_sync_d_hdmi)
                S_display_frame_bcd_hdmi <= S_display_frame_bcd_sync_hdmi;
        end
    end

    // Synchronize the per-frame toggle into the 50 MHz reference domain,
    // then count the number of received camera frames in each exact second.
    always @(posedge I_sys_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_fps_frame_toggle_meta_sys   <= 1'b0;
            S_fps_frame_toggle_sync_sys   <= 1'b0;
            S_fps_frame_toggle_sync_d_sys <= 1'b0;
            S_fps_second_count_sys        <= 26'd0;
            S_fps_work_d0_sys             <= 4'd0;
            S_fps_work_d1_sys             <= 4'd0;
            S_fps_bcd_sys                 <= 8'd0;
            S_fps_update_toggle_sys       <= 1'b0;
        end
        else begin
            S_fps_frame_toggle_meta_sys   <= S_cap_frame_toggle_csi;
            S_fps_frame_toggle_sync_sys   <= S_fps_frame_toggle_meta_sys;
            S_fps_frame_toggle_sync_d_sys <= S_fps_frame_toggle_sync_sys;

            if(S_fps_second_count_sys == 26'd49_999_999) begin
                S_fps_second_count_sys  <= 26'd0;
                S_fps_update_toggle_sys <= ~S_fps_update_toggle_sys;
                if(S_fps_frame_toggle_sync_sys != S_fps_frame_toggle_sync_d_sys)
                    S_fps_bcd_sys <= F_bcd2_increment({S_fps_work_d1_sys,
                                                       S_fps_work_d0_sys});
                else
                    S_fps_bcd_sys <= {S_fps_work_d1_sys, S_fps_work_d0_sys};
                S_fps_work_d0_sys <= 4'd0;
                S_fps_work_d1_sys <= 4'd0;
            end
            else begin
                S_fps_second_count_sys <= S_fps_second_count_sys + 26'd1;
                if(S_fps_frame_toggle_sync_sys != S_fps_frame_toggle_sync_d_sys)
                    {S_fps_work_d1_sys, S_fps_work_d0_sys} <=
                        F_bcd2_increment({S_fps_work_d1_sys, S_fps_work_d0_sys});
            end
        end
    end

    // Transfer the once-per-second FPS snapshot into the HDMI clock domain.
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_fps_bcd_meta_hdmi             <= 8'd0;
            S_fps_bcd_sync_hdmi             <= 8'd0;
            S_fps_update_toggle_meta_hdmi   <= 1'b0;
            S_fps_update_toggle_sync_hdmi   <= 1'b0;
            S_fps_update_toggle_sync_d_hdmi <= 1'b0;
            S_fps_bcd_hdmi                  <= 8'd0;
        end
        else begin
            S_fps_bcd_meta_hdmi             <= S_fps_bcd_sys;
            S_fps_bcd_sync_hdmi             <= S_fps_bcd_meta_hdmi;
            S_fps_update_toggle_meta_hdmi   <= S_fps_update_toggle_sys;
            S_fps_update_toggle_sync_hdmi   <= S_fps_update_toggle_meta_hdmi;
            S_fps_update_toggle_sync_d_hdmi <= S_fps_update_toggle_sync_hdmi;
            if(S_fps_update_toggle_sync_hdmi != S_fps_update_toggle_sync_d_hdmi)
                S_fps_bcd_hdmi <= S_fps_bcd_sync_hdmi;
        end
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_raw_seen <= 1'b0;
        else if(S_raw10_frame_start | S_axis_tvalid)
            S_dbg_raw_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_seen <= 1'b0;
        else if(S_ISP_O_tuser | S_ISP_O_tvalid)
            S_dbg_isp_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_wr_seen <= 1'b0;
        else if(S_vi_ddr_wr_en)
            S_dbg_ddr_wr_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_rd_seen <= 1'b0;
        else if(S_ddr_user_rd_valid)
            S_dbg_ddr_rd_seen <= 1'b1;
    end

    always @(posedge S_24m_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_cam_cfg_seen <= 1'b0;
        else if(S_cam_cfg_done)
            S_dbg_cam_cfg_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_hs_seen <= 1'b0;
        else if(S_hs_rx_valid)
            S_dbg_hs_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_csi_seen <= 1'b0;
        else if(S_csi_frame_start | S_csi_valid)
            S_dbg_csi_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_raw10_seen <= 1'b0;
        else if(S_raw10_frame_start | S_raw10_valid)
            S_dbg_raw10_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_fs_seen <= 1'b0;
        else if(S_ISP_O_tuser)
            S_dbg_isp_fs_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_valid_seen <= 1'b0;
        else if(S_ISP_O_tvalid)
            S_dbg_isp_valid_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_req_seen <= 1'b0;
        else if(S_vi_ddr_wr_en)
            S_dbg_ddr_req_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_ready_seen <= 1'b0;
        else if(S_ddr_user_ready)
            S_dbg_ddr_ready_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_req_seen <= 1'b0;
        else if(S_video_out_vsync)
            S_dbg_rd_req_seen <= 1'b0;
        else if(S_vo_ddr_rd_en)
            S_dbg_rd_req_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_valid_seen <= 1'b0;
        else if(S_video_out_vsync)
            S_dbg_rd_valid_seen <= 1'b0;
        else if(S_ddr_user_rd_valid)
            S_dbg_rd_valid_seen <= 1'b1;
    end

    always @(posedge S_hdmi_pixel_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_nonzero_seen <= 1'b0;
        else if(S_video_out_vsync)
            S_dbg_rd_nonzero_seen <= 1'b0;
        else if(S_hdmi_window_rd_en && (S_video_rd_data != 24'd0))
            S_dbg_rd_nonzero_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_init_seen <= 1'b0;
        else if(S_init_calib_complete)
            S_dbg_mc_init_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_app_rdy_seen <= 1'b0;
        else if(S_mc_dbg_app_rdy)
            S_dbg_mc_app_rdy_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_wdf_rdy_seen <= 1'b0;
        else if(S_mc_dbg_wdf_rdy)
            S_dbg_mc_wdf_rdy_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_cmd_pop_seen <= 1'b0;
        else if(S_mc_dbg_cmd_pop)
            S_dbg_mc_cmd_pop_seen <= 1'b1;
    end

    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_dbg_cam_cfg_seen_sync <= 2'b00;
            S_dbg_hs_seen_sync      <= 2'b00;
            S_dbg_csi_seen_sync     <= 2'b00;
            S_dbg_raw10_seen_sync   <= 2'b00;
            S_dbg_raw_seen_sync    <= 2'b00;
            S_dbg_isp_seen_sync    <= 2'b00;
            S_dbg_ddr_wr_seen_sync <= 2'b00;
            S_dbg_ddr_rd_seen_sync <= 2'b00;
            S_dbg_isp_fs_seen_sync  <= 2'b00;
            S_dbg_isp_valid_seen_sync <= 2'b00;
            S_dbg_ddr_req_seen_sync <= 2'b00;
            S_dbg_ddr_ready_seen_sync <= 2'b00;
            S_dbg_video_nonzero_seen <= 1'b0;
            S_dbg_rd_req_seen_sync <= 2'b00;
            S_dbg_rd_valid_seen_sync <= 2'b00;
            S_dbg_rd_nonzero_seen_sync <= 2'b00;
            S_dbg_mc_init_seen_sync <= 2'b00;
            S_dbg_mc_app_rdy_seen_sync <= 2'b00;
            S_dbg_mc_wdf_rdy_seen_sync <= 2'b00;
            S_dbg_mc_cmd_pop_seen_sync <= 2'b00;
        end
        else begin
            S_dbg_cam_cfg_seen_sync <= {S_dbg_cam_cfg_seen_sync[0], S_dbg_cam_cfg_seen};
            S_dbg_hs_seen_sync      <= {S_dbg_hs_seen_sync[0],      S_dbg_hs_seen};
            S_dbg_csi_seen_sync     <= {S_dbg_csi_seen_sync[0],     S_dbg_csi_seen};
            S_dbg_raw10_seen_sync   <= {S_dbg_raw10_seen_sync[0],   S_dbg_raw10_seen};
            S_dbg_raw_seen_sync    <= {S_dbg_raw_seen_sync[0],    S_dbg_raw_seen};
            S_dbg_isp_seen_sync    <= {S_dbg_isp_seen_sync[0],    S_dbg_isp_seen};
            S_dbg_ddr_wr_seen_sync <= {S_dbg_ddr_wr_seen_sync[0], S_dbg_ddr_wr_seen};
            S_dbg_ddr_rd_seen_sync <= {S_dbg_ddr_rd_seen_sync[0], S_dbg_ddr_rd_seen};
            S_dbg_isp_fs_seen_sync  <= {S_dbg_isp_fs_seen_sync[0],  S_dbg_isp_fs_seen};
            S_dbg_isp_valid_seen_sync <= {S_dbg_isp_valid_seen_sync[0], S_dbg_isp_valid_seen};
            S_dbg_ddr_req_seen_sync <= {S_dbg_ddr_req_seen_sync[0], S_dbg_ddr_req_seen};
            S_dbg_ddr_ready_seen_sync <= {S_dbg_ddr_ready_seen_sync[0], S_dbg_ddr_ready_seen};
            S_dbg_rd_req_seen_sync <= {S_dbg_rd_req_seen_sync[0], S_dbg_rd_req_seen};
            S_dbg_rd_valid_seen_sync <= {S_dbg_rd_valid_seen_sync[0], S_dbg_rd_valid_seen};
            S_dbg_rd_nonzero_seen_sync <= {S_dbg_rd_nonzero_seen_sync[0], S_dbg_rd_nonzero_seen};
            S_dbg_mc_init_seen_sync <= {S_dbg_mc_init_seen_sync[0], S_dbg_mc_init_seen};
            S_dbg_mc_app_rdy_seen_sync <= {S_dbg_mc_app_rdy_seen_sync[0], S_dbg_mc_app_rdy_seen};
            S_dbg_mc_wdf_rdy_seen_sync <= {S_dbg_mc_wdf_rdy_seen_sync[0], S_dbg_mc_wdf_rdy_seen};
            S_dbg_mc_cmd_pop_seen_sync <= {S_dbg_mc_cmd_pop_seen_sync[0], S_dbg_mc_cmd_pop_seen};
            if(S_hdmi_window_rd_en && (S_video_rd_data != 24'd0))
                S_dbg_video_nonzero_seen <= 1'b1;
        end
    end

    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_diag_in_line_meta<=0;S_diag_in_line_sync<=0;
            S_diag_spatial_line_meta<=0;S_diag_spatial_line_sync<=0;
            S_diag_pack_line_meta<=0;S_diag_pack_line_sync<=0;
            S_diag_in_frame_meta<=0;S_diag_in_frame_sync<=0;
            S_diag_spatial_frame_meta<=0;S_diag_spatial_frame_sync<=0;
            S_diag_pack_frame_meta<=0;S_diag_pack_frame_sync<=0;
            S_diag_ddr_frame_meta<=0;S_diag_ddr_frame_sync<=0;
            S_diag_fifo_level_meta<=0;S_diag_fifo_level_sync<=0;
            S_diag_burst_count_meta<=0;S_diag_burst_count_sync<=0;
            S_diag_line_error_meta<=0;S_diag_line_error_sync<=0;
            S_diag_frame_error_meta<=0;S_diag_frame_error_sync<=0;
            S_diag_burst_active_sync<=0;
        end else begin
            S_diag_in_line_meta<=S_diag_in_line;S_diag_in_line_sync<=S_diag_in_line_meta;
            S_diag_spatial_line_meta<=S_diag_spatial_line;S_diag_spatial_line_sync<=S_diag_spatial_line_meta;
            S_diag_pack_line_meta<=S_diag_pack_line;S_diag_pack_line_sync<=S_diag_pack_line_meta;
            S_diag_in_frame_meta<=S_diag_in_frame;S_diag_in_frame_sync<=S_diag_in_frame_meta;
            S_diag_spatial_frame_meta<=S_diag_spatial_frame;S_diag_spatial_frame_sync<=S_diag_spatial_frame_meta;
            S_diag_pack_frame_meta<=S_diag_pack_frame;S_diag_pack_frame_sync<=S_diag_pack_frame_meta;
            S_diag_ddr_frame_meta<=S_diag_ddr_frame;S_diag_ddr_frame_sync<=S_diag_ddr_frame_meta;
            S_diag_fifo_level_meta<=S_diag_fifo_level;S_diag_fifo_level_sync<=S_diag_fifo_level_meta;
            S_diag_burst_count_meta<=S_diag_burst_count;S_diag_burst_count_sync<=S_diag_burst_count_meta;
            S_diag_line_error_meta<=S_diag_line_error;S_diag_line_error_sync<=S_diag_line_error_meta;
            S_diag_frame_error_meta<=S_diag_frame_error;S_diag_frame_error_sync<=S_diag_frame_error_meta;
            S_diag_burst_active_sync<={S_diag_burst_active_sync[0],S_diag_burst_active};
        end
    end

    assign S_lane_error_any = |S_lane_error;

    assign S_vo_dbg_fifo_rst = 1'b0;
    assign S_vo_dbg_ddr_rd_valid = 1'b0;
    assign S_vo_dbg_fifo_rd_en = 1'b0;
    assign S_vo_dbg_fifo_empty = 1'b0;
    assign S_mc_dbg_fifo_afull = 1'b0;
    assign S_mc_dbg_app_rdy = 1'b0;
    assign S_mc_dbg_wdf_rdy = 1'b0;
    assign S_mc_dbg_cmd_pop = 1'b0;

    assign S_hdmi_debug_status = {
        (|S_ddr_user_rd_data),
        S_ddr_user_rd_valid,
        S_vo_ddr_rd_en,
        S_vi_ddr_wr_en
    };
	
	assign O_cam_rst 	= 1'b1;
    assign O_cam_24m 	= S_24m_clk;
	
	
	
	
    PLL u_PLL(
        .refclk      ( I_sys_clk         ),
        .reset    	 ( ~I_rst_n          ),
        
        .clk0_out    ( S_100m_clk        ),
        .clk1_out    ( S_24m_clk         ),

        .clk4_out    ( S_hdmi_pixel_clk  ),
        .clk5_out    ( S_hdmi_serial_clk ),

        .lock        ( S_pll_lock        )

    );


	

  
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
    wire [4:0] S_motion_regions_hdmi;
    wire S_motion_regions_valid_hdmi,S_motion_regions_overflow_hdmi;
    wire [15:0] S_motion_blocks_bcd_hdmi;
    uart_telemetry u_uart_telemetry(.clk(S_hdmi_pixel_clk),.rst_n(S_hdmi_rst_n),
        .mode(S_switch_hdmi_sync),.region_valid(S_motion_enable_hdmi && S_motion_regions_valid_hdmi),
        .region_overflow(S_motion_enable_hdmi && S_motion_regions_overflow_hdmi),
        .regions(S_motion_regions_hdmi),.fps_bcd(S_fps_bcd_hdmi),.delay_bcd(S_delay_frames_bcd_hdmi),
        .capture_bcd(S_cap_frame_bcd_hdmi),.display_bcd(S_display_frame_bcd_hdmi),
        .blocks_bcd(S_motion_blocks_bcd_hdmi),
        .label_valid(S_label_enable_hdmi && (S_label_status_result_hdmi != 2'd0)),
        .label_result(S_label_status_result_hdmi),.label_cause(S_label_status_cause_hdmi),
        .label_passes(S_label_status_passes_hdmi),.label_fails(S_label_status_fails_hdmi),
        .label_unknowns(S_label_status_unknowns_hdmi),.barcode_valid(S_label_enable_hdmi && S_barcode_valid_hdmi),
        .barcode_order(S_barcode_order_hdmi),.barcode_count(S_barcode_count_hdmi),.tx(O_uart_tx));

  ae_set u_ae_set (
      .I_clk(S_24m_clk),
      .I_rst(~S_rst_n),
      // K1/K2 choose colour/shape in detection/tracking modes. Route idle-high
      // levels to AE there so the same press cannot also change brightness.
      .I_btn(S_ae_buttons_blocked_sync ? 2'b11 : I_button[1:0]),
      .I_remote_dec(S_remote_ae_dec),.I_remote_inc(S_remote_ae_inc),
      .I_fps_60(S_fps60_switch_sync),
      .I_frame_luma(S_frame_luma),
      .I_luma_toggle(S_luma_toggle),
      .I_ae_error(S_ae_error),
      .I_lock(S_image_lock_cam),.O_locked(S_ae_locked),
      .O_debug(S_ae_debug),
      .O_debug_toggle(S_ae_debug_toggle),
      .I_cam_cfg_done(S_cam_cfg_done),
      .I_ae_cfg_done(S_ae_cfg_done),
      .O_ae_req(S_ae_req),
      .O_ae(S_ae),
      .O_ag(S_ag)
  );

    // Only effective mode 0000 selects 60 FPS image processing.
    // Synchronize this mode decode into the 24 MHz camera-control domain.

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
    // K1 cycles colour, K2 cycles shape in 0001 or paused/lost 0100.
    // K3/K4 select image algorithms, or pause/start tracking and homing.
    key_remove_shakes u_color_key_dec (
        .I_clk          ( S_hdmi_pixel_clk ),
        .I_rst_n        ( S_hdmi_rst_n ),
        .I_key_in       ( I_button[0]  ),
        .O_key_trig_out ( S_color_key_dec_physical )
    );

    key_remove_shakes u_color_key_inc (
        .I_clk          ( S_hdmi_pixel_clk ),
        .I_rst_n        ( S_hdmi_rst_n ),
        .I_key_in       ( I_button[1]  ),
        .O_key_trig_out ( S_color_key_inc_physical )
    );
    key_remove_shakes u_algo_key_dec (
        .I_clk          ( S_hdmi_pixel_clk ),
        .I_rst_n        ( S_hdmi_rst_n ),
        .I_key_in       ( I_button[2]  ),
        .O_key_trig_out ( S_algo_key_dec_physical )
    );

    key_remove_shakes u_algo_key_inc (
        .I_clk          ( S_hdmi_pixel_clk ),
        .I_rst_n        ( S_hdmi_rst_n ),
        .I_key_in       ( I_button[3]  ),
        .O_key_trig_out ( S_algo_key_inc_physical )
    );

    assign S_color_key_dec=S_color_key_dec_physical | S_remote_keys[0];
    assign S_color_key_inc=S_color_key_inc_physical | S_remote_keys[1];
    assign S_algo_key_dec=S_algo_key_dec_physical | S_remote_keys[2];
    assign S_algo_key_inc=S_algo_key_inc_physical | S_remote_keys[3];

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

    // The mode counter and OSD share the HDMI clock.  Only the ISP copy
    // needs a two-flop synchronizer into the asynchronous CSI clock domain.
    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_algo_mode_csi_meta <= 4'd0;
            S_algo_mode_csi      <= 4'd0;
            S_track_enable_csi_meta <= 1'b0;
            S_track_enable_csi      <= 1'b0;
            S_motion_enable_csi_meta <= 1'b0;
            S_motion_enable_csi      <= 1'b0;
            S_black_enable_csi_meta  <= 1'b0;
            S_black_enable_csi       <= 1'b0;
        end
        else begin
            S_algo_mode_csi_meta <= S_algo_mode;
            S_algo_mode_csi      <= S_algo_mode_csi_meta;
            S_track_enable_csi_meta <= S_track_enable_async;
            S_track_enable_csi      <= S_track_enable_csi_meta;
            S_motion_enable_csi_meta <= S_motion_enable_async;
            S_motion_enable_csi      <= S_motion_enable_csi_meta;
            S_black_enable_csi_meta  <= S_black_enable_async;
            S_black_enable_csi       <= S_black_enable_csi_meta;
        end
    end

    // Exact mode decode: 0001 is the colour-mask view, 0010 zooms the
    // blue-rectangle region, 0011 detects motion, 0100 tracks, and 0101 homes.
    assign S_servo_test_mode = (S_switch_hdmi_sync == 4'b0011) ||
                               (S_switch_hdmi_sync == 4'b0100);


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

    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_track_enable_hdmi_meta <= 1'b0;
            S_track_enable_hdmi      <= 1'b0;
            S_motion_enable_hdmi_meta <= 1'b0;
            S_motion_enable_hdmi      <= 1'b0;
            S_black_enable_hdmi_meta  <= 1'b0;
            S_black_enable_hdmi       <= 1'b0;
        end
        else begin
            S_track_enable_hdmi_meta <= S_track_enable_async;
            S_track_enable_hdmi      <= S_track_enable_hdmi_meta;
            S_motion_enable_hdmi_meta <= S_motion_enable_async;
            S_motion_enable_hdmi      <= S_motion_enable_hdmi_meta;
            S_black_enable_hdmi_meta  <= S_black_enable_async;
            S_black_enable_hdmi       <= S_black_enable_hdmi_meta;
        end
    end

    // The detector publishes one stable coordinate snapshot per camera frame.
    // Two-stage data and toggle synchronizers transfer that snapshot to HDMI.
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_black_valid_meta_hdmi  <= 1'b0;
            S_black_valid_sync_hdmi  <= 1'b0;
            S_black_left_meta_hdmi   <= 12'd0;
            S_black_left_sync_hdmi   <= 12'd0;
            S_black_right_meta_hdmi  <= 12'd0;
            S_black_right_sync_hdmi  <= 12'd0;
            S_black_top_meta_hdmi    <= 12'd0;
            S_black_top_sync_hdmi    <= 12'd0;
            S_black_bottom_meta_hdmi <= 12'd0;
            S_black_bottom_sync_hdmi <= 12'd0;
            S_black_toggle_meta_hdmi <= 1'b0;
            S_black_toggle_sync_hdmi <= 1'b0;
        end
        else begin
            S_black_valid_meta_hdmi  <= S_black_valid_csi;
            S_black_valid_sync_hdmi  <= S_black_valid_meta_hdmi;
            S_black_left_meta_hdmi   <= S_black_left_csi;
            S_black_left_sync_hdmi   <= S_black_left_meta_hdmi;
            S_black_right_meta_hdmi  <= S_black_right_csi;
            S_black_right_sync_hdmi  <= S_black_right_meta_hdmi;
            S_black_top_meta_hdmi    <= S_black_top_csi;
            S_black_top_sync_hdmi    <= S_black_top_meta_hdmi;
            S_black_bottom_meta_hdmi <= S_black_bottom_csi;
            S_black_bottom_sync_hdmi <= S_black_bottom_meta_hdmi;
            S_black_toggle_meta_hdmi <= S_black_toggle_csi;
            S_black_toggle_sync_hdmi <= S_black_toggle_meta_hdmi;
        end
    end

    uicfgcs500_720p #(
      .CLK_DIV(24000000 / 100000 - 1)
  ) u_uicfgcs500 (
      .I_clk(S_24m_clk),  //系统时钟输入
      .I_rst_n(S_rst_n),  //系统复位输入
      .I_fps_60(S_fps60_switch_sync),
      .I_ae_req(S_ae_req),
      .I_ae(S_ae),
      .I_ag(S_ag),
      .O_cam_scl(O_cam_scl),  //I2C总线，SCL时钟
      .IO_cam_sda(IO_cam_sda),  //I2C总线，SDA数据
      .O_cfg_done(S_cam_cfg_done),  //摄像头寄存器初始化完成
      .O_ae_error(S_ae_error),
      .O_ae_cfg_done(S_ae_cfg_done)  //AE配置完成
  );
	
    mipi_dphy_rx_ph1p_mipiio_wrapper#(
        .DPHY_RX_LOCATION      ( "DPHY0" ),
        .HS_EQUALIZER          ( "0dB"   ),//"0dB","1.5dB","3dB","4.5dB","6dB","7.5dB","9dB","10.5dB"
        .HS_VGA_GAIN           ( "8dB" ),//"-3dB","-1.5dB","0dB","1.5dB","3dB","4.5dB","6dB","7.5dB"
        .LANE_NUM              ( 2       ),
        .BYTE_NUM              ( 1       )
    )u_mipi_dphy_rx_ph1p_mipiio_wrapper(
        .I_lp_clk              ( S_100m_clk       ),
        .I_rst                 ( ~S_rst_n         ),

        .I_clk_lane_in_delay   ( 6'd0             ),
        .I_data_lane0_in_delay ( 6'd0             ),
        .I_data_lane1_in_delay ( 6'd0             ),
        .I_data_lane2_in_delay ( 6'd0             ),
        .I_data_lane3_in_delay ( 6'd0             ),

        .I_lane_invert         ( 4'b0000          ),
     
        .O_hs_rx_clk           ( S_csi_rx_clk     ),
        .O_hs_rx_valid         ( S_hs_rx_valid    ),
        .O_hs_rx_data          ( S_hs_rx_data     ),
      
        .O_lp_rx_lane0_p       (  ),
        .O_lp_rx_lane0_n       (  ),
      
        .I_lp_tx_en            ( 1'b0             ),
        .I_lp_tx_lane0_p       ( 1'b1             ),
        .I_lp_tx_lane0_n       ( 1'b1             ),
      
        .O_lane_match_error    (                  ),
        .O_lane_error          ( S_lane_error     ),
      
        .IO_rx_clk_pad_n       ( IO_rx_clk_pad_n  ),
        .IO_rx_clk_pad_p       ( IO_rx_clk_pad_p  ),
        .IO_rx_data_pad_n      ( IO_rx_data_pad_n ),
        .IO_rx_data_pad_p      ( IO_rx_data_pad_p )
    );
	
	
 //  cwc cwc_inst
 //(
 //    .probe0(S_hs_rx_valid),
 //    .probe1(S_hs_rx_data),
 //    .probe2(S_lane_error),
 //    .clk(S_csi_rx_clk)
 //);

 //csi 解码为RAW数据
csi_unpacket_2lane u_csi_unpacket(
.I_clk                 ( S_csi_rx_clk       ),
.I_rst_n               ( S_rst_n        	),
.I_hs_valid            ( S_hs_rx_valid     ),
.I_hs_data             ( S_hs_rx_data      ),

.O_csi_frame_start     ( S_csi_frame_start ),
.O_csi_frame_end       ( S_csi_frame_end   ),
.O_csi_valid           ( S_csi_valid       ),
.O_csi_data            ( S_csi_data        )
);


//解码为RAW8
raw10_unpacket_2lane u_raw10_unpacket (
.I_clk  (S_csi_rx_clk),
.I_rst_n(S_rst_n),

.I_csi_frame_start(S_csi_frame_start),
.I_csi_frame_end  (S_csi_frame_end),
.I_csi_valid      (S_csi_valid),
.I_csi_data       (S_csi_data),

.O_raw10_frame_start(S_raw10_frame_start),
.O_raw10_frame_end  (S_raw10_frame_end),
.O_raw10_valid      (S_raw10_valid),
.O_raw10_data       (S_raw10_data)
  );


//将数据转为stream流
uial2axis #(
.IMG_WIDTH(1280),
.IMG_HEIGHT(720),
.INPUT_DATA_WIDTH(40)
) 
u_uial2axis (
.I_native_clk(S_csi_rx_clk),
.I_rst_n     (S_rst_n),
.I_data      (S_raw10_data       ),
.I_data_valid(S_raw10_valid      ),
.I_data_start(S_raw10_frame_start),
.I_data_end  (S_raw10_frame_end  ),
.axis_tvalid (S_axis_tvalid),
.axis_tdata  (S_axis_tdata ),
.axis_tuser  (S_axis_tuser ),
.axis_tlast  (S_axis_tlast )
);
	

// 原厂HD模式直接输出1280x720 RAW10，不再进行FPGA固定窗口裁剪。
assign S_raw_tdata  = S_axis_tdata;
assign S_raw_tlast  = S_axis_tlast;
assign S_raw_tvalid = S_axis_tvalid;
assign S_raw_tuser  = S_axis_tuser;


//cwc1 cwc1_Inst
//  (
//      .probe0(S_axis_tuser),
//      .probe1(S_axis_tvalid),
//      .probe2(S_axis_tlast),
//      .probe3(S_axis_tdata),
//      .probe4(S_ISP_O_tuser),
//      .probe5(S_ISP_O_tvalid),
//      .probe6(S_ISP_O_tlast),
//      .probe7(S_ISP_O_tdata),
//      .probe8 (S_raw_tdata ),
//      .probe9 (S_raw_tlast ),
//      .probe10(S_raw_tvalid),
//      .probe11(S_raw_tuser ),
//      .clk(S_csi_rx_clk)
//  );


//ISP算法顶层模块
isp_top u_isp_top (
.axi4s_video_aclk(S_csi_rx_clk),
.I_rst_n         (S_rst_n),
.I_color_lock(S_image_lock_csi),.O_color_locked(S_color_locked),
.I_algo_mode     ((S_track_enable_csi || S_label_enable_csi || S_motion_enable_csi ||
                   S_black_enable_csi) ?
                  4'd0 : S_algo_mode_csi),
.I_black_enable  (S_black_enable_csi),
.I_tlast         (S_raw_tlast	),
.I_tuser         (S_raw_tuser	),
.I_tdata         (S_raw_tdata	),
.I_tvalid        (S_raw_tvalid	),
.I_tdest         (),
.O_tready        (S_ISP_O_tready),
.O_tdata         (S_ISP_O_tdata ),
.O_tlast         (S_ISP_O_tlast ),
.O_tuser         (S_ISP_O_tuser ),
.O_tvalid        (S_ISP_O_tvalid),
.I_tready        (),
.O_frame_luma    (S_frame_luma),
.O_luma_toggle   (S_luma_toggle)
,.O_black_valid  (S_black_valid_csi)
,.O_black_left   (S_black_left_csi)
,.O_black_right  (S_black_right_csi)
,.O_black_top    (S_black_top_csi)
,.O_black_bottom (S_black_bottom_csi)
,.O_black_toggle (S_black_toggle_csi)
,.O_diag_in_line (S_diag_in_line)
,.O_diag_spatial_line (S_diag_spatial_line)
,.O_diag_pack_line (S_diag_pack_line)
,.O_diag_in_frame (S_diag_in_frame)
,.O_diag_spatial_frame (S_diag_spatial_frame)
,.O_diag_pack_frame (S_diag_pack_frame)
,.O_diag_line_error (S_diag_line_error)
,.O_diag_frame_error (S_diag_frame_error)
  );


    video_in u_video_in(
        .I_rst_n              (  S_rst_n             ),

        .I_camera_clk         ( S_csi_rx_clk          ),
        .I_camera_frame_start ( S_ISP_O_tuser  ),
        .I_camera_frame_bcd   ( S_cap_frame_bcd_csi ),
        .I_camera_valid       ( S_ISP_O_tvalid ),
        .I_camera_data        ( S_ISP_O_tdata  ),
        .I_mipi_rx_error      ( 1'b0			      ),

        .I_ddr_clk            ( S_ddr_clk             ),
		.I_display_pause      ( 1'b0                  ),
        .I_video_out_rd_busy  ( S_video_out_rd_busy   ),
        .O_video_in_wr_busy   ( S_video_in_wr_busy    ),
        .O_video_out_rp       ( S_video_out_rp        ),
        .O_video_out_frame_bcd( S_video_out_frame_bcd_ddr ),

        .O_ddr_user_wr_en     ( S_vi_ddr_wr_en        ),
        .O_ddr_user_addr      ( S_vi_ddr_wr_addr      ),
        .O_ddr_user_wr_data   ( S_vi_ddr_wr_data      ),
        .I_ddr_user_ready     ( S_ddr_user_ready      ),
        .O_diag_fifo_level    ( S_diag_fifo_level     ),
        .O_diag_burst_count   ( S_diag_burst_count    ),
        .O_diag_burst_active  ( S_diag_burst_active   ),
        .O_diag_ddr_frame     ( S_diag_ddr_frame      )
    );



    assign S_ddr_user_wr_en    = S_vi_ddr_wr_en;

    assign S_ddr_user_rd_en    = S_vo_ddr_rd_en;

    assign S_ddr_user_addr     = S_vi_ddr_wr_en ? S_vi_ddr_wr_addr :
                                 S_vo_ddr_rd_en ? S_vo_ddr_rd_addr : 'd0;

    assign S_ddr_user_wr_data  = S_vi_ddr_wr_data;


    assign S_video_out_rst_n = S_hdmi_rst_n;

    video_out u_video_out(
        .I_rst_n             ( S_video_out_rst_n    ),
        .I_ddr_clk           ( S_ddr_clk            ),
 
        .O_video_out_rd_busy ( S_video_out_rd_busy  ),
        .I_video_in_wr_busy  ( S_video_in_wr_busy   ),
        .I_video_out_rp      ( S_video_out_rp       ),
        .I_video_out_frame_bcd ( S_video_out_frame_bcd_ddr ),
        // Label-local zoom was removed in the moving inspection mode.
        .I_zoom_enable       ( 1'b0 ),
        .I_zoom_src_x(S_label_zoom_src_x),.I_zoom_src_y(S_label_zoom_src_y),
        .O_zoom_src_x(S_label_zoom_view_x),.O_zoom_src_y(S_label_zoom_view_y),
        .O_zoom_active       ( S_zoom_active_hdmi  ),
        .O_display_frame_bcd ( S_display_frame_bcd_ddr ),
        .O_display_frame_toggle ( S_display_frame_toggle_ddr ),
 
        .O_ddr_user_rd_en    ( S_vo_ddr_rd_en       ),
        .O_ddr_user_addr     ( S_vo_ddr_rd_addr     ),
        .I_ddr_user_ready    ( S_ddr_user_ready     ),
        .I_ddr_user_rd_valid ( S_ddr_user_rd_valid  ),
        .I_ddr_user_rd_data  ( S_ddr_user_rd_data   ),

        .I_dsi_clk           ( S_hdmi_pixel_clk     ),
        .I_video_vsync       ( S_video_out_vsync    ),
        .I_video_rd_en       ( S_hdmi_window_rd_en  ),
        .O_vdieo_data        ( S_video_rd_data      )
    );



    mc_to_user_interface u_mc_to_user_interface(
        .I_clk                   ( S_ddr_clk               ),
        .I_rst_n                 ( S_rst_n                 ),

        .I_ddr_user_wr_en        ( S_ddr_user_wr_en        ),
        .I_ddr_user_rd_en        ( S_ddr_user_rd_en        ),
        .I_ddr_user_addr         ( S_ddr_user_addr         ),
        .I_ddr_user_wr_data      ( S_ddr_user_wr_data      ),
        .O_ddr_user_ready        ( S_ddr_user_ready        ),
        .O_ddr_user_rd_valid     ( S_ddr_user_rd_valid     ),
        .O_ddr_user_rd_data      ( S_ddr_user_rd_data      ),
            
        .O_mc_app_en             ( S_mc_app_en             ),
        .O_mc_app_addr           ( S_mc_app_addr           ),
        .O_mc_app_cmd            ( S_mc_app_cmd            ),
        .I_mc_app_rdy            ( S_mc_app_rdy            ),
        .O_mc_app_wdf_wren       ( S_mc_app_wdf_wren       ),
        .O_mc_app_wdf_data       ( S_mc_app_wdf_data       ),
        .O_mc_app_wdf_end        ( S_mc_app_wdf_end        ),
        .O_mc_app_wdf_mask       ( S_mc_app_wdf_mask       ),
        .I_mc_app_wdf_rdy        ( S_mc_app_wdf_rdy        ),
        .I_mc_app_rd_data        ( S_mc_app_rd_data        ),
        .I_mc_app_rd_data_end    ( S_mc_app_rd_data_end    ),
        .I_mc_app_rd_data_valid  ( S_mc_app_rd_data_valid  )
    );



    ph1p35_324_ddr_wrapper u_ph1p35_324_ddr_wrapper(
        .I_sys_clk              ( I_sys_clk              ),
        .I_sys_rst_n            ( S_rst_n                ),

        .O_ddr_clk              ( S_ddr_clk              ),
        .O_init_calib_complete  ( S_init_calib_complete  ),
        .I_mc_app_addr          ( S_mc_app_addr          ),
        .I_mc_app_cmd           ( S_mc_app_cmd           ),
        .I_mc_app_en            ( S_mc_app_en            ),
        .I_mc_app_wdf_data      ( S_mc_app_wdf_data      ),
        .I_mc_app_wdf_end       ( S_mc_app_wdf_end       ),
        .I_mc_app_wdf_mask      ( S_mc_app_wdf_mask      ),
        .I_mc_app_wdf_wren      ( S_mc_app_wdf_wren      ),
        .O_mc_app_rd_data       ( S_mc_app_rd_data       ),
        .O_mc_app_rd_data_end   ( S_mc_app_rd_data_end   ),
        .O_mc_app_rd_data_valid ( S_mc_app_rd_data_valid ),
        .O_mc_app_rdy           ( S_mc_app_rdy           ),
        .O_mc_app_wdf_rdy       ( S_mc_app_wdf_rdy       ),

        .ddr_addr               ( ddr_addr               ),
        .ddr_ba                 ( ddr_ba                 ),
        .ddr_cke                ( ddr_cke                ),
        .ddr_odt                ( ddr_odt                ),
        .ddr_cs_n               ( ddr_cs_n               ),
        .ddr_ras_n              ( ddr_ras_n              ),
        .ddr_cas_n              ( ddr_cas_n              ),
        .ddr_we_n               ( ddr_we_n               ),
        .ddr_ck_p               ( ddr_ck_p               ),
        .ddr_ck_n               ( ddr_ck_n               ),
        .ddr_dm                 ( ddr_dm                 ),
        .ddr_dq                 ( ddr_dq                 ),
        .ddr_dqs_p              ( ddr_dqs_p              ),
        .ddr_dqs_n              ( ddr_dqs_n              )
    );



    uivtc #(
        .H_ActiveSize ( 1280 ),
        .H_FrameSize  ( 1650 ),
        .H_SyncStart  ( 1390 ),
        .H_SyncEnd    ( 1430 ),
        .V_ActiveSize ( 720  ),
        .V_FrameSize  ( 750  ),
        .V_SyncStart  ( 725  ),
        .V_SyncEnd    ( 730  )
    )u_hdmi_vtc(
        .I_vtc_rstn    ( S_hdmi_rst_n    ),
        .I_vtc_clk     ( S_hdmi_pixel_clk ),
        .O_vtc_vs      ( S_hdmi_vsync     ),
        .O_vtc_hs      ( S_hdmi_hsync     ),
        .O_vtc_de_valid( S_hdmi_de        ),
        .O_vtc_user    ( S_hdmi_user      ),
        .O_vtc_last    ( S_hdmi_last      )
    );

    hdmi_mixer #(
        .H_OFFSET   ( 0    ),
        .V_OFFSET   ( 0    ),
        .IMG_WIDTH  ( 1280 ),
        .IMG_HEIGHT ( 720  ),
        .DEBUG_MODE ( 0    )
    )u_hdmi_mixer(
        .I_clk           ( S_hdmi_pixel_clk   ),
        .I_rst_n         ( S_hdmi_rst_n       ),
        .I_video_vsync   ( S_hdmi_vsync       ),
        .I_video_hsync   ( S_hdmi_hsync       ),
        .I_video_de      ( S_hdmi_de          ),
        .I_video_user    ( S_hdmi_user        ),
        .I_video_last    ( S_hdmi_last        ),
        .I_debug_status  ( S_hdmi_debug_status),
        .I_switch_state  ( S_switch_hdmi_sync ),
        .I_label_enable(S_label_enable_hdmi),.I_label_keys_n(I_button),
        .I_label_remote_action(S_label_remote_action),
        .I_label_imaging_locked(S_ae_locked_hdmi && S_color_locked_hdmi),
        .O_label_imaging_lock(S_label_imaging_lock),
        .O_label_result(S_label_result_hdmi),
        .O_label_status_result(S_label_status_result_hdmi),.O_label_status_cause(S_label_status_cause_hdmi),
        .O_label_status_passes(S_label_status_passes_hdmi),.O_label_status_fails(S_label_status_fails_hdmi),
        .O_label_status_unknowns(S_label_status_unknowns_hdmi),.O_barcode_valid(S_barcode_valid_hdmi),
        .O_barcode_order(S_barcode_order_hdmi),.O_barcode_count(S_barcode_count_hdmi),
        .I_label_zoom_supported(1'b0),.I_label_zoom_active(1'b0),
        .I_label_zoom_src_x(12'd0),.I_label_zoom_src_y(12'sd0),
        .O_label_zoom_request(S_label_zoom_request_hdmi),
        .O_label_zoom_src_x(S_label_zoom_src_x),.O_label_zoom_src_y(S_label_zoom_src_y),
        .O_label_buzzer_n(S_label_buzzer_n),
        .I_algo_mode     ( (S_track_enable_hdmi || S_label_enable_hdmi || S_motion_enable_hdmi ||
                            S_black_enable_hdmi) ?
                           4'd0 : S_algo_mode ),
        .I_track_enable  ( S_track_enable_hdmi && !S_zoom_active_hdmi),
        .I_track_color   ( S_track_color      ),
        .I_track_shape   ( S_track_shape      ),
        .I_learn_prepare ( S_learn_prepare ),.I_learn_start(S_learn_start),
        .I_servo_state   ( S_servo_state ),
        .I_pan_pulse_us  ( S_pan_pulse_us ),
        .I_tilt_pulse_us ( S_tilt_pulse_us ),
        .O_measure_update ( S_servo_measure_update ),
        .O_measure_valid  ( S_servo_measure_valid ),
        .O_measure_large  ( S_servo_measure_large ),
        .O_measure_dx     ( S_servo_measure_dx ),
        .O_measure_dy     ( S_servo_measure_dy ),
        .O_motion_regions(S_motion_regions_hdmi),.O_motion_regions_valid(S_motion_regions_valid_hdmi),
        .O_motion_regions_overflow(S_motion_regions_overflow_hdmi),.O_motion_blocks_bcd(S_motion_blocks_bcd_hdmi),
        .I_motion_enable ( S_motion_enable_hdmi && !S_zoom_active_hdmi),
        .I_black_enable  ( S_black_enable_hdmi),
        .I_black_valid   ( S_black_valid_sync_hdmi),
        .I_black_left    ( S_black_left_sync_hdmi),
        .I_black_right   ( S_black_right_sync_hdmi),
        .I_black_top     ( S_black_top_sync_hdmi),
        .I_black_bottom  ( S_black_bottom_sync_hdmi),
        .I_black_update_toggle ( S_black_toggle_sync_hdmi),
        .I_zoom_active   ( 1'b0 ),
        .O_zoom_request  ( S_zoom_request_hdmi),
        .I_capture_frame_bcd ( S_cap_frame_bcd_hdmi ),
        .I_camera_fps_bcd    ( S_fps_bcd_hdmi       ),
        .I_display_frame_bcd ( S_display_frame_bcd_hdmi ),
        .I_delay_frames_bcd  ( S_delay_frames_bcd_hdmi ),
        .I_ae_debug(S_ae_debug),
        .I_ae_debug_toggle(S_ae_debug_toggle),
        .I_diag_in_line(S_diag_in_line_sync),
        .I_diag_spatial_line(S_diag_spatial_line_sync),
        .I_diag_pack_line(S_diag_pack_line_sync),
        .I_diag_in_frame(S_diag_in_frame_sync),
        .I_diag_spatial_frame(S_diag_spatial_frame_sync),
        .I_diag_pack_frame(S_diag_pack_frame_sync),
        .I_diag_ddr_frame(S_diag_ddr_frame_sync),
        .I_diag_fifo_level(S_diag_fifo_level_sync),
        .I_diag_burst_count(S_diag_burst_count_sync),
        .I_diag_burst_active(S_diag_burst_active_sync[1]),
        .I_diag_line_error(S_diag_line_error_sync),
        .I_diag_frame_error(S_diag_frame_error_sync),
        .O_video_rd_en   ( S_hdmi_window_rd_en),
        .I_video_rd_data ( S_video_rd_data    ),
        .O_hdmi_vsync    ( S_hdmi_out_vsync   ),
        .O_hdmi_hsync    ( S_hdmi_out_hsync   ),
        .O_hdmi_de       ( S_hdmi_out_de      ),
        .O_hdmi_data     ( S_hdmi_out_data    )
    );

    hdmi_tx u_hdmi_tx(
        .I_pixel_clk        ( S_hdmi_pixel_clk  ),
        .I_serial_clk       ( S_hdmi_serial_clk ),
        .I_rst              ( ~S_hdmi_rst_n     ),
        .I_key_in           ( 1'b0              ),
        .I_edid_read_trig   ( 1'b0              ),
        .O_edid_read_valid  (                   ),
        .O_edid_read_data   (                   ),
        .I_video_rgb_enable ( 1'b1              ),
        .I_video_in_vs      ( S_hdmi_out_vsync  ),
        .I_video_in_de      ( S_hdmi_out_de     ),
        .I_video_in_user    ( 1'b0              ),
        .I_video_in_valid   ( 1'b0              ),
        .I_video_in_last    ( 1'b0              ),
        .O_video_in_ready   (                   ),
        .I_video_in_data    ( S_hdmi_out_data   ),
        .I_audio_valid      ( 1'b0              ),
        .I_audio_left_data  ( 24'd0             ),
        .I_audio_right_data ( 24'd0             ),
        .I_i2s_BCLK         ( 1'b0              ),
        .I_i2s_LRCK         ( 1'b0              ),
        .I_i2s_DOUT         ( 1'b0              ),
        .O_ddc_scl          (                   ),
        .O_hdmi_clk_p       (                   ),
        .O_hdmi_tx_p        (                   ),
        .O_tmds_ch0_p       ( O_tmds_ch0_p      ),
        .O_tmds_ch1_p       ( O_tmds_ch1_p      ),
        .O_tmds_ch2_p       ( O_tmds_ch2_p      ),
        .O_tmds_clk_p       ( O_tmds_clk_p      )
    );


    
endmodule

// 0100: two-axis auto (K4 start/K3 pause); 0101: return to neutral.
// 0110..1111: 60 FPS image processing. Pan/tilt limits are unchanged.
module servo_pan_tracker #(
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
    input wire I_remote_valid,input wire [2:0] I_remote_state,
    input wire I_remote_context,input wire I_measure_large
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
    reg S_previous_valid,S_previous_pan_sign,S_previous_tilt_sign;
    reg [1:0] S_pan_budget,S_tilt_budget;
    function [3:0] F_speed;
        input [12:0] error,previous;
        input history,large_target;
        reg [3:0] speed;
        reg [12:0] closing;
        begin
            closing=previous-error;
            if(error>=320) speed=8;
            else if(error>=192) speed=6;
            else if(error>=96) speed=4;
            else if(error>=48) speed=2;
            else speed=1;
            // Two-frame look-ahead: brake before delayed feedback crosses centre.
            if(large_target && speed>3) speed=3;
            if(error<96) speed=1;
            if(history && previous>error) begin
                if(closing>=(error>>1)) speed=0;
                else if(error<192 && closing>=8 && speed>2) speed=2;
            end
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
                nm=cm>=tm ? tm : (cm+1>tm ? tm : cm+1);
                F_ramp=target[4] ? -$signed(nm) : $signed(nm);
            end
        end
    endfunction
    wire [3:0] S_speed_pan=F_speed(S_abs_dx,S_previous_dx,S_previous_valid && S_previous_pan_sign==I_measure_dx[12],I_measure_large===1'b1);
    wire [3:0] S_speed_tilt=F_speed(S_abs_dy,S_previous_dy,S_previous_valid && S_previous_tilt_sign==I_measure_dy[12],I_measure_large===1'b1);
    wire [4:0] S_restart_threshold=I_measure_large===1'b1 ? 5'd16:5'd20;
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
            S_rate_pan<=0;S_rate_tilt<=0;S_pan_budget<=0;S_tilt_budget<=0;O_pan_pwm<=0;O_tilt_pwm<=0;
        end else begin
            if(S_remote_valid || I_remote_context===1'b1) begin S_mode_sample<=I_mode;S_mode_stable<=I_mode;end
            if(!S_run) begin S_rate_pan<=0;S_rate_tilt<=0;S_pan_budget<=0;S_tilt_budget<=0;end
            if(S_pan_mode && S_armed && I_measure_update && I_measure_valid &&
                    !I_key_dec && !S_remote_valid && !S_color_changed) begin
                S_pan_budget<=S_abs_dx<96 ? 2'd1:2'd2;
                S_tilt_budget<=S_abs_dy<96 ? 2'd1:2'd2;
            end
            if(S_us_tick) begin
                S_us_div<=0;
                if(S_frame_us==19999) begin
                    S_frame_us<=0;S_mode_sample<=I_mode;
                    S_mode_stable<=(S_remote_valid || I_mode==S_mode_sample)?I_mode:4'd0;
                    O_pan_pwm<=(S_remote_valid || I_mode==S_mode_sample) &&
                        (I_mode==3 || (I_mode==4 && S_home_active));
                    O_tilt_pwm<=(S_remote_valid || I_mode==S_mode_sample) &&
                        (I_mode==3 || (I_mode==4 && S_home_active));
                    if(S_run && !(I_measure_update && I_measure_valid)) begin
                        if(S_pan_budget!=0) begin
                            S_rate_pan<=S_next_rate_pan;S_pan_budget<=S_pan_budget-1'b1;
                            S_pan_pulse_us<=F_limit($signed({2'b0,S_pan_pulse_us})+
                                $signed({{9{S_next_rate_pan[4]}},S_next_rate_pan}));
                        end else S_rate_pan<=0;
                        if(S_tilt_budget!=0) begin
                            S_rate_tilt<=S_next_rate_tilt;S_tilt_budget<=S_tilt_budget-1'b1;
                            S_tilt_pulse_us<=F_tilt_limit($signed({2'b0,S_tilt_pulse_us})+
                                $signed({{9{S_next_rate_tilt[4]}},S_next_rate_tilt}));
                        end else S_rate_tilt<=0;
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
            S_previous_dx<=0;S_previous_dy<=0;S_previous_valid<=0;S_previous_pan_sign<=0;S_previous_tilt_sign<=0;
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
                    S_previous_pan_sign<=I_measure_dx[12];S_previous_tilt_sign<=I_measure_dy[12];
                    S_pan_target_us<=S_pan_pulse_us;S_tilt_target_us<=S_tilt_pulse_us;
                    if(S_abs_dx<=12 || (S_previous_valid && S_previous_pan_sign!=I_measure_dx[12] && S_abs_dx<96)) begin
                        S_adjusting<=S_abs_dx>12 && S_adjusting;S_command_pan<=0;end
                    else if(S_adjusting || S_abs_dx>=S_restart_threshold) begin
                        S_adjusting<=1;
                        S_command_pan<=I_measure_dx[12] ? $signed({1'b0,S_speed_pan}):-$signed({1'b0,S_speed_pan});
                    end else S_command_pan<=0;
                    if(S_abs_dy<=12 || (S_previous_valid && S_previous_tilt_sign!=I_measure_dy[12] && S_abs_dy<96)) begin
                        S_adjusting_tilt<=S_abs_dy>12 && S_adjusting_tilt;S_command_tilt<=0;end
                    else if(S_adjusting_tilt || S_abs_dy>=S_restart_threshold) begin
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


// 115200 8N1 RX only. Legacy 00..0F mode bytes remain supported.
// Framed commands: A5 OP LO HI XOR(A5,OP,LO,HI).
module uart_switch_control #(
    parameter integer CLOCK_HZ=50000000,BAUD=115200,DEBOUNCE_CYCLES=250000,
    FRAME_TIMEOUT_CYCLES=CLOCK_HZ/100
)(input wire I_clk,I_rst_n,I_rx,input wire [3:0] I_switch,
  output reg [3:0] O_switch,output reg [11:0] O_action_data,output reg O_action_toggle);
    localparam BIT_CYCLES=(CLOCK_HZ+BAUD/2)/BAUD;
    localparam TB=$clog2(BIT_CYCLES),DB=$clog2(DEBOUNCE_CYCLES),GB=$clog2(FRAME_TIMEOUT_CYCLES);
    localparam [1:0] IDLE=0,START=1,DATA=2,STOP=3;
    localparam [2:0] P_IDLE=0,P_OP=1,P_LO=2,P_HI=3,P_CHECK=4;
    reg rx_meta,rx_sync,rx_previous;
    reg [1:0] state;reg [TB-1:0] timer;reg [2:0] bit_index;reg [7:0] rx_byte;
    reg [3:0] sw_meta,sw_sync,sw_sample,sw_stable,keys_held;
    reg [DB-1:0] sw_timer;
    reg [2:0] packet_state;reg [7:0] opcode,arg_lo,arg_hi,checksum;
    reg [GB-1:0] gap;
    wire goto_allowed=(arg_lo[7:4]==0 && arg_lo[3:0]<=5) ||
        ((arg_lo[7:4]==1 || arg_lo[7:4]==2) && arg_lo[3:0]==0) ||
        (arg_lo[7:4]==3 && arg_lo[3:0]<=1) ||
        (arg_lo[7:4]==4 && arg_lo[3:0]<=4) ||
        (arg_lo[7:4]==5 && arg_lo[3:0]<=5);
    wire key_allowed=arg_lo[7:4]==0 && (arg_hi==0 ||
        (arg_hi==1 && arg_lo==8 && O_switch==5));
    wire scene_allowed=arg_lo[7:5]==0 && arg_hi[7:4]==0 && arg_hi[1:0]!=0 &&
        ((arg_lo[3:0]==1 && !arg_lo[4] && arg_hi[3:2]!=3) || arg_lo[3:0]==3);
    wire context_allowed=arg_lo[7:4]<=5 && arg_lo[3:0]!=0 &&
        (arg_hi==0 || (arg_hi==1 && arg_lo==8'h58));
    task select_mode;
        input [3:0] value;
        begin O_switch<=value>=6?0:value;keys_held<=0;end
    endtask
    task accept_byte;
        input [7:0] value;
        reg [3:0] pressed;
        begin
            gap<=0;
            case(packet_state)
                P_IDLE:if(value==8'ha5) begin packet_state<=P_OP;checksum<=value;end
                       else if(value[7:4]==0) select_mode(value[3:0]);
                P_OP:begin opcode<=value;checksum<=checksum^value;packet_state<=P_LO;end
                P_LO:begin arg_lo<=value;checksum<=checksum^value;packet_state<=P_HI;end
                P_HI:begin arg_hi<=value;checksum<=checksum^value;packet_state<=P_CHECK;end
                P_CHECK:begin
                    packet_state<=P_IDLE;
                    if(value==checksum) begin
                        case(opcode)
                            1:if(arg_hi==0 && arg_lo[7:4]==0) select_mode(arg_lo[3:0]);
                            2,3:if(key_allowed) begin
                                pressed=opcode==2 ? arg_lo[3:0]&~keys_held:arg_lo[3:0];
                                if(opcode==2) keys_held<=arg_lo[3:0];
                                if(pressed!=0) begin
                                    O_action_data<={2'd1,O_switch,arg_hi[0],1'b0,pressed};
                                    O_action_toggle<=~O_action_toggle;
                                end
                            end
                            4:if(arg_hi==0 && goto_allowed) begin
                                select_mode(arg_lo[7:4]);
                                O_action_data<={2'd2,arg_lo[7:4],2'b00,arg_lo[3:0]};
                                O_action_toggle<=~O_action_toggle;
                            end
                            8'h10:if(scene_allowed) begin
                                select_mode(arg_lo[3:0]);
                                O_action_data<={2'd0,arg_lo[3:0],arg_lo[4],1'b0,arg_hi[3:0]};
                                O_action_toggle<=~O_action_toggle;
                            end
                            8'h12:if(context_allowed) begin
                                select_mode(arg_lo[7:4]);
                                O_action_data<={2'd3,arg_lo[7:4],arg_hi[0],1'b0,arg_lo[3:0]};
                                O_action_toggle<=~O_action_toggle;
                            end
                            // Other parameter opcodes remain reserved.
                            default:;
                        endcase
                    end else if(value==8'ha5) begin packet_state<=P_OP;checksum<=value;end
                end
                default:packet_state<=P_IDLE;
            endcase
        end
    endtask
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin rx_meta<=1;rx_sync<=1;rx_previous<=1;sw_meta<=0;sw_sync<=0;end
        else begin rx_meta<=I_rx;rx_sync<=rx_meta;rx_previous<=rx_sync;sw_meta<=I_switch;sw_sync<=sw_meta;end
    end
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            state<=IDLE;timer<=0;bit_index<=0;rx_byte<=0;
            sw_sample<=0;sw_stable<=0;sw_timer<=0;O_switch<=0;keys_held<=0;
            packet_state<=P_IDLE;opcode<=0;arg_lo<=0;arg_hi<=0;checksum<=0;gap<=0;
            O_action_data<=0;O_action_toggle<=0;
        end else begin
            if(sw_sync!=sw_sample) begin sw_sample<=sw_sync;sw_timer<=0;end
            else if(sw_timer!=DEBOUNCE_CYCLES-1) sw_timer<=sw_timer+1'b1;
            else if(sw_stable!=sw_sample) begin sw_stable<=sw_sample;select_mode(sw_sample);end
            if(packet_state==P_IDLE || state!=IDLE) gap<=0;
            else if(gap==FRAME_TIMEOUT_CYCLES-1) begin packet_state<=P_IDLE;gap<=0;end
            else gap<=gap+1'b1;
            // Accepted UART commands take priority over a simultaneous DIP change.
            case(state)
                IDLE:if(rx_previous && !rx_sync) begin state<=START;timer<=BIT_CYCLES/2-1;end
                START:if(timer!=0) timer<=timer-1'b1;
                      else if(rx_sync) state<=IDLE;
                      else begin state<=DATA;timer<=BIT_CYCLES-1;bit_index<=0;end
                DATA:if(timer!=0) timer<=timer-1'b1;
                     else begin rx_byte<={rx_sync,rx_byte[7:1]};timer<=BIT_CYCLES-1;
                         if(bit_index==7) state<=STOP;else bit_index<=bit_index+1'b1;end
                STOP:if(timer!=0) timer<=timer-1'b1;
                     else begin
                         if(rx_sync) accept_byte(rx_byte);
                         else begin packet_state<=P_IDLE;gap<=0;end
                         state<=IDLE;
                     end
            endcase
        end
    end
endmodule

// Source payload is held until the next packet (at least 5 UART bytes).
// Wait an extra destination clock after toggle synchronization, then require
// the separately synchronized mode to match before emitting one action pulse.
module uart_action_bridge(
    input wire I_clk,I_rst_n,input wire [3:0] I_mode,
    input wire [11:0] I_data,input wire I_toggle,
    output reg O_valid,output reg [1:0] O_kind,
    output reg [3:0] O_value,output reg O_long
);
    reg [11:0] data_meta,data_sync,pending_data;
    reg toggle_meta,toggle_sync,toggle_settle,toggle_previous,pending;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            data_meta<=0;data_sync<=0;pending_data<=0;
            toggle_meta<=0;toggle_sync<=0;toggle_settle<=0;toggle_previous<=0;pending<=0;
            O_valid<=0;O_kind<=0;O_value<=0;O_long<=0;
        end else begin
            data_meta<=I_data;data_sync<=data_meta;
            toggle_meta<=I_toggle;toggle_sync<=toggle_meta;toggle_settle<=toggle_sync;
            toggle_previous<=toggle_settle;O_valid<=0;
            if(toggle_settle!=toggle_previous) begin pending<=1;pending_data<=data_sync;end
            else if(pending && I_mode==pending_data[9:6]) begin
                pending<=0;O_valid<=1;O_kind<=pending_data[11:10];
                O_long<=pending_data[5];O_value<=pending_data[3:0];
            end
        end
    end
endmodule


// Qualify a bundled mode value after two synchronization stages. Commands are
// held for at least one UART byte; a one-cycle mixed binary code is not applied.
module switch_state_sync (
    input wire I_clk,I_rst_n,
    input wire [3:0] I_state,
    output reg [3:0] O_state
);
    reg [3:0] meta,sync,previous;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin meta<=0;sync<=0;previous<=0;O_state<=0;end
        else begin
            meta<=I_state;sync<=meta;previous<=sync;
            if(sync==previous) O_state<=sync;
        end
    end
endmodule

// One scanner drives all eight digits. All inputs share the HDMI clock.
// SEL0..3 show the effective binary mode; SEL4..7 show a held label result.
module switch_state_display (
    input wire I_clk,I_rst_n,
    input wire [3:0] I_state,
    input wire [1:0] I_result,
    output reg [7:0] O_segment_n,O_digit_n
);
    reg [16:0] scan;
    reg [3:0] snapshot;
    reg [1:0] result_snapshot;
    wire [2:0] digit=scan[16:14];
    wire selected_bit=digit==0 ? I_state[3] : snapshot[3-digit];
    reg [7:0] pattern;
    always @* begin
        pattern=8'hff;
        if(digit<4) pattern=selected_bit ? 8'hf9 : 8'hc0;
        else if(snapshot==4'd5) begin
            case(result_snapshot)
                1:case(digit) 4:pattern=8'h8c;5:pattern=8'h88;6,7:pattern=8'h92;default:;endcase
                2:case(digit) 4:pattern=8'h8e;5:pattern=8'h88;6:pattern=8'hf9;7:pattern=8'hc7;default:;endcase
                3:case(digit) 4:pattern=8'hc1;5:pattern=8'hc8;default:;endcase
                default:;
            endcase
        end
    end
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin scan<=0;snapshot<=0;result_snapshot<=0;O_segment_n<=8'hff;O_digit_n<=8'hff;end
        else begin
            scan<=scan+1'b1;
            if(scan[13:0]==0) begin
                O_digit_n<=8'hff;
                O_segment_n<=pattern;
                if(digit==0) begin snapshot<=I_state;result_snapshot<=I_result;end
            end else if(scan[13:0]==1) O_digit_n<=pattern==8'hff ? 8'hff : ~(8'b1<<digit);
        end
    end
endmodule
