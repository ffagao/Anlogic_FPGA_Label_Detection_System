module isp_top (
    input 			axi4s_video_aclk,
    input 			I_rst_n			,
    input I_color_lock,
    output wire O_color_locked,
    input [3:0]     I_algo_mode     ,
    input           I_black_enable  ,
    input 			I_tlast			,
    input 			I_tuser			,
    input [39:0] 	I_tdata			,
    input 			I_tvalid		,
    input [9:0] 	I_tdest			,
    input 			O_tready		,
    output [127:0] 	O_tdata			,
    output 			O_tlast			,
    output 			O_tuser			,
    output 			O_tvalid		,
    output 			I_tready        ,
    output wire [7:0] O_frame_luma   ,
    output wire      O_luma_toggle  ,
    output wire      O_black_valid  ,
    output wire [11:0] O_black_left ,
    output wire [11:0] O_black_right,
    output wire [11:0] O_black_top  ,
    output wire [11:0] O_black_bottom,
    output wire      O_black_toggle
    ,output wire [9:0] O_diag_in_line
    ,output wire [9:0] O_diag_spatial_line
    ,output wire [8:0] O_diag_pack_line
    ,output wire [17:0] O_diag_in_frame
    ,output wire [17:0] O_diag_spatial_frame
    ,output wire [17:0] O_diag_pack_frame
    ,output wire [2:0] O_diag_line_error
    ,output wire [2:0] O_diag_frame_error
);
 
