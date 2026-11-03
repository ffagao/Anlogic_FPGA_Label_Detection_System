module rectangle_tracker_v40_reference #(
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
    reg [11:0] pixel_x, pixel_y;
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
    wire [11:0] lock_center_x = (O_left + O_right) >> 1;
    wire [11:0] lock_center_y = (O_top + O_bottom) >> 1;
    reg        frame_id_valid;
    reg [23:0] last_frame_id;
    reg        frame_mask_seen;
    wire       new_camera_frame = !frame_id_valid || (pixel_frame_id != last_frame_id);
    wire       frame_start = pixel_de && (pixel_x == 12'd0) && (pixel_y == 12'd0);
    assign O_result_update = I_enable && frame_start && process_frame && !view_changed;
    wire       line_end = pixel_de && (pixel_x == IMG_WIDTH - 1);

    reg        run_active;
    reg [11:0] run_start;
    reg [11:0] run_last;
    reg [11:0] run_hits;
    reg [2:0]  run_gap;
    reg [11:0] row_best_left;
    reg [11:0] row_best_right;
    reg [11:0] row_best_hits;
    reg        row_best_matches;
    // Keep the locked target's run even if another object has more pixels.
    wire       row_in_lock = O_track_valid &&
                    (({1'b0,pixel_y} + {1'b0,MATCH_MARGIN}) >= {1'b0,O_top}) &&
                    ({1'b0,pixel_y} <= ({1'b0,O_bottom} + {1'b0,MATCH_MARGIN}));
    wire [11:0] run_center = (run_start + run_last) >> 1;
    wire       run_matches_lock = row_in_lock && (run_hits >= min_row_pix) &&
                    (({1'b0,run_center} + {1'b0,MATCH_MARGIN}) >= {1'b0,O_left}) &&
                    ({1'b0,run_center} <= ({1'b0,O_right} + {1'b0,MATCH_MARGIN}));

    wire       eol_run_valid = run_active || mask_pixel;
    wire [11:0] eol_run_left = run_active ? run_start : pixel_x;
    wire [11:0] eol_run_right = mask_pixel ? pixel_x : run_last;
    wire [11:0] eol_run_hits = run_active ?
                                (run_hits + (mask_pixel ? 12'd1 : 12'd0)) :
                                (mask_pixel ? 12'd1 : 12'd0);
    wire [11:0] eol_center = (eol_run_left + eol_run_right) >> 1;
    wire       eol_matches_lock = row_in_lock && (eol_run_hits >= min_row_pix) &&
                    (({1'b0,eol_center} + {1'b0,MATCH_MARGIN}) >= {1'b0,O_left}) &&
                    ({1'b0,eol_center} <= ({1'b0,O_right} + {1'b0,MATCH_MARGIN}));
    wire       eol_use_run = eol_run_valid &&
                    ((eol_matches_lock && !row_best_matches) ||
                     ((eol_matches_lock == row_best_matches) &&
                      (eol_run_hits > row_best_hits)));
    wire [11:0] line_left = eol_use_run ? eol_run_left : row_best_left;
    wire [11:0] line_right = eol_use_run ? eol_run_right : row_best_right;
    wire [11:0] line_hits = eol_use_run ? eol_run_hits : row_best_hits;
    wire        line_matches_lock = eol_use_run ? eol_matches_lock : row_best_matches;
    wire        line_valid = (line_hits >= min_row_pix);

    reg        comp_active;
    reg [11:0] comp_last_left, comp_last_right;
    reg [11:0] comp_left;
    reg [11:0] comp_right;
    reg [11:0] comp_top;
    reg [11:0] comp_bottom;
    reg [19:0] comp_pixels;
    reg [2:0]  comp_row_gap;

    wire [12:0] comp_width = {1'b0,comp_right} -
                             {1'b0,comp_left} + 13'd1;
    wire [12:0] comp_height = {1'b0,comp_bottom} -
                              {1'b0,comp_top} + 13'd1;
    wire [25:0] comp_area = comp_width * comp_height;
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
    wire [11:0] comp_center_x = (comp_left + comp_right) >> 1;
    wire [11:0] comp_center_y = (comp_top + comp_bottom) >> 1;
    wire [11:0] comp_dx = (comp_center_x >= IMG_WIDTH/2) ?
                    (comp_center_x - IMG_WIDTH/2) : (IMG_WIDTH/2 - comp_center_x);
    wire [11:0] comp_dy = (comp_center_y >= IMG_HEIGHT/2) ?
                    (comp_center_y - IMG_HEIGHT/2) : (IMG_HEIGHT/2 - comp_center_y);
    wire [12:0] comp_distance = {1'b0,comp_dx} + {1'b0,comp_dy};
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
    reg [25:0] proj_axis_q;
    reg [19:0] proj_pixels_q;
    reg [31:0] area_axis_q, area_diag_q, area_near_q, area_far_q;
    reg [31:0] pixels_scaled_q, min_area_q, max_area_q, pixels_metric_q;
    wire [31:0] min_pair_a = area_axis_q < area_diag_q ? area_axis_q : area_diag_q;
    wire [31:0] min_pair_b = area_near_q < area_far_q ? area_near_q : area_far_q;
    wire [31:0] max_pair_a = area_axis_q > area_diag_q ? area_axis_q : area_diag_q;
    wire [31:0] max_pair_b = area_near_q > area_far_q ? area_near_q : area_far_q;
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
    wire [35:0] metric_pixels = {4'd0,pixels_metric_q};
    wire [35:0] metric_min = {4'd0,min_area_q};
    wire [35:0] metric_max = {4'd0,max_area_q};
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
    reg [25:0] comp_area_q;
    reg [12:0] comp_distance_q;
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
    reg [11:0] best_left;
    reg [11:0] best_right;
    reg [11:0] best_top;
    reg [11:0] best_bottom;
    reg [25:0] best_area;
    reg [1:0]  best_shape;
    reg        best_matches;
    reg [12:0] best_distance;
    reg        candidate_valid;
    reg        candidate_ok;
    reg        candidate_matches;
    reg [11:0] candidate_left, candidate_right, candidate_top, candidate_bottom;
    reg [25:0] candidate_area;
    reg [12:0] candidate_distance;

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
            best_distance <= 13'h1fff;
            candidate_distance <= 13'h1fff;
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
            best_distance <= 13'h1fff;
            candidate_distance <= 13'h1fff;
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