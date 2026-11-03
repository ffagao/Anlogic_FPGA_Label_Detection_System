module hdmi_mixer_v35_baseline #(
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
    input wire I_label_imaging_locked,
    output wire O_label_imaging_lock,O_label_buzzer_n,
    input wire [3:0]  I_servo_state,
    input wire [11:0] I_pan_pulse_us,
    input wire [11:0] I_tilt_pulse_us,
    output reg        O_measure_update,
    output wire       O_measure_valid,
    output reg signed [12:0] O_measure_dx,
    output reg signed [12:0] O_measure_dy,
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
    reg [11:0] S_x;
    reg [11:0] S_y;
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
    localparam [11:0] AIM_DEADZONE = 12'd20;
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
    assign O_measure_valid = S_measure_snapshot_valid && S_aim_detect_now &&
                    (S_measure_color == I_track_color) &&
                    (S_measure_shape == I_track_shape) &&
                    (S_measure_view == I_switch_state);
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_measure_pending<=0; O_measure_update<=0;
            S_measure_snapshot_valid<=0; O_measure_dx<=0; O_measure_dy<=0;
            S_measure_color<=0; S_measure_shape<=0; S_measure_view<=0;
        end
        else begin
            S_measure_pending<=S_track_result_update;
            O_measure_update<=S_measure_pending && I_track_enable;
            if(!I_track_enable) S_measure_snapshot_valid<=0;
            else if(S_measure_pending) begin
                S_measure_snapshot_valid<=S_aim_detect_now;
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
    wire S_custom_selected=I_track_color==3'd5;
    target_color_learning u_target_color_learning (
        .I_clk(I_clk),.I_rst_n(I_rst_n),.I_selected(S_custom_selected),
        .I_learn_enable(I_switch_state==4'd1 && S_custom_selected),
        .I_prepare(I_learn_prepare),.I_start(I_learn_start),
        .I_de(S_video_de_2d),.I_x(S_x_2d),.I_y(S_y_2d),
        .I_rgb(S_video_data_raw_2d),.I_frame_id(S_display_frame_bcd_osd),
        .O_valid(S_custom_valid),.O_status(S_learn_status),.O_rgb(S_learn_rgb),
        .O_generation(S_custom_generation),.O_mask(S_custom_mask),.O_preparing(S_custom_preparing)
    );
    wire S_teach_overlay_on;
    wire [23:0] S_teach_overlay_pixel;
    reg S_teach_overlay_on_2d;
    target_teach_overlay u_target_teach_overlay (
        .I_clk(I_clk),.I_rst_n(I_rst_n),
        .I_enable((I_switch_state==4'd1 || I_switch_state==4'd3) && I_track_enable),
        .I_custom(S_custom_selected),.I_teach_mode(I_switch_state==4'd1),.I_preparing(S_custom_preparing),
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
        .O_count_bcd    ( S_motion_count_bcd       )
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
            S_x <= 12'd0;
            S_y <= 12'd0;
        end
        else if(I_video_user) begin
            S_x <= 12'd0;
            S_y <= 12'd0;
        end
        else if(I_video_de) begin
            if(I_video_last) begin
                S_x <= 12'd0;
                S_y <= S_y + 12'd1;
            end
            else begin
                S_x <= S_x + 12'd1;
            end
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
        .I_frames_bcd(I_delay_frames_bcd), .I_fps60(I_switch_state==4'b0110),
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
        .O_imaging_lock(O_label_imaging_lock),.O_hit(S_label_hit),.O_color(S_label_color),
        .O_buzzer_n(O_label_buzzer_n),.O_seg_sel(),.O_seg_dig()
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