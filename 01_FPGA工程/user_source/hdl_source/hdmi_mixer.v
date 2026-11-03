module hdmi_mixer #(
    parameter H_OFFSET = 128,
    parameter V_OFFSET = 60,
    parameter IMG_WIDTH = 1280,
    parameter IMG_HEIGHT = 720,
    parameter integer DEBUG_MODE = 0
)(
    input wire        I_clk,
    input wire        I_rst_n,

    input wire        I_video_vsync,
    input wire        I_video_hsync,
    input wire        I_video_de,
    input wire        I_video_user,
    input wire        I_video_last,

    input wire[3:0]   I_debug_status,
    input wire[3:0]   I_switch_state,
    input wire[3:0]   I_algo_mode,
    input wire        I_track_enable,
    input wire[2:0]   I_track_color, // BLUE, RED, GREEN, PURPLE, YELLOW
    input wire[1:0]   I_track_shape, // 1 RECT, 2 CIRCLE, 3 TRIANGLE
    input wire I_learn_prepare,I_learn_start,
    input wire I_label_enable,
    input wire [3:0] I_label_keys_n,
    input wire [2:0] I_label_remote_action,
    input wire I_label_imaging_locked,
    output wire O_label_imaging_lock,O_label_buzzer_n,
    output wire [1:0] O_label_result,
    output wire [1:0] O_label_status_result,
    output wire [3:0] O_label_status_cause,
    output wire [23:0] O_label_status_passes,O_label_status_fails,O_label_status_unknowns,
    output wire O_barcode_valid,output wire [23:0] O_barcode_order,O_barcode_count,
    input wire I_label_zoom_supported,I_label_zoom_active,
    input wire [11:0] I_label_zoom_src_x,input wire signed [11:0] I_label_zoom_src_y,
    output wire O_label_zoom_request,output wire [11:0] O_label_zoom_src_x,
    output wire signed [11:0] O_label_zoom_src_y,
    input wire [3:0]  I_servo_state,
    input wire [11:0] I_pan_pulse_us,
    input wire [11:0] I_tilt_pulse_us,
    output reg        O_measure_update,
    output wire       O_measure_valid,
    output reg        O_measure_large,
    output reg signed [12:0] O_measure_dx,
    output reg signed [12:0] O_measure_dy,
    output wire [4:0] O_motion_regions,
    output wire O_motion_regions_valid,O_motion_regions_overflow,
    output wire [15:0] O_motion_blocks_bcd,
    input wire        I_motion_enable,
    input wire        I_black_enable,
    input wire        I_black_valid,
    input wire[11:0]  I_black_left,
    input wire[11:0]  I_black_right,
    input wire[11:0]  I_black_top,
    input wire[11:0]  I_black_bottom,
    input wire        I_black_update_toggle,
    input wire        I_zoom_active,
    input wire[23:0]  I_capture_frame_bcd,
    input wire[7:0]   I_camera_fps_bcd,
    input wire[23:0]  I_display_frame_bcd,
    input wire[7:0]   I_delay_frames_bcd,
    input wire [71:0] I_ae_debug,
    input wire I_ae_debug_toggle,
    input wire [9:0] I_diag_in_line,I_diag_spatial_line,
    input wire [8:0] I_diag_pack_line,I_diag_fifo_level,I_diag_burst_count,
    input wire [17:0] I_diag_in_frame,I_diag_spatial_frame,I_diag_pack_frame,I_diag_ddr_frame,
    input wire I_diag_burst_active,
    input wire [2:0] I_diag_line_error,I_diag_frame_error,

    output wire       O_video_rd_en,
    input wire[23:0]  I_video_rd_data,
    output wire       O_zoom_request,

    output reg        O_hdmi_vsync,
    output reg        O_hdmi_hsync,
    output reg        O_hdmi_de,
    output reg[23:0]  O_hdmi_data
);

    reg        S_video_vsync_1d;
    reg        S_video_vsync_2d;
    reg        S_video_hsync_1d;
    reg        S_video_hsync_2d;
    reg        S_video_de_1d;
    reg        S_video_de_2d;
    reg [23:0] S_video_data_1d;
    reg [23:0] S_video_data_2d;
    reg [23:0] S_video_data_raw_2d;
    reg [11:0] S_next_x,S_next_y;
    // USER may coincide with DE on the first pixel, or arrive in blanking.
    wire [11:0] S_x=I_video_user ? 12'd0 : S_next_x;
    wire [11:0] S_y=I_video_user ? 12'd0 : S_next_y;
    reg [11:0] S_x_1d;
    reg [11:0] S_x_2d;
    reg [11:0] S_y_1d;
    reg [11:0] S_y_2d;

    wire S_zoom_banner_on;
    wire [23:0] S_zoom_banner_pixel;
    assign S_zoom_banner_on=1'b0;
    assign S_zoom_banner_pixel=24'd0;

    reg        S_osd_hit;
    reg [23:0] S_osd_color;
    reg [11:0] S_logo_x;
    reg [11:0] S_logo_y;
    reg [3:0]  S_char_idx;
    reg [2:0]  S_char_row;
    reg [2:0]  S_char_col;
    reg [4:0]  S_char_bits;
    reg        S_char_on;
    reg        S_logo_blue_on;
    reg        S_logo_red_on;
    reg [11:0] S_logo_tmp_y;
    reg [3:0]  S_logo_red_band;
    reg [11:0] S_logo_red_x_start;
    reg [11:0] S_logo_red_x_end;
    reg [14:0] S_logo_addr;
    wire[24:0] S_logo_pixel=25'd0;
    reg [5:0]  S_frame_div;
    reg [11:0] S_dyn_x;
    reg [11:0] S_dyn_y;
    reg [3:0]  S_dyn_char;
    reg [2:0]  S_dyn_col;
    reg [2:0]  S_dyn_row;
    reg [4:0]  S_dyn_bits;
    reg        S_dyn_on;
    reg [23:0] S_dyn_color;
    reg [3:0]  S_dyn_digit_idx;
    reg [11:0] S_dyn_digit_x;
    reg [6:0]  S_dyn_seg;
    reg [3:0]  S_sec_d0;
    reg [3:0]  S_sec_d1;
    reg [3:0]  S_sec_d2;
    reg [3:0]  S_sec_d3;
    reg [3:0]  S_sec_d4;
    reg [3:0]  S_sec_d5;
    reg [3:0]  S_frame_d0;
    reg [3:0]  S_frame_d1;
    reg [3:0]  S_frame_d2;
    reg [3:0]  S_frame_d3;
    reg [3:0]  S_frame_d4;
    reg [3:0]  S_frame_d5;
    reg [3:0]  S_algo_mode_osd;
    reg [3:0]  S_switch_state_osd;
    reg        S_track_enable_osd;
    reg [2:0]  S_track_color_osd;
    reg [1:0]  S_track_shape_osd;
    reg        S_motion_enable_osd;
    reg        S_black_enable_osd;
    reg        S_black_valid_osd;
    reg [23:0] S_capture_frame_bcd_osd;
    reg [23:0] S_display_frame_bcd_osd;
    reg [7:0]  S_camera_fps_bcd_osd;
    reg [7:0]  S_delay_frames_bcd_osd;
    reg [2:0]  S_lbl_row;
    reg [2:0]  S_lbl_col;
    reg [1:0]  S_lbl_idx;
    reg [4:0]  S_lbl_bits;
    reg [6:0]  S_lbl_local_x;
    reg [3:0]  S_dyn_dec_digit;
    reg [4:0]  S_cn_local_x;
    reg [4:0]  S_cn_local_y;
    reg [3:0]  S_cn_col;
    reg [3:0]  S_cn_row;
    reg [15:0] S_cn_row_bits;
    reg        S_cn_on;
    reg [9:0]  S_cn_scale_x;
    reg [9:0]  S_cn_scale_y;
    reg [7:0]  S_pf_char;
    reg [4:0]  S_pf_local_x;
    reg [4:0]  S_pf_local_y;
    reg [3:0]  S_pf_col;
    reg [3:0]  S_pf_row;
    wire [15:0] S_pf_row_bits;
    reg        S_pf_on;
    reg [9:0]  S_pf_scale_x;
    reg [9:0]  S_pf_scale_y;
    reg [11:0] S_info_x;
    reg [11:0] S_info_y;
    reg [7:0]  S_info_char;
    reg [4:0]  S_info_local_x;
    reg [4:0]  S_info_local_y;
    reg [3:0]  S_info_col;
    reg [3:0]  S_info_row;
    reg        S_info_on;
    reg [15:0] S_black_x_bcd;
    reg [15:0] S_black_y_bcd;
    reg [15:0] S_black_dist_bcd;
    reg [11:0] S_bcd_bin_shift;
    reg [11:0] S_bcd_source_y;
    reg [11:0] S_bcd_source_dist;
    reg [15:0] S_bcd_work;
    reg [3:0]  S_bcd_count;
    reg [2:0]  S_bcd_value;
    reg        S_bcd_busy;
    reg [11:0] S_bcd_source_dx, S_bcd_source_dy;
    reg [15:0] S_aim_dx_bcd, S_aim_dy_bcd;
    reg [15:0] S_pan_pulse_bcd, S_tilt_pulse_bcd;
    reg [11:0] S_bcd_source_pan, S_bcd_source_tilt;
    reg S_bcd_servo_mode;
    wire S_servo_view = (S_switch_state_osd==4'b0011) ||
                        (S_switch_state_osd==4'b0100);
    reg S_bcd_track_mode;
    reg S_aim_snapshot_valid;
    reg [2:0] S_aim_snapshot_color;
    reg [1:0] S_aim_snapshot_shape;
    reg [3:0] S_aim_snapshot_view;
    reg [11:0] S_aim_center_x, S_aim_center_y;
    reg signed [12:0] S_aim_error_x, S_aim_error_y;
    reg [1:0] S_aim_h_snapshot, S_aim_v_snapshot;


    localparam LOGO_X = 12'd0;
    localparam LOGO_Y = 12'd0;
    localparam LOGO_W = 12'd160;
    localparam LOGO_H = 12'd160;

    localparam COLOR_LOGO_BLUE   = 24'h1f315c;
    localparam COLOR_LOGO_RED    = 24'hec1c2d;
    localparam COLOR_TEXT        = 24'h00e6ff;
    localparam DYN_OSD_X         = 12'd8;
    localparam DYN_OSD_Y         = 12'd168;
    localparam DYN_OSD_W         = 12'd250;
    localparam DYN_OSD_H         = 12'd544;
    localparam CN_Y_OFFSET       = 12'd2;
    localparam COLOR_DYN_TEXT    = 24'hfff200;
    localparam COLOR_TRACK_BOX   = 24'h00ffff;
    localparam COLOR_TRACK_CROSS = 24'hffffff;
    localparam COLOR_MOTION_BOX  = 24'hff3000;
    localparam COLOR_BLACK_WAIT  = 24'h00ff00;
    localparam COLOR_BLACK_LOCK  = 24'hff0000;
    localparam CHAR_AN           = 8'h80;
    localparam CHAR_LU           = 8'h81;
    localparam CHAR_B            = 8'h42;
    localparam CHAR_C            = 8'h43;
    localparam CHAR_D            = 8'h44;
    localparam CHAR_E            = 8'h45;
    localparam CHAR_F            = 8'h46;
    localparam CHAR_G            = 8'h47;
    localparam CHAR_H            = 8'h48;
    localparam CHAR_I            = 8'h49;
    localparam CHAR_L            = 8'h4c;
    localparam CHAR_A            = 8'h41;
    localparam CHAR_P            = 8'h50;
    localparam CHAR_R            = 8'h52;
    localparam CHAR_S            = 8'h53;
    localparam CHAR_M            = 8'h4d;
    localparam CHAR_N            = 8'h4e;
    localparam CHAR_O            = 8'h4f;
    localparam CHAR_T            = 8'h54;
    localparam CHAR_V            = 8'h56;
    localparam CHAR_Y            = 8'h59;
    localparam CHAR_X            = 8'h58;
    localparam CHAR_W            = 8'h57;
    localparam CHAR_SPACE        = 8'h20;
    localparam CHAR_0            = 8'h30;
    localparam CHAR_COLON        = 8'h3a;

    function [4:0] F_logo_text_bits;
        input [3:0] I_char;
        input [2:0] I_row;
        begin
            case(I_char)
                4'd0: begin
                    case(I_row) // A
                        3'd0: F_logo_text_bits = 5'b01110;
                        3'd1: F_logo_text_bits = 5'b10001;
                        3'd2: F_logo_text_bits = 5'b10001;
                        3'd3: F_logo_text_bits = 5'b11111;
                        3'd4: F_logo_text_bits = 5'b10001;
                        3'd5: F_logo_text_bits = 5'b10001;
                        3'd6: F_logo_text_bits = 5'b10001;
                        default: F_logo_text_bits = 5'b00000;
                    endcase
                end
                4'd1: begin
                    case(I_row) // N
                        3'd0: F_logo_text_bits = 5'b10001;
                        3'd1: F_logo_text_bits = 5'b11001;
                        3'd2: F_logo_text_bits = 5'b10101;
                        3'd3: F_logo_text_bits = 5'b10011;
                        3'd4: F_logo_text_bits = 5'b10001;
                        3'd5: F_logo_text_bits = 5'b10001;
                        3'd6: F_logo_text_bits = 5'b10001;
                        default: F_logo_text_bits = 5'b00000;
                    endcase
                end
                4'd2: begin
                    case(I_row) // L
                        3'd0: F_logo_text_bits = 5'b10000;
                        3'd1: F_logo_text_bits = 5'b10000;
                        3'd2: F_logo_text_bits = 5'b10000;
                        3'd3: F_logo_text_bits = 5'b10000;
                        3'd4: F_logo_text_bits = 5'b10000;
                        3'd5: F_logo_text_bits = 5'b10000;
                        3'd6: F_logo_text_bits = 5'b11111;
                        default: F_logo_text_bits = 5'b00000;
                    endcase
                end
                4'd3: begin
                    case(I_row) // O
                        3'd0: F_logo_text_bits = 5'b01110;
                        3'd1: F_logo_text_bits = 5'b10001;
                        3'd2: F_logo_text_bits = 5'b10001;
                        3'd3: F_logo_text_bits = 5'b10001;
                        3'd4: F_logo_text_bits = 5'b10001;
                        3'd5: F_logo_text_bits = 5'b10001;
                        3'd6: F_logo_text_bits = 5'b01110;
                        default: F_logo_text_bits = 5'b00000;
                    endcase
                end
                4'd4: begin
                    case(I_row) // G
                        3'd0: F_logo_text_bits = 5'b01110;
                        3'd1: F_logo_text_bits = 5'b10001;
                        3'd2: F_logo_text_bits = 5'b10000;
                        3'd3: F_logo_text_bits = 5'b10111;
                        3'd4: F_logo_text_bits = 5'b10001;
                        3'd5: F_logo_text_bits = 5'b10001;
                        3'd6: F_logo_text_bits = 5'b01110;
                        default: F_logo_text_bits = 5'b00000;
                    endcase
                end
                4'd5: begin
                    case(I_row) // I
                        3'd0: F_logo_text_bits = 5'b11111;
                        3'd1: F_logo_text_bits = 5'b00100;
                        3'd2: F_logo_text_bits = 5'b00100;
                        3'd3: F_logo_text_bits = 5'b00100;
                        3'd4: F_logo_text_bits = 5'b00100;
                        3'd5: F_logo_text_bits = 5'b00100;
                        3'd6: F_logo_text_bits = 5'b11111;
                        default: F_logo_text_bits = 5'b00000;
                    endcase
                end
                4'd6: begin
                    case(I_row) // C
                        3'd0: F_logo_text_bits = 5'b01110;
                        3'd1: F_logo_text_bits = 5'b10001;
                        3'd2: F_logo_text_bits = 5'b10000;
                        3'd3: F_logo_text_bits = 5'b10000;
                        3'd4: F_logo_text_bits = 5'b10000;
                        3'd5: F_logo_text_bits = 5'b10001;
                        3'd6: F_logo_text_bits = 5'b01110;
                        default: F_logo_text_bits = 5'b00000;
                    endcase
                end
                default: F_logo_text_bits = 5'b00000;
            endcase
        end
    endfunction

    // 7-seg bit mapping: {a,b,c,d,e,f,g}
    function [6:0] F_hex7seg;
        input [3:0] I_hex;
        begin
            case(I_hex)
                4'h0: F_hex7seg = 7'b1111110;
                4'h1: F_hex7seg = 7'b0110000;
                4'h2: F_hex7seg = 7'b1101101;
                4'h3: F_hex7seg = 7'b1111001;
                4'h4: F_hex7seg = 7'b0110011;
                4'h5: F_hex7seg = 7'b1011011;
                4'h6: F_hex7seg = 7'b1011111;
                4'h7: F_hex7seg = 7'b1110000;
                4'h8: F_hex7seg = 7'b1111111;
                4'h9: F_hex7seg = 7'b1111011;
                4'ha: F_hex7seg = 7'b1110111;
                4'hb: F_hex7seg = 7'b0011111;
                4'hc: F_hex7seg = 7'b1001110;
                4'hd: F_hex7seg = 7'b0111101;
                4'he: F_hex7seg = 7'b1001111;
                4'hf: F_hex7seg = 7'b1000111;
                default: F_hex7seg = 7'b0000000;
            endcase
        end
    endfunction

    function [4:0] F_sec_label_bits;
        input [1:0] I_idx;
        input [2:0] I_row;
        begin
            case(I_idx)
                2'd0: begin // S
                    case(I_row)
                        3'd0: F_sec_label_bits = 5'b01111;
                        3'd1: F_sec_label_bits = 5'b10000;
                        3'd2: F_sec_label_bits = 5'b10000;
                        3'd3: F_sec_label_bits = 5'b01110;
                        3'd4: F_sec_label_bits = 5'b00001;
                        3'd5: F_sec_label_bits = 5'b00001;
                        3'd6: F_sec_label_bits = 5'b11110;
                        default: F_sec_label_bits = 5'b00000;
                    endcase
                end
                2'd1: begin // E
                    case(I_row)
                        3'd0: F_sec_label_bits = 5'b11111;
                        3'd1: F_sec_label_bits = 5'b10000;
                        3'd2: F_sec_label_bits = 5'b10000;
                        3'd3: F_sec_label_bits = 5'b11110;
                        3'd4: F_sec_label_bits = 5'b10000;
                        3'd5: F_sec_label_bits = 5'b10000;
                        3'd6: F_sec_label_bits = 5'b11111;
                        default: F_sec_label_bits = 5'b00000;
                    endcase
                end
                2'd2: begin // C
                    case(I_row)
                        3'd0: F_sec_label_bits = 5'b01110;
                        3'd1: F_sec_label_bits = 5'b10001;
                        3'd2: F_sec_label_bits = 5'b10000;
                        3'd3: F_sec_label_bits = 5'b10000;
                        3'd4: F_sec_label_bits = 5'b10000;
                        3'd5: F_sec_label_bits = 5'b10001;
                        3'd6: F_sec_label_bits = 5'b01110;
                        default: F_sec_label_bits = 5'b00000;
                    endcase
                end
                default: begin // ':'
                    case(I_row)
                        3'd2: F_sec_label_bits = 5'b00100;
                        3'd5: F_sec_label_bits = 5'b00100;
                        default: F_sec_label_bits = 5'b00000;
                    endcase
                end
            endcase
        end
    endfunction

    // 16x16 Chinese bitmap rows for "an" and "lu" (road).
    function [15:0] F_cn16_row;
        input I_char; // 0: an, 1: lu
        input [3:0] I_row;
        begin
            if(!I_char) begin
                case(I_row)
                    4'd0:  F_cn16_row = 16'h0200;
                    4'd1:  F_cn16_row = 16'h0100;
                    4'd2:  F_cn16_row = 16'h3ffc;
                    4'd3:  F_cn16_row = 16'h2004;
                    4'd4:  F_cn16_row = 16'h4208;
                    4'd5:  F_cn16_row = 16'h0200;
                    4'd6:  F_cn16_row = 16'h0200;
                    4'd7:  F_cn16_row = 16'hfffe;
                    4'd8:  F_cn16_row = 16'h0420;
                    4'd9:  F_cn16_row = 16'h0820;
                    4'd10: F_cn16_row = 16'h1840;
                    4'd11: F_cn16_row = 16'h0640;
                    4'd12: F_cn16_row = 16'h0180;
                    4'd13: F_cn16_row = 16'h0260;
                    4'd14: F_cn16_row = 16'h0c10;
                    4'd15: F_cn16_row = 16'h7008;
                    default: F_cn16_row = 16'h0000;
                endcase
            end
            else begin
                case(I_row)
                    4'd0:  F_cn16_row = 16'h0040;
                    4'd1:  F_cn16_row = 16'h7c40;
                    4'd2:  F_cn16_row = 16'h4478;
                    4'd3:  F_cn16_row = 16'h4488;
                    4'd4:  F_cn16_row = 16'h4550;
                    4'd5:  F_cn16_row = 16'h7c20;
                    4'd6:  F_cn16_row = 16'h1050;
                    4'd7:  F_cn16_row = 16'h1088;
                    4'd8:  F_cn16_row = 16'h1106;
                    4'd9:  F_cn16_row = 16'h5cf8;
                    4'd10: F_cn16_row = 16'h5088;
                    4'd11: F_cn16_row = 16'h5088;
                    4'd12: F_cn16_row = 16'h5088;
                    4'd13: F_cn16_row = 16'h5c88;
                    4'd14: F_cn16_row = 16'he0f8;
                    4'd15: F_cn16_row = 16'h0088;
                    default: F_cn16_row = 16'h0000;
                endcase
            end
        end
    endfunction

    function [4:0] F_dyn_char_bits;
        input [3:0] I_char;
        input [2:0] I_row;
        begin
            case(I_char)
                4'h0: begin case(I_row) 3'd0:F_dyn_char_bits=5'b01110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b10011; 3'd3:F_dyn_char_bits=5'b10101; 3'd4:F_dyn_char_bits=5'b11001; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b01110; default:F_dyn_char_bits=5'b00000; endcase end
                4'h1: begin case(I_row) 3'd0:F_dyn_char_bits=5'b00100; 3'd1:F_dyn_char_bits=5'b01100; 3'd2:F_dyn_char_bits=5'b00100; 3'd3:F_dyn_char_bits=5'b00100; 3'd4:F_dyn_char_bits=5'b00100; 3'd5:F_dyn_char_bits=5'b00100; 3'd6:F_dyn_char_bits=5'b01110; default:F_dyn_char_bits=5'b00000; endcase end
                4'h2: begin case(I_row) 3'd0:F_dyn_char_bits=5'b01110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b00001; 3'd3:F_dyn_char_bits=5'b00110; 3'd4:F_dyn_char_bits=5'b01000; 3'd5:F_dyn_char_bits=5'b10000; 3'd6:F_dyn_char_bits=5'b11111; default:F_dyn_char_bits=5'b00000; endcase end
                4'h3: begin case(I_row) 3'd0:F_dyn_char_bits=5'b11110; 3'd1:F_dyn_char_bits=5'b00001; 3'd2:F_dyn_char_bits=5'b00001; 3'd3:F_dyn_char_bits=5'b01110; 3'd4:F_dyn_char_bits=5'b00001; 3'd5:F_dyn_char_bits=5'b00001; 3'd6:F_dyn_char_bits=5'b11110; default:F_dyn_char_bits=5'b00000; endcase end
                4'h4: begin case(I_row) 3'd0:F_dyn_char_bits=5'b00010; 3'd1:F_dyn_char_bits=5'b00110; 3'd2:F_dyn_char_bits=5'b01010; 3'd3:F_dyn_char_bits=5'b10010; 3'd4:F_dyn_char_bits=5'b11111; 3'd5:F_dyn_char_bits=5'b00010; 3'd6:F_dyn_char_bits=5'b00010; default:F_dyn_char_bits=5'b00000; endcase end
                4'h5: begin case(I_row) 3'd0:F_dyn_char_bits=5'b11111; 3'd1:F_dyn_char_bits=5'b10000; 3'd2:F_dyn_char_bits=5'b11110; 3'd3:F_dyn_char_bits=5'b00001; 3'd4:F_dyn_char_bits=5'b00001; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b01110; default:F_dyn_char_bits=5'b00000; endcase end
                4'h6: begin case(I_row) 3'd0:F_dyn_char_bits=5'b00110; 3'd1:F_dyn_char_bits=5'b01000; 3'd2:F_dyn_char_bits=5'b10000; 3'd3:F_dyn_char_bits=5'b11110; 3'd4:F_dyn_char_bits=5'b10001; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b01110; default:F_dyn_char_bits=5'b00000; endcase end
                4'h7: begin case(I_row) 3'd0:F_dyn_char_bits=5'b11111; 3'd1:F_dyn_char_bits=5'b00001; 3'd2:F_dyn_char_bits=5'b00010; 3'd3:F_dyn_char_bits=5'b00100; 3'd4:F_dyn_char_bits=5'b01000; 3'd5:F_dyn_char_bits=5'b01000; 3'd6:F_dyn_char_bits=5'b01000; default:F_dyn_char_bits=5'b00000; endcase end
                4'h8: begin case(I_row) 3'd0:F_dyn_char_bits=5'b01110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b10001; 3'd3:F_dyn_char_bits=5'b01110; 3'd4:F_dyn_char_bits=5'b10001; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b01110; default:F_dyn_char_bits=5'b00000; endcase end
                4'h9: begin case(I_row) 3'd0:F_dyn_char_bits=5'b01110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b10001; 3'd3:F_dyn_char_bits=5'b01111; 3'd4:F_dyn_char_bits=5'b00001; 3'd5:F_dyn_char_bits=5'b00010; 3'd6:F_dyn_char_bits=5'b11100; default:F_dyn_char_bits=5'b00000; endcase end
                4'ha: begin case(I_row) 3'd0:F_dyn_char_bits=5'b01110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b10001; 3'd3:F_dyn_char_bits=5'b11111; 3'd4:F_dyn_char_bits=5'b10001; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b10001; default:F_dyn_char_bits=5'b00000; endcase end
                4'hb: begin case(I_row) 3'd0:F_dyn_char_bits=5'b11110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b10001; 3'd3:F_dyn_char_bits=5'b11110; 3'd4:F_dyn_char_bits=5'b10001; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b11110; default:F_dyn_char_bits=5'b00000; endcase end
                4'hc: begin case(I_row) 3'd0:F_dyn_char_bits=5'b01110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b10000; 3'd3:F_dyn_char_bits=5'b10000; 3'd4:F_dyn_char_bits=5'b10000; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b01110; default:F_dyn_char_bits=5'b00000; endcase end
                4'hd: begin case(I_row) 3'd0:F_dyn_char_bits=5'b11110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b10001; 3'd3:F_dyn_char_bits=5'b10001; 3'd4:F_dyn_char_bits=5'b10001; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b11110; default:F_dyn_char_bits=5'b00000; endcase end
                4'he: begin case(I_row) 3'd0:F_dyn_char_bits=5'b11111; 3'd1:F_dyn_char_bits=5'b10000; 3'd2:F_dyn_char_bits=5'b10000; 3'd3:F_dyn_char_bits=5'b11110; 3'd4:F_dyn_char_bits=5'b10000; 3'd5:F_dyn_char_bits=5'b10000; 3'd6:F_dyn_char_bits=5'b11111; default:F_dyn_char_bits=5'b00000; endcase end
                4'hf: begin case(I_row) 3'd0:F_dyn_char_bits=5'b11111; 3'd1:F_dyn_char_bits=5'b10000; 3'd2:F_dyn_char_bits=5'b10000; 3'd3:F_dyn_char_bits=5'b11110; 3'd4:F_dyn_char_bits=5'b10000; 3'd5:F_dyn_char_bits=5'b10000; 3'd6:F_dyn_char_bits=5'b10000; default:F_dyn_char_bits=5'b00000; endcase end
                default: F_dyn_char_bits = 5'b00000;
            endcase
        end
    endfunction

    // Unified prefix character library (16x16 rows): an/lu/S/E/C/:
    function [15:0] F_osd_char16_row;
        input [7:0] I_char;
        input [3:0] I_row;
        begin
            case(I_char)
                CHAR_AN: begin
                    case(I_row)
                        4'd0:  F_osd_char16_row = 16'h0200;
                        4'd1:  F_osd_char16_row = 16'h0100;
                        4'd2:  F_osd_char16_row = 16'h3ffc;
                        4'd3:  F_osd_char16_row = 16'h2004;
                        4'd4:  F_osd_char16_row = 16'h4208;
                        4'd5:  F_osd_char16_row = 16'h0200;
                        4'd6:  F_osd_char16_row = 16'h0200;
                        4'd7:  F_osd_char16_row = 16'hfffe;
                        4'd8:  F_osd_char16_row = 16'h0420;
                        4'd9:  F_osd_char16_row = 16'h0820;
                        4'd10: F_osd_char16_row = 16'h1840;
                        4'd11: F_osd_char16_row = 16'h0640;
                        4'd12: F_osd_char16_row = 16'h0180;
                        4'd13: F_osd_char16_row = 16'h0260;
                        4'd14: F_osd_char16_row = 16'h0c10;
                        4'd15: F_osd_char16_row = 16'h7008;
                        default: F_osd_char16_row = 16'h0000;
                    endcase
                end
                CHAR_LU: begin
                    case(I_row)
                        4'd0:  F_osd_char16_row = 16'h0040;
                        4'd1:  F_osd_char16_row = 16'h7c40;
                        4'd2:  F_osd_char16_row = 16'h4478;
                        4'd3:  F_osd_char16_row = 16'h4488;
                        4'd4:  F_osd_char16_row = 16'h4550;
                        4'd5:  F_osd_char16_row = 16'h7c20;
                        4'd6:  F_osd_char16_row = 16'h1050;
                        4'd7:  F_osd_char16_row = 16'h1088;
                        4'd8:  F_osd_char16_row = 16'h1106;
                        4'd9:  F_osd_char16_row = 16'h5cf8;
                        4'd10: F_osd_char16_row = 16'h5088;
                        4'd11: F_osd_char16_row = 16'h5088;
                        4'd12: F_osd_char16_row = 16'h5088;
                        4'd13: F_osd_char16_row = 16'h5c88;
                        4'd14: F_osd_char16_row = 16'he0f8;
                        4'd15: F_osd_char16_row = 16'h0088;
                        default: F_osd_char16_row = 16'h0000;
                    endcase
                end
                CHAR_C: begin
                    case(I_row)
                        4'd2:  F_osd_char16_row = 16'h03f0;
                        4'd3:  F_osd_char16_row = 16'h0c0c;
                        4'd4:  F_osd_char16_row = 16'h1800;
                        4'd5:  F_osd_char16_row = 16'h3000;
                        4'd6:  F_osd_char16_row = 16'h3000;
                        4'd7:  F_osd_char16_row = 16'h3000;
                        4'd8:  F_osd_char16_row = 16'h3000;
                        4'd9:  F_osd_char16_row = 16'h3000;
                        4'd10: F_osd_char16_row = 16'h1800;
                        4'd11: F_osd_char16_row = 16'h0c0c;
                        4'd12: F_osd_char16_row = 16'h03f0;
                        default: F_osd_char16_row = 16'h0000;
                    endcase
                end
                CHAR_E: begin
                    case(I_row)
                        4'd2:  F_osd_char16_row = 16'h3e00;
                        4'd3:  F_osd_char16_row = 16'h3000;
                        4'd4:  F_osd_char16_row = 16'h3000;
                        4'd5:  F_osd_char16_row = 16'h3e00;
                        4'd6:  F_osd_char16_row = 16'h3000;
                        4'd7:  F_osd_char16_row = 16'h3000;
                        4'd8:  F_osd_char16_row = 16'h3000;
                        4'd9:  F_osd_char16_row = 16'h3e00;
                        default: F_osd_char16_row = 16'h0000;
                    endcase
                end
                CHAR_S: begin
                    case(I_row)
                        4'd2:  F_osd_char16_row = 16'h1e00;
                        4'd3:  F_osd_char16_row = 16'h3000;
                        4'd4:  F_osd_char16_row = 16'h3000;
                        4'd5:  F_osd_char16_row = 16'h1c00;
                        4'd6:  F_osd_char16_row = 16'h0600;
                        4'd7:  F_osd_char16_row = 16'h0600;
                        4'd8:  F_osd_char16_row = 16'h0600;
                        4'd9:  F_osd_char16_row = 16'h3c00;
                        default: F_osd_char16_row = 16'h0000;
                    endcase
                end
                CHAR_COLON: begin
                    case(I_row)
                        4'd6:  F_osd_char16_row = 16'h0180;
                        4'd7:  F_osd_char16_row = 16'h0180;
                        4'd10: F_osd_char16_row = 16'h0180;
                        4'd11: F_osd_char16_row = 16'h0180;
                        default: F_osd_char16_row = 16'h0000;
                    endcase
                end
                default: F_osd_char16_row = 16'h0000;
            endcase
        end
    endfunction

    function [7:0] F_color_name;
        input [2:0] I_color;
        input [3:0] I_index;
        begin
            F_color_name = CHAR_SPACE;
            case(I_color)
                3'd0: case(I_index)
                    4'd0: F_color_name = CHAR_B;
                    4'd1: F_color_name = CHAR_L;
                    4'd2: F_color_name = 8'h55;
                    4'd3: F_color_name = CHAR_E;
                    default: F_color_name = CHAR_SPACE;
                endcase
                3'd1: case(I_index)
                    4'd0: F_color_name = CHAR_R;
                    4'd1: F_color_name = CHAR_E;
                    4'd2: F_color_name = CHAR_D;
                    default: F_color_name = CHAR_SPACE;
                endcase
                3'd2: case(I_index)
                    4'd0: F_color_name = CHAR_G;
                    4'd1: F_color_name = CHAR_R;
                    4'd2: F_color_name = CHAR_E;
                    4'd3: F_color_name = CHAR_E;
                    4'd4: F_color_name = CHAR_N;
                    default: F_color_name = CHAR_SPACE;
                endcase
                3'd5: case(I_index)
                    0:F_color_name="C";1:F_color_name="U";2:F_color_name="S";
                    3:F_color_name="T";4:F_color_name="O";5:F_color_name="M";
                    default:F_color_name=CHAR_SPACE;
                endcase
                default: case(I_index)
                    4'd0: F_color_name = 8'h55;
                    4'd1: F_color_name = CHAR_N;
                    4'd2: F_color_name = 8'h4b;
                    4'd3: F_color_name = CHAR_N;
                    4'd4: F_color_name = CHAR_O;
                    4'd5: F_color_name = CHAR_W;
                    4'd6: F_color_name = CHAR_N;
                    default: F_color_name = CHAR_SPACE;
                endcase
            endcase
        end
    endfunction

    function [7:0] F_shape_name;
        input [1:0] I_shape;
        input [3:0] I_index;
        begin
            F_shape_name = CHAR_SPACE;
            case(I_shape)
                2'd1: case(I_index)
                    4'd0: F_shape_name = CHAR_R;
                    4'd1: F_shape_name = CHAR_E;
                    4'd2: F_shape_name = CHAR_C;
                    4'd3: F_shape_name = CHAR_T;
                    default: F_shape_name = CHAR_SPACE;
                endcase
                2'd2: case(I_index)
                    4'd0: F_shape_name = CHAR_C;
                    4'd1: F_shape_name = CHAR_I;
                    4'd2: F_shape_name = CHAR_R;
                    4'd3: F_shape_name = CHAR_C;
                    4'd4: F_shape_name = CHAR_L;
                    4'd5: F_shape_name = CHAR_E;
                    default: F_shape_name = CHAR_SPACE;
                endcase
                2'd3: case(I_index)
                    4'd0: F_shape_name = CHAR_T;
                    4'd1: F_shape_name = CHAR_R;
                    4'd2: F_shape_name = CHAR_I;
                    4'd3: F_shape_name = CHAR_A;
                    4'd4: F_shape_name = CHAR_N;
                    4'd5: F_shape_name = CHAR_G;
                    4'd6: F_shape_name = CHAR_L;
                    4'd7: F_shape_name = CHAR_E;
                    default: F_shape_name = CHAR_SPACE;
                endcase
                default: case(I_index)
                    4'd0: F_shape_name = 8'h55;
                    4'd1: F_shape_name = CHAR_N;
                    4'd2: F_shape_name = 8'h4b;
                    4'd3: F_shape_name = CHAR_N;
                    4'd4: F_shape_name = CHAR_O;
                    4'd5: F_shape_name = CHAR_W;
                    4'd6: F_shape_name = CHAR_N;
                    default: F_shape_name = CHAR_SPACE;
                endcase
            endcase
        end
    endfunction

    function [7:0] F_aim_direction_name;
        input [1:0] I_direction;
        input I_vertical;
        input [3:0] I_index;
        begin
            F_aim_direction_name = CHAR_SPACE;
            case({I_vertical,I_direction})
                3'd1: case(I_index)
                    4'd0: F_aim_direction_name = 8'h4c;
                    4'd1: F_aim_direction_name = 8'h45;
                    4'd2: F_aim_direction_name = 8'h46;
                    4'd3: F_aim_direction_name = 8'h54;
                    default: F_aim_direction_name = CHAR_SPACE;
                endcase
                3'd2: case(I_index)
                    4'd0: F_aim_direction_name = 8'h52;
                    4'd1: F_aim_direction_name = 8'h49;
                    4'd2: F_aim_direction_name = 8'h47;
                    4'd3: F_aim_direction_name = 8'h48;
                    4'd4: F_aim_direction_name = 8'h54;
                    default: F_aim_direction_name = CHAR_SPACE;
                endcase
                3'd5: case(I_index)
                    4'd0: F_aim_direction_name = 8'h55;
                    4'd1: F_aim_direction_name = 8'h50;
                    default: F_aim_direction_name = CHAR_SPACE;
                endcase
                3'd6: case(I_index)
                    4'd0: F_aim_direction_name = 8'h44;
                    4'd1: F_aim_direction_name = 8'h4f;
                    4'd2: F_aim_direction_name = 8'h57;
                    4'd3: F_aim_direction_name = 8'h4e;
                    default: F_aim_direction_name = CHAR_SPACE;
                endcase
                default: case(I_index)
                    4'd0: F_aim_direction_name = 8'h53;
                    4'd1: F_aim_direction_name = 8'h54;
                    4'd2: F_aim_direction_name = 8'h4f;
                    4'd3: F_aim_direction_name = 8'h50;
                    default: F_aim_direction_name = CHAR_SPACE;
                endcase
            endcase
        end
    endfunction

    function F_char_pixel;
        input [15:0] I_row_bits;
        input [3:0]  I_col;
        begin
            case(I_col)
                4'd0:  F_char_pixel = I_row_bits[15];
                4'd1:  F_char_pixel = I_row_bits[14];
                4'd2:  F_char_pixel = I_row_bits[13];
                4'd3:  F_char_pixel = I_row_bits[12];
                4'd4:  F_char_pixel = I_row_bits[11];
                4'd5:  F_char_pixel = I_row_bits[10];
                4'd6:  F_char_pixel = I_row_bits[9];
                4'd7:  F_char_pixel = I_row_bits[8];
                4'd8:  F_char_pixel = I_row_bits[7];
                4'd9:  F_char_pixel = I_row_bits[6];
                4'd10: F_char_pixel = I_row_bits[5];
                4'd11: F_char_pixel = I_row_bits[4];
                4'd12: F_char_pixel = I_row_bits[3];
                4'd13: F_char_pixel = I_row_bits[2];
                4'd14: F_char_pixel = I_row_bits[1];
                4'd15: F_char_pixel = I_row_bits[0];
            endcase
        end
    endfunction

    assign O_video_rd_en = I_video_de;

    wire        S_track_valid;
    wire [11:0] S_track_left;
    wire [11:0] S_track_right;
    wire [11:0] S_track_top;
    wire [11:0] S_track_bottom;
    wire [11:0] S_track_center_x;
    wire [11:0] S_track_center_y;
    wire        S_track_border_2d;
    wire        S_track_cross_2d;
    wire        S_track_result_update;
    reg         S_measure_pending, S_measure_snapshot_valid;
    reg [2:0]   S_measure_color;
    reg [1:0]   S_measure_shape;
    reg [3:0]   S_measure_view, S_servo_state_osd;
    wire        S_track_detect_valid;
    wire [1:0]  S_track_shape;
    wire        S_track_candidate_valid;
    wire        S_track_candidate_ok;
    wire        S_track_mask_pixel;
    wire        S_track_mask_seen;
    wire [11:0] S_track_raw_left;
    wire [11:0] S_track_raw_right;
    wire [11:0] S_track_raw_top;
    wire [11:0] S_track_raw_bottom;
    wire        S_track_raw_border_2d;
    wire        S_track_mask_view = (S_switch_state_osd == 4'b0001);
    // Blend selected mask pixels with 25% cyan while retaining the camera image.
    wire [9:0] S_mask_fill_red =
                    ({2'b00,S_video_data_raw_2d[23:16]} << 1) +
                    {2'b00,S_video_data_raw_2d[23:16]};
    wire [9:0] S_mask_fill_green =
                    ({2'b00,S_video_data_raw_2d[15:8]} << 1) +
                    {2'b00,S_video_data_raw_2d[15:8]} + 10'd255;
    wire [9:0] S_mask_fill_blue =
                    ({2'b00,S_video_data_raw_2d[7:0]} << 1) +
                    {2'b00,S_video_data_raw_2d[7:0]} + 10'd255;
    wire [23:0] S_track_mask_fill =
                    {S_mask_fill_red[9:2],S_mask_fill_green[9:2],
                     S_mask_fill_blue[9:2]};
    reg         S_track_frame_start_1d;
    reg         S_track_frame_start_2d;
    wire        S_motion_valid;
    wire [11:0] S_motion_left;
    wire [11:0] S_motion_right;
    wire [11:0] S_motion_top;
    wire [11:0] S_motion_bottom;
    wire [15:0] S_motion_count_bcd;
    assign O_motion_blocks_bcd=S_motion_count_bcd;
    wire        S_motion_border_1d;
    // Format the centre measured from the actual displayed pixels. In zoom
    // mode, report its inverse-mapped original-camera coordinates.
    wire [11:0] S_display_center_sensor_x = I_zoom_active ?
                    ((S_track_center_x >> 1) + 12'd320) : S_track_center_x;
    wire [11:0] S_display_center_sensor_y = I_zoom_active ?
                    ((S_track_center_y >> 1) + 12'd180) : S_track_center_y;
    wire [11:0] S_display_center_dx = (S_display_center_sensor_x >= 12'd640) ?
                    (S_display_center_sensor_x - 12'd640) :
                    (12'd640 - S_display_center_sensor_x);
    wire [11:0] S_display_center_dy = (S_display_center_sensor_y >= 12'd360) ?
                    (S_display_center_sensor_y - 12'd360) :
                    (12'd360 - S_display_center_sensor_y);
    wire [11:0] S_display_center_distance = S_display_center_dx + S_display_center_dy;
    localparam [11:0] AIM_CENTER_X = IMG_WIDTH / 2;
    localparam [11:0] AIM_CENTER_Y = IMG_HEIGHT / 2;
    localparam [11:0] AIM_DEADZONE = 12'd12;
    // 0 STOP, 1 negative (LEFT/UP), 2 positive (RIGHT/DOWN).
    // These image-space directions are not servo electrical polarities.
    wire S_custom_valid,S_custom_generation,S_custom_mask,S_custom_preparing;
    wire S_aim_detect_now = S_track_enable_osd && I_track_enable &&
                    !S_black_enable_osd && !S_custom_preparing && S_track_valid && S_track_detect_valid &&
                    (S_track_color_osd == I_track_color) &&
                    (S_track_shape_osd == I_track_shape) &&
                    (S_track_shape == S_track_shape_osd);
    wire signed [12:0] S_aim_raw_dx = $signed({1'b0,S_track_center_x}) -
                                     $signed({1'b0,AIM_CENTER_X});
    wire signed [12:0] S_aim_raw_dy = $signed({1'b0,S_track_center_y}) -
                                     $signed({1'b0,AIM_CENTER_Y});
    // The detector publishes only completed distinct camera images.
    // Wait one clock for its registered box/valid result, then export atomically.
    wire [11:0] S_measure_box_width=S_track_right-S_track_left;
    wire [11:0] S_measure_box_height=S_track_bottom-S_track_top;
    assign O_measure_valid = S_measure_snapshot_valid && S_aim_detect_now &&
                    (S_measure_color == I_track_color) &&
                    (S_measure_shape == I_track_shape) &&
                    (S_measure_view == I_switch_state);
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_measure_pending<=0; O_measure_update<=0;
            S_measure_snapshot_valid<=0; O_measure_dx<=0; O_measure_dy<=0; O_measure_large<=0;
            S_measure_color<=0; S_measure_shape<=0; S_measure_view<=0;
        end
        else begin
            S_measure_pending<=S_track_result_update;
            O_measure_update<=S_measure_pending && I_track_enable;
            if(!I_track_enable) begin S_measure_snapshot_valid<=0;O_measure_large<=0;end
            else if(S_measure_pending) begin
                S_measure_snapshot_valid<=S_aim_detect_now;
                // Image footprint is a conservative proximity proxy, not range.
                if(!S_aim_detect_now) O_measure_large<=0;
                else if(S_measure_box_width>=384 || S_measure_box_height>=288) O_measure_large<=1;
                else if(S_measure_box_width<=320 && S_measure_box_height<=240) O_measure_large<=0;
                O_measure_dx<=S_aim_detect_now ? S_aim_raw_dx : 13'sd0;
                O_measure_dy<=S_aim_detect_now ? S_aim_raw_dy : 13'sd0;
                S_measure_color<=I_track_color; S_measure_shape<=I_track_shape;
                S_measure_view<=I_switch_state;
            end
        end
    end
    wire S_aim_valid;
    wire [3:0] S_learn_status;
    wire [23:0] S_learn_rgb;
    wire S_custom_selected=I_track_color==3'd5 && I_switch_state!=4'd1;
    target_color_learning u_target_color_learning (
        .I_clk(I_clk),.I_rst_n(I_rst_n),.I_selected(S_custom_selected),
        .I_learn_enable(I_switch_state==4'd4),
        .I_prepare(I_learn_prepare),.I_start(I_learn_start),
        .I_de(S_video_de_2d && !(I_label_zoom_active===1'b1)),.I_x(S_x_2d),.I_y(S_y_2d),
        .I_rgb(S_video_data_raw_2d),.I_frame_id(S_display_frame_bcd_osd),
        .O_valid(S_custom_valid),.O_status(S_learn_status),.O_rgb(S_learn_rgb),
        .O_generation(S_custom_generation),.O_mask(S_custom_mask),.O_preparing(S_custom_preparing)
    );
    wire S_teach_overlay_on;
    wire [23:0] S_teach_overlay_pixel;
    reg S_teach_overlay_on_2d;
    target_teach_overlay u_target_teach_overlay (
        .I_clk(I_clk),.I_rst_n(I_rst_n),
        .I_enable((I_switch_state==4'd1 || I_switch_state==4'd3 || I_switch_state==4'd4) && I_track_enable),
        .I_custom(S_custom_selected),.I_teach_mode(I_switch_state!=4'd3),.I_preparing(S_custom_preparing),
        .I_status(S_learn_status),.I_rgb(S_learn_rgb),.I_learn_valid(S_custom_valid),
        .I_x(S_x),.I_y(S_y),.I_target_valid(S_aim_valid && !S_custom_preparing),
        .I_center_x(S_aim_center_x),.I_center_y(S_aim_center_y),
        .I_x_bcd(S_black_x_bcd),.I_y_bcd(S_black_y_bcd),
        .O_on(S_teach_overlay_on),.O_pixel(S_teach_overlay_pixel)
    );
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) S_teach_overlay_on_2d<=0;
        else S_teach_overlay_on_2d<=S_teach_overlay_on;
    end
    wire [11:0] S_aim_abs_dx = S_aim_raw_dx[12] ? -S_aim_raw_dx : S_aim_raw_dx;
    wire [11:0] S_aim_abs_dy = S_aim_raw_dy[12] ? -S_aim_raw_dy : S_aim_raw_dy;
    // Mask stale held boxes, colour/view transitions and incomplete formatting.
    assign S_aim_valid = S_aim_detect_now && S_aim_snapshot_valid && !S_bcd_busy &&
                    (S_aim_snapshot_color == S_track_color_osd) &&
                    (S_aim_snapshot_shape == S_track_shape_osd) &&
                    (S_aim_snapshot_view == S_switch_state_osd);
    wire signed [12:0] S_aim_dx = S_aim_valid ? S_aim_error_x : 13'sd0;
    wire signed [12:0] S_aim_dy = S_aim_valid ? S_aim_error_y : 13'sd0;
    wire [1:0] S_aim_h_direction = S_aim_valid ? S_aim_h_snapshot : 2'd0;
    wire [1:0] S_aim_v_direction = S_aim_valid ? S_aim_v_snapshot : 2'd0;
    wire S_aim_centered = S_aim_valid &&
                    (S_aim_h_direction == 2'd0) && (S_aim_v_direction == 2'd0);
    wire S_aim_center_cross_2d =
                    ((((S_x_2d + 12'd16) >= AIM_CENTER_X) &&
                      (S_x_2d <= (AIM_CENTER_X + 12'd16)) &&
                      ((S_y_2d + 12'd1) >= AIM_CENTER_Y) &&
                      (S_y_2d <= (AIM_CENTER_Y + 12'd1))) ||
                     (((S_y_2d + 12'd16) >= AIM_CENTER_Y) &&
                      (S_y_2d <= (AIM_CENTER_Y + 12'd16)) &&
                      ((S_x_2d + 12'd1) >= AIM_CENTER_X) &&
                      (S_x_2d <= (AIM_CENTER_X + 12'd1))));
    wire [3:0] S_bcd_add0 = (S_bcd_work[3:0] >= 4'd5) ?
                            (S_bcd_work[3:0] + 4'd3) : S_bcd_work[3:0];
    wire [3:0] S_bcd_add1 = (S_bcd_work[7:4] >= 4'd5) ?
                            (S_bcd_work[7:4] + 4'd3) : S_bcd_work[7:4];
    wire [3:0] S_bcd_add2 = (S_bcd_work[11:8] >= 4'd5) ?
                            (S_bcd_work[11:8] + 4'd3) : S_bcd_work[11:8];
    wire [3:0] S_bcd_add3 = (S_bcd_work[15:12] >= 4'd5) ?
                            (S_bcd_work[15:12] + 4'd3) : S_bcd_work[15:12];
    wire [15:0] S_bcd_next = {S_bcd_add3[2:0], S_bcd_add2,
                              S_bcd_add1, S_bcd_add0, S_bcd_bin_shift[11]};
    wire [11:0] S_black_input_center_x =
                    (I_black_left + I_black_right) >> 1;
    wire [11:0] S_black_input_center_y =
                    (I_black_top + I_black_bottom) >> 1;
    wire [11:0] S_black_input_dx = (S_black_input_center_x >= 12'd640) ?
                    (S_black_input_center_x - 12'd640) :
                    (12'd640 - S_black_input_center_x);
    wire [11:0] S_black_input_dy = (S_black_input_center_y >= 12'd360) ?
                    (S_black_input_center_y - 12'd360) :
                    (12'd360 - S_black_input_center_y);
    wire [11:0] S_black_input_distance = S_black_input_dx + S_black_input_dy;
    wire S_black_enter_condition = I_black_valid &&
                    (I_black_left >= 12'd320) && (I_black_right <= 12'd959) &&
                    (I_black_top >= 12'd180) && (I_black_bottom <= 12'd539) &&
                    (S_black_input_distance <= 12'd120);
    wire S_black_exit_condition = !I_black_valid ||
                    (I_black_left < 12'd320) || (I_black_right > 12'd959) ||
                    (I_black_top < 12'd180) || (I_black_bottom > 12'd539) ||
                    (S_black_input_distance > 12'd160);

    rectangle_tracker #(
        .IMG_WIDTH  ( IMG_WIDTH  ),
        .IMG_HEIGHT ( IMG_HEIGHT )
    ) u_rectangle_tracker (
        .I_clk          ( I_clk              ),
        .I_rst_n        ( I_rst_n            ),
        .I_enable       ( (S_track_enable_osd && !S_custom_preparing) || S_black_enable_osd ),
        .I_de           ( S_video_de_2d      ),
        .I_x            ( S_x_2d             ),
        .I_y            ( S_y_2d             ),
        .I_rgb          ( S_video_data_raw_2d),
        .I_frame_id     ( S_display_frame_bcd_osd ),
        .I_require_rectangle ( S_track_enable_osd ),
        .I_color_select ( S_black_enable_osd ? 3'd0 : S_track_color_osd ),
        .I_shape_select ( S_track_shape_osd ),
        .I_custom_mask  ( S_custom_mask ),
        .I_view_id      ( {S_black_enable_osd,(S_black_enable_osd ? I_zoom_active:S_custom_generation)} ),
        .O_result_update ( S_track_result_update ),
        .O_detect_valid ( S_track_detect_valid ),
        .O_detect_shape ( S_track_shape       ),
        .O_candidate_valid ( S_track_candidate_valid ),
        .O_candidate_ok ( S_track_candidate_ok ),
        .O_mask_pixel   ( S_track_mask_pixel ),
        .O_mask_seen    ( S_track_mask_seen ),
        .O_raw_left     ( S_track_raw_left ),
        .O_raw_right    ( S_track_raw_right ),
        .O_raw_top      ( S_track_raw_top ),
        .O_raw_bottom   ( S_track_raw_bottom ),
        .O_track_valid  ( S_track_valid      ),
        .O_left         ( S_track_left       ),
        .O_right        ( S_track_right      ),
        .O_top          ( S_track_top        ),
        .O_bottom       ( S_track_bottom     )
    );

    assign S_track_center_x = (S_track_left + S_track_right) >> 1;
    assign S_track_center_y = (S_track_top + S_track_bottom) >> 1;
    assign S_track_border_2d = S_track_valid &&
                            (S_x_2d >= S_track_left) &&
                            (S_x_2d <= S_track_right) &&
                            (S_y_2d >= S_track_top) &&
                            (S_y_2d <= S_track_bottom) &&
                            (((S_x_2d - S_track_left) < 12'd3) ||
                             ((S_track_right - S_x_2d) < 12'd3) ||
                             ((S_y_2d - S_track_top) < 12'd3) ||
                             ((S_track_bottom - S_y_2d) < 12'd3));
    assign S_track_cross_2d = S_aim_valid &&
                           ((((S_x_2d + 12'd12) >= S_aim_center_x) &&
                             (S_x_2d <= (S_aim_center_x + 12'd12)) &&
                             ((S_y_2d + 12'd1) >= S_aim_center_y) &&
                             (S_y_2d <= (S_aim_center_y + 12'd1))) ||
                            (((S_y_2d + 12'd12) >= S_aim_center_y) &&
                             (S_y_2d <= (S_aim_center_y + 12'd12)) &&
                             ((S_x_2d + 12'd1) >= S_aim_center_x) &&
                             (S_x_2d <= (S_aim_center_x + 12'd1))));

    // Yellow: unpadded candidate before rectangle rejection and smoothing.
    assign S_track_raw_border_2d = S_track_candidate_valid &&
                    (S_x_2d >= S_track_raw_left) && (S_x_2d <= S_track_raw_right) &&
                    (S_y_2d >= S_track_raw_top) && (S_y_2d <= S_track_raw_bottom) &&
                    (((S_x_2d - S_track_raw_left) < 12'd2) ||
                     ((S_track_raw_right - S_x_2d) < 12'd2) ||
                     ((S_y_2d - S_track_raw_top) < 12'd2) ||
                     ((S_track_raw_bottom - S_y_2d) < 12'd2));

    motion_detector #(
        .IMG_WIDTH  ( IMG_WIDTH  ),
        .IMG_HEIGHT ( IMG_HEIGHT )
    ) u_motion_detector (
        .I_clk          ( I_clk                    ),
        .I_rst_n        ( I_rst_n                  ),
        .I_enable       ( S_motion_enable_osd      ),
        .I_frame_start  ( I_video_user             ),
        .I_frame_id     ( I_display_frame_bcd      ),
        .I_de           ( S_video_de_2d            ),
        .I_x            ( S_x_2d                   ),
        .I_y            ( S_y_2d                   ),
        .I_rgb          ( S_video_data_raw_2d      ),
        .O_motion_valid ( S_motion_valid           ),
        .O_left         ( S_motion_left            ),
        .O_right        ( S_motion_right           ),
        .O_top          ( S_motion_top             ),
        .O_bottom       ( S_motion_bottom          ),
        .O_count_bcd    ( S_motion_count_bcd       ),
        .O_regions      ( O_motion_regions         ),
        .O_regions_valid( O_motion_regions_valid   ),
        .O_regions_overflow(O_motion_regions_overflow)
    );

    assign S_motion_border_1d = S_motion_valid &&
                               (S_x_1d >= S_motion_left) &&
                               (S_x_1d <= S_motion_right) &&
                               (S_y_1d >= S_motion_top) &&
                               (S_y_1d <= S_motion_bottom) &&
                               (((S_x_1d - S_motion_left) < 12'd3) ||
                                ((S_motion_right - S_x_1d) < 12'd3) ||
                                ((S_y_1d - S_motion_top) < 12'd3) ||
                                ((S_motion_bottom - S_y_1d) < 12'd3));

    wire [24:0] S_compact_logo;
    v34_logo_rom #(.X(LOGO_X),.Y(LOGO_Y)) u_compact_logo (
        .I_clk(I_clk),.I_x(S_x),.I_y(S_y),.I_label(I_label_enable),.O_pixel(S_compact_logo)
    );

    osd_char_lib u_osd_char_lib(
        .I_char     ( S_pf_char     ),
        .I_row      ( S_pf_row      ),
        .O_row_bits ( S_pf_row_bits )
    );

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_next_x <= 12'd0;
            S_next_y <= 12'd0;
        end
        else if(I_video_user) begin
            S_next_x <= I_video_de ? 12'd1 : 12'd0;
            S_next_y <= 12'd0;
        end
        else if(I_video_de) begin
            if(I_video_last) begin
                S_next_x <= 12'd0;
                S_next_y <= S_y + 12'd1;
            end
            else S_next_x <= S_x + 12'd1;
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_frame_div <= 6'd0;
            S_sec_d0 <= 4'd0;
            S_sec_d1 <= 4'd0;
            S_sec_d2 <= 4'd0;
            S_sec_d3 <= 4'd0;
            S_sec_d4 <= 4'd0;
            S_sec_d5 <= 4'd0;
            S_frame_d0 <= 4'd0;
            S_frame_d1 <= 4'd0;
            S_frame_d2 <= 4'd0;
            S_frame_d3 <= 4'd0;
            S_frame_d4 <= 4'd0;
            S_frame_d5 <= 4'd0;
        end
        else if(I_video_user) begin
            // Count frames generated by the HDMI timing itself.  This is
            // deliberately independent of CAP/DISP so each stage is visible.
            if(S_frame_d0 == 4'd9) begin
                S_frame_d0 <= 4'd0;
                if(S_frame_d1 == 4'd9) begin
                    S_frame_d1 <= 4'd0;
                    if(S_frame_d2 == 4'd9) begin
                        S_frame_d2 <= 4'd0;
                        if(S_frame_d3 == 4'd9) begin
                            S_frame_d3 <= 4'd0;
                            if(S_frame_d4 == 4'd9) begin
                                S_frame_d4 <= 4'd0;
                                if(S_frame_d5 == 4'd9)
                                    S_frame_d5 <= 4'd0;
                                else
                                    S_frame_d5 <= S_frame_d5 + 4'd1;
                            end
                            else
                                S_frame_d4 <= S_frame_d4 + 4'd1;
                        end
                        else
                            S_frame_d3 <= S_frame_d3 + 4'd1;
                    end
                    else
                        S_frame_d2 <= S_frame_d2 + 4'd1;
                end
                else
                    S_frame_d1 <= S_frame_d1 + 4'd1;
            end
            else
                S_frame_d0 <= S_frame_d0 + 4'd1;

            // The output timing is 1280x720@60 Hz, so 60 frame-start
            // pulses form one displayed second.
            if(S_frame_div == 6'd59) begin
                S_frame_div <= 6'd0;
                if(S_sec_d0 == 4'd9) begin
                    S_sec_d0 <= 4'd0;
                    if(S_sec_d1 == 4'd9) begin
                        S_sec_d1 <= 4'd0;
                        if(S_sec_d2 == 4'd9) begin
                            S_sec_d2 <= 4'd0;
                            if(S_sec_d3 == 4'd9) begin
                                S_sec_d3 <= 4'd0;
                                if(S_sec_d4 == 4'd9) begin
                                    S_sec_d4 <= 4'd0;
                                    if(S_sec_d5 == 4'd9)
                                        S_sec_d5 <= 4'd0;
                                    else
                                        S_sec_d5 <= S_sec_d5 + 4'd1;
                                end
                                else
                                    S_sec_d4 <= S_sec_d4 + 4'd1;
                            end
                            else
                                S_sec_d3 <= S_sec_d3 + 4'd1;
                        end
                        else
                            S_sec_d2 <= S_sec_d2 + 4'd1;
                    end
                    else
                        S_sec_d1 <= S_sec_d1 + 4'd1;
                end
                else
                    S_sec_d0 <= S_sec_d0 + 4'd1;
            end
            else
                S_frame_div <= S_frame_div + 6'd1;
        end
    end

    // Shared shift/add-3 converter: X/Y/distance and, in detection mode, DX/DY.
    // SW=0001/0100/0101 uses the tracked target centre; SW=0010 keeps the
    // blue-rectangle zoom centre/distance source. These modes use exact
    // switch decodes and therefore never request the converter together.
    // It needs 36 clocks in zoom mode or 60 in detection mode, avoiding
    // binary-to-decimal networks on the HDMI critical path.
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_track_frame_start_1d <= 1'b0;
            S_track_frame_start_2d <= 1'b0;
        end
        else begin
            S_track_frame_start_1d <= S_video_de_2d &&
                                     (S_x_2d == 12'd0) && (S_y_2d == 12'd0);
            S_track_frame_start_2d <= S_track_frame_start_1d;
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_black_x_bcd    <= 16'd0;
            S_black_y_bcd    <= 16'd0;
            S_black_dist_bcd <= 16'd0;
            S_bcd_bin_shift  <= 12'd0;
            S_bcd_source_y   <= 12'd0;
            S_bcd_source_dist<= 12'd0;
            S_bcd_work       <= 16'd0;
            S_bcd_count      <= 4'd0;
            S_bcd_value      <= 3'd0;
            S_bcd_busy       <= 1'b0;
            S_bcd_source_dx <= 12'd0; S_bcd_source_dy <= 12'd0;
            S_aim_dx_bcd <= 16'd0; S_aim_dy_bcd <= 16'd0;
            S_pan_pulse_bcd<=16'h1500; S_tilt_pulse_bcd<=16'h1500;
            S_bcd_source_pan<=12'd1500; S_bcd_source_tilt<=12'd1500;
            S_bcd_servo_mode<=0;
            S_bcd_track_mode <= 1'b0; S_aim_snapshot_valid <= 1'b0;
            S_aim_snapshot_color <= 3'd0; S_aim_snapshot_shape <= 2'd1; S_aim_snapshot_view <= 4'd0;
            S_aim_center_x <= 12'd0; S_aim_center_y <= 12'd0;
            S_aim_error_x <= 13'sd0; S_aim_error_y <= 13'sd0;
            S_aim_h_snapshot <= 2'd0; S_aim_v_snapshot <= 2'd0;
        end
        else if((I_video_user && !(I_track_enable || I_black_enable)) ||
                (S_track_frame_start_2d && (I_track_enable || I_black_enable))) begin
            S_bcd_bin_shift <= S_track_enable_osd ?
                    (S_aim_detect_now ? S_track_center_x : 12'd0) :
                    (S_track_valid ? S_display_center_sensor_x : 12'd0);
            S_bcd_source_y <= S_track_enable_osd ?
                    (S_aim_detect_now ? S_track_center_y : 12'd0) :
                    (S_track_valid ? S_display_center_sensor_y : 12'd0);
            S_bcd_source_dx <= S_aim_detect_now ? S_aim_abs_dx : 12'd0;
            S_bcd_source_dy <= S_aim_detect_now ? S_aim_abs_dy : 12'd0;
            S_bcd_track_mode <= S_track_enable_osd;
            S_bcd_servo_mode <= S_servo_view;
            S_bcd_source_pan <= I_pan_pulse_us;
            S_bcd_source_tilt <= I_tilt_pulse_us;
            S_aim_snapshot_valid <= S_aim_detect_now;
            S_aim_snapshot_color <= S_track_color_osd;
            S_aim_snapshot_shape <= S_track_shape_osd;
            S_aim_snapshot_view <= S_switch_state_osd;
            S_aim_center_x <= S_aim_detect_now ? S_track_center_x : 12'd0;
            S_aim_center_y <= S_aim_detect_now ? S_track_center_y : 12'd0;
            S_aim_error_x <= S_aim_detect_now ? S_aim_raw_dx : 13'sd0;
            S_aim_error_y <= S_aim_detect_now ? S_aim_raw_dy : 13'sd0;
            S_aim_h_snapshot <= (!S_aim_detect_now || (S_aim_abs_dx <= AIM_DEADZONE)) ?
                    2'd0 : (S_aim_raw_dx[12] ? 2'd1 : 2'd2);
            S_aim_v_snapshot <= (!S_aim_detect_now || (S_aim_abs_dy <= AIM_DEADZONE)) ?
                    2'd0 : (S_aim_raw_dy[12] ? 2'd1 : 2'd2);
            S_bcd_source_dist <= (I_black_enable && S_track_valid) ?
                                 S_display_center_distance : 12'd0;
            S_bcd_work      <= 16'd0;
            S_bcd_count     <= 4'd0;
            S_bcd_value     <= 3'd0;
            S_bcd_busy      <= I_track_enable || I_black_enable;
        end
        else if(S_bcd_busy) begin
            S_bcd_bin_shift <= {S_bcd_bin_shift[10:0],1'b0};
            if(S_bcd_count == 4'd11) begin
                S_bcd_count <= 4'd0;
                S_bcd_work  <= 16'd0;
                case(S_bcd_value)
                    3'd0: begin
                        S_black_x_bcd   <= S_bcd_next;
                        S_bcd_bin_shift <= S_bcd_source_y;
                        S_bcd_value     <= 3'd1;
                    end
                    3'd1: begin
                        S_black_y_bcd   <= S_bcd_next;
                        S_bcd_bin_shift <= S_bcd_source_dist;
                        S_bcd_value     <= 3'd2;
                    end
                    3'd2: begin
                        S_black_dist_bcd <= S_bcd_next;
                        if(S_bcd_track_mode) begin
                            S_bcd_bin_shift <= S_bcd_source_dx;
                            S_bcd_value <= 3'd3;
                        end
                        else S_bcd_busy <= 1'b0;
                    end
                    3'd3: begin
                        S_aim_dx_bcd <= S_bcd_next;
                        S_bcd_bin_shift <= S_bcd_source_dy;
                        S_bcd_value <= 3'd4;
                    end
                    3'd4: begin
                        S_aim_dy_bcd <= S_bcd_next;
                        if(S_bcd_servo_mode) begin
                            S_bcd_bin_shift<=S_bcd_source_pan;
                            S_bcd_value<=3'd5;
                        end
                        else S_bcd_busy<=1'b0;
                    end
                    3'd5: begin
                        S_pan_pulse_bcd<=S_bcd_next;
                        S_bcd_bin_shift<=S_bcd_source_tilt;
                        S_bcd_value<=3'd6;
                    end
                    default: begin
                        S_tilt_pulse_bcd<=S_bcd_next;
                        S_bcd_busy<=1'b0;
                    end
                endcase
            end
            else begin
                S_bcd_work  <= S_bcd_next;
                S_bcd_count <= S_bcd_count + 4'd1;
            end
        end
    end

    // Bundled AE snapshot: source bus settles with the toggle and stays
    // unchanged for about 2.7 ms. After two sampling stages, wait one
    // extra destination clock before accepting the bundled payload.
    reg [71:0] S_ae_debug_meta, S_ae_debug_sync, S_ae_debug_latest;
    reg [71:0] S_ae_debug_osd;
    reg S_ae_toggle_meta, S_ae_toggle_sync, S_ae_toggle_settle, S_ae_toggle_d;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_ae_debug_meta<=0; S_ae_debug_sync<=0; S_ae_debug_latest<=0;
            S_ae_toggle_meta<=0; S_ae_toggle_sync<=0; S_ae_toggle_settle<=0; S_ae_toggle_d<=0;
            S_ae_debug_osd<=0;
        end else begin
            S_ae_debug_meta<=I_ae_debug; S_ae_debug_sync<=S_ae_debug_meta;
            S_ae_toggle_meta<=I_ae_debug_toggle; S_ae_toggle_sync<=S_ae_toggle_meta;
            S_ae_toggle_settle<=S_ae_toggle_sync; S_ae_toggle_d<=S_ae_toggle_settle;
            if(S_ae_toggle_settle!=S_ae_toggle_d) S_ae_debug_latest<=S_ae_debug_sync;
            if(I_video_user) S_ae_debug_osd<=S_ae_debug_latest;
        end
    end
    function [7:0] F_hex_char;
        input [3:0] digit;
        begin F_hex_char=(digit<10) ? (8'h30+digit) : (8'h41+digit-10); end
    endfunction
    function [7:0] F_ae_status_char;
        input [3:0] status, pos;
        reg [39:0] text_word;
        begin
            case(status)
                0: text_word="WAIT ";
                1: text_word="BUSY ";
                2: text_word="UP   ";
                3: text_word="DOWN ";
                4: text_word="LIMIT";
                6: text_word="ERROR";
                default: text_word="LOCK ";
            endcase
            case(pos)
                0: F_ae_status_char=text_word[39:32];
                1: F_ae_status_char=text_word[31:24];
                2: F_ae_status_char=text_word[23:16];
                3: F_ae_status_char=text_word[15:8];
                4: F_ae_status_char=text_word[7:0];
                default: F_ae_status_char=0;
            endcase
        end
    endfunction
    wire [15:0] S_delay_ms_bcd;
    osd_latency_ms u_latency_ms (
        .I_clk(I_clk), .I_rst_n(I_rst_n), .I_start(I_video_user),
        .I_frames_bcd(I_delay_frames_bcd), .I_fps60(I_switch_state==4'b0000),
        .O_ms_bcd(S_delay_ms_bcd)
    );

    // Freeze all externally generated OSD values at the HDMI frame boundary.
    // This prevents a multi-digit value from changing halfway down the screen.
    assign O_zoom_request=1'b0;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_servo_state_osd        <= 4'd0;
            S_algo_mode_osd         <= 4'd0;
            S_switch_state_osd      <= 4'd0;
            S_track_enable_osd      <= 1'b0;
            S_track_color_osd       <= 3'd0;
            S_track_shape_osd       <= 2'd1;
            S_motion_enable_osd     <= 1'b0;
            S_black_enable_osd      <= 1'b0;
            S_black_valid_osd       <= 1'b0;
            S_capture_frame_bcd_osd <= 24'd0;
            S_display_frame_bcd_osd <= 24'd0;
            S_camera_fps_bcd_osd    <= 8'd0;
            S_delay_frames_bcd_osd  <= 8'd0;
        end
        else if(I_video_user) begin
            S_servo_state_osd        <= I_servo_state;
            S_algo_mode_osd         <= I_algo_mode;
            S_switch_state_osd      <= I_switch_state;
            S_track_enable_osd      <= I_track_enable;
            S_track_color_osd       <= I_track_color;
            S_track_shape_osd       <= I_track_shape;
            S_motion_enable_osd     <= I_motion_enable;
            S_black_enable_osd      <= I_black_enable;
            S_black_valid_osd       <= I_black_valid;
            S_capture_frame_bcd_osd <= I_capture_frame_bcd;
            S_display_frame_bcd_osd <= I_display_frame_bcd;
            S_camera_fps_bcd_osd    <= I_camera_fps_bcd;
            S_delay_frames_bcd_osd  <= I_delay_frames_bcd;
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_x_1d <= 12'd0;
            S_x_2d <= 12'd0;
            S_y_1d <= 12'd0;
            S_y_2d <= 12'd0;
            S_logo_addr <= 15'd0;
        end
        else begin
            S_x_1d <= S_x;
            S_x_2d <= S_x_1d;
            S_y_1d <= S_y;
            S_y_2d <= S_y_1d;

            // Pre-calculate the logo ROM address one stage ahead.  This
            // keeps the original pixel alignment while removing the
            // multiply/address logic from the HDMI output critical path.
            if((S_x >= LOGO_X) && (S_x < (LOGO_X + LOGO_W)) &&
               (S_y >= LOGO_Y) && (S_y < (LOGO_Y + LOGO_H)))
                S_logo_addr <= ((S_y - LOGO_Y) * LOGO_W) +
                               (S_x - LOGO_X);
            else
                S_logo_addr <= 15'd0;
        end
    end

    // Keep the annotation with the matched target, outside both status columns.
    reg [10:0] S_caption_x;
    reg [9:0] S_caption_y;
    reg S_caption_valid;
    reg [7:0] S_caption_dx;
    reg [5:0] S_caption_dy;
    wire S_caption_visible=S_caption_valid && S_aim_detect_now &&
        (S_switch_state_osd==4'd1 || S_switch_state_osd==4'd3);
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin S_caption_x<=0;S_caption_y<=0;S_caption_valid<=0;end
        else if(S_track_frame_start_2d) begin
            S_caption_valid<=S_aim_detect_now && (I_switch_state==1 || I_switch_state==3);
            S_caption_x<=S_track_left<272?11'd272:(S_track_left>888?11'd888:S_track_left[10:0]);
            S_caption_y<=S_track_top>=40?(S_track_top-12'd40):
                         (S_track_bottom<=680?(S_track_bottom+12'd4):12'd4);
        end
    end

    always @(*) begin
        S_osd_hit   = 1'b0;
        S_osd_color = 24'd0;
        S_logo_x = 12'd0;
        S_logo_y = 12'd0;
        S_char_idx = 4'd0;
        S_char_row = 3'd0;
        S_char_col = 3'd0;
        S_char_bits = 5'd0;
        S_char_on = 1'b0;
        S_logo_blue_on = 1'b0;
        S_logo_red_on = 1'b0;
        S_logo_tmp_y = 12'd0;
        S_logo_red_band = 4'd0;
        S_logo_red_x_start = 12'd0;
        S_logo_red_x_end = 12'd0;
        S_dyn_x = 12'd0;
        S_dyn_y = 12'd0;
        S_dyn_char = 4'd0;
        S_dyn_col = 3'd0;
        S_dyn_row = 3'd0;
        S_dyn_bits = 5'd0;
        S_dyn_on = 1'b0;
        S_dyn_color = COLOR_DYN_TEXT;
        S_dyn_digit_idx = 4'd0;
        S_dyn_digit_x = 12'd0;
        S_dyn_seg = 7'd0;
        S_lbl_row = 3'd0;
        S_lbl_col = 3'd0;
        S_lbl_idx = 2'd0;
        S_lbl_bits = 5'd0;
        S_lbl_local_x = 7'd0;
        S_dyn_dec_digit = 4'd0;
        S_cn_local_x = 5'd0;
        S_cn_local_y = 5'd0;
        S_cn_col = 4'd0;
        S_cn_row = 4'd0;
        S_cn_row_bits = 16'd0;
        S_cn_on = 1'b0;
        S_cn_scale_x = 10'd0;
        S_cn_scale_y = 10'd0;
        S_pf_char = 8'd0;
        S_pf_local_x = 5'd0;
        S_pf_local_y = 5'd0;
        S_pf_col = 4'd0;
        S_pf_row = 4'd0;
        S_pf_on = 1'b0;
        S_pf_scale_x = 10'd0;
        S_pf_scale_y = 10'd0;
        S_info_x = 12'd0;
        S_info_y = 12'd0;
        S_info_char = 8'd0;
        S_info_local_x = 5'd0;
        S_info_local_y = 5'd0;
        S_info_col = 4'd0;
        S_info_row = 4'd0;
        S_info_on = 1'b0;
        S_caption_dx=0;S_caption_dy=0;

        if(S_video_de_1d) begin
            if((S_x_1d >= LOGO_X) && (S_x_1d < (LOGO_X + LOGO_W)) &&
               (S_y_1d >= LOGO_Y) && (S_y_1d < (LOGO_Y + LOGO_H))) begin
                S_logo_x = S_x_1d - LOGO_X;
                S_logo_y = S_y_1d - LOGO_Y;
                if(S_logo_pixel[24]) begin
                    S_osd_hit   = 1'b1;
                    S_osd_color = S_logo_pixel[23:0];
                end
            end

            if((!S_osd_hit) &&
               (S_x_1d >= DYN_OSD_X) && (S_x_1d < (DYN_OSD_X + DYN_OSD_W)) &&
               (S_y_1d >= DYN_OSD_Y) && (S_y_1d < (DYN_OSD_Y + DYN_OSD_H))) begin
                S_dyn_x = S_x_1d - DYN_OSD_X;
                S_dyn_y = S_y_1d - DYN_OSD_Y;

                // Uniform 16x16 grid avoids per-pixel /15 and /24 scaling.
                // Keep the seconds counter and the two Chinese prefix glyphs.
                if((S_dyn_x < 12'd208) && (S_dyn_y < 12'd16)) begin
                    case(S_dyn_x[7:4])
                        0: S_pf_char=CHAR_AN;
                        1: S_pf_char=CHAR_LU;
                        3: S_pf_char=CHAR_S;
                        4: S_pf_char=CHAR_E;
                        5: S_pf_char=CHAR_C;
                        6: S_pf_char=CHAR_COLON;
                        7: S_pf_char=CHAR_0+S_sec_d5;
                        8: S_pf_char=CHAR_0+S_sec_d4;
                        9: S_pf_char=CHAR_0+S_sec_d3;
                        10: S_pf_char=CHAR_0+S_sec_d2;
                        11: S_pf_char=CHAR_0+S_sec_d1;
                        12: S_pf_char=CHAR_0+S_sec_d0;
                        default: S_pf_char=0;
                    endcase
                    S_pf_col=S_dyn_x[3:0]; S_pf_row=S_dyn_y[3:0];
                    if(F_char_pixel(S_pf_row_bits,S_pf_col)) S_dyn_on=1;
                end

                // The former top-right M:n indicator is intentionally disabled;
                // the complete MODE:n NAME line is rendered at the bottom.
                if(1'b0 && (S_dyn_x >= 12'd202) && (S_dyn_x < 12'd250) &&
                   (S_dyn_y >= 12'd4) && (S_dyn_y < 12'd20)) begin
                    if(S_dyn_x < 12'd218) begin
                        S_pf_char = CHAR_M;
                        S_pf_local_x = S_dyn_x - 12'd202;
                    end
                    else if(S_dyn_x < 12'd234) begin
                        S_pf_char = CHAR_COLON;
                        S_pf_local_x = S_dyn_x - 12'd218;
                    end
                    else begin
                        S_pf_char = CHAR_0 + {4'd0, S_algo_mode_osd};
                        S_pf_local_x = S_dyn_x - 12'd234;
                    end
                    S_pf_local_y = S_dyn_y - 12'd4;
                    S_pf_col = S_pf_local_x[3:0];
                    S_pf_row = S_pf_local_y[3:0];
                    case(S_pf_col)
                        4'd0:  S_pf_on = S_pf_row_bits[15];
                        4'd1:  S_pf_on = S_pf_row_bits[14];
                        4'd2:  S_pf_on = S_pf_row_bits[13];
                        4'd3:  S_pf_on = S_pf_row_bits[12];
                        4'd4:  S_pf_on = S_pf_row_bits[11];
                        4'd5:  S_pf_on = S_pf_row_bits[10];
                        4'd6:  S_pf_on = S_pf_row_bits[9];
                        4'd7:  S_pf_on = S_pf_row_bits[8];
                        4'd8:  S_pf_on = S_pf_row_bits[7];
                        4'd9:  S_pf_on = S_pf_row_bits[6];
                        4'd10: S_pf_on = S_pf_row_bits[5];
                        4'd11: S_pf_on = S_pf_row_bits[4];
                        4'd12: S_pf_on = S_pf_row_bits[3];
                        4'd13: S_pf_on = S_pf_row_bits[2];
                        4'd14: S_pf_on = S_pf_row_bits[1];
                        4'd15: S_pf_on = S_pf_row_bits[0];
                        default: S_pf_on = 1'b0;
                    endcase
                    if(S_pf_on)
                        S_dyn_on = 1'b1;
                end

                // HDMI output-frame counter: FRAME:000000.  CAP and DISP below
                // identify the camera frames entering and leaving the buffer.
                if(1'b0 && (S_dyn_y >= 12'd28) && (S_dyn_y < 12'd52)) begin
                    if((S_dyn_x < 12'd80) &&
                       (S_dyn_y >= 12'd32) && (S_dyn_y < 12'd48)) begin
                        case(S_dyn_x[6:4])
                            3'd0: S_pf_char = CHAR_F;
                            3'd1: S_pf_char = CHAR_R;
                            3'd2: S_pf_char = CHAR_A;
                            3'd3: S_pf_char = CHAR_M;
                            3'd4: S_pf_char = CHAR_E;
                            default: S_pf_char = 8'd0;
                        endcase
                        S_pf_local_x = {1'b0, S_dyn_x[3:0]};
                        S_pf_local_y = S_dyn_y - 12'd32;
                        S_pf_col = S_pf_local_x[3:0];
                        S_pf_row = S_pf_local_y[3:0];
                        case(S_pf_col)
                            4'd0:  S_pf_on = S_pf_row_bits[15];
                            4'd1:  S_pf_on = S_pf_row_bits[14];
                            4'd2:  S_pf_on = S_pf_row_bits[13];
                            4'd3:  S_pf_on = S_pf_row_bits[12];
                            4'd4:  S_pf_on = S_pf_row_bits[11];
                            4'd5:  S_pf_on = S_pf_row_bits[10];
                            4'd6:  S_pf_on = S_pf_row_bits[9];
                            4'd7:  S_pf_on = S_pf_row_bits[8];
                            4'd8:  S_pf_on = S_pf_row_bits[7];
                            4'd9:  S_pf_on = S_pf_row_bits[6];
                            4'd10: S_pf_on = S_pf_row_bits[5];
                            4'd11: S_pf_on = S_pf_row_bits[4];
                            4'd12: S_pf_on = S_pf_row_bits[3];
                            4'd13: S_pf_on = S_pf_row_bits[2];
                            4'd14: S_pf_on = S_pf_row_bits[1];
                            4'd15: S_pf_on = S_pf_row_bits[0];
                            default: S_pf_on = 1'b0;
                        endcase
                    end
                    else if((S_dyn_x >= 12'd80) && (S_dyn_x < 12'd88) &&
                            (S_dyn_y >= 12'd32) && (S_dyn_y < 12'd48)) begin
                        S_pf_char = CHAR_COLON;
                        S_pf_local_x = S_dyn_x - 12'd80;
                        S_pf_local_y = S_dyn_y - 12'd32;
                        S_pf_scale_x = S_pf_local_x * 10'd16;
                        S_pf_col = S_pf_scale_x / 10'd8;
                        S_pf_row = S_pf_local_y[3:0];
                        case(S_pf_col)
                            4'd0:  S_pf_on = S_pf_row_bits[15];
                            4'd1:  S_pf_on = S_pf_row_bits[14];
                            4'd2:  S_pf_on = S_pf_row_bits[13];
                            4'd3:  S_pf_on = S_pf_row_bits[12];
                            4'd4:  S_pf_on = S_pf_row_bits[11];
                            4'd5:  S_pf_on = S_pf_row_bits[10];
                            4'd6:  S_pf_on = S_pf_row_bits[9];
                            4'd7:  S_pf_on = S_pf_row_bits[8];
                            4'd8:  S_pf_on = S_pf_row_bits[7];
                            4'd9:  S_pf_on = S_pf_row_bits[6];
                            4'd10: S_pf_on = S_pf_row_bits[5];
                            4'd11: S_pf_on = S_pf_row_bits[4];
                            4'd12: S_pf_on = S_pf_row_bits[3];
                            4'd13: S_pf_on = S_pf_row_bits[2];
                            4'd14: S_pf_on = S_pf_row_bits[1];
                            4'd15: S_pf_on = S_pf_row_bits[0];
                            default: S_pf_on = 1'b0;
                        endcase
                    end
                    else if((S_dyn_x >= 12'd90) && (S_dyn_x < 12'd180)) begin
                        if(S_dyn_x < 12'd105) begin
                            S_dyn_digit_x = S_dyn_x - 12'd90;
                            S_dyn_dec_digit = S_frame_d5;
                        end
                        else if(S_dyn_x < 12'd120) begin
                            S_dyn_digit_x = S_dyn_x - 12'd105;
                            S_dyn_dec_digit = S_frame_d4;
                        end
                        else if(S_dyn_x < 12'd135) begin
                            S_dyn_digit_x = S_dyn_x - 12'd120;
                            S_dyn_dec_digit = S_frame_d3;
                        end
                        else if(S_dyn_x < 12'd150) begin
                            S_dyn_digit_x = S_dyn_x - 12'd135;
                            S_dyn_dec_digit = S_frame_d2;
                        end
                        else if(S_dyn_x < 12'd165) begin
                            S_dyn_digit_x = S_dyn_x - 12'd150;
                            S_dyn_dec_digit = S_frame_d1;
                        end
                        else begin
                            S_dyn_digit_x = S_dyn_x - 12'd165;
                            S_dyn_dec_digit = S_frame_d0;
                        end

                        S_pf_char = CHAR_0 + {4'd0, S_dyn_dec_digit};
                        S_pf_local_x = S_dyn_digit_x[4:0];
                        S_pf_local_y = S_dyn_y - 12'd28;
                        S_pf_scale_x = S_pf_local_x * 10'd16;
                        S_pf_scale_y = S_pf_local_y * 10'd16;
                        S_pf_col = S_pf_scale_x / 10'd15;
                        S_pf_row = S_pf_scale_y / 10'd24;
                        case(S_pf_col)
                            4'd0:  S_pf_on = S_pf_row_bits[15];
                            4'd1:  S_pf_on = S_pf_row_bits[14];
                            4'd2:  S_pf_on = S_pf_row_bits[13];
                            4'd3:  S_pf_on = S_pf_row_bits[12];
                            4'd4:  S_pf_on = S_pf_row_bits[11];
                            4'd5:  S_pf_on = S_pf_row_bits[10];
                            4'd6:  S_pf_on = S_pf_row_bits[9];
                            4'd7:  S_pf_on = S_pf_row_bits[8];
                            4'd8:  S_pf_on = S_pf_row_bits[7];
                            4'd9:  S_pf_on = S_pf_row_bits[6];
                            4'd10: S_pf_on = S_pf_row_bits[5];
                            4'd11: S_pf_on = S_pf_row_bits[4];
                            4'd12: S_pf_on = S_pf_row_bits[3];
                            4'd13: S_pf_on = S_pf_row_bits[2];
                            4'd14: S_pf_on = S_pf_row_bits[1];
                            4'd15: S_pf_on = S_pf_row_bits[0];
                            default: S_pf_on = 1'b0;
                        endcase
                    end

                    if(S_pf_on)
                        S_dyn_on = 1'b1;
                end

                // Measured camera frame rate: FPS:00.  This value is
                // refreshed once per second from the actual input frames.
                if(1'b0 && (S_dyn_y >= 12'd56) && (S_dyn_y < 12'd80)) begin
                    if((S_dyn_x < 12'd48) &&
                       (S_dyn_y >= 12'd60) && (S_dyn_y < 12'd76)) begin
                        case(S_dyn_x[5:4])
                            2'd0: S_pf_char = CHAR_F;
                            2'd1: S_pf_char = CHAR_P;
                            2'd2: S_pf_char = CHAR_S;
                            default: S_pf_char = 8'd0;
                        endcase
                        S_pf_local_x = {1'b0, S_dyn_x[3:0]};
                        S_pf_local_y = S_dyn_y - 12'd60;
                        S_pf_col = S_pf_local_x[3:0];
                        S_pf_row = S_pf_local_y[3:0];
                        case(S_pf_col)
                            4'd0:  S_pf_on = S_pf_row_bits[15];
                            4'd1:  S_pf_on = S_pf_row_bits[14];
                            4'd2:  S_pf_on = S_pf_row_bits[13];
                            4'd3:  S_pf_on = S_pf_row_bits[12];
                            4'd4:  S_pf_on = S_pf_row_bits[11];
                            4'd5:  S_pf_on = S_pf_row_bits[10];
                            4'd6:  S_pf_on = S_pf_row_bits[9];
                            4'd7:  S_pf_on = S_pf_row_bits[8];
                            4'd8:  S_pf_on = S_pf_row_bits[7];
                            4'd9:  S_pf_on = S_pf_row_bits[6];
                            4'd10: S_pf_on = S_pf_row_bits[5];
                            4'd11: S_pf_on = S_pf_row_bits[4];
                            4'd12: S_pf_on = S_pf_row_bits[3];
                            4'd13: S_pf_on = S_pf_row_bits[2];
                            4'd14: S_pf_on = S_pf_row_bits[1];
                            4'd15: S_pf_on = S_pf_row_bits[0];
                            default: S_pf_on = 1'b0;
                        endcase
                    end
                    else if((S_dyn_x >= 12'd48) && (S_dyn_x < 12'd56) &&
                            (S_dyn_y >= 12'd60) && (S_dyn_y < 12'd76)) begin
                        S_pf_char = CHAR_COLON;
                        S_pf_local_x = S_dyn_x - 12'd48;
                        S_pf_local_y = S_dyn_y - 12'd60;
                        S_pf_scale_x = S_pf_local_x * 10'd16;
                        S_pf_col = S_pf_scale_x / 10'd8;
                        S_pf_row = S_pf_local_y[3:0];
                        case(S_pf_col)
                            4'd0:  S_pf_on = S_pf_row_bits[15];
                            4'd1:  S_pf_on = S_pf_row_bits[14];
                            4'd2:  S_pf_on = S_pf_row_bits[13];
                            4'd3:  S_pf_on = S_pf_row_bits[12];
                            4'd4:  S_pf_on = S_pf_row_bits[11];
                            4'd5:  S_pf_on = S_pf_row_bits[10];
                            4'd6:  S_pf_on = S_pf_row_bits[9];
                            4'd7:  S_pf_on = S_pf_row_bits[8];
                            4'd8:  S_pf_on = S_pf_row_bits[7];
                            4'd9:  S_pf_on = S_pf_row_bits[6];
                            4'd10: S_pf_on = S_pf_row_bits[5];
                            4'd11: S_pf_on = S_pf_row_bits[4];
                            4'd12: S_pf_on = S_pf_row_bits[3];
                            4'd13: S_pf_on = S_pf_row_bits[2];
                            4'd14: S_pf_on = S_pf_row_bits[1];
                            4'd15: S_pf_on = S_pf_row_bits[0];
                            default: S_pf_on = 1'b0;
                        endcase
                    end
                    else if((S_dyn_x >= 12'd58) && (S_dyn_x < 12'd88)) begin
                        if(S_dyn_x < 12'd73) begin
                            S_dyn_digit_x = S_dyn_x - 12'd58;
                            S_dyn_dec_digit = S_camera_fps_bcd_osd[7:4];
                        end
                        else begin
                            S_dyn_digit_x = S_dyn_x - 12'd73;
                            S_dyn_dec_digit = S_camera_fps_bcd_osd[3:0];
                        end

                        S_pf_char = CHAR_0 + {4'd0, S_dyn_dec_digit};
                        S_pf_local_x = S_dyn_digit_x[4:0];
                        S_pf_local_y = S_dyn_y - 12'd56;
                        S_pf_scale_x = S_pf_local_x * 10'd16;
                        S_pf_scale_y = S_pf_local_y * 10'd16;
                        S_pf_col = S_pf_scale_x / 10'd15;
                        S_pf_row = S_pf_scale_y / 10'd24;
                        case(S_pf_col)
                            4'd0:  S_pf_on = S_pf_row_bits[15];
                            4'd1:  S_pf_on = S_pf_row_bits[14];
                            4'd2:  S_pf_on = S_pf_row_bits[13];
                            4'd3:  S_pf_on = S_pf_row_bits[12];
                            4'd4:  S_pf_on = S_pf_row_bits[11];
                            4'd5:  S_pf_on = S_pf_row_bits[10];
                            4'd6:  S_pf_on = S_pf_row_bits[9];
                            4'd7:  S_pf_on = S_pf_row_bits[8];
                            4'd8:  S_pf_on = S_pf_row_bits[7];
                            4'd9:  S_pf_on = S_pf_row_bits[6];
                            4'd10: S_pf_on = S_pf_row_bits[5];
                            4'd11: S_pf_on = S_pf_row_bits[4];
                            4'd12: S_pf_on = S_pf_row_bits[3];
                            4'd13: S_pf_on = S_pf_row_bits[2];
                            4'd14: S_pf_on = S_pf_row_bits[1];
                            4'd15: S_pf_on = S_pf_row_bits[0];
                            default: S_pf_on = 1'b0;
                        endcase
                    end

                    if(S_pf_on)
                        S_dyn_on = 1'b1;
                end

                // Uniform 16x16 HDMI output-frame line: FRAME:000000.
                if((S_dyn_x < 12'd192) &&
                   (S_dyn_y >= 12'd32) && (S_dyn_y < 12'd48)) begin
                    case(S_dyn_x[7:4])
                        4'd0:  S_pf_char = CHAR_F;
                        4'd1:  S_pf_char = CHAR_R;
                        4'd2:  S_pf_char = CHAR_A;
                        4'd3:  S_pf_char = CHAR_M;
                        4'd4:  S_pf_char = CHAR_E;
                        4'd5:  S_pf_char = CHAR_COLON;
                        4'd6:  S_pf_char = CHAR_0 + {4'd0, S_frame_d5};
                        4'd7:  S_pf_char = CHAR_0 + {4'd0, S_frame_d4};
                        4'd8:  S_pf_char = CHAR_0 + {4'd0, S_frame_d3};
                        4'd9:  S_pf_char = CHAR_0 + {4'd0, S_frame_d2};
                        4'd10: S_pf_char = CHAR_0 + {4'd0, S_frame_d1};
                        4'd11: S_pf_char = CHAR_0 + {4'd0, S_frame_d0};
                        default: S_pf_char = 8'd0;
                    endcase
                    S_pf_local_x = {1'b0, S_dyn_x[3:0]};
                    S_pf_local_y = S_dyn_y - 12'd32;
                    S_pf_col = S_pf_local_x[3:0];
                    S_pf_row = S_pf_local_y[3:0];
                    S_pf_on = F_char_pixel(S_pf_row_bits, S_pf_col);
                    if(S_pf_on)
                        S_dyn_on = 1'b1;
                end

                // Uniform 16x16 measured camera frame-rate line: FPS:00.
                if((S_dyn_x < 12'd96) &&
                   (S_dyn_y >= 12'd60) && (S_dyn_y < 12'd76)) begin
                    case(S_dyn_x[7:4])
                        4'd0: S_pf_char = CHAR_F;
                        4'd1: S_pf_char = CHAR_P;
                        4'd2: S_pf_char = CHAR_S;
                        4'd3: S_pf_char = CHAR_COLON;
                        4'd4: S_pf_char = CHAR_0 + {4'd0, S_camera_fps_bcd_osd[7:4]};
                        4'd5: S_pf_char = CHAR_0 + {4'd0, S_camera_fps_bcd_osd[3:0]};
                        default: S_pf_char = 8'd0;
                    endcase
                    S_pf_local_x = {1'b0, S_dyn_x[3:0]};
                    S_pf_local_y = S_dyn_y - 12'd60;
                    S_pf_col = S_pf_local_x[3:0];
                    S_pf_row = S_pf_local_y[3:0];
                    S_pf_on = F_char_pixel(S_pf_row_bits, S_pf_col);
                    if(S_pf_on)
                        S_dyn_on = 1'b1;
                end

                // Latest camera frame accepted by the capture side.
                if((S_dyn_x < 12'd160) &&
                   (S_dyn_y >= 12'd84) && (S_dyn_y < 12'd100)) begin
                    case(S_dyn_x[7:4])
                        4'd0: S_pf_char = CHAR_C;
                        4'd1: S_pf_char = CHAR_A;
                        4'd2: S_pf_char = CHAR_P;
                        4'd3: S_pf_char = CHAR_COLON;
                        4'd4: S_pf_char = CHAR_0 + {4'd0, S_capture_frame_bcd_osd[23:20]};
                        4'd5: S_pf_char = CHAR_0 + {4'd0, S_capture_frame_bcd_osd[19:16]};
                        4'd6: S_pf_char = CHAR_0 + {4'd0, S_capture_frame_bcd_osd[15:12]};
                        4'd7: S_pf_char = CHAR_0 + {4'd0, S_capture_frame_bcd_osd[11:8]};
                        4'd8: S_pf_char = CHAR_0 + {4'd0, S_capture_frame_bcd_osd[7:4]};
                        4'd9: S_pf_char = CHAR_0 + {4'd0, S_capture_frame_bcd_osd[3:0]};
                        default: S_pf_char = 8'd0;
                    endcase
                    S_pf_local_x = {1'b0, S_dyn_x[3:0]};
                    S_pf_local_y = S_dyn_y - 12'd84;
                    S_pf_col = S_pf_local_x[3:0];
                    S_pf_row = S_pf_local_y[3:0];
                    S_pf_on = F_char_pixel(S_pf_row_bits, S_pf_col);
                    if(S_pf_on)
                        S_dyn_on = 1'b1;
                end

                // Camera frame currently selected by the display reader.
                if((S_dyn_x < 12'd176) &&
                   (S_dyn_y >= 12'd108) && (S_dyn_y < 12'd124)) begin
                    case(S_dyn_x[7:4])
                        4'd0:  S_pf_char = CHAR_D;
                        4'd1:  S_pf_char = CHAR_I;
                        4'd2:  S_pf_char = CHAR_S;
                        4'd3:  S_pf_char = CHAR_P;
                        4'd4:  S_pf_char = CHAR_COLON;
                        4'd5:  S_pf_char = CHAR_0 + {4'd0, S_display_frame_bcd_osd[23:20]};
                        4'd6:  S_pf_char = CHAR_0 + {4'd0, S_display_frame_bcd_osd[19:16]};
                        4'd7:  S_pf_char = CHAR_0 + {4'd0, S_display_frame_bcd_osd[15:12]};
                        4'd8:  S_pf_char = CHAR_0 + {4'd0, S_display_frame_bcd_osd[11:8]};
                        4'd9:  S_pf_char = CHAR_0 + {4'd0, S_display_frame_bcd_osd[7:4]};
                        4'd10: S_pf_char = CHAR_0 + {4'd0, S_display_frame_bcd_osd[3:0]};
                        default: S_pf_char = 8'd0;
                    endcase
                    S_pf_local_x = {1'b0, S_dyn_x[3:0]};
                    S_pf_local_y = S_dyn_y - 12'd108;
                    S_pf_col = S_pf_local_x[3:0];
                    S_pf_row = S_pf_local_y[3:0];
                    S_pf_on = F_char_pixel(S_pf_row_bits, S_pf_col);
                    if(S_pf_on)
                        S_dyn_on = 1'b1;
                end

                // Buffer frame age, not a complete optical latency measurement.
                if((S_dyn_x < 12'd224) &&
                   (S_dyn_y >= 12'd132) && (S_dyn_y < 12'd148)) begin
                    S_dyn_color=24'h00ffff;
                    case(S_dyn_x[7:4])
                        4'd0:  S_pf_char = CHAR_D;
                        4'd1:  S_pf_char = CHAR_E;
                        4'd2:  S_pf_char = CHAR_L;
                        4'd3:  S_pf_char = CHAR_A;
                        4'd4:  S_pf_char = CHAR_Y;
                        4'd5:  S_pf_char = CHAR_COLON;
                        4'd6:  S_pf_char = CHAR_0 + {4'd0, S_delay_frames_bcd_osd[7:4]};
                        4'd7:  S_pf_char = CHAR_0 + {4'd0, S_delay_frames_bcd_osd[3:0]};
                        4'd8:  S_pf_char = 8'd0;
                        4'd9:  S_pf_char = CHAR_F;
                        4'd10: S_pf_char = CHAR_R;
                        4'd11: S_pf_char = CHAR_A;
                        4'd12: S_pf_char = CHAR_M;
                        4'd13: S_pf_char = CHAR_E;
                        default: S_pf_char = 8'd0;
                    endcase
                    S_pf_local_x = {1'b0, S_dyn_x[3:0]};
                    S_pf_local_y = S_dyn_y - 12'd132;
                    S_pf_col = S_pf_local_x[3:0];
                    S_pf_row = S_pf_local_y[3:0];
                    S_pf_on = F_char_pixel(S_pf_row_bits, S_pf_col);
                    if(S_pf_on)
                        S_dyn_on = 1'b1;
                end

                // Selected processing mode and its English name.
                if((S_dyn_x < 12'd240) &&
                   (S_dyn_y >= 12'd156) && (S_dyn_y < 12'd172)) begin
                    if(S_motion_enable_osd) begin
                        case(S_dyn_x[7:4])
                            4'd0:  S_pf_char = CHAR_M;
                            4'd1:  S_pf_char = CHAR_O;
                            4'd2:  S_pf_char = CHAR_T;
                            4'd3:  S_pf_char = CHAR_I;
                            4'd4:  S_pf_char = CHAR_O;
                            4'd5:  S_pf_char = CHAR_N;
                            4'd6:  S_pf_char = CHAR_COLON;
                            4'd7:  S_pf_char = CHAR_0 + {4'd0, S_motion_count_bcd[15:12]};
                            4'd8:  S_pf_char = CHAR_0 + {4'd0, S_motion_count_bcd[11:8]};
                            4'd9:  S_pf_char = CHAR_0 + {4'd0, S_motion_count_bcd[7:4]};
                            4'd10: S_pf_char = CHAR_0 + {4'd0, S_motion_count_bcd[3:0]};
                            default: S_pf_char = 8'd0;
                        endcase
                    end
                    else begin
                      case(S_dyn_x[7:4])
                        4'd0: S_pf_char = CHAR_M;
                        4'd1: S_pf_char = CHAR_O;
                        4'd2: S_pf_char = CHAR_D;
                        4'd3: S_pf_char = CHAR_E;
                        4'd4: S_pf_char = CHAR_COLON;
                        4'd5: S_pf_char = CHAR_0 + {4'd0, S_algo_mode_osd};
                        4'd6: S_pf_char = 8'd0;
                        default: begin
                            case(S_algo_mode_osd)
                                3'd0: begin // NORMAL
                                    case(S_dyn_x[7:4])
                                        4'd7:  S_pf_char = CHAR_N;
                                        4'd8:  S_pf_char = CHAR_O;
                                        4'd9:  S_pf_char = CHAR_R;
                                        4'd10: S_pf_char = CHAR_M;
                                        4'd11: S_pf_char = CHAR_A;
                                        4'd12: S_pf_char = CHAR_L;
                                        default: S_pf_char = 8'd0;
                                    endcase
                                end
                                3'd1: begin // EDGE
                                    case(S_dyn_x[7:4])
                                        4'd7:  S_pf_char = CHAR_E;
                                        4'd8:  S_pf_char = CHAR_D;
                                        4'd9:  S_pf_char = CHAR_G;
                                        4'd10: S_pf_char = CHAR_E;
                                        default: S_pf_char = 8'd0;
                                    endcase
                                end
                                3'd2: begin // GRAY
                                    case(S_dyn_x[7:4])
                                        4'd7:  S_pf_char = CHAR_G;
                                        4'd8:  S_pf_char = CHAR_R;
                                        4'd9:  S_pf_char = CHAR_A;
                                        4'd10: S_pf_char = CHAR_Y;
                                        default: S_pf_char = 8'd0;
                                    endcase
                                end
                                3'd3: begin // BINARY
                                    case(S_dyn_x[7:4])
                                        4'd7:  S_pf_char = CHAR_B;
                                        4'd8:  S_pf_char = CHAR_I;
                                        4'd9:  S_pf_char = CHAR_N;
                                        4'd10: S_pf_char = CHAR_A;
                                        4'd11: S_pf_char = CHAR_R;
                                        4'd12: S_pf_char = CHAR_Y;
                                        default: S_pf_char = 8'd0;
                                    endcase
                                end
                                3'd4: begin // HIST EQ
                                    case(S_dyn_x[7:4])
                                        4'd7: S_pf_char = 8'h48;
                                        4'd8: S_pf_char = 8'h49;
                                        4'd9: S_pf_char = 8'h53;
                                        4'd10: S_pf_char = 8'h54;
                                        4'd11: S_pf_char = 8'h20;
                                        4'd12: S_pf_char = 8'h45;
                                        4'd13: S_pf_char = 8'h51;
                                        default: S_pf_char = 8'd0;
                                    endcase
                                end
                                3'd5: begin // RED EDGE
                                    case(S_dyn_x[7:4])
                                        4'd7: S_pf_char=CHAR_R;4'd8: S_pf_char=CHAR_E;4'd9: S_pf_char=CHAR_D;
                                        4'd10: S_pf_char=8'h20;4'd11: S_pf_char=CHAR_E;4'd12: S_pf_char=CHAR_D;
                                        4'd13: S_pf_char=CHAR_G;4'd14: S_pf_char=CHAR_E;
                                        default:S_pf_char=8'd0;
                                    endcase
                                end
                                default: begin // RESERVED
                                    case(S_dyn_x[7:4])
                                        4'd7:  S_pf_char = CHAR_R;
                                        4'd8:  S_pf_char = CHAR_E;
                                        4'd9:  S_pf_char = CHAR_S;
                                        4'd10: S_pf_char = CHAR_E;
                                        4'd11: S_pf_char = CHAR_R;
                                        4'd12: S_pf_char = CHAR_V;
                                        4'd13: S_pf_char = CHAR_E;
                                        4'd14: S_pf_char = CHAR_D;
                                        default: S_pf_char = 8'd0;
                                    endcase
                                end
                            endcase
                        end
                      endcase
                    end
                    S_pf_local_x = {1'b0, S_dyn_x[3:0]};
                    S_pf_local_y = S_dyn_y - 12'd156;
                    S_pf_col = S_pf_local_x[3:0];
                    S_pf_row = S_pf_local_y[3:0];
                    S_pf_on = F_char_pixel(S_pf_row_bits, S_pf_col);
                    if(S_pf_on)
                        S_dyn_on = 1'b1;
                end

                // Current physical switch state, ordered as SW4..SW1.
                if((S_dyn_x < 12'd176) &&
                   (S_dyn_y >= 12'd180) && (S_dyn_y < 12'd196)) begin
                    case(S_dyn_x[7:4])
                        4'd0:  S_pf_char = CHAR_S;
                        4'd1:  S_pf_char = CHAR_W;
                        4'd2:  S_pf_char = CHAR_I;
                        4'd3:  S_pf_char = CHAR_T;
                        4'd4:  S_pf_char = CHAR_C;
                        4'd5:  S_pf_char = CHAR_H;
                        4'd6:  S_pf_char = CHAR_COLON;
                        4'd7:  S_pf_char = CHAR_0 + {7'd0,S_switch_state_osd[3]};
                        4'd8:  S_pf_char = CHAR_0 + {7'd0,S_switch_state_osd[2]};
                        4'd9:  S_pf_char = CHAR_0 + {7'd0,S_switch_state_osd[1]};
                        4'd10: S_pf_char = CHAR_0 + {7'd0,S_switch_state_osd[0]};
                        default: S_pf_char = 8'd0;
                    endcase
                    S_pf_local_x = {1'b0, S_dyn_x[3:0]};
                    S_pf_local_y = S_dyn_y - 12'd180;
                    S_pf_col = S_pf_local_x[3:0];
                    S_pf_row = S_pf_local_y[3:0];
                    S_pf_on = F_char_pixel(S_pf_row_bits, S_pf_col);
                    if(S_pf_on)
                        S_dyn_on = 1'b1;
                end

                if(S_dyn_y>=204 && S_dyn_y<220) S_dyn_color=24'h00ffff;
                if((S_dyn_x < 12'd208) &&
                   (S_dyn_y >= 12'd204) && (S_dyn_y < 12'd220)) begin
                    case(S_dyn_x[7:4])
                        0: S_pf_char=CHAR_D;
                        1: S_pf_char=CHAR_E;
                        2: S_pf_char=CHAR_L;
                        3: S_pf_char=CHAR_A;
                        4: S_pf_char=CHAR_Y;
                        5: S_pf_char=CHAR_COLON;
                        6: S_pf_char=CHAR_0+S_delay_ms_bcd[15:12];
                        7: S_pf_char=CHAR_0+S_delay_ms_bcd[11:8];
                        8: S_pf_char=CHAR_0+S_delay_ms_bcd[7:4];
                        9: S_pf_char=CHAR_0+S_delay_ms_bcd[3:0];
                        10: S_pf_char=8'd0;
                        11: S_pf_char=CHAR_M;
                        12: S_pf_char=CHAR_S;
                        default: S_pf_char=0;
                    endcase
                    S_pf_col=S_dyn_x[3:0]; S_pf_local_y=S_dyn_y-12'd204;
                    S_pf_row=S_pf_local_y[3:0];
                    if(F_char_pixel(S_pf_row_bits,S_pf_col)) S_dyn_on=1;
                end
                if(S_dyn_x<240 && S_dyn_y>=228 && S_dyn_y<244) begin
                    case(S_dyn_x[7:4])
                        0: S_pf_char=8'h41;
                        1: S_pf_char=8'h45;
                        2: S_pf_char=8'h20;
                        3: S_pf_char=8'h53;
                        4: S_pf_char=8'h54;
                        5: S_pf_char=8'h41;
                        6: S_pf_char=8'h54;
                        7: S_pf_char=8'h55;
                        8: S_pf_char=8'h53;
                        9: S_pf_char=8'h3a;
                        default: S_pf_char=F_ae_status_char(S_ae_debug_osd[71:68],S_dyn_x[7:4]-4'd10);
                    endcase
                    S_pf_col=S_dyn_x[3:0];S_pf_local_y=S_dyn_y-12'd228;S_pf_row=S_pf_local_y[3:0];
                    if(F_char_pixel(S_pf_row_bits,S_pf_col)) S_dyn_on=1;
                end
                if(S_dyn_x<240 && S_dyn_y>=252 && S_dyn_y<268) begin
                    case(S_dyn_x[7:4])
                        0: S_pf_char=8'h42;
                        1: S_pf_char=8'h52;
                        2: S_pf_char=8'h49;
                        3: S_pf_char=8'h47;
                        4: S_pf_char=8'h48;
                        5: S_pf_char=8'h54;
                        6: S_pf_char=8'h4e;
                        7: S_pf_char=8'h45;
                        8: S_pf_char=8'h53;
                        9: S_pf_char=8'h53;
                        10: S_pf_char=8'h3a;
                        11: S_pf_char=CHAR_0+S_ae_debug_osd[67:64];
                        12: S_pf_char=CHAR_0+S_ae_debug_osd[63:60];
                        13: S_pf_char=CHAR_0+S_ae_debug_osd[59:56];
                        default: S_pf_char=0;
                    endcase
                    S_pf_col=S_dyn_x[3:0];S_pf_local_y=S_dyn_y-12'd252;S_pf_row=S_pf_local_y[3:0];
                    if(F_char_pixel(S_pf_row_bits,S_pf_col)) S_dyn_on=1;
                end
                if(S_dyn_x<240 && S_dyn_y>=276 && S_dyn_y<292) begin
                    case(S_dyn_x[7:4])
                        0: S_pf_char=8'h54;
                        1: S_pf_char=8'h41;
                        2: S_pf_char=8'h52;
                        3: S_pf_char=8'h47;
                        4: S_pf_char=8'h45;
                        5: S_pf_char=8'h54;
                        6: S_pf_char=8'h3a;
                        7: S_pf_char=CHAR_0+S_ae_debug_osd[55:52];
                        8: S_pf_char=CHAR_0+S_ae_debug_osd[51:48];
                        9: S_pf_char=CHAR_0+S_ae_debug_osd[47:44];
                        default: S_pf_char=0;
                    endcase
                    S_pf_col=S_dyn_x[3:0];S_pf_local_y=S_dyn_y-12'd276;S_pf_row=S_pf_local_y[3:0];
                    if(F_char_pixel(S_pf_row_bits,S_pf_col)) S_dyn_on=1;
                end
                if(S_dyn_x<240 && S_dyn_y>=300 && S_dyn_y<316) begin
                    case(S_dyn_x[7:4])
                        0: S_pf_char=8'h45;
                        1: S_pf_char=8'h58;
                        2: S_pf_char=8'h50;
                        3: S_pf_char=8'h20;
                        4: S_pf_char=8'h53;
                        5: S_pf_char=8'h45;
                        6: S_pf_char=8'h54;
                        7: S_pf_char=8'h3a;
                        8: S_pf_char=CHAR_0+S_ae_debug_osd[43:40];
                        9: S_pf_char=CHAR_0+S_ae_debug_osd[39:36];
                        10: S_pf_char=CHAR_0+S_ae_debug_osd[35:32];
                        11: S_pf_char=CHAR_0+S_ae_debug_osd[31:28];
                        default: S_pf_char=0;
                    endcase
                    S_pf_col=S_dyn_x[3:0];S_pf_local_y=S_dyn_y-12'd300;S_pf_row=S_pf_local_y[3:0];
                    if(F_char_pixel(S_pf_row_bits,S_pf_col)) S_dyn_on=1;
                end
                if(S_dyn_x<240 && S_dyn_y>=324 && S_dyn_y<340) begin
                    case(S_dyn_x[7:4])
                        0: S_pf_char=8'h47;
                        1: S_pf_char=8'h41;
                        2: S_pf_char=8'h49;
                        3: S_pf_char=8'h4e;
                        4: S_pf_char=8'h20;
                        5: S_pf_char=8'h49;
                        6: S_pf_char=8'h4e;
                        7: S_pf_char=8'h44;
                        8: S_pf_char=8'h45;
                        9: S_pf_char=8'h58;
                        10: S_pf_char=8'h3a;
                        11: S_pf_char=CHAR_0+S_ae_debug_osd[27:24];
                        12: S_pf_char=CHAR_0+S_ae_debug_osd[23:20];
                        13: S_pf_char=CHAR_0+S_ae_debug_osd[19:16];
                        default: S_pf_char=0;
                    endcase
                    S_pf_col=S_dyn_x[3:0];S_pf_local_y=S_dyn_y-12'd324;S_pf_row=S_pf_local_y[3:0];
                    if(F_char_pixel(S_pf_row_bits,S_pf_col)) S_dyn_on=1;
                end
                if(S_dyn_x<240 && S_dyn_y>=348 && S_dyn_y<364) begin
                    case(S_dyn_x[7:4])
                        0: S_pf_char=8'h4d;
                        1: S_pf_char=8'h45;
                        2: S_pf_char=8'h54;
                        3: S_pf_char=8'h45;
                        4: S_pf_char=8'h52;
                        5: S_pf_char=8'h20;
                        6: S_pf_char=8'h43;
                        7: S_pf_char=8'h4e;
                        8: S_pf_char=8'h54;
                        9: S_pf_char=8'h3a;
                        10: S_pf_char=8'h30;
                        11: S_pf_char=8'h58;
                        12: S_pf_char=F_hex_char(S_ae_debug_osd[15:12]);
                        13: S_pf_char=F_hex_char(S_ae_debug_osd[11:8]);
                        default: S_pf_char=0;
                    endcase
                    S_pf_col=S_dyn_x[3:0];S_pf_local_y=S_dyn_y-12'd348;S_pf_row=S_pf_local_y[3:0];
                    if(F_char_pixel(S_pf_row_bits,S_pf_col)) S_dyn_on=1;
                end
                if(S_dyn_x<240 && S_dyn_y>=372 && S_dyn_y<388) begin
                    case(S_dyn_x[7:4])
                        0: S_pf_char=8'h43;
                        1: S_pf_char=8'h4f;
                        2: S_pf_char=8'h4e;
                        3: S_pf_char=8'h46;
                        4: S_pf_char=8'h49;
                        5: S_pf_char=8'h47;
                        6: S_pf_char=8'h20;
                        7: S_pf_char=8'h43;
                        8: S_pf_char=8'h4e;
                        9: S_pf_char=8'h54;
                        10: S_pf_char=8'h3a;
                        11: S_pf_char=8'h30;
                        12: S_pf_char=8'h58;
                        13: S_pf_char=F_hex_char(S_ae_debug_osd[7:4]);
                        14: S_pf_char=F_hex_char(S_ae_debug_osd[3:0]);
                        default: S_pf_char=0;
                    endcase
                    S_pf_col=S_dyn_x[3:0];S_pf_local_y=S_dyn_y-12'd372;S_pf_row=S_pf_local_y[3:0];
                    if(F_char_pixel(S_pf_row_bits,S_pf_col)) S_dyn_on=1;
                end

                if(S_dyn_on) begin
                    S_osd_hit = 1'b1;
                    S_osd_color = S_dyn_color;
                end
            end

            // SW4321=0001 and 0010 share the fixed right-top status area.
            // Detection and zoom modes show their existing target/status fields.

            if((S_track_enable_osd || S_black_enable_osd) &&
               (S_x_1d >= (S_track_enable_osd ? 12'd1024 : 12'd1056)) && (S_x_1d < 12'd1280) &&
               (S_y_1d >= (S_track_enable_osd ? 12'd24:12'd64)) &&
               (S_y_1d < (S_track_enable_osd ?
                    (((S_switch_state_osd == 4'b0011) ||
                      (S_switch_state_osd == 4'b0100)) ? 12'd400 : 12'd304) : 12'd128))) begin
                S_info_x = S_x_1d - (S_track_enable_osd ? 12'd1024 : 12'd1056);
                S_info_y = S_y_1d - (S_track_enable_osd ? 12'd24:12'd64);
                if(S_info_y < 12'd16) begin
                    if(S_track_enable_osd) begin
                        case(S_info_x[7:4])
                            4'd0: S_info_char = 8'h43;
                            4'd1: S_info_char = 8'h45;
                            4'd2: S_info_char = 8'h4e;
                            4'd3: S_info_char = 8'h54;
                            4'd4: S_info_char = 8'h45;
                            4'd5: S_info_char = 8'h52;
                            4'd6: S_info_char = 8'h3a;
                            4'd7: S_info_char = S_aim_valid ? (CHAR_0 + {4'd0,S_black_x_bcd[15:12]}) : 8'h2d;
                            4'd8: S_info_char = S_aim_valid ? (CHAR_0 + {4'd0,S_black_x_bcd[11:8]}) : 8'h2d;
                            4'd9: S_info_char = S_aim_valid ? (CHAR_0 + {4'd0,S_black_x_bcd[7:4]}) : 8'h2d;
                            4'd10: S_info_char = S_aim_valid ? (CHAR_0 + {4'd0,S_black_x_bcd[3:0]}) : 8'h2d;
                            4'd12: S_info_char = S_aim_valid ? (CHAR_0 + {4'd0,S_black_y_bcd[15:12]}) : 8'h2d;
                            4'd13: S_info_char = S_aim_valid ? (CHAR_0 + {4'd0,S_black_y_bcd[11:8]}) : 8'h2d;
                            4'd14: S_info_char = S_aim_valid ? (CHAR_0 + {4'd0,S_black_y_bcd[7:4]}) : 8'h2d;
                            4'd15: S_info_char = S_aim_valid ? (CHAR_0 + {4'd0,S_black_y_bcd[3:0]}) : 8'h2d;
                            4'd11: S_info_char = 8'h2c;
                            default: S_info_char = CHAR_SPACE;
                        endcase
                    end
                    else begin
                    case(S_info_x[7:4])
                        4'd0:  S_info_char = CHAR_X;
                        4'd1:  S_info_char = CHAR_COLON;
                        4'd2:  S_info_char = CHAR_0 + {4'd0,S_black_x_bcd[15:12]};
                        4'd3:  S_info_char = CHAR_0 + {4'd0,S_black_x_bcd[11:8]};
                        4'd4:  S_info_char = CHAR_0 + {4'd0,S_black_x_bcd[7:4]};
                        4'd5:  S_info_char = CHAR_0 + {4'd0,S_black_x_bcd[3:0]};
                        4'd6:  S_info_char = CHAR_SPACE;
                        4'd7:  S_info_char = CHAR_Y;
                        4'd8:  S_info_char = CHAR_COLON;
                        4'd9:  S_info_char = CHAR_0 + {4'd0,S_black_y_bcd[15:12]};
                        4'd10: S_info_char = CHAR_0 + {4'd0,S_black_y_bcd[11:8]};
                        4'd11: S_info_char = CHAR_0 + {4'd0,S_black_y_bcd[7:4]};
                        4'd12: S_info_char = CHAR_0 + {4'd0,S_black_y_bcd[3:0]};
                        default: S_info_char = 8'd0;
                    endcase
                    end
                    S_info_local_y = S_info_y;
                end
                else if(S_track_enable_osd &&
                        (S_info_y >= 12'd24) && (S_info_y < 12'd40)) begin
                    // DET reports the latest unique camera-frame decision;
                    // it stays zero while the cyan historical box is held.
                    case(S_info_x[7:4])
                        4'd0: S_info_char = CHAR_D;
                        4'd1: S_info_char = CHAR_E;
                        4'd2: S_info_char = CHAR_T;
                        4'd3: S_info_char = CHAR_COLON;
                        4'd4: S_info_char = CHAR_0 + {7'd0,S_track_detect_valid};
                        4'd5: S_info_char = CHAR_SPACE;
                        4'd6: S_info_char = CHAR_C;
                        4'd7: S_info_char = CHAR_A;
                        4'd8: S_info_char = CHAR_N;
                        4'd9: S_info_char = CHAR_D;
                        4'd10: S_info_char = CHAR_COLON;
                        4'd11: S_info_char = CHAR_0 + {7'd0,S_track_candidate_valid};
                        default: S_info_char = 8'd0;
                    endcase
                    S_info_local_y = S_info_y - 12'd24;
                end
                else if(S_track_enable_osd &&
                        (S_info_y >= 12'd48) && (S_info_y < 12'd64)) begin
                    case(S_info_x[7:4])
                        4'd0: S_info_char = CHAR_S;
                        4'd1: S_info_char = CHAR_T;
                        4'd2: S_info_char = CHAR_A;
                        4'd3: S_info_char = CHAR_T;
                        4'd4: S_info_char = CHAR_E;
                        4'd5: S_info_char = CHAR_COLON;
                        default: begin
                            if(S_track_detect_valid) begin
                                case(S_info_x[7:4]) // FOUND
                                    4'd6: S_info_char = CHAR_F;
                                    4'd7: S_info_char = CHAR_O;
                                    4'd8: S_info_char = 8'h55;
                                    4'd9: S_info_char = CHAR_N;
                                    4'd10: S_info_char = CHAR_D;
                                    default: S_info_char = 8'd0;
                                endcase
                            end
                            else if(S_track_valid) begin
                                case(S_info_x[7:4]) // HOLD
                                    4'd6: S_info_char = CHAR_H;
                                    4'd7: S_info_char = CHAR_O;
                                    4'd8: S_info_char = CHAR_L;
                                    4'd9: S_info_char = CHAR_D;
                                    default: S_info_char = 8'd0;
                                endcase
                            end
                            else if(S_track_candidate_valid && !S_track_candidate_ok) begin
                                case(S_info_x[7:4]) // REJECT
                                    4'd6: S_info_char = CHAR_R;
                                    4'd7: S_info_char = CHAR_E;
                                    4'd8: S_info_char = 8'h4a;
                                    4'd9: S_info_char = CHAR_E;
                                    4'd10: S_info_char = CHAR_C;
                                    4'd11: S_info_char = CHAR_T;
                                    default: S_info_char = 8'd0;
                                endcase
                            end
                            else if(S_track_mask_seen) begin
                                case(S_info_x[7:4]) // MASK (below candidate size)
                                    4'd6: S_info_char = CHAR_M;
                                    4'd7: S_info_char = CHAR_A;
                                    4'd8: S_info_char = CHAR_S;
                                    4'd9: S_info_char = 8'h4b;
                                    default: S_info_char = 8'd0;
                                endcase
                            end
                            else begin
                                case(S_info_x[7:4]) // NONE
                                    4'd6: S_info_char = CHAR_N;
                                    4'd7: S_info_char = CHAR_O;
                                    4'd8: S_info_char = CHAR_N;
                                    4'd9: S_info_char = CHAR_E;
                                    default: S_info_char = 8'd0;
                                endcase
                            end
                        end
                    endcase
                    S_info_local_y = S_info_y - 12'd48;
                end
                else if(S_track_enable_osd &&
                        (S_info_y >= 12'd72) && (S_info_y < 12'd88)) begin
                    case(S_info_x[7:4])
                        4'd0: S_info_char = 8'h57; // WANT: selected shape
                        4'd1: S_info_char = CHAR_A;
                        4'd2: S_info_char = CHAR_N;
                        4'd3: S_info_char = CHAR_T;
                        4'd4: S_info_char = CHAR_COLON;
                        default: S_info_char = F_shape_name(S_track_shape_osd, S_info_x[7:4] - 4'd5);
                    endcase
                    S_info_local_y = S_info_y - 12'd72;
                end
                else if(S_track_enable_osd &&
                        (S_info_y >= 12'd96) && (S_info_y < 12'd112)) begin
                    case(S_info_x[7:4])
                        4'd0: S_info_char = CHAR_S;
                        4'd1: S_info_char = CHAR_E;
                        4'd2: S_info_char = CHAR_L;
                        4'd3: S_info_char = CHAR_E;
                        4'd4: S_info_char = CHAR_C;
                        4'd5: S_info_char = CHAR_T;
                        4'd6: S_info_char = CHAR_COLON;
                        default: S_info_char = F_color_name(S_track_color_osd, S_info_x[7:4] - 4'd7);
                    endcase
                    S_info_local_y = S_info_y - 12'd96;
                end
                else if(S_track_enable_osd &&
                        (S_info_y >= 12'd120) && (S_info_y < 12'd136)) begin
                    case(S_info_x[7:4])
                        4'd0: S_info_char = CHAR_C;
                        4'd1: S_info_char = CHAR_O;
                        4'd2: S_info_char = CHAR_L;
                        4'd3: S_info_char = CHAR_O;
                        4'd4: S_info_char = CHAR_R;
                        4'd5: S_info_char = CHAR_COLON;
                        default: S_info_char = F_color_name(S_track_detect_valid ? S_track_color_osd : 3'd7,
                                                          S_info_x[7:4] - 4'd6);
                    endcase
                    S_info_local_y = S_info_y - 12'd120;
                end
                else if(S_track_enable_osd &&
                        (S_info_y >= 12'd144) && (S_info_y < 12'd160)) begin
                    case(S_info_x[7:4])
                        4'd0: S_info_char = CHAR_S;
                        4'd1: S_info_char = CHAR_H;
                        4'd2: S_info_char = CHAR_A;
                        4'd3: S_info_char = CHAR_P;
                        4'd4: S_info_char = CHAR_E;
                        4'd5: S_info_char = CHAR_COLON;
                        default: S_info_char = F_shape_name(
                            S_track_detect_valid ? S_track_shape : 2'd0,
                            S_info_x[7:4] - 4'd6);
                    endcase
                    S_info_local_y = S_info_y - 12'd144;
                end
                else if(S_track_enable_osd &&
                        (S_info_y >= 12'd168) && (S_info_y < 12'd184)) begin
                    case(S_info_x[7:4])
                            4'd0: S_info_char = 8'h44;
                            4'd1: S_info_char = 8'h58;
                            4'd2: S_info_char = 8'h3a;
                            4'd3: S_info_char = !S_aim_valid ? 8'h2d : (S_aim_dx[12] ? 8'h2d : 8'h2b);
                            4'd4: S_info_char = S_aim_valid ? (CHAR_0 + {4'd0,S_aim_dx_bcd[15:12]}) : 8'h2d;
                            4'd5: S_info_char = S_aim_valid ? (CHAR_0 + {4'd0,S_aim_dx_bcd[11:8]}) : 8'h2d;
                            4'd6: S_info_char = S_aim_valid ? (CHAR_0 + {4'd0,S_aim_dx_bcd[7:4]}) : 8'h2d;
                            4'd7: S_info_char = S_aim_valid ? (CHAR_0 + {4'd0,S_aim_dx_bcd[3:0]}) : 8'h2d;
                            default: S_info_char = CHAR_SPACE;
                    endcase
                    S_info_local_y = S_info_y - 12'd168;
                end
                else if(S_track_enable_osd &&
                        (S_info_y >= 12'd192) && (S_info_y < 12'd208)) begin
                    case(S_info_x[7:4])
                            4'd0: S_info_char = 8'h44;
                            4'd1: S_info_char = 8'h59;
                            4'd2: S_info_char = 8'h3a;
                            4'd3: S_info_char = !S_aim_valid ? 8'h2d : (S_aim_dy[12] ? 8'h2d : 8'h2b);
                            4'd4: S_info_char = S_aim_valid ? (CHAR_0 + {4'd0,S_aim_dy_bcd[15:12]}) : 8'h2d;
                            4'd5: S_info_char = S_aim_valid ? (CHAR_0 + {4'd0,S_aim_dy_bcd[11:8]}) : 8'h2d;
                            4'd6: S_info_char = S_aim_valid ? (CHAR_0 + {4'd0,S_aim_dy_bcd[7:4]}) : 8'h2d;
                            4'd7: S_info_char = S_aim_valid ? (CHAR_0 + {4'd0,S_aim_dy_bcd[3:0]}) : 8'h2d;
                            default: S_info_char = CHAR_SPACE;
                    endcase
                    S_info_local_y = S_info_y - 12'd192;
                end
                else if(S_track_enable_osd &&
                        (S_info_y >= 12'd216) && (S_info_y < 12'd232)) begin
                    case(S_info_x[7:4])
                            4'd0: S_info_char = 8'h48;
                            4'd1: S_info_char = 8'h3a;
                            default: S_info_char = F_aim_direction_name(S_aim_h_direction,
                                    1'b0, S_info_x[7:4] - 4'd2);
                    endcase
                    S_info_local_y = S_info_y - 12'd216;
                end
                else if(S_track_enable_osd &&
                        (S_info_y >= 12'd240) && (S_info_y < 12'd256)) begin
                    case(S_info_x[7:4])
                            4'd0: S_info_char = 8'h56;
                            4'd1: S_info_char = 8'h3a;
                            default: S_info_char = F_aim_direction_name(S_aim_v_direction,
                                    1'b1, S_info_x[7:4] - 4'd2);
                    endcase
                    S_info_local_y = S_info_y - 12'd240;
                end
                else if(S_track_enable_osd &&
                        (S_info_y >= 12'd264) && (S_info_y < 12'd280)) begin
                    case(S_info_x[7:4])
                            4'd0: S_info_char = 8'h41;
                            4'd1: S_info_char = 8'h49;
                            4'd2: S_info_char = 8'h4d;
                            4'd3: S_info_char = 8'h3a;
                        default: begin
                            if(!S_aim_valid) begin
                                case(S_info_x[7:4])
                                    4'd4: S_info_char = 8'h4e;
                                    4'd5: S_info_char = 8'h4f;
                                    4'd6: S_info_char = 8'h20;
                                    4'd7: S_info_char = 8'h54;
                                    4'd8: S_info_char = 8'h41;
                                    4'd9: S_info_char = 8'h52;
                                    4'd10: S_info_char = 8'h47;
                                    4'd11: S_info_char = 8'h45;
                                    4'd12: S_info_char = 8'h54;
                                    default: S_info_char = CHAR_SPACE;
                                endcase
                            end
                            else if(S_aim_centered) begin
                                case(S_info_x[7:4])
                                    4'd4: S_info_char = 8'h43;
                                    4'd5: S_info_char = 8'h45;
                                    4'd6: S_info_char = 8'h4e;
                                    4'd7: S_info_char = 8'h54;
                                    4'd8: S_info_char = 8'h45;
                                    4'd9: S_info_char = 8'h52;
                                    4'd10: S_info_char = 8'h45;
                                    4'd11: S_info_char = 8'h44;
                                    default: S_info_char = CHAR_SPACE;
                                endcase
                            end
                            else begin
                                case(S_info_x[7:4])
                                    4'd4: S_info_char = 8'h41;
                                    4'd5: S_info_char = 8'h44;
                                    4'd6: S_info_char = 8'h4a;
                                    4'd7: S_info_char = 8'h55;
                                    4'd8: S_info_char = 8'h53;
                                    4'd9: S_info_char = 8'h54;
                                    default: S_info_char = CHAR_SPACE;
                                endcase
                            end
                        end
                    endcase
                    S_info_local_y = S_info_y - 12'd264;
                end
                else if(S_track_enable_osd &&
                        (S_info_y >= 12'd288) && (S_info_y < 12'd304)) begin
                    // Servo status is independent of target aim errors.
                    case(S_switch_state_osd)
                        4'b0011: begin
                            case(S_servo_state_osd)
                                4'd0: begin
                                    case(S_info_x[7:4])
                                        4'd0: S_info_char = 8'h41;
                                        4'd1: S_info_char = 8'h49;
                                        4'd2: S_info_char = 8'h4d;
                                        4'd3: S_info_char = 8'h3a;
                                        4'd4: S_info_char = 8'h49;
                                        4'd5: S_info_char = 8'h44;
                                        4'd6: S_info_char = 8'h4c;
                                        4'd7: S_info_char = 8'h45;
                                        default: S_info_char = CHAR_SPACE;
                                    endcase
                                end
                                4'd1: begin
                                    case(S_info_x[7:4])
                                        4'd0: S_info_char = 8'h41;
                                        4'd1: S_info_char = 8'h49;
                                        4'd2: S_info_char = 8'h4d;
                                        4'd3: S_info_char = 8'h3a;
                                        4'd4: S_info_char = 8'h50;
                                        4'd5: S_info_char = 8'h41;
                                        4'd6: S_info_char = 8'h55;
                                        4'd7: S_info_char = 8'h53;
                                        4'd8: S_info_char = 8'h45;
                                        4'd9: S_info_char = 8'h44;
                                        default: S_info_char = CHAR_SPACE;
                                    endcase
                                end
                                4'd2: begin
                                    case(S_info_x[7:4])
                                        4'd0: S_info_char = 8'h41;
                                        4'd1: S_info_char = 8'h49;
                                        4'd2: S_info_char = 8'h4d;
                                        4'd3: S_info_char = 8'h3a;
                                        4'd4: S_info_char = 8'h53;
                                        4'd5: S_info_char = 8'h45;
                                        4'd6: S_info_char = 8'h41;
                                        4'd7: S_info_char = 8'h52;
                                        4'd8: S_info_char = 8'h43;
                                        4'd9: S_info_char = 8'h48;
                                        default: S_info_char = CHAR_SPACE;
                                    endcase
                                end
                                4'd3: begin
                                    case(S_info_x[7:4])
                                        4'd0: S_info_char = 8'h41;
                                        4'd1: S_info_char = 8'h49;
                                        4'd2: S_info_char = 8'h4d;
                                        4'd3: S_info_char = 8'h3a;
                                        4'd4: S_info_char = 8'h54;
                                        4'd5: S_info_char = 8'h52;
                                        4'd6: S_info_char = 8'h41;
                                        4'd7: S_info_char = 8'h43;
                                        4'd8: S_info_char = 8'h4b;
                                        4'd9: S_info_char = 8'h49;
                                        4'd10: S_info_char = 8'h4e;
                                        4'd11: S_info_char = 8'h47;
                                        default: S_info_char = CHAR_SPACE;
                                    endcase
                                end
                                4'd4: begin
                                    case(S_info_x[7:4])
                                        4'd0: S_info_char = 8'h41;
                                        4'd1: S_info_char = 8'h49;
                                        4'd2: S_info_char = 8'h4d;
                                        4'd3: S_info_char = 8'h3a;
                                        4'd4: S_info_char = 8'h43;
                                        4'd5: S_info_char = 8'h45;
                                        4'd6: S_info_char = 8'h4e;
                                        4'd7: S_info_char = 8'h54;
                                        4'd8: S_info_char = 8'h45;
                                        4'd9: S_info_char = 8'h52;
                                        4'd10: S_info_char = 8'h45;
                                        4'd11: S_info_char = 8'h44;
                                        default: S_info_char = CHAR_SPACE;
                                    endcase
                                end
                                4'd5: begin
                                    case(S_info_x[7:4])
                                        4'd0: S_info_char = 8'h41;
                                        4'd1: S_info_char = 8'h49;
                                        4'd2: S_info_char = 8'h4d;
                                        4'd3: S_info_char = 8'h3a;
                                        4'd4: S_info_char = 8'h54;
                                        4'd5: S_info_char = 8'h45;
                                        4'd6: S_info_char = 8'h4d;
                                        4'd7: S_info_char = 8'h50;
                                        4'd9: S_info_char = 8'h4c;
                                        4'd10: S_info_char = 8'h4f;
                                        4'd11: S_info_char = 8'h53;
                                        4'd12: S_info_char = 8'h54;
                                        default: S_info_char = CHAR_SPACE;
                                    endcase
                                end
                                4'd6: begin
                                    case(S_info_x[7:4])
                                        4'd0: S_info_char = 8'h41;
                                        4'd1: S_info_char = 8'h49;
                                        4'd2: S_info_char = 8'h4d;
                                        4'd3: S_info_char = 8'h3a;
                                        4'd4: S_info_char = 8'h4c;
                                        4'd5: S_info_char = 8'h4f;
                                        4'd6: S_info_char = 8'h53;
                                        4'd7: S_info_char = 8'h54;
                                        default: S_info_char = CHAR_SPACE;
                                    endcase
                                end
                                4'd7: begin
                                    case(S_info_x[7:4])
                                        4'd0: S_info_char = 8'h41;
                                        4'd1: S_info_char = 8'h49;
                                        4'd2: S_info_char = 8'h4d;
                                        4'd3: S_info_char = 8'h3a;
                                        4'd4: S_info_char = 8'h4c;
                                        4'd5: S_info_char = 8'h49;
                                        4'd6: S_info_char = 8'h4d;
                                        4'd7: S_info_char = 8'h49;
                                        4'd8: S_info_char = 8'h54;
                                        default: S_info_char = CHAR_SPACE;
                                    endcase
                                end
                                4'd8: begin
                                    case(S_info_x[7:4])
                                        4'd0: S_info_char = 8'h41;
                                        4'd1: S_info_char = 8'h49;
                                        4'd2: S_info_char = 8'h4d;
                                        4'd3: S_info_char = 8'h3a;
                                        4'd4: S_info_char = 8'h48;
                                        4'd5: S_info_char = 8'h4f;
                                        4'd6: S_info_char = 8'h4c;
                                        4'd7: S_info_char = 8'h44;
                                        default: S_info_char = CHAR_SPACE;
                                    endcase
                                end
                                default: S_info_char = CHAR_SPACE;
                            endcase
                        end
                        4'b0100: begin
                            case(S_servo_state_osd)
                                4'd9: begin
                                    case(S_info_x[7:4])
                                        4'd0: S_info_char=8'h48; 4'd1: S_info_char=8'h4f;
                                        4'd2: S_info_char=8'h4d; 4'd3: S_info_char=8'h45;
                                        4'd4: S_info_char=8'h3a; 4'd5: S_info_char=8'h50;
                                        4'd6: S_info_char=8'h52; 4'd7: S_info_char=8'h45;
                                        4'd8: S_info_char=8'h53; 4'd9: S_info_char=8'h53;
                                        4'd11: S_info_char=8'h4b; 4'd12: S_info_char=8'h34;
                                        default: S_info_char=CHAR_SPACE;
                                    endcase
                                end
                                4'd10: begin
                                    case(S_info_x[7:4])
                                        4'd0: S_info_char=8'h48; 4'd1: S_info_char=8'h4f;
                                        4'd2: S_info_char=8'h4d; 4'd3: S_info_char=8'h45;
                                        4'd4: S_info_char=8'h3a; 4'd5: S_info_char=8'h52;
                                        4'd6: S_info_char=8'h45; 4'd7: S_info_char=8'h54;
                                        4'd8: S_info_char=8'h55; 4'd9: S_info_char=8'h52;
                                        4'd10: S_info_char=8'h4e; 4'd11: S_info_char=8'h49;
                                        4'd12: S_info_char=8'h4e; 4'd13: S_info_char=8'h47;
                                        default: S_info_char=CHAR_SPACE;
                                    endcase
                                end
                                4'd11: begin
                                    case(S_info_x[7:4])
                                        4'd0: S_info_char=8'h48; 4'd1: S_info_char=8'h4f;
                                        4'd2: S_info_char=8'h4d; 4'd3: S_info_char=8'h45;
                                        4'd4: S_info_char=8'h3a; 4'd5: S_info_char=8'h43;
                                        4'd6: S_info_char=8'h45; 4'd7: S_info_char=8'h4e;
                                        4'd8: S_info_char=8'h54; 4'd9: S_info_char=8'h45;
                                        4'd10: S_info_char=8'h52; 4'd11: S_info_char=8'h45;
                                        4'd12: S_info_char=8'h44;
                                        default: S_info_char=CHAR_SPACE;
                                    endcase
                                end
                                4'd12: begin
                                    case(S_info_x[7:4])
                                        4'd0: S_info_char=8'h48; 4'd1: S_info_char=8'h4f;
                                        4'd2: S_info_char=8'h4d; 4'd3: S_info_char=8'h45;
                                        4'd4: S_info_char=8'h3a; 4'd5: S_info_char=8'h43;
                                        4'd6: S_info_char=8'h41; 4'd7: S_info_char=8'h4e;
                                        4'd8: S_info_char=8'h43; 4'd9: S_info_char=8'h45;
                                        4'd10: S_info_char=8'h4c; 4'd11: S_info_char=8'h4c;
                                        4'd12: S_info_char=8'h45; 4'd13: S_info_char=8'h44;
                                        default: S_info_char=CHAR_SPACE;
                                    endcase
                                end
                                default: begin
                                    case(S_info_x[7:4])
                                        4'd0: S_info_char=8'h48; 4'd1: S_info_char=8'h4f;
                                        4'd2: S_info_char=8'h4d; 4'd3: S_info_char=8'h45;
                                        4'd4: S_info_char=8'h3a; 4'd5: S_info_char=8'h50;
                                        4'd6: S_info_char=8'h52; 4'd7: S_info_char=8'h45;
                                        4'd8: S_info_char=8'h53; 4'd9: S_info_char=8'h53;
                                        4'd11: S_info_char=8'h4b; 4'd12: S_info_char=8'h34;
                                        default: S_info_char=CHAR_SPACE;
                                    endcase
                                end
                            endcase
                        end
                        default: S_info_char = CHAR_SPACE;
                    endcase
                    S_info_local_y = S_info_y - 12'd288;
                end
                else if(S_track_enable_osd && S_servo_view &&
                        (S_info_y >= 12'd312) && (S_info_y < 12'd328)) begin
                    // Actual emitted pulse widths; these are commands, not angle feedback.
                    case(S_info_x[7:4])
                        4'd0: S_info_char=8'h50;
                        4'd1: S_info_char=8'h3a;
                        4'd2: S_info_char=CHAR_0+{4'd0,S_pan_pulse_bcd[15:12]};
                        4'd3: S_info_char=CHAR_0+{4'd0,S_pan_pulse_bcd[11:8]};
                        4'd4: S_info_char=CHAR_0+{4'd0,S_pan_pulse_bcd[7:4]};
                        4'd5: S_info_char=CHAR_0+{4'd0,S_pan_pulse_bcd[3:0]};
                        4'd6: S_info_char=8'h20;
                        4'd7: S_info_char=8'h54;
                        4'd8: S_info_char=8'h3a;
                        4'd9: S_info_char=CHAR_0+{4'd0,S_tilt_pulse_bcd[15:12]};
                        4'd10: S_info_char=CHAR_0+{4'd0,S_tilt_pulse_bcd[11:8]};
                        4'd11: S_info_char=CHAR_0+{4'd0,S_tilt_pulse_bcd[7:4]};
                        4'd12: S_info_char=CHAR_0+{4'd0,S_tilt_pulse_bcd[3:0]};
                        4'd13: S_info_char=8'h55;
                        4'd14: S_info_char=8'h53;
                        default: S_info_char=CHAR_SPACE;
                    endcase
                    S_info_local_y=S_info_y-12'd312;
                end
                else if(S_track_enable_osd && S_servo_view &&
                        (S_info_y >= 12'd336) && (S_info_y < 12'd352)) begin
                    case(S_info_x[7:4])
                        4'd0: S_info_char=8'h50;
                        4'd1: S_info_char=8'h41;
                        4'd2: S_info_char=8'h4e;
                        4'd3: S_info_char=8'h3a;
                        4'd4: S_info_char=8'h30;
                        4'd5: S_info_char=8'h35;
                        4'd6: S_info_char=8'h30;
                        4'd7: S_info_char=8'h30;
                        4'd8: S_info_char=8'h2d;
                        4'd9: S_info_char=8'h31;
                        4'd10: S_info_char=8'h39;
                        4'd11: S_info_char=8'h30;
                        4'd12: S_info_char=8'h30;
                        default: S_info_char=CHAR_SPACE;
                    endcase
                    S_info_local_y=S_info_y-12'd336;
                end
                else if(S_track_enable_osd && (S_switch_state_osd == 4'b0011) &&
                        (S_info_y >= 12'd384) && (S_info_y < 12'd400)) begin
                    case(S_info_x[7:4])
                        4'd0: S_info_char=8'h4b;
                        4'd1: S_info_char=8'h31;
                        4'd2: S_info_char=8'h2f;
                        4'd3: S_info_char=8'h4b;
                        4'd4: S_info_char=8'h32;
                        4'd5: S_info_char=8'h3a;
                        4'd6: S_info_char=8'h43;
                        4'd7: S_info_char=8'h4f;
                        4'd8: S_info_char=8'h4c;
                        4'd9: S_info_char=8'h4f;
                        4'd10: S_info_char=8'h52;
                        default: S_info_char=CHAR_SPACE;
                    endcase
                    S_info_local_y=S_info_y-12'd384;
                end
                else if(S_track_enable_osd && S_servo_view &&
                        (S_info_y >= 12'd360) && (S_info_y < 12'd376)) begin
                    case(S_info_x[7:4])
                        4'd0: S_info_char=8'h54;
                        4'd1: S_info_char=8'h49;
                        4'd2: S_info_char=8'h4c;
                        4'd3: S_info_char=8'h54;
                        4'd4: S_info_char=8'h3a;
                        4'd5: S_info_char=8'h30;
                        4'd6: S_info_char=8'h35;
                        4'd7: S_info_char=8'h30;
                        4'd8: S_info_char=8'h30;
                        4'd9: S_info_char=8'h2d;
                        4'd10: S_info_char=8'h31;
                        4'd11: S_info_char=8'h38;
                        4'd12: S_info_char=8'h35;
                        4'd13: S_info_char=8'h30;
                        default: S_info_char=CHAR_SPACE;
                    endcase
                    S_info_local_y=S_info_y-12'd360;
                end
                else if(S_black_enable_osd &&
                        (S_info_y >= 12'd24) && (S_info_y < 12'd40)) begin
                    case(S_info_x[7:4])
                        4'd0: S_info_char = CHAR_D;
                        4'd1: S_info_char = CHAR_I;
                        4'd2: S_info_char = CHAR_S;
                        4'd3: S_info_char = CHAR_T;
                        4'd4: S_info_char = CHAR_COLON;
                        4'd5: S_info_char = CHAR_0 + {4'd0,S_black_dist_bcd[15:12]};
                        4'd6: S_info_char = CHAR_0 + {4'd0,S_black_dist_bcd[11:8]};
                        4'd7: S_info_char = CHAR_0 + {4'd0,S_black_dist_bcd[7:4]};
                        4'd8: S_info_char = CHAR_0 + {4'd0,S_black_dist_bcd[3:0]};
                        default: S_info_char = 8'd0;
                    endcase
                    S_info_local_y = S_info_y - 12'd24;
                end
                else if(S_black_enable_osd &&
                        (S_info_y >= 12'd48) && (S_info_y < 12'd64)) begin
                    if(I_zoom_active && S_black_valid_osd) begin
                        case(S_info_x[7:4])
                            4'd0: S_info_char = CHAR_W;
                            4'd1: S_info_char = CHAR_A;
                            4'd2: S_info_char = CHAR_R;
                            4'd3: S_info_char = CHAR_N;
                            4'd4: S_info_char = CHAR_I;
                            4'd5: S_info_char = CHAR_N;
                            4'd6: S_info_char = CHAR_G;
                            default: S_info_char = 8'd0;
                        endcase
                    end
                    else if(!S_black_valid_osd) begin
                        case(S_info_x[7:4])
                            4'd0: S_info_char = CHAR_N;
                            4'd1: S_info_char = CHAR_O;
                            4'd2: S_info_char = CHAR_SPACE;
                            4'd3: S_info_char = CHAR_T;
                            4'd4: S_info_char = CHAR_A;
                            4'd5: S_info_char = CHAR_R;
                            4'd6: S_info_char = CHAR_G;
                            4'd7: S_info_char = CHAR_E;
                            4'd8: S_info_char = CHAR_T;
                            default: S_info_char = 8'd0;
                        endcase
                    end
                    S_info_local_y = S_info_y - 12'd48;
                end
                S_pf_char = S_info_char;
                S_info_local_x = {1'b0,S_info_x[3:0]};
                S_info_col = S_info_local_x[3:0];
                S_info_row = S_info_local_y[3:0];
                S_pf_row = S_info_row;
                S_info_on = F_char_pixel(S_pf_row_bits, S_info_col);
                if(S_info_on) begin
                    S_osd_hit = 1'b1;
                    if(S_track_enable_osd)
                        S_osd_color = COLOR_TRACK_BOX;
                    else
                        S_osd_color = I_zoom_active ? COLOR_BLACK_LOCK : 24'hffffff;
                end
            end

            if(S_caption_visible && S_x_1d>=S_caption_x && S_x_1d<S_caption_x+12'd136 &&
               S_y_1d>=S_caption_y && S_y_1d<S_caption_y+12'd36) begin
                S_caption_dx=S_x_1d-S_caption_x;S_caption_dy=S_y_1d-S_caption_y;
                S_osd_hit=1;S_osd_color=24'h101820;
                if(S_caption_dx>=4 && S_caption_dx<132 && S_caption_dy>=2 && S_caption_dy<34) begin
                    S_pf_local_x=S_caption_dx-8'd4;
                    S_pf_local_y=S_caption_dy-6'd2;
                    S_pf_char=S_pf_local_y[4]?F_shape_name(S_track_shape_osd,(S_caption_dx-8'd4)>>4):
                                                            F_color_name(S_track_color_osd,(S_caption_dx-8'd4)>>4);
                    S_pf_row=S_pf_local_y[3:0];S_pf_col=S_pf_local_x[3:0];
                    if(F_char_pixel(S_pf_row_bits,S_pf_col))
                        S_osd_color=S_pf_local_y[4]?24'hffffff:24'h00e6ff;
                end
            end
        end
    end

    reg S_osd_hit_2d;
    reg [23:0] S_osd_color_2d;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin S_osd_hit_2d<=0;S_osd_color_2d<=0;end
        else begin S_osd_hit_2d<=S_osd_hit;S_osd_color_2d<=S_osd_color;end
    end


    reg S_base_vsync,S_base_hsync,S_base_de;
    reg [23:0] S_base_data,S_base_data_1d,S_base_data_2d;
    reg [2:0] S_sync_1d,S_sync_2d,S_label_en_pipe;
    wire S_label_hit;
    wire [23:0] S_label_color;
    label_application u_label_application (
        .I_clk(I_clk),.I_rst_n(I_rst_n),.I_enable(I_label_enable),
        .I_de(S_video_de_2d),.I_x(S_x_2d),.I_y(S_y_2d),
        .I_rgb(S_video_data_raw_2d),.I_frame_id(S_display_frame_bcd_osd),
        .I_keys_n(I_label_keys_n),.I_imaging_locked(I_label_imaging_locked),
        .I_remote_action(I_label_remote_action),
        .I_zoom_supported(I_label_zoom_supported),.I_zoom_active(I_label_zoom_active),
        .I_zoom_src_x(I_label_zoom_src_x),.I_zoom_src_y(I_label_zoom_src_y),
        .O_zoom_request(O_label_zoom_request),.O_zoom_src_x(O_label_zoom_src_x),.O_zoom_src_y(O_label_zoom_src_y),
        .O_imaging_lock(O_label_imaging_lock),.O_hit(S_label_hit),.O_color(S_label_color),
        .O_buzzer_n(O_label_buzzer_n),.O_seg_sel(),.O_seg_dig(),.O_display_result(O_label_result),
        .O_status_result(O_label_status_result),.O_status_cause(O_label_status_cause),
        .O_status_passes(O_label_status_passes),.O_status_fails(O_label_status_fails),
        .O_status_unknowns(O_label_status_unknowns),.O_barcode_valid(O_barcode_valid),
        .O_barcode_order(O_barcode_order),.O_barcode_count(O_barcode_count)
    );
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_base_data_1d<=0;S_base_data_2d<=0;S_sync_1d<=0;S_sync_2d<=0;S_label_en_pipe<=0;
            O_hdmi_vsync<=0;O_hdmi_hsync<=0;O_hdmi_de<=0;O_hdmi_data<=0;
        end else begin
            S_base_data_1d<=S_base_data;S_base_data_2d<=S_base_data_1d;
            S_sync_1d<={S_base_vsync,S_base_hsync,S_base_de};S_sync_2d<=S_sync_1d;
            {O_hdmi_vsync,O_hdmi_hsync,O_hdmi_de}<=S_sync_2d;
            S_label_en_pipe<={S_label_en_pipe[1:0],I_label_enable};
            O_hdmi_data<=(S_label_en_pipe[2] && S_label_hit) ? S_label_color : S_base_data_2d;
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_video_vsync_1d <= 1'b0;
            S_video_vsync_2d <= 1'b0;
            S_video_hsync_1d <= 1'b0;
            S_video_hsync_2d <= 1'b0;
            S_video_de_1d    <= 1'b0;
            S_video_de_2d    <= 1'b0;
            S_video_data_raw_2d <= 24'd0;
            S_base_vsync     <= 1'b0;
            S_base_hsync     <= 1'b0;
            S_base_de        <= 1'b0;
            S_base_data      <= 24'd0;
        end
        else begin
            S_video_vsync_1d <= I_video_vsync;
            S_video_vsync_2d <= S_video_vsync_1d;
            S_base_vsync     <= S_video_vsync_2d;

            S_video_hsync_1d <= I_video_hsync;
            S_video_hsync_2d <= S_video_hsync_1d;
            S_base_hsync     <= S_video_hsync_2d;

            S_video_de_1d    <= I_video_de;
            S_video_de_2d    <= S_video_de_1d;
            S_base_de        <= S_video_de_2d;
            S_video_data_1d  <= I_video_rd_data;
            S_video_data_raw_2d <= S_video_data_1d;
            if(S_teach_overlay_on)
                S_video_data_2d <= S_teach_overlay_pixel;
            else if(S_zoom_banner_on)
                S_video_data_2d <= S_zoom_banner_pixel;
            else if(S_motion_enable_osd && S_motion_border_1d)
                S_video_data_2d <= COLOR_MOTION_BOX;
            else
                S_video_data_2d <= S_video_data_1d;

            if(DEBUG_MODE == 1) begin
                if(S_video_de_2d) begin
                    if(S_x < 12'd128)
                        S_base_data <= 24'hff0000;
                    else if(S_x < 12'd256)
                        S_base_data <= 24'h00ff00;
                    else if(S_x < 12'd384)
                        S_base_data <= 24'h0000ff;
                    else if(S_x < 12'd512)
                        S_base_data <= 24'hffff00;
                    else if(S_x < 12'd640)
                        S_base_data <= 24'h00ffff;
                    else if(S_x < 12'd768)
                        S_base_data <= 24'hff00ff;
                    else if(S_x < 12'd896)
                        S_base_data <= 24'hffffff;
                    else
                        S_base_data <= 24'h202020;
                end
                else begin
                    S_base_data <= 24'd0;
                end
            end
            else if(DEBUG_MODE == 2) begin
                if(S_video_de_2d) begin
                    case (I_debug_status)
                        4'b0000: S_base_data <= 24'h000000;
                        4'b0001: S_base_data <= 24'hff0000;
                        4'b0011: S_base_data <= 24'hffff00;
                        4'b0111: S_base_data <= 24'h00ff00;
                        4'b1111: S_base_data <= I_video_rd_data;
                        default: S_base_data <= 24'h0000ff;
                    endcase
                end
                else begin
                    S_base_data <= 24'd0;
                end
            end
            else if(DEBUG_MODE == 3) begin
                if(S_video_de_2d) begin
                    if(S_x < 12'd256)
                        S_base_data <= I_debug_status[0] ? 24'hff8000 : 24'h201000;
                    else if(S_x < 12'd512)
                        S_base_data <= I_debug_status[1] ? 24'hffff00 : 24'h202000;
                    else if(S_x < 12'd768)
                        S_base_data <= I_debug_status[2] ? 24'hff0000 : 24'h200000;
                    else
                        S_base_data <= I_debug_status[3] ? 24'h00ffff : 24'h002020;
                end
                else begin
                    S_base_data <= 24'd0;
                end
            end
            else begin
                if(I_label_enable)
                    S_base_data <= S_compact_logo[24] ? S_compact_logo[23:0] : S_video_data_raw_2d;
                else if(S_compact_logo[24])
                    S_base_data <= S_compact_logo[23:0];
                else if(S_osd_hit_2d)
                    S_base_data <= S_osd_color_2d;
                else if(S_teach_overlay_on_2d)
                    S_base_data <= S_video_data_2d;
                else if(S_black_enable_osd) begin
                    // The locator sees the actual full or enlarged image.
                    // Its box therefore already uses display coordinates.
                    if(S_track_border_2d)
                        S_base_data <= I_zoom_active ? COLOR_BLACK_LOCK : COLOR_BLACK_WAIT;
                    else
                        S_base_data <= S_video_data_2d;
                end
                else if(S_track_enable_osd) begin
                    // Use the same stage-2 coordinates as the raw pixels/OSD.
                    if(S_track_cross_2d)
                        S_base_data <= COLOR_TRACK_CROSS;
                    else if(S_aim_center_cross_2d)
                        S_base_data <= 24'hff8000;
                    else if(S_track_border_2d)
                        S_base_data <= COLOR_TRACK_BOX;
                    else if(S_track_raw_border_2d)
                        S_base_data <= 24'hffff00;
                    else if(S_track_mask_view)
                        S_base_data <= S_track_mask_pixel ?
                                       S_track_mask_fill : S_video_data_raw_2d;
                    else
                        S_base_data <= S_video_data_raw_2d;
                end
                else
                    S_base_data <= S_video_data_2d;
            end
        end
    end

endmodule


// Low-resource frame-difference motion detector.
//
// The 1280x720 image is averaged into 8x8 luminance blocks (160x90).  One
// 8-bit value per block is retained, so a complete previous frame fits in
// embedded RAM.  Only a new camera frame identity is processed; repeated HDMI
// scans of the same 30-FPS camera frame retain the preceding result.  A causal
// neighbour test rejects isolated noisy blocks, while a global-change limit
// suppresses exposure and lighting transitions.
module motion_detector #(
    parameter IMG_WIDTH      = 1280,
    parameter IMG_HEIGHT     = 720,
    parameter DIFF_THRESHOLD = 8'd18,
    parameter MIN_BLOCKS     = 14'd10,
    parameter MAX_BLOCKS     = 14'd7200,
    parameter HOLD_FRAMES    = 3
)(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_enable,
    input  wire        I_frame_start,
    input  wire [23:0] I_frame_id,
    input  wire        I_de,
    input  wire [11:0] I_x,
    input  wire [11:0] I_y,
    input  wire [23:0] I_rgb,
    output reg         O_motion_valid,
    output reg  [11:0] O_left,
    output reg  [11:0] O_right,
    output reg  [11:0] O_top,
    output reg  [11:0] O_bottom,
    output reg  [15:0] O_count_bcd,
    output wire [4:0] O_regions,
    output wire O_regions_valid,O_regions_overflow
);

    localparam integer BLOCK_SHIFT  = 3;
    localparam integer GRID_WIDTH   = IMG_WIDTH >> BLOCK_SHIFT;
    localparam integer GRID_HEIGHT  = IMG_HEIGHT >> BLOCK_SHIFT;
    localparam integer TOTAL_BLOCKS = GRID_WIDTH * GRID_HEIGHT;

    wire [7:0] red   = I_rgb[23:16];
    wire [7:0] green = I_rgb[15:8];
    wire [7:0] blue  = I_rgb[7:0];
    wire [7:0] gray  = {2'b0,red[7:2]} +
                       {1'b0,green[7:1]} +
                       {2'b0,blue[7:2]};

    wire [7:0] block_x = I_x[10:3];
    wire [6:0] block_y = I_y[9:3];
    wire       end_block_column = (I_x[2:0] == 3'd7);
    wire       end_block_row    = (I_y[2:0] == 3'd7);

    reg [10:0] horizontal_sum;
    wire [10:0] completed_row_sum = horizontal_sum + {3'd0,gray};

    // Partial sums for the 160 block columns.  Do not reset inferred RAMs;
    // the first row/frame naturally initializes every addressed location.
    (* ram_style = "block" *) reg [13:0] vertical_sum_mem [0:GRID_WIDTH-1];
    (* ram_style = "block" *) reg [7:0] previous_luma_mem [0:TOTAL_BLOCKS-1];
    (* ram_style = "block" *) reg motion_line_mem [0:GRID_WIDTH-1];

    wire [13:0] previous_vertical_sum = vertical_sum_mem[block_x];
    wire [13:0] completed_block_sum = previous_vertical_sum +
                                                {3'd0,completed_row_sum};
    wire [7:0] completed_block_luma = completed_block_sum[13:6];

    reg [13:0] block_addr;
    reg [7:0] previous_block_luma;
    reg       compare_pending;
    reg [7:0] pending_block_luma;
    reg [7:0] pending_block_x;
    reg [6:0] pending_block_y;
    reg       pending_left_changed;
    reg       pending_top_changed;
    reg       pending_top_left_changed;
    wire [8:0] luma_difference =
        (pending_block_luma >= previous_block_luma) ?
        ({1'b0,pending_block_luma} - {1'b0,previous_block_luma}) :
        ({1'b0,previous_block_luma} - {1'b0,pending_block_luma});
    wire raw_changed = (luma_difference >= {1'b0,DIFF_THRESHOLD});

    reg left_changed;
    reg top_left_changed;
    wire top_changed = (block_y != 7'd0) && motion_line_mem[block_x];
    wire neighbour_changed =
                             ((pending_block_x != 8'd0) &&
                              pending_left_changed) ||
                             pending_top_changed ||
                             ((pending_block_x != 8'd0) &&
                              (pending_block_y != 7'd0) &&
                              pending_top_left_changed);
    wire filtered_changed = raw_changed && neighbour_changed;

    reg        process_frame;
    reg        frame_id_valid;
    reg [23:0] last_frame_id;
    reg        history_valid;

    reg [13:0] work_count;
    reg [15:0] work_count_bcd;
    reg [7:0]  work_min_x;
    reg [7:0]  work_max_x;
    reg [6:0]  work_min_y;
    reg [6:0]  work_max_y;
    reg [2:0]  hold_frames;

    wire new_camera_frame = !frame_id_valid || (I_frame_id != last_frame_id);
    wire block_complete = process_frame && I_de &&
                          end_block_column && end_block_row;
    wire result_valid = history_valid &&
                        (work_count >= MIN_BLOCKS) &&
                        (work_count <= MAX_BLOCKS);
    motion_region_counter #(.GRID_WIDTH(GRID_WIDTH),.MIN_BLOCKS(4)) regions(
        .clk(I_clk),.rst_n(I_rst_n),.enable(I_enable),
        .frame_start(I_frame_start),
        .publish(process_frame),.frame_ok(history_valid && work_count<=MAX_BLOCKS),
        .block_valid(compare_pending),.changed(filtered_changed),
        .block_x(pending_block_x),.block_y(pending_block_y),
        .region_count(O_regions),.count_valid(O_regions_valid),.overflow(O_regions_overflow));

    function [15:0] F_bcd4_increment;
        input [15:0] I_bcd;
        reg carry0;
        reg carry1;
        reg carry2;
        begin
            F_bcd4_increment = I_bcd;
            carry0 = 1'b0;
            carry1 = 1'b0;
            carry2 = 1'b0;
            if(I_bcd[3:0] == 4'd9) begin
                F_bcd4_increment[3:0] = 4'd0;
                carry0 = 1'b1;
            end
            else
                F_bcd4_increment[3:0] = I_bcd[3:0] + 4'd1;

            if(carry0) begin
                if(I_bcd[7:4] == 4'd9) begin
                    F_bcd4_increment[7:4] = 4'd0;
                    carry1 = 1'b1;
                end
                else
                    F_bcd4_increment[7:4] = I_bcd[7:4] + 4'd1;
            end

            if(carry1) begin
                if(I_bcd[11:8] == 4'd9) begin
                    F_bcd4_increment[11:8] = 4'd0;
                    carry2 = 1'b1;
                end
                else
                    F_bcd4_increment[11:8] = I_bcd[11:8] + 4'd1;
            end

            if(carry2 && (I_bcd[15:12] != 4'd9))
                F_bcd4_increment[15:12] = I_bcd[15:12] + 4'd1;
        end
    endfunction

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            horizontal_sum <= 11'd0;
            block_addr     <= 14'd0;
            previous_block_luma <= 8'd0;
            compare_pending <= 1'b0;
            pending_block_luma <= 8'd0;
            pending_block_x <= 8'd0;
            pending_block_y <= 7'd0;
            pending_left_changed <= 1'b0;
            pending_top_changed <= 1'b0;
            pending_top_left_changed <= 1'b0;
            left_changed   <= 1'b0;
            top_left_changed <= 1'b0;
            process_frame  <= 1'b0;
            frame_id_valid <= 1'b0;
            last_frame_id  <= 24'd0;
            history_valid  <= 1'b0;
            work_count     <= 14'd0;
            work_count_bcd <= 16'd0;
            work_min_x     <= 8'd0;
            work_max_x     <= 8'd0;
            work_min_y     <= 7'd0;
            work_max_y     <= 7'd0;
            hold_frames    <= 3'd0;
            O_motion_valid <= 1'b0;
            O_left         <= 12'd0;
            O_right        <= 12'd0;
            O_top          <= 12'd0;
            O_bottom       <= 12'd0;
            O_count_bcd    <= 16'd0;
        end
        else if(!I_enable) begin
            horizontal_sum <= 11'd0;
            block_addr     <= 14'd0;
            compare_pending <= 1'b0;
            left_changed   <= 1'b0;
            top_left_changed <= 1'b0;
            process_frame  <= 1'b0;
            frame_id_valid <= 1'b0;
            history_valid  <= 1'b0;
            work_count     <= 14'd0;
            work_count_bcd <= 16'd0;
            hold_frames    <= 3'd0;
            O_motion_valid <= 1'b0;
            O_count_bcd    <= 16'd0;
        end
        else if(I_frame_start) begin
            compare_pending <= 1'b0;
            // Publish the completed unique camera frame.  Repeated HDMI scans
            // do not clear or overwrite the stored luminance history.
            if(process_frame) begin
                if(result_valid) begin
                    hold_frames    <= 3'd0;
                    O_motion_valid <= 1'b1;
                    O_count_bcd    <= work_count_bcd;
                    O_left <= (work_min_x == 8'd0) ? 12'd0 :
                              (({4'd0,work_min_x} - 12'd1) << 3);
                    O_right <= (work_max_x >= GRID_WIDTH - 1) ?
                               (IMG_WIDTH - 1) :
                               ((({4'd0,work_max_x} + 12'd1) << 3) + 12'd7);
                    O_top <= (work_min_y == 7'd0) ? 12'd0 :
                             (({5'd0,work_min_y} - 12'd1) << 3);
                    O_bottom <= (work_max_y >= GRID_HEIGHT - 1) ?
                                (IMG_HEIGHT - 1) :
                                ((({5'd0,work_max_y} + 12'd1) << 3) + 12'd7);
                end
                else if(work_count > MAX_BLOCKS) begin
                    // A majority of the image changing together is normally
                    // an AE step or lighting transition, not a moving object.
                    O_motion_valid <= 1'b0;
                    O_count_bcd    <= 16'd0;
                    hold_frames    <= 3'd0;
                end
                else if(O_motion_valid) begin
                    if(hold_frames == HOLD_FRAMES - 1) begin
                        O_motion_valid <= 1'b0;
                        O_count_bcd    <= 16'd0;
                        hold_frames    <= 3'd0;
                    end
                    else
                        hold_frames <= hold_frames + 3'd1;
                end
                else begin
                    O_count_bcd <= 16'd0;
                end
            end

            process_frame <= new_camera_frame;
            if(new_camera_frame) begin
                frame_id_valid <= 1'b1;
                last_frame_id  <= I_frame_id;
                horizontal_sum <= 11'd0;
                block_addr     <= 14'd0;
                left_changed   <= 1'b0;
                top_left_changed <= 1'b0;
                work_count     <= 14'd0;
                work_count_bcd <= 16'd0;
                work_min_x     <= 8'd0;
                work_max_x     <= 8'd0;
                work_min_y     <= 7'd0;
                work_max_y     <= 7'd0;
            end
        end
        else begin
            compare_pending <= 1'b0;

            // The previous-frame RAM has a synchronous read.  Complete the
            // comparison one clock after the block average is submitted.
            if(compare_pending) begin
                motion_line_mem[pending_block_x] <= raw_changed;
                left_changed     <= raw_changed;
                top_left_changed <= pending_top_changed;

                if(filtered_changed) begin
                    if(work_count != 14'h3fff)
                        work_count <= work_count + 14'd1;
                    if(work_count_bcd != 16'h9999)
                        work_count_bcd <= F_bcd4_increment(work_count_bcd);

                    if(work_count == 14'd0) begin
                        work_min_x <= pending_block_x;
                        work_max_x <= pending_block_x;
                        work_min_y <= pending_block_y;
                        work_max_y <= pending_block_y;
                    end
                    else begin
                        if(pending_block_x < work_min_x)
                            work_min_x <= pending_block_x;
                        if(pending_block_x > work_max_x)
                            work_max_x <= pending_block_x;
                        if(pending_block_y < work_min_y)
                            work_min_y <= pending_block_y;
                        if(pending_block_y > work_max_y)
                            work_max_y <= pending_block_y;
                    end
                end
            end

            if(process_frame && I_de) begin
                if(I_x[2:0] == 3'd0)
                    horizontal_sum <= {3'd0,gray};
                else
                    horizontal_sum <= horizontal_sum + {3'd0,gray};

                if(end_block_column) begin
                    if(I_y[2:0] == 3'd0)
                        vertical_sum_mem[block_x] <= {3'd0,completed_row_sum};
                    else if(!end_block_row)
                        vertical_sum_mem[block_x] <= completed_block_sum;
                end

                if(block_complete) begin
                    // Nonblocking read-before-write coding maps the full
                    // 160x90 history into embedded read-first RAM.
                    previous_block_luma <= previous_luma_mem[block_addr];
                    previous_luma_mem[block_addr] <= completed_block_luma;
                    compare_pending <= history_valid;
                    pending_block_luma <= completed_block_luma;
                    pending_block_x <= block_x;
                    pending_block_y <= block_y;
                    pending_left_changed <= left_changed;
                    pending_top_changed <= top_changed;
                    pending_top_left_changed <= top_left_changed;

                    if(block_addr == TOTAL_BLOCKS - 1) begin
                        block_addr    <= block_addr;
                        history_valid <= 1'b1;
                    end
                    else
                        block_addr <= block_addr + 14'd1;
                end
            end
        end
    end

endmodule


// Lightweight single-target rectangle tracker.
//
// A selected BLUE/RED/GREEN/PURPLE/YELLOW mask feeds the row-run detector.
// The longest run on each row is joined to overlapping runs on following rows.
// Component profiles must match the requested rectangle/circle/triangle before
// they participate in target selection. The colour-only zoom path bypasses this.
// The output
// box is averaged between frames and held briefly across a missed detection to
// prevent visible flicker.
module rectangle_tracker #(
    parameter IMG_WIDTH     = 1280,
    parameter IMG_HEIGHT    = 720,
    parameter [7:0] SAT_THRESHOLD = 8'd40,
    parameter [7:0] BLUE_MIN      = 8'd64,
    parameter [7:0] BLUE_MARGIN   = 8'd20,
    parameter MIN_ROW_PIX   = 12'd48,
    parameter MIN_WIDTH     = 12'd80,
    parameter MIN_HEIGHT    = 12'd48,
    parameter MAX_RUN_GAP   = 3,
    parameter MAX_ROW_GAP   = 3,
    parameter MATCH_MARGIN  = 12'd32,
    parameter HOLD_FRAMES   = 3
)(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_enable,
    input  wire        I_de,
    input  wire [11:0] I_x,
    input  wire [11:0] I_y,
    input  wire [23:0] I_rgb,
    input  wire [23:0] I_frame_id,
    input  wire        I_require_rectangle,
    input  wire [1:0]  I_view_id,
    input  wire [2:0]  I_color_select, // 0..4 presets, 5 CUSTOM, 7 none
    input wire I_custom_mask,
    input  wire [1:0]  I_shape_select, // strict requested shape in shape modes
    output wire        O_mask_pixel,
    output reg         O_mask_seen,
    output wire        O_result_update,
    output reg         O_detect_valid,
    output reg  [1:0]  O_detect_shape, // 0 unknown, 1 rectangle, 2 circle, 3 triangle
    output reg         O_candidate_valid,
    output reg         O_candidate_ok,
    output reg  [11:0] O_raw_left,
    output reg  [11:0] O_raw_right,
    output reg  [11:0] O_raw_top,
    output reg  [11:0] O_raw_bottom,
    output reg         O_track_valid,
    output reg  [11:0] O_left,
    output reg  [11:0] O_right,
    output reg  [11:0] O_top,
    output reg  [11:0] O_bottom
);

    // Internal raster coordinates need only represent the configured image.
    // Keep the public 12-bit ports unchanged for project and display wiring.
    localparam integer X_BITS = (IMG_WIDTH > 1) ? $clog2(IMG_WIDTH) : 1;
    localparam integer Y_BITS = (IMG_HEIGHT > 1) ? $clog2(IMG_HEIGHT) : 1;
    localparam integer RUN_COUNT_BITS = (IMG_WIDTH > 1) ? $clog2(IMG_WIDTH + 1) : 1;
    localparam integer WIDTH_BITS = (IMG_WIDTH > 1) ? $clog2(IMG_WIDTH + 1) : 1;
    localparam integer HEIGHT_BITS = (IMG_HEIGHT > 1) ? $clog2(IMG_HEIGHT + 1) : 1;
    localparam integer X_DISTANCE_BITS = $clog2(((IMG_WIDTH + 1) / 2) + 1);
    localparam integer Y_DISTANCE_BITS = $clog2(((IMG_HEIGHT + 1) / 2) + 1);
    localparam integer DISTANCE_BITS =
        $clog2(((IMG_WIDTH + 1) / 2) + ((IMG_HEIGHT + 1) / 2) + 2);

    wire [7:0] red   = I_rgb[23:16];
    wire [7:0] green = I_rgb[15:8];
    wire [7:0] blue  = I_rgb[7:0];
    wire [7:0] rgb_max = (red >= green) ?
                         ((red >= blue) ? red : blue) :
                         ((green >= blue) ? green : blue);
    wire [7:0] rgb_min = (red <= green) ?
                         ((red <= blue) ? red : blue) :
                         ((green <= blue) ? green : blue);
    wire [8:0] saturation = {1'b0,rgb_max} - {1'b0,rgb_min};
    // Purple and blue use disjoint red/blue ratios; yellow requires two
    // bright channels. Thresholds describe colour ranges, not exact RGB codes.
    wire [8:0] colour_margin = I_require_rectangle ? {1'b0,BLUE_MARGIN} : 9'd24;
    wire purple_pixel = (blue >= BLUE_MIN) && (red >= 8'd40) &&
                    ({1'b0,red} >= {1'b0,green} + 9'd20) &&
                    ({1'b0,blue} >= {1'b0,green} + 9'd32) &&
                    ({1'b0,blue} >= {1'b0,red} + 9'd8) &&
                    ({1'b0,blue} < {red,1'b0});
    wire blue_pixel = (blue >= BLUE_MIN) && !purple_pixel &&
                    ({1'b0,blue} >= {1'b0,red} + colour_margin) &&
                    ({1'b0,blue} >= {1'b0,green} + colour_margin);
    wire yellow_pixel;
    wire red_pixel = (red >= BLUE_MIN) && !yellow_pixel &&
                    ({1'b0,red} >= {1'b0,green} + colour_margin) &&
                    ({1'b0,red} >= {1'b0,blue} + colour_margin);
    wire green_pixel = (green >= BLUE_MIN) && !yellow_pixel &&
                    ({1'b0,green} >= {1'b0,red} + colour_margin) &&
                    ({1'b0,green} >= {1'b0,blue} + colour_margin);
    assign yellow_pixel = (red >= BLUE_MIN) && (green >= BLUE_MIN) &&
                    ({1'b0,red} >= {1'b0,blue} + 9'd32) &&
                    ({1'b0,green} >= {1'b0,blue} + 9'd32) &&
                    ({red,2'b0} >= ({2'b0,green} << 1) + {2'b0,green}) &&
                    ({green,2'b0} >= ({2'b0,red} << 1) + {2'b0,red});
    wire selected_pixel = (I_color_select == 3'd0) ? blue_pixel :
                          (I_color_select == 3'd1) ? red_pixel :
                          (I_color_select == 3'd2) ? green_pixel :
                          (I_color_select == 3'd5) ? I_custom_mask : 1'b0;
    wire input_mask_pixel = selected_pixel &&
                    (!I_require_rectangle || saturation >= {1'b0,SAT_THRESHOLD});
    assign O_mask_pixel = input_mask_pixel;
    // Separate colour classification from run/component accumulation.
    // Delay coordinates and frame identity with the mask; the display mask
    // stays combinational so the existing HDMI pixel alignment is unchanged.
    reg        mask_pixel;
    reg        pixel_de;
    reg [X_BITS-1:0] pixel_x;
    reg [Y_BITS-1:0] pixel_y;
    reg [23:0] pixel_frame_id;
    reg [1:0]  pixel_view_id, pixel_shape;
    reg [2:0]  pixel_color;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            mask_pixel <= 1'b0;
            pixel_de <= 1'b0;
            pixel_x <= 12'd0;
            pixel_y <= 12'd0;
            pixel_frame_id <= 24'd0;
            pixel_view_id <= 2'd0;
            pixel_color <= 3'd0; pixel_shape <= 2'd1;
        end
        else begin
            mask_pixel <= input_mask_pixel;
            pixel_de <= I_de;
            pixel_x <= I_x;
            pixel_y <= I_y;
            pixel_frame_id <= I_frame_id;
            pixel_view_id <= I_view_id;
            pixel_color <= I_color_select; pixel_shape <= I_shape_select;
        end
    end
    reg        process_frame;
    reg        view_valid;
    reg [1:0]  last_view_id;
    reg [2:0]  last_color;
    reg [1:0]  last_shape;
    wire       view_changed = !view_valid || (pixel_view_id != last_view_id) ||
                              (pixel_color != last_color) || (pixel_shape != last_shape);
    wire [11:0] min_width = I_require_rectangle ? MIN_WIDTH : 12'd56;
    wire [11:0] min_height = I_require_rectangle ? MIN_HEIGHT : 12'd36;
    // Keep narrow apex/edge rows so round and triangular silhouettes retain
    // their full height. Minimum component size and shape profiles reject noise.
    wire [11:0] min_row_pix = I_require_rectangle ? 12'd8 : 12'd28;
    wire [X_BITS-1:0] lock_center_x = (O_left + O_right) >> 1;
    wire [Y_BITS-1:0] lock_center_y = (O_top + O_bottom) >> 1;
    reg        frame_id_valid;
    reg [23:0] last_frame_id;
    reg        frame_mask_seen;
    wire       new_camera_frame = !frame_id_valid || (pixel_frame_id != last_frame_id);
    wire       frame_start = pixel_de && (pixel_x == 12'd0) && (pixel_y == 12'd0);
    assign O_result_update = I_enable && frame_start && process_frame && !view_changed;
    wire       line_end = pixel_de && (pixel_x == IMG_WIDTH - 1);

    reg        run_active;
    reg [X_BITS-1:0] run_start;
    reg [X_BITS-1:0] run_last;
    reg [RUN_COUNT_BITS-1:0] run_hits;
    reg [2:0]  run_gap;
    reg [X_BITS-1:0] row_best_left;
    reg [X_BITS-1:0] row_best_right;
    reg [RUN_COUNT_BITS-1:0] row_best_hits;
    reg        row_best_matches;
    // Keep the locked target's run even if another object has more pixels.
    wire       row_in_lock = O_track_valid &&
                    (({1'b0,pixel_y} + {1'b0,MATCH_MARGIN}) >= {1'b0,O_top}) &&
                    ({1'b0,pixel_y} <= ({1'b0,O_bottom} + {1'b0,MATCH_MARGIN}));
    wire [X_BITS:0] run_center_sum = {1'b0,run_start} + {1'b0,run_last};
    wire [X_BITS-1:0] run_center = run_center_sum[X_BITS:1];
    wire       run_matches_lock = row_in_lock && (run_hits >= min_row_pix) &&
                    (({1'b0,run_center} + {1'b0,MATCH_MARGIN}) >= {1'b0,O_left}) &&
                    ({1'b0,run_center} <= ({1'b0,O_right} + {1'b0,MATCH_MARGIN}));

    wire       eol_run_valid = run_active || mask_pixel;
    wire [X_BITS-1:0] eol_run_left = run_active ? run_start : pixel_x;
    wire [X_BITS-1:0] eol_run_right = mask_pixel ? pixel_x : run_last;
    wire [RUN_COUNT_BITS-1:0] eol_run_hits = run_active ?
                                (run_hits + mask_pixel) :
                                (mask_pixel ? {{(RUN_COUNT_BITS-1){1'b0}},1'b1} : {RUN_COUNT_BITS{1'b0}});
    wire [X_BITS:0] eol_center_sum = {1'b0,eol_run_left} + {1'b0,eol_run_right};
    wire [X_BITS-1:0] eol_center = eol_center_sum[X_BITS:1];
    wire       eol_matches_lock = row_in_lock && (eol_run_hits >= min_row_pix) &&
                    (({1'b0,eol_center} + {1'b0,MATCH_MARGIN}) >= {1'b0,O_left}) &&
                    ({1'b0,eol_center} <= ({1'b0,O_right} + {1'b0,MATCH_MARGIN}));
    wire       eol_use_run = eol_run_valid &&
                    ((eol_matches_lock && !row_best_matches) ||
                     ((eol_matches_lock == row_best_matches) &&
                      (eol_run_hits > row_best_hits)));
    wire [X_BITS-1:0] line_left = eol_use_run ? eol_run_left : row_best_left;
    wire [X_BITS-1:0] line_right = eol_use_run ? eol_run_right : row_best_right;
    wire [RUN_COUNT_BITS-1:0] line_hits = eol_use_run ? eol_run_hits : row_best_hits;
    wire        line_matches_lock = eol_use_run ? eol_matches_lock : row_best_matches;
    wire        line_valid = (line_hits >= min_row_pix);

    reg        comp_active;
    reg [X_BITS-1:0] comp_last_left, comp_last_right;
    reg [X_BITS-1:0] comp_left;
    reg [X_BITS-1:0] comp_right;
    reg [Y_BITS-1:0] comp_top;
    reg [Y_BITS-1:0] comp_bottom;
    reg [19:0] comp_pixels;
    reg [2:0]  comp_row_gap;

    wire [WIDTH_BITS-1:0] comp_width =
        {{(WIDTH_BITS-X_BITS){1'b0}},comp_right} -
        {{(WIDTH_BITS-X_BITS){1'b0}},comp_left} +
        {{(WIDTH_BITS-1){1'b0}},1'b1};
    wire [HEIGHT_BITS-1:0] comp_height =
        {{(HEIGHT_BITS-Y_BITS){1'b0}},comp_bottom} -
        {{(HEIGHT_BITS-Y_BITS){1'b0}},comp_top} +
        {{(HEIGHT_BITS-1){1'b0}},1'b1};
    localparam RAW_AREA_BITS=$clog2(IMG_WIDTH*IMG_HEIGHT+1);
    wire [WIDTH_BITS+HEIGHT_BITS-1:0] comp_area_product = comp_width * comp_height;
    wire [RAW_AREA_BITS-1:0] comp_area = comp_area_product[RAW_AREA_BITS-1:0];
    wire [27:0] comp_pixel_score_5 =
                    ({8'd0,comp_pixels} << 2) + {8'd0,comp_pixels};
    wire        comp_size_valid = comp_active &&
                    (comp_width >= min_width) &&
                    (comp_height >= min_height) &&
                    ({3'd0,comp_width} <= {comp_height,3'b000}) &&
                    ({3'd0,comp_height} <= {comp_width,3'b000});
    // Size/fill is a preliminary gate. Strict requested-shape filtering follows
    // the profile calculation before any component competes for target lock.
    wire        comp_track_valid = comp_size_valid &&
                    (I_require_rectangle ?
                     (comp_pixel_score_5 >= comp_area) :
                     ({6'd0,comp_pixels} >= (comp_area >> 2)));
    wire [X_BITS:0] comp_center_x_sum = {1'b0,comp_left} + {1'b0,comp_right};
    wire [Y_BITS:0] comp_center_y_sum = {1'b0,comp_top} + {1'b0,comp_bottom};
    wire [X_BITS-1:0] comp_center_x = comp_center_x_sum[X_BITS:1];
    wire [Y_BITS-1:0] comp_center_y = comp_center_y_sum[Y_BITS:1];
    wire [X_DISTANCE_BITS-1:0] comp_dx = (comp_center_x >= IMG_WIDTH/2) ?
                    (comp_center_x - IMG_WIDTH/2) : (IMG_WIDTH/2 - comp_center_x);
    wire [Y_DISTANCE_BITS-1:0] comp_dy = (comp_center_y >= IMG_HEIGHT/2) ?
                    (comp_center_y - IMG_HEIGHT/2) : (IMG_HEIGHT/2 - comp_center_y);
    wire [DISTANCE_BITS-1:0] comp_distance =
        {{(DISTANCE_BITS-X_DISTANCE_BITS){1'b0}},comp_dx} +
        {{(DISTANCE_BITS-Y_DISTANCE_BITS){1'b0}},comp_dy};
    // Match the completed component. Rotation moves individual edge runs
    // much farther than the centre, so their lock flags must not split it.
    wire [12:0] lock_width = {1'b0,O_right} - {1'b0,O_left} + 13'd1;
    wire [12:0] lock_height = {1'b0,O_bottom} - {1'b0,O_top} + 13'd1;
    wire [12:0] match_x = {1'b0,MATCH_MARGIN} + (lock_width >> 2);
    wire [12:0] match_y = {1'b0,MATCH_MARGIN} + (lock_height >> 2);
    wire comp_matches_lock = O_track_valid &&
                    (({1'b0,comp_center_x} + match_x) >= {1'b0,lock_center_x}) &&
                    ({1'b0,comp_center_x} <= ({1'b0,lock_center_x} + match_x)) &&
                    (({1'b0,comp_center_y} + match_y) >= {1'b0,lock_center_y}) &&
                    ({1'b0,comp_center_y} <= ({1'b0,lock_center_y} + match_y));
    wire line_matches = comp_active && line_valid &&
                    (({1'b0,line_right} + MAX_RUN_GAP) >= {1'b0,comp_last_left}) &&
                    ({1'b0,line_left} <= ({1'b0,comp_last_right} + MAX_RUN_GAP));

    // Project complete colour components onto four pairs of orthogonal
    // axes. Their tightest enclosing area separates triangles from rectangles;
    // circles keep almost the same enclosing area in every direction.
    wire [13:0] row_xl = {2'd0,line_left};
    wire [13:0] row_xr = {2'd0,line_right};
    wire [13:0] row_y = {2'd0,pixel_y};
    wire [13:0] row_rev_l = IMG_WIDTH - 1 - line_right;
    wire [13:0] row_rev_r = IMG_WIDTH - 1 - line_left;
    wire [13:0] row_diag_u_min = row_xl + row_y;
    wire [13:0] row_diag_u_max = row_xr + row_y;
    reg [13:0] comp_diag_u_min, comp_diag_u_max;
    wire [13:0] span_diag_u = comp_diag_u_max - comp_diag_u_min + 14'd2;
    wire [13:0] row_diag_v_min = row_rev_l + row_y;
    wire [13:0] row_diag_v_max = row_rev_r + row_y;
    reg [13:0] comp_diag_v_min, comp_diag_v_max;
    wire [13:0] span_diag_v = comp_diag_v_max - comp_diag_v_min + 14'd2;
    wire [13:0] row_near_u_min = ((row_xl << 2) + row_xl) + (row_y << 1);
    wire [13:0] row_near_u_max = ((row_xr << 2) + row_xr) + (row_y << 1);
    reg [13:0] comp_near_u_min, comp_near_u_max;
    wire [13:0] span_near_u = comp_near_u_max - comp_near_u_min + 14'd7;
    wire [13:0] row_near_v_min = (row_rev_l << 1) + ((row_y << 2) + row_y);
    wire [13:0] row_near_v_max = (row_rev_r << 1) + ((row_y << 2) + row_y);
    reg [13:0] comp_near_v_min, comp_near_v_max;
    wire [13:0] span_near_v = comp_near_v_max - comp_near_v_min + 14'd7;
    wire [13:0] row_far_u_min = (row_xl << 1) + ((row_y << 2) + row_y);
    wire [13:0] row_far_u_max = (row_xr << 1) + ((row_y << 2) + row_y);
    reg [13:0] comp_far_u_min, comp_far_u_max;
    wire [13:0] span_far_u = comp_far_u_max - comp_far_u_min + 14'd7;
    wire [13:0] row_far_v_min = ((row_rev_l << 2) + row_rev_l) + (row_y << 1);
    wire [13:0] row_far_v_max = ((row_rev_r << 2) + row_rev_r) + (row_y << 1);
    reg [13:0] comp_far_v_min, comp_far_v_max;
    wire [13:0] span_far_v = comp_far_v_max - comp_far_v_min + 14'd7;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            comp_diag_u_min <= 14'd0; comp_diag_u_max <= 14'd0;
            comp_diag_v_min <= 14'd0; comp_diag_v_max <= 14'd0;
            comp_near_u_min <= 14'd0; comp_near_u_max <= 14'd0;
            comp_near_v_min <= 14'd0; comp_near_v_max <= 14'd0;
            comp_far_u_min <= 14'd0; comp_far_u_max <= 14'd0;
            comp_far_v_min <= 14'd0; comp_far_v_max <= 14'd0;
        end
        else if(pixel_de && process_frame && line_end && line_valid) begin
            if(!comp_active || !line_matches) begin
                comp_diag_u_min <= row_diag_u_min; comp_diag_u_max <= row_diag_u_max;
                comp_diag_v_min <= row_diag_v_min; comp_diag_v_max <= row_diag_v_max;
                comp_near_u_min <= row_near_u_min; comp_near_u_max <= row_near_u_max;
                comp_near_v_min <= row_near_v_min; comp_near_v_max <= row_near_v_max;
                comp_far_u_min <= row_far_u_min; comp_far_u_max <= row_far_u_max;
                comp_far_v_min <= row_far_v_min; comp_far_v_max <= row_far_v_max;
            end
            else begin
                if(row_diag_u_min < comp_diag_u_min) comp_diag_u_min <= row_diag_u_min;
                if(row_diag_u_max > comp_diag_u_max) comp_diag_u_max <= row_diag_u_max;
                if(row_diag_v_min < comp_diag_v_min) comp_diag_v_min <= row_diag_v_min;
                if(row_diag_v_max > comp_diag_v_max) comp_diag_v_max <= row_diag_v_max;
                if(row_near_u_min < comp_near_u_min) comp_near_u_min <= row_near_u_min;
                if(row_near_u_max > comp_near_u_max) comp_near_u_max <= row_near_u_max;
                if(row_near_v_min < comp_near_v_min) comp_near_v_min <= row_near_v_min;
                if(row_near_v_max > comp_near_v_max) comp_near_v_max <= row_near_v_max;
                if(row_far_u_min < comp_far_u_min) comp_far_u_min <= row_far_u_min;
                if(row_far_u_max > comp_far_u_max) comp_far_u_max <= row_far_u_max;
                if(row_far_v_min < comp_far_v_min) comp_far_v_min <= row_far_v_min;
                if(row_far_v_max > comp_far_v_max) comp_far_v_max <= row_far_v_max;
            end
        end
    end

    // Pipeline products, common-denominator areas (58), then extrema.
    // A component is consumed at the following row/frame boundary, after
    // these short pipelines have settled during the intervening pixels.
    reg [27:0] proj_diag_q, proj_near_q, proj_far_q;
    reg [RAW_AREA_BITS-1:0] proj_axis_q;
    reg [19:0] proj_pixels_q;
    localparam AREA_BITS=$clog2(29*(IMG_WIDTH+IMG_HEIGHT)*(IMG_WIDTH+IMG_HEIGHT)+1);
    localparam METRIC_BITS=(AREA_BITS>26?AREA_BITS:26)+5;
    reg [AREA_BITS-1:0] area_axis_q, area_diag_q, area_near_q, area_far_q;
    // Even the full 20-bit counter times58 fits in26 bits.
    reg [25:0] pixels_scaled_q,pixels_metric_q;
    reg [AREA_BITS-1:0] min_area_q,max_area_q;
    wire [AREA_BITS-1:0] min_pair_a = area_axis_q < area_diag_q ? area_axis_q : area_diag_q;
    wire [AREA_BITS-1:0] min_pair_b = area_near_q < area_far_q ? area_near_q : area_far_q;
    wire [AREA_BITS-1:0] max_pair_a = area_axis_q > area_diag_q ? area_axis_q : area_diag_q;
    wire [AREA_BITS-1:0] max_pair_b = area_near_q > area_far_q ? area_near_q : area_far_q;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            proj_diag_q <= 28'd0; proj_near_q <= 28'd0; proj_far_q <= 28'd0;
            proj_axis_q <= 26'd0; proj_pixels_q <= 20'd0;
            area_axis_q <= 32'd0; area_diag_q <= 32'd0;
            area_near_q <= 32'd0; area_far_q <= 32'd0;
            pixels_scaled_q <= 32'd0; pixels_metric_q <= 32'd0;
            min_area_q <= 32'd0; max_area_q <= 32'd0;
        end
        else begin
            proj_axis_q <= comp_area;
            proj_diag_q <= span_diag_u * span_diag_v;
            proj_near_q <= span_near_u * span_near_v;
            proj_far_q <= span_far_u * span_far_v;
            proj_pixels_q <= comp_pixels;
            area_axis_q <= (({6'd0,proj_axis_q} << 6) - ({6'd0,proj_axis_q} << 2) - ({6'd0,proj_axis_q} << 1));
            area_diag_q <= (({4'd0,proj_diag_q} << 5) - ({4'd0,proj_diag_q} << 1) - {4'd0,proj_diag_q});
            area_near_q <= {3'd0,proj_near_q,1'b0};
            area_far_q <= {3'd0,proj_far_q,1'b0};
            pixels_scaled_q <= (({12'd0,proj_pixels_q} << 6) - ({12'd0,proj_pixels_q} << 2) - ({12'd0,proj_pixels_q} << 1));
            min_area_q <= min_pair_a < min_pair_b ? min_pair_a : min_pair_b;
            max_area_q <= max_pair_a > max_pair_b ? max_pair_a : max_pair_b;
            pixels_metric_q <= pixels_scaled_q;
        end
    end
    // Disjoint fill windows leave ambiguous contours UNKNOWN instead of
    // letting the rectangle branch capture a rotated triangle.
    wire [METRIC_BITS-1:0] metric_pixels = {{(METRIC_BITS-26){1'b0}},pixels_metric_q};
    wire [METRIC_BITS-1:0] metric_min = {{(METRIC_BITS-AREA_BITS){1'b0}},min_area_q};
    wire [METRIC_BITS-1:0] metric_max = {{(METRIC_BITS-AREA_BITS){1'b0}},max_area_q};
    wire comp_triangle_profile = (min_area_q != 0) &&
                    (((metric_pixels << 2) + metric_pixels) >= ((metric_min << 1))) &&
                    (((metric_pixels << 4)) <= ((metric_min << 3) + metric_min)) &&
                    (((metric_max << 2)) <= ((metric_min << 2) + metric_min)) &&
                    ((({3'd0,comp_width} << 2)) >= (({3'd0,comp_height} << 1) + {3'd0,comp_height})) &&
                    ((({3'd0,comp_height} << 2)) >= (({3'd0,comp_width} << 1) + {3'd0,comp_width}));
    wire comp_circle_profile = (min_area_q != 0) &&
                    (((metric_pixels << 3) + (metric_pixels << 1)) >= ((metric_min << 2) + (metric_min << 1) + metric_min)) &&
                    (((metric_pixels << 4) + (metric_pixels << 2)) <= ((metric_min << 4) + metric_min)) &&
                    (((metric_max << 3)) <= ((metric_min << 3) + metric_min)) &&
                    ((({3'd0,comp_width} << 2) + {3'd0,comp_width}) >= (({3'd0,comp_height} << 2))) &&
                    ((({3'd0,comp_height} << 2) + {3'd0,comp_height}) >= (({3'd0,comp_width} << 2)));
    wire comp_rect_profile = (min_area_q != 0) &&
                    (((metric_pixels << 2) + metric_pixels) >= ((metric_min << 1) + metric_min)) &&
                    (((metric_pixels << 4) + (metric_pixels << 2)) <= ((metric_min << 4) + (metric_min << 2) + metric_min)) &&
                    (((metric_max << 2) + metric_max) >= ((metric_min << 2) + (metric_min << 1)));
    wire [1:0] comp_shape = comp_triangle_profile ? 2'd3 :
                    (comp_circle_profile ? 2'd2 :
                     (comp_rect_profile ? 2'd1 : 2'd0));
    wire comp_geometry_valid = comp_track_valid &&
                    (!I_require_rectangle || (comp_shape == I_shape_select));

    // Register classification before frame-level candidate selection.
    reg [RAW_AREA_BITS-1:0] comp_area_q;
    reg [DISTANCE_BITS-1:0] comp_distance_q;
    reg [1:0]  comp_shape_q;
    reg        comp_geometry_valid_q;
    reg        comp_track_valid_q;
    reg        comp_size_valid_q;
    reg        comp_matches_lock_q;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            comp_area_q <= 26'd0;
            comp_distance_q <= 13'd0;
            comp_shape_q <= 2'd0;
            comp_geometry_valid_q <= 1'b0;
            comp_track_valid_q <= 1'b0;
            comp_size_valid_q <= 1'b0;
            comp_matches_lock_q <= 1'b0;
        end
        else begin
            comp_area_q <= comp_area;
            comp_distance_q <= comp_distance;
            comp_shape_q <= comp_shape;
            comp_geometry_valid_q <= comp_geometry_valid;
            comp_track_valid_q <= comp_geometry_valid;
            comp_size_valid_q <= comp_size_valid;
            comp_matches_lock_q <= comp_matches_lock;
        end
    end

    reg        best_valid;
    reg [X_BITS-1:0] best_left;
    reg [X_BITS-1:0] best_right;
    reg [Y_BITS-1:0] best_top;
    reg [Y_BITS-1:0] best_bottom;
    reg [RAW_AREA_BITS-1:0] best_area;
    reg [1:0]  best_shape;
    reg        best_matches;
    reg [DISTANCE_BITS-1:0] best_distance;
    reg        candidate_valid;
    reg        candidate_ok;
    reg        candidate_matches;
    reg [X_BITS-1:0] candidate_left, candidate_right;
    reg [Y_BITS-1:0] candidate_top, candidate_bottom;
    reg [RAW_AREA_BITS-1:0] candidate_area;
    reg [DISTANCE_BITS-1:0] candidate_distance;

    wire use_current = comp_track_valid_q &&
                       (!best_valid || (comp_matches_lock_q && !best_matches) ||
                        ((comp_matches_lock_q == best_matches) &&
                         (I_require_rectangle ? (comp_area_q > best_area) :
                          ((comp_distance_q < best_distance) ||
                           ((comp_distance_q == best_distance) && (comp_area_q > best_area))))));
    wire frame_matches = use_current ? comp_matches_lock_q : best_matches;
    wire use_candidate = comp_size_valid_q &&
                       (!candidate_valid || (comp_matches_lock_q && !candidate_matches) ||
                        ((comp_matches_lock_q == candidate_matches) &&
                         (I_require_rectangle ? (comp_area_q > candidate_area) :
                          ((comp_distance_q < candidate_distance) ||
                           ((comp_distance_q == candidate_distance) && (comp_area_q > candidate_area))))));
    wire frame_rect_valid = use_current || best_valid;
    // While locked, another valid rectangle is a distractor, not an
    // immediate replacement. Let the normal miss counter expire first.
    wire frame_target_valid = frame_rect_valid && (!O_track_valid || frame_matches);
    wire [11:0] frame_left = use_current ? comp_left : best_left;
    wire [11:0] frame_right = use_current ? comp_right : best_right;
    wire [11:0] frame_top = use_current ? comp_top : best_top;
    wire [11:0] frame_bottom = use_current ? comp_bottom : best_bottom;
    wire [1:0]  frame_shape = I_require_rectangle ? (use_current ? comp_shape_q : best_shape) : 2'd0;

    wire [11:0] padded_left = (frame_left > 12'd4) ?
                              (frame_left - 12'd4) : 12'd0;
    wire [11:0] padded_top = (frame_top > 12'd4) ?
                             (frame_top - 12'd4) : 12'd0;
    wire [12:0] right_plus_pad = {1'b0,frame_right} + 13'd4;
    wire [12:0] bottom_plus_pad = {1'b0,frame_bottom} + 13'd4;
    wire [11:0] padded_right = (right_plus_pad >= IMG_WIDTH) ?
                               (IMG_WIDTH - 1) : right_plus_pad[11:0];
    wire [11:0] padded_bottom = (bottom_plus_pad >= IMG_HEIGHT) ?
                                (IMG_HEIGHT - 1) : bottom_plus_pad[11:0];

    reg [2:0] miss_frames;
    reg [1:0] shape_pending;
    reg       shape_pending_valid;
    reg [1:0] shape_unknown_frames;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            run_active    <= 1'b0;
            run_start     <= 12'd0;
            run_last      <= 12'd0;
            run_hits      <= 12'd0;
            run_gap       <= 3'd0;
            row_best_left <= 12'd0;
            row_best_right<= 12'd0;
            row_best_hits <= 12'd0;
            comp_active   <= 1'b0;
            comp_last_left <= 12'd0;
            comp_last_right <= 12'd0;
            comp_left     <= 12'd0;
            comp_right    <= 12'd0;
            comp_top      <= 12'd0;
            comp_bottom   <= 12'd0;
            comp_pixels   <= 20'd0;
            comp_row_gap  <= 3'd0;
            best_valid    <= 1'b0;
            best_left     <= 12'd0;
            best_right    <= 12'd0;
            best_top      <= 12'd0;
            best_bottom   <= 12'd0;
            best_area     <= 26'd0;
            best_shape    <= 2'd0;
            miss_frames   <= 3'd0;
            O_track_valid <= 1'b0;
            O_left        <= 12'd0;
            O_right       <= 12'd0;
            O_top         <= 12'd0;
            O_bottom      <= 12'd0;
            process_frame <= 1'b0;
            view_valid <= 1'b0;
            last_view_id <= 2'd0;
            last_color <= 3'd0; last_shape <= 2'd1;
            best_distance <= {DISTANCE_BITS{1'b1}};
            candidate_distance <= {DISTANCE_BITS{1'b1}};
            frame_id_valid <= 1'b0;
            last_frame_id <= 24'd0;
            frame_mask_seen <= 1'b0;
            row_best_matches <= 1'b0;
            best_matches <= 1'b0;
            candidate_valid <= 1'b0;
            candidate_ok <= 1'b0;
            candidate_matches <= 1'b0;
            candidate_area <= 26'd0;
            candidate_left <= 12'd0; candidate_right <= 12'd0;
            candidate_top <= 12'd0; candidate_bottom <= 12'd0;
            O_detect_valid <= 1'b0;
            O_detect_shape <= 2'd0;
            shape_pending <= 2'd0;
            shape_pending_valid <= 1'b0;
            shape_unknown_frames <= 2'd0;
            O_candidate_valid <= 1'b0;
            O_candidate_ok <= 1'b0;
            O_mask_seen <= 1'b0;
            O_raw_left <= 12'd0; O_raw_right <= 12'd0;
            O_raw_top <= 12'd0; O_raw_bottom <= 12'd0;
        end
        else if(!I_enable) begin
            run_active    <= 1'b0;
            run_hits      <= 12'd0;
            run_gap       <= 3'd0;
            row_best_hits <= 12'd0;
            comp_active   <= 1'b0;
            comp_pixels   <= 20'd0;
            comp_row_gap  <= 3'd0;
            best_valid    <= 1'b0;
            best_area     <= 26'd0;
            best_shape    <= 2'd0;
            miss_frames   <= 3'd0;
            O_track_valid <= 1'b0;
            process_frame <= 1'b0;
            view_valid <= 1'b0;
            last_view_id <= 2'd0;
            last_color <= 3'd0; last_shape <= 2'd1;
            best_distance <= {DISTANCE_BITS{1'b1}};
            candidate_distance <= {DISTANCE_BITS{1'b1}};
            frame_id_valid <= 1'b0;
            frame_mask_seen <= 1'b0;
            row_best_matches <= 1'b0;
            best_matches <= 1'b0;
            candidate_valid <= 1'b0;
            candidate_area <= 26'd0;
            O_detect_valid <= 1'b0;
            O_detect_shape <= 2'd0;
            shape_pending <= 2'd0;
            shape_pending_valid <= 1'b0;
            shape_unknown_frames <= 2'd0;
            O_candidate_valid <= 1'b0;
            O_candidate_ok <= 1'b0;
            O_mask_seen <= 1'b0;
        end
        else if(frame_start) begin
            // Publish once per distinct camera image; a 60-Hz duplicate must
            // not smooth twice or consume another lost-frame allowance.
            if(process_frame && !view_changed) begin
              O_detect_valid <= frame_target_valid;
              if(frame_target_valid) begin
                  if(frame_shape == 2'd0) begin
                      shape_pending_valid <= 1'b0;
                      if(shape_unknown_frames == 2'd2) begin
                          O_detect_shape <= 2'd0;
                          shape_unknown_frames <= 2'd0;
                      end
                      else begin
                          shape_unknown_frames <= shape_unknown_frames + 2'd1;
                      end
                  end
                  else begin
                      shape_unknown_frames <= 2'd0;
                      if(frame_shape == O_detect_shape) begin
                          shape_pending_valid <= 1'b0;
                      end
                      else if(shape_pending_valid && (frame_shape == shape_pending)) begin
                          O_detect_shape <= frame_shape;
                          shape_pending_valid <= 1'b0;
                      end
                      else begin
                          shape_pending <= frame_shape;
                          shape_pending_valid <= 1'b1;
                      end
                  end
              end
              else begin
                  shape_pending_valid <= 1'b0;
                  shape_unknown_frames <= 2'd0;
              end
              O_mask_seen <= frame_mask_seen;
              O_candidate_valid <= use_candidate || candidate_valid;
              O_candidate_ok <= use_candidate ? comp_geometry_valid : candidate_ok;
              O_raw_left <= use_candidate ? comp_left : candidate_left;
              O_raw_right <= use_candidate ? comp_right : candidate_right;
              O_raw_top <= use_candidate ? comp_top : candidate_top;
              O_raw_bottom <= use_candidate ? comp_bottom : candidate_bottom;
            if(frame_target_valid) begin
                miss_frames <= 3'd0;
                if(O_track_valid && frame_matches) begin
                    O_left   <= (O_left + padded_left) >> 1;
                    O_right  <= (O_right + padded_right) >> 1;
                    O_top    <= (O_top + padded_top) >> 1;
                    O_bottom <= (O_bottom + padded_bottom) >> 1;
                end
                else begin
                    O_left   <= padded_left;
                    O_right  <= padded_right;
                    O_top    <= padded_top;
                    O_bottom <= padded_bottom;
                end
                O_track_valid <= 1'b1;
            end
            else if(O_track_valid) begin
                if(miss_frames == HOLD_FRAMES - 1) begin
                    O_track_valid <= 1'b0;
                    O_detect_shape <= 2'd0;
                    shape_pending_valid <= 1'b0;
                    shape_unknown_frames <= 2'd0;
                    miss_frames   <= 3'd0;
                end
                else begin
                    miss_frames <= miss_frames + 3'd1;
                end
            end

            end
            if(view_changed) begin
                O_track_valid <= 1'b0;
                O_detect_valid <= 1'b0;
                O_detect_shape <= 2'd0;
                shape_pending <= 2'd0;
                shape_pending_valid <= 1'b0;
                shape_unknown_frames <= 2'd0;
                O_candidate_valid <= 1'b0;
                O_candidate_ok <= 1'b0;
                O_mask_seen <= 1'b0;
                miss_frames <= 3'd0;
            end
            process_frame <= new_camera_frame || view_changed;
            view_valid <= 1'b1;
            last_view_id <= pixel_view_id;
            last_color <= pixel_color; last_shape <= pixel_shape;
            best_distance <= 13'h1fff;
            candidate_distance <= 13'h1fff;
            frame_id_valid <= 1'b1;
            last_frame_id <= pixel_frame_id;
            frame_mask_seen <= (new_camera_frame || view_changed) && mask_pixel;
            row_best_matches <= 1'b0;
            best_matches <= 1'b0;
            candidate_valid <= 1'b0;
            candidate_area <= 26'd0;
            run_active    <= 1'b0;
            run_hits      <= 12'd0;
            run_gap       <= 3'd0;
            row_best_hits <= 12'd0;
            comp_active   <= 1'b0;
            comp_pixels   <= 20'd0;
            comp_row_gap  <= 3'd0;
            best_valid    <= 1'b0;
            best_area     <= 26'd0;
            best_shape    <= 2'd0;
        end
        else if(pixel_de && process_frame) begin
            if(mask_pixel)
                frame_mask_seen <= 1'b1;
            if(line_end) begin
                // End the current row and merge its strongest colour run into
                // the active rectangle component.
                if(line_valid) begin
                    if(!comp_active) begin
                        comp_active  <= 1'b1;
                        comp_last_left <= line_left;
                        comp_last_right <= line_right;
                        comp_left    <= line_left;
                        comp_right   <= line_right;
                        comp_top     <= pixel_y;
                        comp_bottom  <= pixel_y;
                        comp_pixels  <= line_hits;
                        comp_row_gap <= 3'd0;
                    end
                    else if(line_matches) begin
                        comp_last_left <= line_left;
                        comp_last_right <= line_right;
                        if(line_left < comp_left)
                            comp_left <= line_left;
                        if(line_right > comp_right)
                            comp_right <= line_right;
                        comp_bottom  <= pixel_y;
                        comp_pixels  <= comp_pixels + line_hits;
                        comp_row_gap <= 3'd0;
                    end
                    else begin
                        if(use_candidate) begin
                            candidate_valid <= 1'b1;
                            candidate_ok <= comp_geometry_valid_q;
                            candidate_matches <= comp_matches_lock_q;
                            candidate_area <= comp_area_q;
                            candidate_distance <= comp_distance_q;
                            candidate_left <= comp_left; candidate_right <= comp_right;
                            candidate_top <= comp_top; candidate_bottom <= comp_bottom;
                        end
                        if(use_current) begin
                            best_valid  <= 1'b1;
                            best_left   <= comp_left;
                            best_right  <= comp_right;
                            best_top    <= comp_top;
                            best_bottom <= comp_bottom;
                            best_area   <= comp_area_q;
                            best_shape  <= comp_shape_q;
                            best_matches <= comp_matches_lock_q;
                            best_distance <= comp_distance_q;
                        end
                        comp_active  <= 1'b1;
                        comp_last_left <= line_left;
                        comp_last_right <= line_right;
                        comp_left    <= line_left;
                        comp_right   <= line_right;
                        comp_top     <= pixel_y;
                        comp_bottom  <= pixel_y;
                        comp_pixels  <= line_hits;
                        comp_row_gap <= 3'd0;
                    end
                end
                else if(comp_active) begin
                    if(comp_row_gap == MAX_ROW_GAP - 1) begin
                        if(use_candidate) begin
                            candidate_valid <= 1'b1;
                            candidate_ok <= comp_geometry_valid_q;
                            candidate_matches <= comp_matches_lock_q;
                            candidate_area <= comp_area_q;
                            candidate_distance <= comp_distance_q;
                            candidate_left <= comp_left; candidate_right <= comp_right;
                            candidate_top <= comp_top; candidate_bottom <= comp_bottom;
                        end
                        if(use_current) begin
                            best_valid  <= 1'b1;
                            best_left   <= comp_left;
                            best_right  <= comp_right;
                            best_top    <= comp_top;
                            best_bottom <= comp_bottom;
                            best_area   <= comp_area_q;
                            best_shape  <= comp_shape_q;
                            best_matches <= comp_matches_lock_q;
                            best_distance <= comp_distance_q;
                        end
                        comp_active  <= 1'b0;
                        comp_pixels  <= 20'd0;
                        comp_row_gap <= 3'd0;
                    end
                    else begin
                        comp_row_gap <= comp_row_gap + 3'd1;
                    end
                end

                run_active    <= 1'b0;
                run_hits      <= 12'd0;
                run_gap       <= 3'd0;
                row_best_hits <= 12'd0;
                row_best_matches <= 1'b0;
            end
            else if(mask_pixel) begin
                if(!run_active) begin
                    run_active <= 1'b1;
                    run_start  <= pixel_x;
                    run_last   <= pixel_x;
                    run_hits   <= 12'd1;
                    run_gap    <= 3'd0;
                end
                else begin
                    run_last <= pixel_x;
                    run_hits <= run_hits + 12'd1;
                    run_gap  <= 3'd0;
                end
            end
            else if(run_active) begin
                if(run_gap < MAX_RUN_GAP) begin
                    run_gap <= run_gap + 3'd1;
                end
                else begin
                    if((run_matches_lock && !row_best_matches) ||
                       ((run_matches_lock == row_best_matches) &&
                        (run_hits > row_best_hits))) begin
                        row_best_matches <= run_matches_lock;
                        row_best_left  <= run_start;
                        row_best_right <= run_last;
                        row_best_hits  <= run_hits;
                    end
                    run_active <= 1'b0;
                    run_hits   <= 12'd0;
                    run_gap    <= 3'd0;
                end
            end
        end
    end

endmodule

// Frame-age estimate: round(frames*1000 / nominal camera FPS).
// A serial divider and shared BCD converter finish within 32 pixel clocks,
// long before the left status panel begins at y=168. No pixel-path divider.
module osd_latency_ms (
    input wire I_clk, I_rst_n, I_start, I_fps60,
    input wire [7:0] I_frames_bcd,
    output reg [15:0] O_ms_bcd
);
    reg [1:0] state;
    reg [4:0] count;
    reg [16:0] dividend, quotient;
    reg [6:0] remainder;
    reg [6:0] divisor;
    reg [15:0] bcd, adjusted;
    wire [6:0] frames=({3'd0,I_frames_bcd[7:4]}<<3)+
                       ({3'd0,I_frames_bcd[7:4]}<<1)+I_frames_bcd[3:0];
    // 1000 = 1024 - 16 - 8; avoid consuming a DSP for a once/frame constant.
    wire [16:0] frame_scaled=({10'd0,frames}<<10)-
                              ({10'd0,frames}<<4)-({10'd0,frames}<<3);
    wire [7:0] trial={remainder,dividend[16]};
    wire take_bit=(trial>={1'b0,divisor});
    wire [16:0] next_quotient={quotient[15:0],take_bit};
    wire [15:0] next_bcd={adjusted[14:0],quotient[11]};
    integer k;
    always @* begin
        adjusted=bcd;
        for(k=0;k<4;k=k+1)
            if(bcd[k*4+:4]>=5) adjusted[k*4+:4]=bcd[k*4+:4]+4'd3;
    end
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            state<=0; count<=0; dividend<=0; quotient<=0;
            remainder<=0; divisor<=30; bcd<=0; O_ms_bcd<=0;
        end else if(I_start) begin
            dividend<=frame_scaled+(I_fps60 ? 17'd30 : 17'd15);
            divisor<=I_fps60 ? 7'd60 : 7'd30;
            remainder<=0; quotient<=0; count<=0; state<=1;
        end else if(state==1) begin
            remainder<=take_bit ? trial-divisor : trial;
            dividend<={dividend[15:0],1'b0}; quotient<=next_quotient;
            if(count==16) begin state<=2; count<=0; bcd<=0; end
            else count<=count+1'b1;
        end else if(state==2) begin
            quotient<={quotient[15:0],1'b0}; bcd<=next_bcd;
            if(count==11) begin O_ms_bcd<=next_bcd; state<=0; end
            else count<=count+1'b1;
        end
    end
endmodule

// Top-right fixed banner: x=888..1271, y=16..47; 16x16 character cells.
// One registered ROM stage aligns with video stage 1, then the existing stage-2
// video register performs the overlay. Detector input remains raw.
module blue_zoom_banner (
    input wire I_clk,I_rst_n,I_enable,
    input wire [11:0] I_x,I_y,
    output reg O_on,
    output wire [23:0] O_pixel
);
    wire [8:0] text_x=I_x-12'd896;
    wire [3:0] text_y=I_y-12'd24;
    reg [7:0] row_bits;
    reg [2:0] column;
    reg text_on;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin O_on<=0;text_on<=0;row_bits<=0;column<=0;end
        else begin
            O_on<=I_enable && I_x>=12'd888 && I_x<12'd1272 && I_y>=12'd16 && I_y<12'd48;
            text_on<=I_x>=12'd896 && I_x<12'd1264 && I_y>=12'd24 && I_y<12'd40;
            column<=text_x[3:1];
            case({text_x[8:4],text_y[3:1]})
                8'h00: row_bits<=8'h78;
                8'h01: row_bits<=8'h44;
                8'h02: row_bits<=8'h44;
                8'h03: row_bits<=8'h78;
                8'h04: row_bits<=8'h44;
                8'h05: row_bits<=8'h44;
                8'h06: row_bits<=8'h78;
                8'h08: row_bits<=8'h40;
                8'h09: row_bits<=8'h40;
                8'h0a: row_bits<=8'h40;
                8'h0b: row_bits<=8'h40;
                8'h0c: row_bits<=8'h40;
                8'h0d: row_bits<=8'h40;
                8'h0e: row_bits<=8'h7c;
                8'h10: row_bits<=8'h44;
                8'h11: row_bits<=8'h44;
                8'h12: row_bits<=8'h44;
                8'h13: row_bits<=8'h44;
                8'h14: row_bits<=8'h44;
                8'h15: row_bits<=8'h44;
                8'h16: row_bits<=8'h38;
                8'h18: row_bits<=8'h7c;
                8'h19: row_bits<=8'h40;
                8'h1a: row_bits<=8'h40;
                8'h1b: row_bits<=8'h78;
                8'h1c: row_bits<=8'h40;
                8'h1d: row_bits<=8'h40;
                8'h1e: row_bits<=8'h7c;
                8'h28: row_bits<=8'h78;
                8'h29: row_bits<=8'h44;
                8'h2a: row_bits<=8'h44;
                8'h2b: row_bits<=8'h78;
                8'h2c: row_bits<=8'h50;
                8'h2d: row_bits<=8'h48;
                8'h2e: row_bits<=8'h44;
                8'h30: row_bits<=8'h7c;
                8'h31: row_bits<=8'h40;
                8'h32: row_bits<=8'h40;
                8'h33: row_bits<=8'h78;
                8'h34: row_bits<=8'h40;
                8'h35: row_bits<=8'h40;
                8'h36: row_bits<=8'h7c;
                8'h38: row_bits<=8'h38;
                8'h39: row_bits<=8'h44;
                8'h3a: row_bits<=8'h40;
                8'h3b: row_bits<=8'h40;
                8'h3c: row_bits<=8'h40;
                8'h3d: row_bits<=8'h44;
                8'h3e: row_bits<=8'h38;
                8'h40: row_bits<=8'h7c;
                8'h41: row_bits<=8'h10;
                8'h42: row_bits<=8'h10;
                8'h43: row_bits<=8'h10;
                8'h44: row_bits<=8'h10;
                8'h45: row_bits<=8'h10;
                8'h46: row_bits<=8'h10;
                8'h48: row_bits<=8'h38;
                8'h49: row_bits<=8'h44;
                8'h4a: row_bits<=8'h44;
                8'h4b: row_bits<=8'h7c;
                8'h4c: row_bits<=8'h44;
                8'h4d: row_bits<=8'h44;
                8'h4e: row_bits<=8'h44;
                8'h50: row_bits<=8'h44;
                8'h51: row_bits<=8'h64;
                8'h52: row_bits<=8'h54;
                8'h53: row_bits<=8'h4c;
                8'h54: row_bits<=8'h44;
                8'h55: row_bits<=8'h44;
                8'h56: row_bits<=8'h44;
                8'h58: row_bits<=8'h38;
                8'h59: row_bits<=8'h44;
                8'h5a: row_bits<=8'h40;
                8'h5b: row_bits<=8'h5c;
                8'h5c: row_bits<=8'h44;
                8'h5d: row_bits<=8'h44;
                8'h5e: row_bits<=8'h38;
                8'h60: row_bits<=8'h40;
                8'h61: row_bits<=8'h40;
                8'h62: row_bits<=8'h40;
                8'h63: row_bits<=8'h40;
                8'h64: row_bits<=8'h40;
                8'h65: row_bits<=8'h40;
                8'h66: row_bits<=8'h7c;
                8'h68: row_bits<=8'h7c;
                8'h69: row_bits<=8'h40;
                8'h6a: row_bits<=8'h40;
                8'h6b: row_bits<=8'h78;
                8'h6c: row_bits<=8'h40;
                8'h6d: row_bits<=8'h40;
                8'h6e: row_bits<=8'h7c;
                8'h78: row_bits<=8'h78;
                8'h79: row_bits<=8'h44;
                8'h7a: row_bits<=8'h44;
                8'h7b: row_bits<=8'h44;
                8'h7c: row_bits<=8'h44;
                8'h7d: row_bits<=8'h44;
                8'h7e: row_bits<=8'h78;
                8'h80: row_bits<=8'h7c;
                8'h81: row_bits<=8'h40;
                8'h82: row_bits<=8'h40;
                8'h83: row_bits<=8'h78;
                8'h84: row_bits<=8'h40;
                8'h85: row_bits<=8'h40;
                8'h86: row_bits<=8'h7c;
                8'h88: row_bits<=8'h7c;
                8'h89: row_bits<=8'h10;
                8'h8a: row_bits<=8'h10;
                8'h8b: row_bits<=8'h10;
                8'h8c: row_bits<=8'h10;
                8'h8d: row_bits<=8'h10;
                8'h8e: row_bits<=8'h10;
                8'h90: row_bits<=8'h7c;
                8'h91: row_bits<=8'h40;
                8'h92: row_bits<=8'h40;
                8'h93: row_bits<=8'h78;
                8'h94: row_bits<=8'h40;
                8'h95: row_bits<=8'h40;
                8'h96: row_bits<=8'h7c;
                8'h98: row_bits<=8'h38;
                8'h99: row_bits<=8'h44;
                8'h9a: row_bits<=8'h40;
                8'h9b: row_bits<=8'h40;
                8'h9c: row_bits<=8'h40;
                8'h9d: row_bits<=8'h44;
                8'h9e: row_bits<=8'h38;
                8'ha0: row_bits<=8'h7c;
                8'ha1: row_bits<=8'h10;
                8'ha2: row_bits<=8'h10;
                8'ha3: row_bits<=8'h10;
                8'ha4: row_bits<=8'h10;
                8'ha5: row_bits<=8'h10;
                8'ha6: row_bits<=8'h10;
                8'ha8: row_bits<=8'h7c;
                8'ha9: row_bits<=8'h40;
                8'haa: row_bits<=8'h40;
                8'hab: row_bits<=8'h78;
                8'hac: row_bits<=8'h40;
                8'had: row_bits<=8'h40;
                8'hae: row_bits<=8'h7c;
                8'hb0: row_bits<=8'h78;
                8'hb1: row_bits<=8'h44;
                8'hb2: row_bits<=8'h44;
                8'hb3: row_bits<=8'h44;
                8'hb4: row_bits<=8'h44;
                8'hb5: row_bits<=8'h44;
                8'hb6: row_bits<=8'h78;
                default:row_bits<=0;
            endcase
        end
    end
    assign O_pixel=(text_on && row_bits[7-column]) ? 24'hfff200 : 24'h101820;
endmodule

// Learning runs on untouched displayed RGB, before any mask/OSD is drawn.
// A 64x64 central ROI, sampled every fourth pixel/row: 256 samples/frame.
// Eight distinct camera frames are averaged; all divisions are powers of two.
module target_color_learning (
    input wire I_clk,I_rst_n,I_selected,I_learn_enable,I_prepare,I_start,
    input wire I_de,
    input wire [11:0] I_x,I_y,
    input wire [23:0] I_rgb,I_frame_id,
    output reg O_valid,
    output reg [3:0] O_status,
    output reg [23:0] O_rgb,
    output reg O_generation,
    output wire O_mask,O_preparing
);
    localparam EMPTY=0,READY=1,SAMPLE=2,OK=3,DARK=4,BRIGHT=5,MIXED=6,UNSTABLE=7,COMMIT=8;
    wire frame_start=I_de && I_x==0 && I_y==0;
    wire [8:0] cr=9'd256+{1'b0,I_rgb[23:16]}-{1'b0,I_rgb[15:8]};
    wire [8:0] cb=9'd256+{1'b0,I_rgb[7:0]}-{1'b0,I_rgb[15:8]};
    wire [7:0] rgb_max=(I_rgb[23:16]>I_rgb[15:8]) ?
         ((I_rgb[23:16]>I_rgb[7:0]) ? I_rgb[23:16]:I_rgb[7:0]):
         ((I_rgb[15:8]>I_rgb[7:0]) ? I_rgb[15:8]:I_rgb[7:0]);
    wire [7:0] rgb_min=(I_rgb[23:16]<I_rgb[15:8]) ?
         ((I_rgb[23:16]<I_rgb[7:0]) ? I_rgb[23:16]:I_rgb[7:0]):
         ((I_rgb[15:8]<I_rgb[7:0]) ? I_rgb[15:8]:I_rgb[7:0]);
    reg [8:0] cr_low,cr_high,cb_low,cb_high;
    assign O_preparing=I_selected && I_learn_enable && (O_status==READY || O_status==SAMPLE || O_status==COMMIT);
    assign O_mask=O_valid && !O_preparing && cr>=cr_low && cr<=cr_high &&
         cb>=cb_low && cb<=cb_high && rgb_max>=8'd32 && rgb_min<8'd244 &&
         ({1'b0,rgb_max}-{1'b0,rgb_min})>=9'd24;
    reg active,frame_seen;
    reg [23:0] last_frame;
    reg [8:0] sample_count;
    reg [15:0] sum_r,sum_g,sum_b;
    reg [8:0] min_cr,max_cr,min_cb,max_cb;
    reg [10:0] total_r,total_g,total_b;
    reg [2:0] accepted;
    reg [8:0] first_cr,first_cb;
    reg [7:0] first_luma;
    wire [7:0] mean_r=sum_r[15:8],mean_g=sum_g[15:8],mean_b=sum_b[15:8];
    wire [9:0] luma_sum={2'd0,mean_r}+{1'd0,mean_g,1'b0}+{2'd0,mean_b};
    wire [8:0] mean_cr=9'd256+{1'b0,mean_r}-{1'b0,mean_g};
    wire [8:0] mean_cb=9'd256+{1'b0,mean_b}-{1'b0,mean_g};
    wire [8:0] drift_cr=(mean_cr>first_cr) ? mean_cr-first_cr:first_cr-mean_cr;
    wire [8:0] drift_cb=(mean_cb>first_cb) ? mean_cb-first_cb:first_cb-mean_cb;
    wire [7:0] drift_luma=(luma_sum[9:2]>first_luma) ? luma_sum[9:2]-first_luma:first_luma-luma_sum[9:2];
    wire [8:0] learned_cr=9'd256+{1'b0,total_r[10:3]}-{1'b0,total_g[10:3]};
    wire [8:0] learned_cb=9'd256+{1'b0,total_b[10:3]}-{1'b0,total_g[10:3]};
    wire [7:0] mean_max=(mean_r>mean_g) ? ((mean_r>mean_b)?mean_r:mean_b):((mean_g>mean_b)?mean_g:mean_b);
    wire [7:0] mean_min=(mean_r<mean_g) ? ((mean_r<mean_b)?mean_r:mean_b):((mean_g<mean_b)?mean_g:mean_b);
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_valid<=0;O_status<=EMPTY;O_rgb<=0;O_generation<=0;
            cr_low<=0;cr_high<=0;cb_low<=0;cb_high<=0;
            active<=0;frame_seen<=0;last_frame<=0;sample_count<=0;
            sum_r<=0;sum_g<=0;sum_b<=0;total_r<=0;total_g<=0;total_b<=0;
            min_cr<=511;max_cr<=0;min_cb<=511;max_cb<=0;accepted<=0;
            first_cr<=0;first_cb<=0;first_luma<=0;
        end else if(I_learn_enable && (I_prepare || I_start)) begin
            O_status<=I_start ? SAMPLE:READY;
            active<=0;frame_seen<=0;sample_count<=0;accepted<=0;
            sum_r<=0;sum_g<=0;sum_b<=0;total_r<=0;total_g<=0;total_b<=0;
            min_cr<=511;max_cr<=0;min_cb<=511;max_cb<=0;
        end else if(!I_selected || !I_learn_enable) begin
            active<=0;
            if(O_status==SAMPLE || O_status==COMMIT || O_status==READY)
                O_status<=O_valid ? OK:EMPTY;
        end else if(O_status==COMMIT) begin
            // All source sums have been registered before generating bounds.
            O_rgb<={total_r[10:3],total_g[10:3],total_b[10:3]};
            cr_low<=(learned_cr<9'd32) ? 9'd0:learned_cr-9'd32;
            cr_high<=(learned_cr>9'd479) ? 9'd511:learned_cr+9'd32;
            cb_low<=(learned_cb<9'd32) ? 9'd0:learned_cb-9'd32;
            cb_high<=(learned_cb>9'd479) ? 9'd511:learned_cb+9'd32;
            O_valid<=1;O_status<=OK;O_generation<=!O_generation;active<=0;
        end else if(O_status==SAMPLE) begin
            if(frame_start) begin
                active<=!frame_seen || I_frame_id!=last_frame;
                frame_seen<=1;last_frame<=I_frame_id;
                sum_r<=0;sum_g<=0;sum_b<=0;sample_count<=0;
                min_cr<=511;max_cr<=0;min_cb<=511;max_cb<=0;
                if(active) begin
                    if(sample_count!=9'd256) O_status<=UNSTABLE;
                    else if(luma_sum[9:2]<8'd24) O_status<=DARK;
                    else if(luma_sum[9:2]>=8'd244) O_status<=BRIGHT;
                    else if(max_cr-min_cr>9'd64 || max_cb-min_cb>9'd64 ||
                            {1'b0,mean_max}-{1'b0,mean_min}<9'd24) O_status<=MIXED;
                    else if(accepted!=0 && (drift_cr>9'd24 || drift_cb>9'd24 || drift_luma>8'd32)) O_status<=UNSTABLE;
                    else begin
                        total_r<=total_r+{3'd0,mean_r};total_g<=total_g+{3'd0,mean_g};total_b<=total_b+{3'd0,mean_b};
                        if(accepted==0) begin first_cr<=mean_cr;first_cb<=mean_cb;first_luma<=luma_sum[9:2];end
                        if(accepted==3'd7) O_status<=COMMIT;
                        else accepted<=accepted+1'b1;
                    end
                end
            end else if(active && I_de && I_x>=12'd608 && I_x<12'd672 &&
                        I_y>=12'd328 && I_y<12'd392 && I_x[1:0]==0 && I_y[1:0]==0) begin
                sample_count<=sample_count+1'b1;
                sum_r<=sum_r+{8'd0,I_rgb[23:16]};sum_g<=sum_g+{8'd0,I_rgb[15:8]};sum_b<=sum_b+{8'd0,I_rgb[7:0]};
                if(cr<min_cr) min_cr<=cr;if(cr>max_cr) max_cr<=cr;
                if(cb<min_cb) min_cb<=cb;if(cb>max_cb) max_cb<=cb;
            end
        end
    end
endmodule

// All graphic/text flags and glyph rows are registered once, matching
// the existing mixer stage 1. No new external video or DE/sync latency.
module target_teach_overlay (
    input wire I_clk,I_rst_n,I_enable,I_custom,I_teach_mode,I_preparing,I_target_valid,I_learn_valid,
    input wire [3:0] I_status,
    input wire [23:0] I_rgb,
    input wire [11:0] I_x,I_y,I_center_x,I_center_y,
    input wire [15:0] I_x_bcd,I_y_bcd,
    output reg O_on,
    output wire [23:0] O_pixel
);
    // 1280x720 ->160x90 is a wiring shift, with no division or frame RAM.
    wire [11:0] point_x=12'd1100+{3'd0,I_center_x[11:3]};
    wire [11:0] point_y=12'd472+{3'd0,I_center_y[11:3]};
    wire panel=I_x>=12'd1088 && I_x<12'd1272 && I_y>=12'd440 && I_y<12'd672;
    wire roi=I_preparing && I_x>=12'd607 && I_x<=12'd672 && I_y>=12'd327 && I_y<=12'd392 &&
        (I_x<=12'd608 || I_x>=12'd671 || I_y<=12'd328 || I_y>=12'd391);
    wire map=I_x>=12'd1099 && I_x<=12'd1260 && I_y>=12'd471 && I_y<=12'd562;
    wire border=map && (I_x==12'd1099 || I_x==12'd1260 || I_y==12'd471 || I_y==12'd562);
    wire grid_cross=map && (I_x==12'd1180 || I_y==12'd517);
    wire dot=map && I_target_valid && I_x+12'd2>=point_x && I_x<=point_x+12'd2 &&
        I_y+12'd2>=point_y && I_y<=point_y+12'd2;
    wire swatch=I_custom && I_learn_valid && I_x>=12'd1244 && I_x<12'd1260 && I_y>=12'd612 && I_y<12'd628;
    reg [7:0] char_code;
    reg [3:0] text_y;
    wire [7:0] text_x=I_x-12'd1100;
    wire [4:0] char_index=text_x[7:3];
    reg text_hit;
    reg [159:0] text_line;
    always @* begin
        char_code=8'h20;text_y=0;text_hit=0;text_line="                    ";
        if(I_y>=12'd448 && I_y<12'd464) begin
            text_line="TARGET POSITION     ";text_y=I_y-12'd448;text_hit=1;
        end else if(I_y>=12'd580 && I_y<12'd596) begin
            text_y=I_y-12'd580;text_hit=1;
            if(I_target_valid) text_line={"X:",8'h30+{4'd0,I_x_bcd[15:12]},8'h30+{4'd0,I_x_bcd[11:8]},
                8'h30+{4'd0,I_x_bcd[7:4]},8'h30+{4'd0,I_x_bcd[3:0]}," Y:",
                8'h30+{4'd0,I_y_bcd[15:12]},8'h30+{4'd0,I_y_bcd[11:8]},
                8'h30+{4'd0,I_y_bcd[7:4]},8'h30+{4'd0,I_y_bcd[3:0]},"       "};
            else text_line="X:---- Y:----       ";
        end else if(I_y>=12'd612 && I_y<12'd628) begin
            text_y=I_y-12'd612;text_hit=1;
            if(I_custom) begin
                case(I_status)
                    0:text_line="LEARN: EMPTY        ";1:text_line="LEARN: READY        ";
                    2,8:text_line="LEARN: SAMPLING     ";3:text_line="LEARN: OK           ";
                    4:text_line="FAIL: DARK          ";5:text_line="FAIL: BRIGHT        ";
                    6:text_line="FAIL: MIXED         ";7:text_line="FAIL: UNSTABLE      ";
                    default:text_line="LEARN: EMPTY        ";
                endcase
            end else text_line=I_target_valid ? "TARGET: VALID       ":"TARGET: NONE        ";
        end else if(I_y>=12'd644 && I_y<12'd660) begin
            text_y=I_y-12'd644;text_hit=1;
            if(!I_teach_mode) text_line="K3 PAUSE K4 START   ";
            else if(I_custom) text_line="K1 READY K2 LEARN   ";
            else text_line="K1 COLOR K2 SHAPE   ";
        end else if(!I_target_valid && I_y>=12'd508 && I_y<12'd524) begin
            text_y=I_y-12'd508;text_hit=1;text_line="    NO TARGET       ";
        end
        if(char_index<20) char_code=text_line >> ((19-char_index)*8);
    end
    reg [4:0] glyph;
    reg [2:0] column;
    reg text_on;
    reg [23:0] background,text_colour;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin O_on<=0;glyph<=0;column<=0;text_on<=0;background<=0;text_colour<=0;end
        else begin
            O_on<=I_enable && (panel || roi);
            text_on<=panel && text_hit && I_x>=12'd1100 && I_x<12'd1260;
            column<=text_x[2:0];
            text_colour<=I_custom && I_status>=4 && I_status<=7 && I_y>=612 && I_y<628 ? 24'hff7050:24'hd0f0ff;
            if(roi) background<=24'hffffff;
            else if(dot) background<=24'hfff200;
            else if(border) background<=24'h70d8ff;
            else if(grid_cross) background<=24'h405060;
            else if(swatch) background<=I_rgb;
            else background<=24'h101820;
            case({char_code,text_y[3:1]})
                11'h16b: glyph<=5'h1f;
                11'h180: glyph<=5'h0e;
                11'h181: glyph<=5'h11;
                11'h182: glyph<=5'h13;
                11'h183: glyph<=5'h15;
                11'h184: glyph<=5'h19;
                11'h185: glyph<=5'h11;
                11'h186: glyph<=5'h0e;
                11'h188: glyph<=5'h04;
                11'h189: glyph<=5'h0c;
                11'h18a: glyph<=5'h04;
                11'h18b: glyph<=5'h04;
                11'h18c: glyph<=5'h04;
                11'h18d: glyph<=5'h04;
                11'h18e: glyph<=5'h0e;
                11'h190: glyph<=5'h0e;
                11'h191: glyph<=5'h11;
                11'h192: glyph<=5'h01;
                11'h193: glyph<=5'h02;
                11'h194: glyph<=5'h04;
                11'h195: glyph<=5'h08;
                11'h196: glyph<=5'h1f;
                11'h198: glyph<=5'h1e;
                11'h199: glyph<=5'h01;
                11'h19a: glyph<=5'h01;
                11'h19b: glyph<=5'h0e;
                11'h19c: glyph<=5'h01;
                11'h19d: glyph<=5'h01;
                11'h19e: glyph<=5'h1e;
                11'h1a0: glyph<=5'h02;
                11'h1a1: glyph<=5'h06;
                11'h1a2: glyph<=5'h0a;
                11'h1a3: glyph<=5'h12;
                11'h1a4: glyph<=5'h1f;
                11'h1a5: glyph<=5'h02;
                11'h1a6: glyph<=5'h02;
                11'h1a8: glyph<=5'h1f;
                11'h1a9: glyph<=5'h10;
                11'h1aa: glyph<=5'h10;
                11'h1ab: glyph<=5'h1e;
                11'h1ac: glyph<=5'h01;
                11'h1ad: glyph<=5'h01;
                11'h1ae: glyph<=5'h1e;
                11'h1b0: glyph<=5'h0e;
                11'h1b1: glyph<=5'h10;
                11'h1b2: glyph<=5'h10;
                11'h1b3: glyph<=5'h1e;
                11'h1b4: glyph<=5'h11;
                11'h1b5: glyph<=5'h11;
                11'h1b6: glyph<=5'h0e;
                11'h1b8: glyph<=5'h1f;
                11'h1b9: glyph<=5'h01;
                11'h1ba: glyph<=5'h02;
                11'h1bb: glyph<=5'h04;
                11'h1bc: glyph<=5'h08;
                11'h1bd: glyph<=5'h08;
                11'h1be: glyph<=5'h08;
                11'h1c0: glyph<=5'h0e;
                11'h1c1: glyph<=5'h11;
                11'h1c2: glyph<=5'h11;
                11'h1c3: glyph<=5'h0e;
                11'h1c4: glyph<=5'h11;
                11'h1c5: glyph<=5'h11;
                11'h1c6: glyph<=5'h0e;
                11'h1c8: glyph<=5'h0e;
                11'h1c9: glyph<=5'h11;
                11'h1ca: glyph<=5'h11;
                11'h1cb: glyph<=5'h0f;
                11'h1cc: glyph<=5'h01;
                11'h1cd: glyph<=5'h01;
                11'h1ce: glyph<=5'h0e;
                11'h1d1: glyph<=5'h04;
                11'h1d2: glyph<=5'h04;
                11'h1d4: glyph<=5'h04;
                11'h1d5: glyph<=5'h04;
                11'h208: glyph<=5'h0e;
                11'h209: glyph<=5'h11;
                11'h20a: glyph<=5'h11;
                11'h20b: glyph<=5'h1f;
                11'h20c: glyph<=5'h11;
                11'h20d: glyph<=5'h11;
                11'h20e: glyph<=5'h11;
                11'h210: glyph<=5'h1e;
                11'h211: glyph<=5'h11;
                11'h212: glyph<=5'h11;
                11'h213: glyph<=5'h1e;
                11'h214: glyph<=5'h11;
                11'h215: glyph<=5'h11;
                11'h216: glyph<=5'h1e;
                11'h218: glyph<=5'h0e;
                11'h219: glyph<=5'h11;
                11'h21a: glyph<=5'h10;
                11'h21b: glyph<=5'h10;
                11'h21c: glyph<=5'h10;
                11'h21d: glyph<=5'h11;
                11'h21e: glyph<=5'h0e;
                11'h220: glyph<=5'h1e;
                11'h221: glyph<=5'h11;
                11'h222: glyph<=5'h11;
                11'h223: glyph<=5'h11;
                11'h224: glyph<=5'h11;
                11'h225: glyph<=5'h11;
                11'h226: glyph<=5'h1e;
                11'h228: glyph<=5'h1f;
                11'h229: glyph<=5'h10;
                11'h22a: glyph<=5'h10;
                11'h22b: glyph<=5'h1e;
                11'h22c: glyph<=5'h10;
                11'h22d: glyph<=5'h10;
                11'h22e: glyph<=5'h1f;
                11'h230: glyph<=5'h1f;
                11'h231: glyph<=5'h10;
                11'h232: glyph<=5'h10;
                11'h233: glyph<=5'h1e;
                11'h234: glyph<=5'h10;
                11'h235: glyph<=5'h10;
                11'h236: glyph<=5'h10;
                11'h238: glyph<=5'h0e;
                11'h239: glyph<=5'h11;
                11'h23a: glyph<=5'h10;
                11'h23b: glyph<=5'h17;
                11'h23c: glyph<=5'h11;
                11'h23d: glyph<=5'h11;
                11'h23e: glyph<=5'h0e;
                11'h240: glyph<=5'h11;
                11'h241: glyph<=5'h11;
                11'h242: glyph<=5'h11;
                11'h243: glyph<=5'h1f;
                11'h244: glyph<=5'h11;
                11'h245: glyph<=5'h11;
                11'h246: glyph<=5'h11;
                11'h248: glyph<=5'h1f;
                11'h249: glyph<=5'h04;
                11'h24a: glyph<=5'h04;
                11'h24b: glyph<=5'h04;
                11'h24c: glyph<=5'h04;
                11'h24d: glyph<=5'h04;
                11'h24e: glyph<=5'h1f;
                11'h250: glyph<=5'h07;
                11'h251: glyph<=5'h02;
                11'h252: glyph<=5'h02;
                11'h253: glyph<=5'h02;
                11'h254: glyph<=5'h12;
                11'h255: glyph<=5'h12;
                11'h256: glyph<=5'h0c;
                11'h258: glyph<=5'h11;
                11'h259: glyph<=5'h12;
                11'h25a: glyph<=5'h14;
                11'h25b: glyph<=5'h18;
                11'h25c: glyph<=5'h14;
                11'h25d: glyph<=5'h12;
                11'h25e: glyph<=5'h11;
                11'h260: glyph<=5'h10;
                11'h261: glyph<=5'h10;
                11'h262: glyph<=5'h10;
                11'h263: glyph<=5'h10;
                11'h264: glyph<=5'h10;
                11'h265: glyph<=5'h10;
                11'h266: glyph<=5'h1f;
                11'h268: glyph<=5'h11;
                11'h269: glyph<=5'h1b;
                11'h26a: glyph<=5'h15;
                11'h26b: glyph<=5'h15;
                11'h26c: glyph<=5'h11;
                11'h26d: glyph<=5'h11;
                11'h26e: glyph<=5'h11;
                11'h270: glyph<=5'h11;
                11'h271: glyph<=5'h19;
                11'h272: glyph<=5'h15;
                11'h273: glyph<=5'h13;
                11'h274: glyph<=5'h11;
                11'h275: glyph<=5'h11;
                11'h276: glyph<=5'h11;
                11'h278: glyph<=5'h0e;
                11'h279: glyph<=5'h11;
                11'h27a: glyph<=5'h11;
                11'h27b: glyph<=5'h11;
                11'h27c: glyph<=5'h11;
                11'h27d: glyph<=5'h11;
                11'h27e: glyph<=5'h0e;
                11'h280: glyph<=5'h1e;
                11'h281: glyph<=5'h11;
                11'h282: glyph<=5'h11;
                11'h283: glyph<=5'h1e;
                11'h284: glyph<=5'h10;
                11'h285: glyph<=5'h10;
                11'h286: glyph<=5'h10;
                11'h288: glyph<=5'h0e;
                11'h289: glyph<=5'h11;
                11'h28a: glyph<=5'h11;
                11'h28b: glyph<=5'h11;
                11'h28c: glyph<=5'h15;
                11'h28d: glyph<=5'h12;
                11'h28e: glyph<=5'h0d;
                11'h290: glyph<=5'h1e;
                11'h291: glyph<=5'h11;
                11'h292: glyph<=5'h11;
                11'h293: glyph<=5'h1e;
                11'h294: glyph<=5'h14;
                11'h295: glyph<=5'h12;
                11'h296: glyph<=5'h11;
                11'h298: glyph<=5'h0f;
                11'h299: glyph<=5'h10;
                11'h29a: glyph<=5'h10;
                11'h29b: glyph<=5'h0e;
                11'h29c: glyph<=5'h01;
                11'h29d: glyph<=5'h01;
                11'h29e: glyph<=5'h1e;
                11'h2a0: glyph<=5'h1f;
                11'h2a1: glyph<=5'h04;
                11'h2a2: glyph<=5'h04;
                11'h2a3: glyph<=5'h04;
                11'h2a4: glyph<=5'h04;
                11'h2a5: glyph<=5'h04;
                11'h2a6: glyph<=5'h04;
                11'h2a8: glyph<=5'h11;
                11'h2a9: glyph<=5'h11;
                11'h2aa: glyph<=5'h11;
                11'h2ab: glyph<=5'h11;
                11'h2ac: glyph<=5'h11;
                11'h2ad: glyph<=5'h11;
                11'h2ae: glyph<=5'h0e;
                11'h2b0: glyph<=5'h11;
                11'h2b1: glyph<=5'h11;
                11'h2b2: glyph<=5'h11;
                11'h2b3: glyph<=5'h11;
                11'h2b4: glyph<=5'h11;
                11'h2b5: glyph<=5'h0a;
                11'h2b6: glyph<=5'h04;
                11'h2b8: glyph<=5'h11;
                11'h2b9: glyph<=5'h11;
                11'h2ba: glyph<=5'h11;
                11'h2bb: glyph<=5'h15;
                11'h2bc: glyph<=5'h15;
                11'h2bd: glyph<=5'h15;
                11'h2be: glyph<=5'h0a;
                11'h2c0: glyph<=5'h11;
                11'h2c1: glyph<=5'h11;
                11'h2c2: glyph<=5'h0a;
                11'h2c3: glyph<=5'h04;
                11'h2c4: glyph<=5'h0a;
                11'h2c5: glyph<=5'h11;
                11'h2c6: glyph<=5'h11;
                11'h2c8: glyph<=5'h11;
                11'h2c9: glyph<=5'h11;
                11'h2ca: glyph<=5'h0a;
                11'h2cb: glyph<=5'h04;
                11'h2cc: glyph<=5'h04;
                11'h2cd: glyph<=5'h04;
                11'h2ce: glyph<=5'h04;
                11'h2d0: glyph<=5'h1f;
                11'h2d1: glyph<=5'h01;
                11'h2d2: glyph<=5'h02;
                11'h2d3: glyph<=5'h04;
                11'h2d4: glyph<=5'h08;
                11'h2d5: glyph<=5'h10;
                11'h2d6: glyph<=5'h1f;
                default:glyph<=0;
            endcase
        end
    end
    assign O_pixel=(text_on && column<5 && glyph[4-column]) ? text_colour:background;
endmodule