wire         m_aixs_tvalid;  // 
  wire [127:0] m_aixs_tdata;  // 
  wire         m_aixs_tuser;  // 
  wire         m_aixs_tlast;  // 
  wire         m_aixs_tready;  // 
  
  wire [ 95:0] m_aixs_tdata_96;  // 


  wire         awb_O_tlast;  // 
  wire         awb_O_tuser;  // 
  wire [ 95:0] awb_O_tdata;  // 
  wire         awb_O_tvalid;  // 
  wire         awb_O_tready;  // 

  wire         normal_O_tuser_128;  //
  wire         normal_O_tvalid_128; //
  wire [127:0] normal_O_tdata_128;  //

  wire         edge_O_tuser_128;    //
  wire         edge_O_tvalid_128;   //
  wire [127:0] edge_O_tdata_128;    //

  wire         gray_O_tuser_128;    //
  wire         gray_O_tvalid_128;   //
  wire [127:0] gray_O_tdata_128;    //

  wire         binary_O_tuser_128;  //
  wire         binary_O_tvalid_128; //
  wire [127:0] binary_O_tdata_128;  //



    wire         edge_O_tlast;  //
    wire         edge_O_tuser;  //
    wire [ 95:0] edge_O_tdata;  //
    wire         edge_O_tvalid;  //
    wire         edge_O_tready;  //

    reg  [3:0]   algo_mode_active;
    wire         algo_mode_pending;
    wire         switch_to_edge;
    wire         switch_to_gray;
    wire         switch_to_binary;
    wire         switch_to_normal;
    wire         select_edge;
    wire         select_gray;
    wire         select_binary;
    wire         switch_to_histogram, select_histogram;
    wire [95:0]  histogram_rgb;
    wire         histogram_valid, histogram_user, histogram_last;
    wire [95:0]  histogram_chart_rgb;
    wire         histogram_chart_valid, histogram_chart_user, histogram_chart_last;
    wire         histogram_bin_valid, histogram_done;
    wire [7:0]   histogram_bin_index;
    wire [17:0]  histogram_bin_count, histogram_after_count;
    wire [127:0] histogram_data_128;
    wire         histogram_user_128, histogram_valid_128;

    // Spatial algorithms 7/8 and their dedicated diagnostics were removed.
    assign {O_diag_in_line,O_diag_spatial_line,O_diag_pack_line,
            O_diag_in_frame,O_diag_spatial_frame,O_diag_pack_frame,
            O_diag_line_error,O_diag_frame_error}=0;

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

    wire [23:0]  gray_pix0 = awb_O_tdata[95:72];
    wire [23:0]  gray_pix1 = awb_O_tdata[71:48];
    wire [23:0]  gray_pix2 = awb_O_tdata[47:24];
    wire [23:0]  gray_pix3 = awb_O_tdata[23:0];
    wire [7:0]   gray_y0 = {2'b0,gray_pix0[23:18]} +
                           {1'b0,gray_pix0[15:9]}  +
                           {2'b0,gray_pix0[7:2]};
    wire [7:0]   gray_y1 = {2'b0,gray_pix1[23:18]} +
                           {1'b0,gray_pix1[15:9]}  +
                           {2'b0,gray_pix1[7:2]};
    wire [7:0]   gray_y2 = {2'b0,gray_pix2[23:18]} +
                           {1'b0,gray_pix2[15:9]}  +
                           {2'b0,gray_pix2[7:2]};
    wire [7:0]   gray_y3 = {2'b0,gray_pix3[23:18]} +
                           {1'b0,gray_pix3[15:9]}  +
                           {2'b0,gray_pix3[7:2]};
    wire [95:0]  gray_O_tdata = {{3{gray_y0}}, {3{gray_y1}},
                                 {3{gray_y2}}, {3{gray_y3}}};
    wire [7:0]   binary_y0 = (gray_y0 >= 8'd128) ? 8'hff : 8'h00;
    wire [7:0]   binary_y1 = (gray_y1 >= 8'd128) ? 8'hff : 8'h00;
    wire [7:0]   binary_y2 = (gray_y2 >= 8'd128) ? 8'hff : 8'h00;
    wire [7:0]   binary_y3 = (gray_y3 >= 8'd128) ? 8'hff : 8'h00;
    wire [95:0]  binary_O_tdata = {{3{binary_y0}}, {3{binary_y1}},
                                   {3{binary_y2}}, {3{binary_y3}}};

    // Retired zoom detector: keep compatibility ports inactive.
    assign {O_black_valid,O_black_left,O_black_right,O_black_top,O_black_bottom,O_black_toggle}=0;

    assign awb_O_tready = edge_O_tready;
    assign edge_O_tready = O_tready;

    // Meter RAW10 before demosaic/AWB. This path observes the camera stream
    // directly and does not depend on regenerated downstream line markers.
    ae_raw_meter u_ae_raw_meter (
        .I_clk(axi4s_video_aclk), .I_rst_n(I_rst_n),
        .I_tuser(I_tuser), .I_tvalid(I_tvalid), .I_raw4(I_tdata),
        .O_luma(O_frame_luma), .O_toggle(O_luma_toggle)
    );

    reg edge_frame_red;
    // Algorithms 0..5: NORMAL, EDGE, GRAY, BINARY, HIST EQ, RED EDGE.
    // EDGE and RED EDGE share the detector, line RAM and 96-to-128 packer.
    // Commit a mode change only at the target stream's frame boundary.
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

  //assign m_aixs_tready = O_tready;
  //assign O_tdata  = m_aixs_tdata;
  //assign O_tlast  = m_aixs_tlast    ;
  //assign O_tuser  = m_aixs_tuser    ;
  //assign O_tvalid = m_aixs_tvalid   ;
 
 
demosaic #(
    .IMG_HEIGHT          (720 ), // 图像高度
    .IMG_WIDTH           (1280), // 图像宽度
    .data_complete_delay (50  ),
    .BAYER_MODE          ("BGGR")
)
u_demosaic
(
    .I_clk   			(axi4s_video_aclk)	,   // 时钟信号
    .I_rst_n 			(I_rst_n)	,   // 复位信号，低有效
    .axi4s_video_tdata 	(I_tdata)	,  // AXI4-Stream视频数据
    .axi4s_video_tdest 	(I_tdest)	,
    .axi4s_video_tlast 	(I_tlast)	,  // 行结束信号
    .axi4s_video_tvalid	(I_tvalid)	,  // 数据有效信号
    .axi4s_video_tuser 	(I_tuser)	,  // 帧开始信号
    .axi4s_video_tready	(I_tready)	,  // 从模块准备好接受数据
    .O_tlast  			(m_aixs_tlast)	,  // 输出行结束信号
    .O_tuser  			(m_aixs_tuser)	,  // 输出帧开始信号
    .O_tdata  			(m_aixs_tdata)	,  // 输出数据
    .O_tvalid 			(m_aixs_tvalid)	,  // 输出数据有效信号
    .O_tready   		(m_aixs_tready)	   // 输出数据准备好信号
);
 
data128_96 u_data128_96 (
    .I_tdata(m_aixs_tdata),
    .O_tdata(m_aixs_tdata_96)
);

awb #(
    .IMG_HEIGHT(720 ),
    .IMG_WIDTH (1280)
) u_awb (
    .I_lock(I_color_lock),.O_locked(O_color_locked),
    .I_clk   (axi4s_video_aclk),
    .I_rst_n (I_rst_n),
    .I_tlast (m_aixs_tlast),
    .I_tuser (m_aixs_tuser),
    .I_tdata (m_aixs_tdata_96),
    .I_tvalid(m_aixs_tvalid),
    .I_tready(m_aixs_tready),
    .O_tlast (awb_O_tlast ),
    .O_tuser (awb_O_tuser ),
    .O_tdata (awb_O_tdata ),
    .O_tvalid(awb_O_tvalid),
    .O_tready(awb_O_tready)
);

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

    data_96bit_to_128bit u_normal_data_96bit_to_128bit(
        .I_clk              ( axi4s_video_aclk    ),
        .I_rst_n            ( I_rst_n             ),

        .I_96b_frame_start  ( awb_O_tuser         ),
        .I_96b_valid        ( awb_O_tvalid        ),
        .I_96b_data         ( awb_O_tdata         ),

        .O_128b_frame_start ( normal_O_tuser_128  ),
        .O_128b_valid       ( normal_O_tvalid_128 ),
        .O_128b_data        ( normal_O_tdata_128  )
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

    data_96bit_to_128bit u_gray_data_96bit_to_128bit(
        .I_clk              ( axi4s_video_aclk  ),
        .I_rst_n            ( I_rst_n           ),

        .I_96b_frame_start  ( awb_O_tuser       ),
        .I_96b_valid        ( awb_O_tvalid      ),
        .I_96b_data         ( gray_O_tdata      ),

        .O_128b_frame_start ( gray_O_tuser_128  ),
        .O_128b_valid       ( gray_O_tvalid_128 ),
        .O_128b_data        ( gray_O_tdata_128  )
    );

    data_96bit_to_128bit u_binary_data_96bit_to_128bit(
        .I_clk              ( axi4s_video_aclk    ),
        .I_rst_n            ( I_rst_n             ),

        .I_96b_frame_start  ( awb_O_tuser         ),
        .I_96b_valid        ( awb_O_tvalid        ),
        .I_96b_data         ( binary_O_tdata      ),

        .O_128b_frame_start ( binary_O_tuser_128  ),
        .O_128b_valid       ( binary_O_tvalid_128 ),
        .O_128b_data        ( binary_O_tdata_128  )
    );





//data96_128 u_data96_128 (
//    .I_tdata(awb_O_tdata),
//    .O_tdata(awb_O_tdata_128)
//);
	
endmodule

// Four-pixel-per-clock rectangular-object detector.
//
// A blue-dominant mask is reduced to one horizontal span per 4-pixel word.
// This is a temporary validation of the complete 0011 processing path; the
// downstream signal names retain "black" to keep this change local.
// The strongest run on each row is joined to overlapping runs on subsequent
// rows.  Filled, near-horizontal rectangular regions pass size/aspect/fill
// tests; if several candidates are present, the one nearest (640,360) wins.
module black_rectangle_tracker4 #(
    parameter BLUE_MIN        = 8'd64,
    parameter BLUE_MARGIN     = 8'd24,
    parameter MIN_WIDTH       = 12'd56,
    parameter MIN_HEIGHT      = 12'd36,
    parameter MAX_RUN_GAP     = 3,
    parameter MAX_ROW_GAP     = 3,
    parameter MATCH_MARGIN    = 12'd24,
    parameter HOLD_FRAMES     = 3
)(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_enable,
    input  wire        I_tuser,
    input  wire        I_tlast,
    input  wire        I_tvalid,
    input  wire [95:0] I_rgb4,
    output reg         O_valid,
    output reg  [11:0] O_left,
    output reg  [11:0] O_right,
    output reg  [11:0] O_top,
    output reg  [11:0] O_bottom,
    output reg         O_update_toggle
);
    wire [23:0] pix0 = I_rgb4[95:72];
    wire [23:0] pix1 = I_rgb4[71:48];
    wire [23:0] pix2 = I_rgb4[47:24];
    wire [23:0] pix3 = I_rgb4[23:0];
    // RGB byte order is R[23:16], G[15:8], B[7:0].  Requiring both a minimum
    // blue level and a margin over R/G rejects dark grey and white regions.
    wire blue0 = (pix0[7:0] >= BLUE_MIN) &&
                 ({1'b0,pix0[7:0]} >= ({1'b0,pix0[23:16]} + BLUE_MARGIN)) &&
                 ({1'b0,pix0[7:0]} >= ({1'b0,pix0[15:8]}  + BLUE_MARGIN));
    wire blue1 = (pix1[7:0] >= BLUE_MIN) &&
                 ({1'b0,pix1[7:0]} >= ({1'b0,pix1[23:16]} + BLUE_MARGIN)) &&
                 ({1'b0,pix1[7:0]} >= ({1'b0,pix1[15:8]}  + BLUE_MARGIN));
    wire blue2 = (pix2[7:0] >= BLUE_MIN) &&
                 ({1'b0,pix2[7:0]} >= ({1'b0,pix2[23:16]} + BLUE_MARGIN)) &&
                 ({1'b0,pix2[7:0]} >= ({1'b0,pix2[15:8]}  + BLUE_MARGIN));
    wire blue3 = (pix3[7:0] >= BLUE_MIN) &&
                 ({1'b0,pix3[7:0]} >= ({1'b0,pix3[23:16]} + BLUE_MARGIN)) &&
                 ({1'b0,pix3[7:0]} >= ({1'b0,pix3[15:8]}  + BLUE_MARGIN));
    wire [3:0] black = {blue0, blue1, blue2, blue3};
    wire       any_black = |black;
    wire [2:0] black_count = {2'd0,black[3]} + {2'd0,black[2]} +
                             {2'd0,black[1]} + {2'd0,black[0]};
    wire [2:0] first_black = black[3] ? 3'd0 : black[2] ? 3'd1 :
                             black[1] ? 3'd2 : 3'd3;
    wire [2:0] last_black  = black[0] ? 3'd3 : black[1] ? 3'd2 :
                             black[2] ? 3'd1 : 3'd0;

    reg [11:0] word_x;
    reg [11:0] line_y;
    reg        run_active;
    reg [11:0] run_start;
    reg [11:0] run_last;
    reg [11:0] run_hits;
    reg [2:0]  run_gap;
    reg [11:0] row_best_left;
    reg [11:0] row_best_right;
    reg [11:0] row_best_hits;

    wire [11:0] group_left  = word_x + first_black;
    wire [11:0] group_right = word_x + last_black;
    wire        eol_run_valid = run_active || any_black;
    wire [11:0] eol_run_left = run_active ? run_start : group_left;
    wire [11:0] eol_run_right = any_black ? group_right : run_last;
    wire [11:0] eol_run_hits = run_hits + black_count;
    wire        eol_use_run = eol_run_valid && (eol_run_hits > row_best_hits);
    wire [11:0] line_left = eol_use_run ? eol_run_left : row_best_left;
    wire [11:0] line_right = eol_use_run ? eol_run_right : row_best_right;
    wire [11:0] line_hits = eol_use_run ? eol_run_hits : row_best_hits;
    wire        line_valid = (line_hits >= (MIN_WIDTH >> 1));

    reg        comp_active;
    reg [11:0] comp_left;
    reg [11:0] comp_right;
    reg [11:0] comp_top;
    reg [11:0] comp_bottom;
    reg [19:0] comp_pixels;
    reg [2:0]  comp_row_gap;
    wire [12:0] comp_width = {1'b0,comp_right} - {1'b0,comp_left} + 13'd1;
    wire [12:0] comp_height = {1'b0,comp_bottom} - {1'b0,comp_top} + 13'd1;
    wire [25:0] comp_area = comp_width * comp_height;
    wire [11:0] comp_cx = (comp_left + comp_right) >> 1;
    wire [11:0] comp_cy = (comp_top + comp_bottom) >> 1;
    wire [11:0] comp_dx = (comp_cx >= 12'd640) ?
                          (comp_cx - 12'd640) : (12'd640 - comp_cx);
    wire [11:0] comp_dy = (comp_cy >= 12'd360) ?
                          (comp_cy - 12'd360) : (12'd360 - comp_cy);
    wire [12:0] comp_dist = {1'b0,comp_dx} + {1'b0,comp_dy};
    wire comp_geometry_valid = comp_active &&
             (comp_width >= MIN_WIDTH) && (comp_height >= MIN_HEIGHT) &&
             (comp_width <= 13'd900) && (comp_height <= 13'd600) &&
             ({3'd0,comp_width} <= {comp_height,3'b000}) &&
             ({3'd0,comp_height} <= {comp_width,3'b000}) &&
             // Allow highlights/noise inside an otherwise dark solid target.
             ({6'd0,comp_pixels} >= (comp_area >> 2));
    wire line_matches = comp_active && line_valid &&
             (({1'b0,line_right} + {1'b0,MATCH_MARGIN}) >= {1'b0,comp_left}) &&
             ({1'b0,line_left} <= ({1'b0,comp_right} + {1'b0,MATCH_MARGIN}));

    reg        best_valid;
    reg [11:0] best_left;
    reg [11:0] best_right;
    reg [11:0] best_top;
    reg [11:0] best_bottom;
    reg [12:0] best_dist;
    reg [25:0] best_area;
    wire use_current = comp_geometry_valid && (!best_valid ||
                       (comp_dist < best_dist) ||
                       ((comp_dist == best_dist) && (comp_area > best_area)));
    wire frame_valid = use_current || best_valid;
    wire [11:0] frame_left = use_current ? comp_left : best_left;
    wire [11:0] frame_right = use_current ? comp_right : best_right;
    wire [11:0] frame_top = use_current ? comp_top : best_top;
    wire [11:0] frame_bottom = use_current ? comp_bottom : best_bottom;
    reg [2:0] miss_frames;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            word_x <= 12'd0; line_y <= 12'd0;
            run_active <= 1'b0; run_start <= 12'd0; run_last <= 12'd0;
            run_hits <= 12'd0; run_gap <= 3'd0;
            row_best_left <= 12'd0; row_best_right <= 12'd0;
            row_best_hits <= 12'd0;
            comp_active <= 1'b0; comp_left <= 12'd0; comp_right <= 12'd0;
            comp_top <= 12'd0; comp_bottom <= 12'd0;
            comp_pixels <= 20'd0; comp_row_gap <= 3'd0;
            best_valid <= 1'b0; best_left <= 12'd0; best_right <= 12'd0;
            best_top <= 12'd0; best_bottom <= 12'd0;
            best_dist <= 13'h1fff; best_area <= 26'd0;
            miss_frames <= 3'd0;
            O_valid <= 1'b0; O_left <= 12'd0; O_right <= 12'd0;
            O_top <= 12'd0; O_bottom <= 12'd0;
            O_update_toggle <= 1'b0;
        end
        else if(!I_enable) begin
            word_x <= 12'd0; line_y <= 12'd0;
            run_active <= 1'b0; run_hits <= 12'd0; run_gap <= 3'd0;
            row_best_hits <= 12'd0; comp_active <= 1'b0;
            comp_pixels <= 20'd0; comp_row_gap <= 3'd0;
            best_valid <= 1'b0; best_dist <= 13'h1fff; best_area <= 26'd0;
            miss_frames <= 3'd0; O_valid <= 1'b0;
        end
        else if(I_tvalid) begin
            if(I_tuser) begin
                // Publish the preceding frame.  Coordinates remain stable
                // until the next toggle, allowing safe clock-domain capture.
                if(frame_valid) begin
                    O_valid <= 1'b1;
                    O_left <= frame_left; O_right <= frame_right;
                    O_top <= frame_top; O_bottom <= frame_bottom;
                    miss_frames <= 3'd0;
                end
                else if(O_valid) begin
                    if(miss_frames == HOLD_FRAMES - 1) begin
                        O_valid <= 1'b0;
                        miss_frames <= 3'd0;
                    end
                    else
                        miss_frames <= miss_frames + 3'd1;
                end
                O_update_toggle <= ~O_update_toggle;
                word_x <= 12'd4; line_y <= 12'd0;
                run_active <= 1'b0; run_hits <= 12'd0; run_gap <= 3'd0;
                row_best_hits <= 12'd0; comp_active <= 1'b0;
                comp_pixels <= 20'd0; comp_row_gap <= 3'd0;
                best_valid <= 1'b0; best_dist <= 13'h1fff; best_area <= 26'd0;
            end
            else begin
                if(I_tlast) begin
                    if(line_valid) begin
                        if(!comp_active) begin
                            comp_active <= 1'b1; comp_left <= line_left;
                            comp_right <= line_right; comp_top <= line_y;
                            comp_bottom <= line_y; comp_pixels <= line_hits;
                            comp_row_gap <= 3'd0;
                        end
                        else if(line_matches) begin
                            if(line_left < comp_left) comp_left <= line_left;
                            if(line_right > comp_right) comp_right <= line_right;
                            comp_bottom <= line_y;
                            comp_pixels <= comp_pixels + line_hits;
                            comp_row_gap <= 3'd0;
                        end
                        else begin
                            if(comp_geometry_valid && (!best_valid ||
                               (comp_dist < best_dist) ||
                               ((comp_dist == best_dist) && (comp_area > best_area)))) begin
                                best_valid <= 1'b1; best_left <= comp_left;
                                best_right <= comp_right; best_top <= comp_top;
                                best_bottom <= comp_bottom; best_dist <= comp_dist;
                                best_area <= comp_area;
                            end
                            comp_active <= 1'b1; comp_left <= line_left;
                            comp_right <= line_right; comp_top <= line_y;
                            comp_bottom <= line_y; comp_pixels <= line_hits;
                            comp_row_gap <= 3'd0;
                        end
                    end
                    else if(comp_active) begin
                        if(comp_row_gap == MAX_ROW_GAP - 1) begin
                            if(comp_geometry_valid && (!best_valid ||
                               (comp_dist < best_dist) ||
                               ((comp_dist == best_dist) && (comp_area > best_area)))) begin
                                best_valid <= 1'b1; best_left <= comp_left;
                                best_right <= comp_right; best_top <= comp_top;
                                best_bottom <= comp_bottom; best_dist <= comp_dist;
                                best_area <= comp_area;
                            end
                            comp_active <= 1'b0; comp_pixels <= 20'd0;
                            comp_row_gap <= 3'd0;
                        end
                        else comp_row_gap <= comp_row_gap + 3'd1;
                    end
                    word_x <= 12'd0; line_y <= line_y + 12'd1;
                    run_active <= 1'b0; run_hits <= 12'd0; run_gap <= 3'd0;
                    row_best_hits <= 12'd0;
                end
                else begin
                    word_x <= word_x + 12'd4;
                    if(any_black) begin
                        if(!run_active) begin
                            run_active <= 1'b1; run_start <= group_left;
                            run_last <= group_right; run_hits <= black_count;
                            run_gap <= 3'd0;
                        end
                        else begin
                            run_last <= group_right;
                            run_hits <= run_hits + black_count;
                            run_gap <= 3'd0;
                        end
                    end
                    else if(run_active) begin
                        if(run_gap < MAX_RUN_GAP) run_gap <= run_gap + 3'd1;
                        else begin
                            if(run_hits > row_best_hits) begin
                                row_best_left <= run_start; row_best_right <= run_last;
                                row_best_hits <= run_hits;
                            end
                            run_active <= 1'b0; run_hits <= 12'd0; run_gap <= 3'd0;
                        end
                    end
                end
            end
        end
    end
endmodule

// 1280x720, four RAW10 samples per word. The central 1024x512 Bayer
// region averages R + 2G + B, before white-balance gains and ISP effects.
// Frame-start may precede the first valid word. Bubbles do not end a row.
module ae_raw_meter (
    input wire I_clk, I_rst_n, I_tuser, I_tvalid,
    input wire [39:0] I_raw4,
    output reg [7:0] O_luma,
    output reg O_toggle
);
    reg [8:0] word_x;
    reg [9:0] line_y;
    reg frame_active;
    reg sample_en, sample_last;
    reg [9:0] word_sum;
    reg [26:0] luma_sum;
    wire [9:0] raw_sum = {2'd0,I_raw4[9:2]} + {2'd0,I_raw4[19:12]} +
                         {2'd0,I_raw4[29:22]} + {2'd0,I_raw4[39:32]};
    wire [26:0] rounded_sum = luma_sum + word_sum + 27'd262144;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            word_x<=0; line_y<=0; frame_active<=0;
            sample_en<=0; sample_last<=0; word_sum<=0;
            luma_sum<=0; O_luma<=0; O_toggle<=0;
        end else begin
            sample_en<=0; sample_last<=0;
            if(I_tuser) begin
                word_x<=I_tvalid ? 9'd1 : 9'd0;
                line_y<=0; frame_active<=1;
                luma_sum<=0;
            end else begin
                if(I_tvalid && frame_active) begin
                    sample_en <= (word_x>=32 && word_x<=287 &&
                                  line_y>=104 && line_y<=615);
                    sample_last <= (word_x==287 && line_y==615);
                    word_sum <= raw_sum;
                    if(word_x==319) begin
                        word_x<=0;
                        if(line_y==719) frame_active<=0;
                        else line_y<=line_y+1'b1;
                    end else word_x<=word_x+1'b1;
                end
                if(sample_en) begin
                    luma_sum<=luma_sum+word_sum;
                    if(sample_last) begin
                        O_luma<=rounded_sum[26:19];
                        O_toggle<=~O_toggle;
                    end
                end
            end
        end
    end
endmodule


// Global luminance histogram equalizer, four RGB pixels per clock.
// One rotating pixel from every fourth word (1/16 of pixels) supplies a
// 256-bin histogram. Spacing samples avoids RAM read/modify/write hazards.
// Ping-pong histograms and LUTs keep collection, construction and display
// independent. A completed LUT is committed only on a video frame boundary.
module histogram_equalizer4 #(
    parameter integer WORDS_PER_FRAME = 1280*720/4
)(
    input wire I_clk, I_rst_n, I_enable,
    input wire I_valid, I_user, I_last,
    input wire [95:0] I_rgb,
    output reg O_valid, O_user, O_last,
    output reg [95:0] O_rgb,
    output wire O_bin_valid,
    output wire [7:0] O_bin_index,
    output wire [17:0] O_bin_count,
    output wire O_hist_done,
    output wire [17:0] O_after_count
);
    function [7:0] luma;
        input [23:0] rgb;
        reg [9:0] sum;
        begin
            sum = {2'b0,rgb[23:16]} + {1'b0,rgb[15:8],1'b0} + {2'b0,rgb[7:0]};
            luma = sum[9:2];
        end
    endfunction
    function [7:0] adjust;
        input [7:0] channel;
        input signed [8:0] difference;
        reg signed [9:0] value;
        begin
            value = $signed({2'b0,channel}) + $signed({difference[8],difference});
            adjust = value < 0 ? 8'd0 : value > 255 ? 8'd255 : value[7:0];
        end
    endfunction
    function [23:0] recolour;
        input [23:0] rgb;
        input [7:0] y, mapped;
        reg signed [8:0] difference;
        begin
            difference = $signed({1'b0,mapped})-$signed({1'b0,y});
            recolour = {adjust(rgb[23:16],difference),adjust(rgb[15:8],difference),adjust(rgb[7:0],difference)};
        end
    endfunction
    wire [7:0] y0=luma(I_rgb[95:72]), y1=luma(I_rgb[71:48]);
    wire [7:0] y2=luma(I_rgb[47:24]), y3=luma(I_rgb[23:0]);
    localparam INIT=0, IDLE=1, DRAIN0=2, DRAIN1=3, FIND_READ=4,
               FIND_LOAD=5, READ_BIN=6, LOAD_BIN=7, PREPARE=8, DIVIDE=9, WRITE_MAP=10,
               WAIT_COMMIT=11;
    reg [3:0] state;
    reg [8:0] boot_index;
    wire initialized = state != INIT;
    reg frame_open, capture_bank, job_bank, active_bank, active_valid, lut_pending;
    reg [17:0] word_index, sample_count, job_total;
    reg [7:0] bin_index;
    reg [17:0] cdf, cdf_min, denominator;
    reg [25:0] div_shift;
    reg [18:0] div_remainder;
    reg [4:0] div_steps;
    reg [7:0] map_value;
    wire sof = I_valid && I_user;
    wire eof = I_valid && !I_user && frame_open && word_index == WORDS_PER_FRAME-1;
    wire sample_now = I_enable && initialized && I_valid &&
                      (I_user || (frame_open && word_index[1:0]==2'd0));
    wire [1:0] sample_lane = I_user ? 2'd0 : word_index[3:2];
    wire [7:0] sample_bin = sample_lane==0 ? y0 : sample_lane==1 ? y1 : sample_lane==2 ? y2 : y3;
    reg sample_pending, sample_bank_q;
    reg [7:0] sample_bin_q;

    (* ram_style = "block" *) reg [17:0] hist0[0:255];
    (* ram_style = "block" *) reg [17:0] hist1[0:255];
    reg [17:0] hist0_q, hist1_q;
    reg [7:0] h0_read, h1_read, h0_addr, h1_addr;
    reg h0_we, h1_we;
    reg [17:0] h0_data, h1_data;
    wire [17:0] bin_count = job_bank ? hist1_q : hist0_q;
    assign O_bin_valid = I_enable && state==LOAD_BIN;
    assign O_bin_index = bin_index;
    assign O_bin_count = bin_count;
    reg [17:0] after_hist0[0:63],after_hist1[0:63];
    reg [17:0] after0_q,after1_q;
    reg [5:0] a0_read,a1_read,a0_addr,a1_addr;
    reg a0_we,a1_we;
    reg [17:0] a0_data,a1_data;
    reg sample_tag0,sample_tag1,bank_tag0,bank_tag1;
    reg [1:0] lane_tag0,lane_tag1;
    reg after_pending,after_bank_q;
    reg [5:0] after_bin_q;
    wire [23:0] after_pixel=lane_tag1==0 ? O_rgb[95:72] :
                              lane_tag1==1 ? O_rgb[71:48] :
                              lane_tag1==2 ? O_rgb[47:24] : O_rgb[23:0];
    wire [7:0] after_y=luma(after_pixel);
    assign O_after_count=job_bank ? after1_q : after0_q;
    always @* begin
        a0_read=bin_index[7:2];a1_read=bin_index[7:2];
        a0_addr=bin_index[7:2];a1_addr=bin_index[7:2];
        a0_we=0;a1_we=0;a0_data=0;a1_data=0;
        if(state==INIT) begin
            a0_addr=boot_index[5:0];a1_addr=boot_index[5:0];
            a0_we=I_enable;a1_we=I_enable;
        end
        else begin
            if(sample_tag1) begin
                if(bank_tag1) a1_read=after_y[7:2];else a0_read=after_y[7:2];
            end
            if(after_pending) begin
                if(after_bank_q) begin a1_we=1;a1_addr=after_bin_q;a1_data=after1_q+18'd1;end
                else begin a0_we=1;a0_addr=after_bin_q;a0_data=after0_q+18'd1;end
            end
            if(state==LOAD_BIN && bin_index[1:0]==3) begin
                if(job_bank) begin a1_we=1;a1_addr=bin_index[7:2];a1_data=0;end
                else begin a0_we=1;a0_addr=bin_index[7:2];a0_data=0;end
            end
        end
    end
    always @(posedge I_clk) begin
        after0_q<=after_hist0[a0_read];after1_q<=after_hist1[a1_read];
        if(a0_we) after_hist0[a0_addr]<=a0_data;
        if(a1_we) after_hist1[a1_addr]<=a1_data;
    end
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            sample_tag0<=0;sample_tag1<=0;bank_tag0<=0;bank_tag1<=0;
            lane_tag0<=0;lane_tag1<=0;after_pending<=0;after_bank_q<=0;after_bin_q<=0;
        end
        else if(!I_enable) begin sample_tag0<=0;sample_tag1<=0;after_pending<=0;end
        else begin
            sample_tag0<=sample_now;sample_tag1<=sample_tag0;
            bank_tag0<=capture_bank;bank_tag1<=bank_tag0;
            lane_tag0<=sample_lane;lane_tag1<=lane_tag0;
            after_pending<=sample_tag1;after_bank_q<=bank_tag1;after_bin_q<=after_y[7:2];
        end
    end
    assign O_hist_done = I_enable && state==WRITE_MAP && bin_index==8'd255;
    always @* begin
        h0_read=bin_index; h1_read=bin_index;
        h0_we=0; h1_we=0; h0_addr=bin_index; h1_addr=bin_index;
        h0_data=0; h1_data=0;
        if(state==INIT) begin
            h0_we=I_enable; h1_we=I_enable; h0_addr=boot_index[7:0]; h1_addr=boot_index[7:0];
        end
        else begin
            if(sample_now) begin
                if(capture_bank) h1_read=sample_bin;
                else h0_read=sample_bin;
            end
            if(sample_pending) begin
                if(sample_bank_q) begin h1_we=1; h1_addr=sample_bin_q; h1_data=hist1_q+18'd1; end
                else begin h0_we=1; h0_addr=sample_bin_q; h0_data=hist0_q+18'd1; end
            end
            if(state==LOAD_BIN) begin
                if(job_bank) begin h1_we=1; h1_addr=bin_index; h1_data=0; end
                else begin h0_we=1; h0_addr=bin_index; h0_data=0; end
            end
        end
    end
    always @(posedge I_clk) begin
        hist0_q<=hist0[h0_read]; hist1_q<=hist1[h1_read];
        if(h0_we) hist0[h0_addr]<=h0_data;
        if(h1_we) hist1[h1_addr]<=h1_data;
    end

    // Four independent synchronous lookup ports infer RAM instead of a large
    // combinational 4x256 multiplexer on the pixel timing path.
    (* ram_style = "block" *) reg [7:0] map0[0:511];
    (* ram_style = "block" *) reg [7:0] map1[0:511];
    (* ram_style = "block" *) reg [7:0] map2[0:511];
    (* ram_style = "block" *) reg [7:0] map3[0:511];
    reg [7:0] q0,q1,q2,q3;
    wire pixel_bank = sof && lut_pending ? !active_bank : active_bank;
    wire map_we = I_enable && (state==INIT || state==WRITE_MAP);
    wire [8:0] map_addr = state==INIT ? boot_index : {!active_bank,bin_index};
    // 75% equalization and 25% identity moderate noise/contrast amplification.
    wire [9:0] mixed_map = ({2'b0,map_value} << 1) + {2'b0,map_value} + {2'b0,bin_index};
    wire [7:0] map_data = state==INIT ? boot_index[7:0] : mixed_map[9:2];
    always @(posedge I_clk) begin
        if(I_valid) begin
            q0<=map0[{pixel_bank,y0}]; q1<=map1[{pixel_bank,y1}];
            q2<=map2[{pixel_bank,y2}]; q3<=map3[{pixel_bank,y3}];
        end
        if(map_we) begin
            map0[map_addr]<=map_data; map1[map_addr]<=map_data;
            map2[map_addr]<=map_data; map3[map_addr]<=map_data;
        end
    end
    reg [95:0] rgb_q;
    reg [31:0] y_q;
    reg valid_q,user_q,last_q,apply_q;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            rgb_q<=0; y_q<=0; valid_q<=0; user_q<=0; last_q<=0; apply_q<=0;
            O_valid<=0; O_user<=0; O_last<=0; O_rgb<=0;
        end
        else begin
            rgb_q<=I_rgb; y_q<={y0,y1,y2,y3};
            valid_q<=I_valid; user_q<=I_user && I_valid; last_q<=I_last && I_valid;
            apply_q<=I_enable && initialized && (active_valid || (sof && lut_pending));
            O_valid<=valid_q; O_user<=user_q; O_last<=last_q;
            O_rgb<=apply_q ? {recolour(rgb_q[95:72],y_q[31:24],q0),
                              recolour(rgb_q[71:48],y_q[23:16],q1),
                              recolour(rgb_q[47:24],y_q[15:8],q2),
                              recolour(rgb_q[23:0],y_q[7:0],q3)} : rgb_q;
        end
    end

    wire [17:0] cdf_delta = cdf-cdf_min;
    wire [25:0] numerator = {cdf_delta,8'b0}-{8'b0,cdf_delta};
    wire [18:0] trial = {div_remainder[17:0],div_shift[25]};
    wire subtract = trial >= {1'b0,denominator};
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            state<=INIT; boot_index<=0; frame_open<=0; capture_bank<=0; job_bank<=0;
            active_bank<=0; active_valid<=0; lut_pending<=0;
            word_index<=0; sample_count<=0; job_total<=0; bin_index<=0;
            cdf<=0; cdf_min<=0; denominator<=0; div_shift<=0; div_remainder<=0;
            div_steps<=0; map_value<=0; sample_pending<=0; sample_bank_q<=0; sample_bin_q<=0;
        end
        else if(!I_enable) begin
            state<=INIT; boot_index<=0; frame_open<=0; capture_bank<=0;
            active_bank<=0; active_valid<=0; lut_pending<=0; sample_pending<=0;
            word_index<=0; sample_count<=0;
        end
        else begin
            sample_pending<=sample_now;
            if(sample_now) begin sample_bank_q<=capture_bank; sample_bin_q<=sample_bin; end
            if(sof && initialized) begin
                frame_open<=1; word_index<=1; sample_count<=1;
                if(lut_pending) begin active_bank<=!active_bank; active_valid<=1; lut_pending<=0; end
            end
            else if(I_valid && frame_open) begin
                word_index<=word_index+18'd1;
                if(sample_now) sample_count<=sample_count+18'd1;
                if(eof) frame_open<=0;
            end
            case(state)
                INIT: begin
                    if(boot_index==9'd511) begin state<=IDLE; boot_index<=0; end
                    else boot_index<=boot_index+9'd1;
                end
                IDLE: if(eof) begin
                    job_bank<=capture_bank; capture_bank<=!capture_bank;
                    job_total<=sample_count+sample_now;
                    bin_index<=0; cdf<=0; cdf_min<=0; denominator<=0;
                    state<=DRAIN0;
                end
                DRAIN0: state<=DRAIN1;
                // A ready table owns the shadow bank until it is committed.
                // Short vertical blanking must not let the next job overwrite it.
                DRAIN1: state<=lut_pending ? WAIT_COMMIT : FIND_READ;
                WAIT_COMMIT: if(!lut_pending) state<=FIND_READ;
                FIND_READ: state<=FIND_LOAD;
                FIND_LOAD: begin
                    if(bin_count!=0 || bin_index==8'd255) begin
                        cdf_min<=bin_count; denominator<=job_total-bin_count;
                        bin_index<=0; state<=READ_BIN;
                    end
                    else begin bin_index<=bin_index+8'd1; state<=FIND_READ; end
                end
                READ_BIN: state<=LOAD_BIN;
                LOAD_BIN: begin cdf<=cdf+bin_count; state<=PREPARE; end
                PREPARE: begin
                    if(denominator==0 || job_total==0) begin map_value<=bin_index; state<=WRITE_MAP; end
                    else if(cdf<=cdf_min) begin map_value<=0; state<=WRITE_MAP; end
                    else if(cdf_delta>=denominator) begin map_value<=255; state<=WRITE_MAP; end
                    else begin
                        div_shift<=numerator; div_remainder<=0; div_steps<=26; state<=DIVIDE;
                    end
                end
                DIVIDE: begin
                    div_remainder<=subtract ? trial-{1'b0,denominator} : trial;
                    div_shift<={div_shift[24:0],subtract};
                    div_steps<=div_steps-5'd1;
                    if(div_steps==1) begin map_value<={div_shift[6:0],subtract}; state<=WRITE_MAP; end
                end
                WRITE_MAP: begin
                    if(bin_index==8'd255) begin lut_pending<=1; state<=IDLE; end
                    else begin bin_index<=bin_index+8'd1; state<=READ_BIN; end
                end
                default: state<=INIT;
            endcase
        end
    end
endmodule


// Input-luminance distribution, reusing the equalizer's completed histogram.
// 64 four-level bins; peak-normalized heights are built off the pixel path.
module live_histogram_overlay4 #(
    parameter integer IMAGE_WIDTH=1280,
    parameter integer PLOT_X=720,
    parameter integer PLOT_TOP=584,
    parameter integer PLOT_BOTTOM=680
)(
    input wire I_clk,I_rst_n,I_enable,
    input wire I_valid,I_user,I_last,
    input wire [95:0] I_rgb,
    input wire I_bin_valid,
    input wire [7:0] I_bin_index,
    input wire [17:0] I_bin_count,
    input wire I_hist_done,
    input wire [17:0] I_after_count,
    output reg O_valid,O_user,O_last,
    output reg [95:0] O_rgb
);
    localparam IDLE=0,READ_COUNT=1,LOAD_COUNT=2,DIVIDE=3,WRITE_HEIGHT=4;
    reg [2:0] state;
    reg collecting,active_bank,active_valid,pending;
    reg [17:0] group_sum,peak;
    wire [17:0] grouped = group_sum + I_bin_count;
    reg [6:0] build_index;
    reg [17:0] counts[0:63],after_counts[0:63];
    reg [17:0] before_q,after_q;
    wire [17:0] count_q=build_index[6] ? after_q : before_q;
    reg [6:0] heights[0:255];
    reg [6:0] height_q;
    reg [24:0] dividend;
    reg [18:0] remainder;
    reg [4:0] steps;
    wire [18:0] trial={remainder[17:0],dividend[24]};
    wire subtract=trial>={1'b0,peak};
    wire sof=I_valid && I_user;
    wire read_bank=sof && pending ? !active_bank : active_bank;
    reg [10:0] next_x,next_y;
    wire [10:0] pixel_x=I_user ? 11'd0 : next_x;
    wire [10:0] pixel_y=I_user ? 11'd0 : next_y;
    wire chart_after=pixel_x>=PLOT_X+276;
    wire [10:0] chart_x=chart_after ? pixel_x-11'd288 : pixel_x;
    wire [10:0] relative_x=chart_x-PLOT_X;
    always @(posedge I_clk) begin
        before_q<=counts[build_index[5:0]];after_q<=after_counts[build_index[5:0]];
        height_q<=heights[{read_bank,chart_after,relative_x[7:2]}];
        if(I_enable && I_bin_valid && collecting && I_bin_index[1:0]==3)
            begin counts[I_bin_index[7:2]]<=grouped;after_counts[I_bin_index[7:2]]<=I_after_count;end
        if(I_enable && state==WRITE_HEIGHT)
            heights[{!active_bank,build_index}]<=dividend[6:0];
    end
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            state<=IDLE; collecting<=0; active_bank<=0; active_valid<=0; pending<=0;
            group_sum<=0;peak<=0;build_index<=0;dividend<=0;remainder<=0;steps<=0;
        end
        else if(!I_enable) begin
            state<=IDLE;collecting<=0;active_bank<=0;active_valid<=0;pending<=0;
            group_sum<=0;peak<=0;
        end
        else begin
            if(sof && pending) begin active_bank<=!active_bank;active_valid<=1;pending<=0;end
            if(I_bin_valid) begin
                if(I_bin_index==0) begin
                    collecting<=state==IDLE && !pending;
                    if(state==IDLE && !pending) begin group_sum<=I_bin_count;peak<=0;end
                end
                else if(collecting) begin
                    if(I_bin_index[1:0]==3) begin
                        group_sum<=0;
                        if(grouped>peak || I_after_count>peak) peak<=grouped>I_after_count ? grouped : I_after_count;
                    end
                    else group_sum<=grouped;
                end
            end
            case(state)
                IDLE: if(I_hist_done && collecting) begin
                    collecting<=0;build_index<=0;state<=READ_COUNT;
                end
                READ_COUNT: state<=LOAD_COUNT;
                LOAD_COUNT: begin
                    // 96*count = 64*count + 32*count, using shifts only.
                    dividend<=({7'b0,count_q}<<6)+({7'b0,count_q}<<5);
                    remainder<=0;steps<=25;
                    state<=peak==0 ? WRITE_HEIGHT : DIVIDE;
                    if(peak==0) dividend<=0;
                end
                DIVIDE: begin
                    remainder<=subtract ? trial-{1'b0,peak} : trial;
                    dividend<={dividend[23:0],subtract};steps<=steps-5'd1;
                    if(steps==1) state<=WRITE_HEIGHT;
                end
                WRITE_HEIGHT: begin
                    if(build_index==127) begin pending<=1;state<=IDLE;end
                    else begin build_index<=build_index+7'd1;state<=READ_COUNT;end
                end
                default: state<=IDLE;
            endcase
        end
    end
    // Tiny 5x7 label font; bit 34 is the upper-left pixel.
    function [34:0] glyph;
        input [7:0] c;
        begin
            case(c)
                "I": glyph=35'b11111_00100_00100_00100_00100_00100_11111;
                "N": glyph=35'b10001_11001_11001_10101_10011_10011_10001;
                "P": glyph=35'b11110_10001_10001_11110_10000_10000_10000;
                "U": glyph=35'b10001_10001_10001_10001_10001_10001_01110;
                "T": glyph=35'b11111_00100_00100_00100_00100_00100_00100;
                "Y": glyph=35'b10001_10001_01010_00100_00100_00100_00100;
                "0": glyph=35'b01110_10001_10011_10101_11001_10001_01110;
                "2": glyph=35'b01110_10001_00001_00010_00100_01000_11111;
                "5": glyph=35'b11111_10000_10000_11110_00001_00001_11110;
                "A": glyph=35'b01110_10001_10001_11111_10001_10001_10001;
                "B": glyph=35'b11110_10001_10001_11110_10001_10001_11110;
                "E": glyph=35'b11111_10000_10000_11110_10000_10000_11111;
                "F": glyph=35'b11111_10000_10000_11110_10000_10000_10000;
                "O": glyph=35'b01110_10001_10001_10001_10001_10001_01110;
                "R": glyph=35'b11110_10001_10001_11110_10100_10010_10001;
                default: glyph=0;
            endcase
        end
    endfunction
    function title_pixel;
        input [10:0] x,y;
        input after_view;
        reg [7:0] c;
        reg [34:0] bits;
        reg [10:0] relative;
        reg [2:0] column,row;
        begin
            title_pixel=0;c=" ";column=0;row=0;relative=0;
            // Text at 2x scale: INPUT Y, then 0 and 255 below the axis.
            if(x>=PLOT_X && x<PLOT_X+112 && y>=PLOT_TOP-24 && y<PLOT_TOP-10) begin
                relative=x-PLOT_X;column=relative[3:1];row=(y-(PLOT_TOP-24))>>1;
                case(relative[6:4])
                    0:c=after_view ? "A" : "B";1:c=after_view ? "F" : "E";
                    2:c=after_view ? "T" : "F";3:c=after_view ? "E" : "O";
                    4:c="R";5:c=after_view ? " " : "E";
                    default:c=" ";
                endcase
                bits=glyph(c);
                if(column<5) title_pixel=bits[34-row*5-column];
            end
            else if(y>=PLOT_BOTTOM+8 && y<PLOT_BOTTOM+22) begin
                row=(y-(PLOT_BOTTOM+8))>>1;
                if(x>=PLOT_X && x<PLOT_X+10) begin
                    column=(x-PLOT_X)>>1;bits=glyph("0");
                    title_pixel=bits[34-row*5-column];
                end
                else if(x>=PLOT_X+208 && x<PLOT_X+256) begin
                    relative=x-(PLOT_X+208);column=relative[3:1];
                    c=relative[5:4]==0 ? "2" : "5";bits=glyph(c);
                    if(column<5) title_pixel=bits[34-row*5-column];
                end
            end
        end
    endfunction
    function [23:0] paint;
        input [23:0] rgb;
        input [10:0] x,y;
        input [6:0] height;
        input enabled,ready,after_view;
        begin
            paint=rgb;
            if(enabled && x>=PLOT_X-12 && x<PLOT_X+268 &&
               y>=PLOT_TOP-32 && y<PLOT_BOTTOM+24) begin
                // Dark translucent panel retains some underlying detail.
                paint={2'b0,rgb[23:18],2'b0,rgb[15:10],2'b0,rgb[7:2]};
                if(title_pixel(x,y,after_view)) paint=24'hffffff;
                else if((y==PLOT_BOTTOM && x>=PLOT_X-1 && x<PLOT_X+256) ||
                        (x==PLOT_X-1 && y>=PLOT_TOP && y<=PLOT_BOTTOM)) paint=24'hc0c0c0;
                else if(x>=PLOT_X && x<PLOT_X+256 && y>=PLOT_TOP && y<PLOT_BOTTOM) begin
                    if(ready && height!=0 && y>=PLOT_BOTTOM-height) paint=after_view ? 24'hffb040 : 24'h00e8ff;
                    else if(y==PLOT_TOP || y==PLOT_TOP+24 || y==PLOT_TOP+48 || y==PLOT_TOP+72)
                        paint=24'h384048;
                end
            end
        end
    endfunction
    reg [95:0] rgb_q;
    reg [10:0] x_q,y_q;
    reg valid_q,user_q,last_q,enable_q,ready_q,after_view_q;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            next_x<=0;next_y<=0;rgb_q<=0;x_q<=0;y_q<=0;
            valid_q<=0;user_q<=0;last_q<=0;enable_q<=0;ready_q<=0;after_view_q<=0;
            O_valid<=0;O_user<=0;O_last<=0;O_rgb<=0;
        end
        else begin
            if(I_valid) begin
                if(pixel_x==IMAGE_WIDTH-4) begin next_x<=0;next_y<=pixel_y+11'd1;end
                else begin next_x<=pixel_x+11'd4;next_y<=pixel_y;end
            end
            rgb_q<=I_rgb;x_q<=chart_x;y_q<=pixel_y;after_view_q<=chart_after;
            valid_q<=I_valid;user_q<=I_valid && I_user;last_q<=I_valid && I_last;
            enable_q<=I_enable;ready_q<=active_valid || (sof && pending);
            O_valid<=valid_q;O_user<=user_q;O_last<=last_q;
            O_rgb<={paint(rgb_q[95:72],x_q,y_q,height_q,enable_q,ready_q,after_view_q),
                    paint(rgb_q[71:48],x_q+11'd1,y_q,height_q,enable_q,ready_q,after_view_q),
                    paint(rgb_q[47:24],x_q+11'd2,y_q,height_q,enable_q,ready_q,after_view_q),
                    paint(rgb_q[23:0],x_q+11'd3,y_q,height_q,enable_q,ready_q,after_view_q)};
        end
    end
endmodule

