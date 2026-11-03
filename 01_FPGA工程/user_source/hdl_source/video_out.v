


module video_out (
    input wire        I_rst_n,

    input wire        I_ddr_clk,
    output wire       O_video_out_rd_busy,  
    input wire        I_video_in_wr_busy,   
    input wire[1:0]   I_video_out_rp,
    input wire[23:0]  I_video_out_frame_bcd,
    input wire        I_zoom_enable,
    output wire       O_zoom_active,
    output reg[23:0]  O_display_frame_bcd,
    output reg        O_display_frame_toggle,
    output wire       O_ddr_user_rd_en,
    output reg[24:0]  O_ddr_user_addr,
    input wire        I_ddr_user_ready,
    input wire        I_ddr_user_rd_valid,
    input wire[127:0] I_ddr_user_rd_data,

    input wire        I_dsi_clk,
    input wire        I_video_vsync,
    input wire        I_video_rd_en,  
    output reg[23:0]  O_vdieo_data,
    input wire [11:0] I_zoom_src_x,input wire signed [11:0] I_zoom_src_y,
    output wire [11:0] O_zoom_src_x,output wire signed [11:0] O_zoom_src_y
);

    reg         S_fifo_rst;     
    reg[7:0]    S_fifo_rst_cnt;
    wire[8:0]   S_fifo_wr_num;       
    wire        S_fifo_rd_en;        
    wire[127:0] S_fifo_rd_data;      
    reg         S_video_vsync_1d;
    reg         S_video_vsync_2d;
    reg         S_video_vsync_3d;
    wire        S_video_frame_start;   
    wire        S_ddr_rd_trig;       
    reg         S_ddr_rd_valid;      
    // Reserve FIFO space for every accepted command, including commands still
    // queued by the memory controller. These credits survive a frame flush.
    reg [9:0]   S_read_outstanding;
    reg [17:0]  S_frame_read_count;
    reg         S_frame_synced;
    wire [10:0] S_fifo_reserved = {2'd0,S_fifo_wr_num} + {1'b0,S_read_outstanding};
    reg         S_read_fault;
    reg         S_output_fault_1d;
    reg[9:0]    S_ddr_rd_cnt;        
    reg[3:0]    S_fifo_rd_cnt;       
    reg         S_video_rd_en_1d;
    reg         S_output_pixel_valid_1d;
    reg[3:0]    S_fifo_rd_cnt_1d;     
    reg[127:0]  S_fifo_rd_data_1d;    
	wire        S_fifo_emtpy;     
    reg         S_zoom_ddr_active;
    reg [6:0]   S_zoom_beat_in_row;
    reg         S_zoom_row_copy;
    reg signed [10:0] S_zoom_source_y;
    reg [24:0]  S_crop_row_start;
    reg [22:0]  S_view_packet_dsi;
    reg [22:0]  S_view_meta,S_view_sync;
    wire        S_zoom_dsi_active=S_view_packet_dsi[22];
    reg [10:0]  S_out_x;
    reg [9:0]   S_out_y;
    reg         S_zoom_black_1d;
    reg [1:0]   S_read_bank;
    reg         S_video_vsync_dsi_1d;
    wire        S_video_frame_start_dsi;
    wire        S_source_pixel_advance;



    localparam IMAGE_BASE_ADDR_0 = 25'd0;
    localparam IMAGE_BASE_ADDR_1 = 25'd7000000;
    localparam IMAGE_BASE_ADDR_2 = 25'd14000000;
    localparam IMAGE_BASE_ADDR_3 = 25'd21000000;
    function [24:0] F_image_base;
        input [1:0] bank;
        begin case(bank)
            0:F_image_base=IMAGE_BASE_ADDR_0;1:F_image_base=IMAGE_BASE_ADDR_1;
            2:F_image_base=IMAGE_BASE_ADDR_2;3:F_image_base=IMAGE_BASE_ADDR_3;
        endcase end
    endfunction
    wire [9:0] S_crop_first_y=S_view_sync[10]?10'd0:S_view_sync[9:0];
    wire [24:0] S_crop_y_addr=({15'd0,S_crop_first_y}<<11)-({15'd0,S_crop_first_y}<<7);
    // Read 400 aligned pixels per row. Panel clocks consume the leading
    // alignment pixels; the visible 384 pixels are each displayed twice.
    wire [24:0] S_crop_x_addr=({18'd0,S_view_sync[21:15]}<<4)+({18'd0,S_view_sync[21:15]}<<3);
    wire [24:0] S_selected_base=F_image_base(S_read_bank);


    always @(posedge I_ddr_clk) begin
        S_video_vsync_1d <= I_video_vsync;
        S_video_vsync_2d <=S_video_vsync_1d;
        S_video_vsync_3d <= S_video_vsync_2d;
    end

    assign S_video_frame_start = ~S_video_vsync_3d & S_video_vsync_2d;

    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_view_meta<=0;S_view_sync<=0;
        end
        else begin
            S_view_meta<=S_view_packet_dsi;S_view_sync<=S_view_meta;
        end
    end

    // Capture the camera-frame identity at the same event that selects the
    // DDR read buffer.  A repeated 60 Hz output frame retains the same DISP
    // value until the next completed 30 Hz camera frame is selected.
    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_display_frame_bcd    <= 24'd0;
            O_display_frame_toggle <= 1'b0;
        end
        else if(S_video_frame_start) begin
            O_display_frame_bcd    <= I_video_out_frame_bcd;
            O_display_frame_toggle <= ~O_display_frame_toggle;

        end
    end

    // As in v39, use the next completed camera bank at each output frame.
    // The crop packet is fixed for the frame; the camera/video are never paused.
    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) S_read_bank<=0;
        else if(S_video_frame_start) S_read_bank<=I_video_out_rp;
    end

    // Stop issuing immediately at VSYNC. Discard the old frame's returns,
    // then release the FIFO only after all accepted reads have drained.
    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_fifo_rst <= 1'b1;
            S_fifo_rst_cnt <= 8'd0;
        end
        else if(S_video_frame_start) begin
            S_fifo_rst <= 1'b1;
            S_fifo_rst_cnt <= 8'd0;
        end
        else if(S_fifo_rst) begin
            if(S_read_outstanding != 10'd0)
                S_fifo_rst_cnt <= 8'd0;
            else if(S_fifo_rst_cnt == 8'd10)
                S_fifo_rst <= 1'b0;
            else S_fifo_rst_cnt <= S_fifo_rst_cnt + 8'd1;
        end
    end

    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_read_outstanding <= 10'd0;
            S_frame_read_count <= 18'd0;
            S_frame_synced <= 1'b0;
        end
        else begin
            case({O_ddr_user_rd_en,I_ddr_user_rd_valid})
                2'b10: S_read_outstanding <= S_read_outstanding + 10'd1;
                2'b01: if(S_read_outstanding != 10'd0)
                           S_read_outstanding <= S_read_outstanding - 10'd1;
                default: ;
            endcase
            if(S_video_frame_start) begin
                S_frame_read_count <= 18'd0;
                S_frame_synced <= 1'b1;
            end
            else if(O_ddr_user_rd_en) S_frame_read_count <= S_frame_read_count + 18'd1;
        end
    end

    /*
        这里需要注意fifo的剩余空间一定要大于将要写入的长度，因为ddr读出的时候会有至少40个时钟周期的延时，
        例如每次从ddr读出240个长度的数据，那么fifo的剩余空间最少要设为280，否则会引起fifo写满丢失数据。
    */
    assign S_ddr_rd_trig = (S_fifo_reserved <= 11'd211) && (!I_video_in_wr_busy) && (!S_ddr_rd_valid) && (!S_fifo_rst) && !S_video_frame_start &&
                    (S_frame_read_count < (S_zoom_ddr_active ? 18'd54000 : 18'd172800)) &&
                    I_rst_n && S_frame_synced ? 1'b1 : 1'b0;

    /*
        fifo的深度是512，实际的深度是510，因此需要注意每次读出的长度避免为256，否则连续两次写入会引起fifo写满，丢失数据
    */
    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_ddr_rd_valid <= 1'b0;
        else if(S_video_frame_start || S_fifo_rst)
            S_ddr_rd_valid <= 1'b0;
        else
			if(O_ddr_user_rd_en && S_ddr_rd_cnt == 'd239)
                S_ddr_rd_valid <= 1'b0;
            else if(S_ddr_rd_trig)
                S_ddr_rd_valid <= 1'b1;
            else
                S_ddr_rd_valid <= S_ddr_rd_valid;
    end

    assign O_ddr_user_rd_en = S_ddr_rd_valid && I_ddr_user_ready &&
                              !S_video_frame_start && !S_fifo_rst && I_rst_n;

    always @(posedge I_ddr_clk) begin
        if(S_video_frame_start || S_fifo_rst)
            S_ddr_rd_cnt <= 10'd0;
        else if(S_ddr_rd_valid)
            begin
                if(O_ddr_user_rd_en)
                    S_ddr_rd_cnt <= S_ddr_rd_cnt + 'd1;
                else
                    S_ddr_rd_cnt <= S_ddr_rd_cnt;
            end
        else    
            S_ddr_rd_cnt <= 'd0;
    end


    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_ddr_user_addr <= 'd0;
            S_zoom_ddr_active <= 1'b0;
            S_zoom_beat_in_row <= 7'd0;
            S_zoom_row_copy <= 1'b0;
            S_zoom_source_y <= 0;S_crop_row_start<=0;
        end
        else if(S_video_frame_start) begin
            S_zoom_beat_in_row <= 7'd0;
            S_zoom_row_copy <= 1'b0;
            O_ddr_user_addr<=F_image_base(I_video_out_rp);
        end
        else if(S_fifo_rst && S_fifo_rst_cnt==8'd2) begin
            S_crop_row_start<=S_crop_y_addr;
        end
        else if(S_fifo_rst && S_fifo_rst_cnt==8'd3) begin
            S_crop_row_start<=S_crop_row_start+S_crop_x_addr;
        end
        else if(S_fifo_rst && S_fifo_rst_cnt==8'd4) begin
            // The DSI-side packet has been held since VSYNC and crossed two
            // DDR registers. No read can issue until the existing flush ends.
            S_zoom_ddr_active<=S_view_sync[22];
            S_zoom_source_y<=$signed(S_view_sync[10:0]);
            S_crop_row_start<=S_selected_base+S_crop_row_start;
            O_ddr_user_addr<=S_view_sync[22]?(S_selected_base+S_crop_row_start):S_selected_base;
        end
        else if(O_ddr_user_rd_en) begin
            if(S_zoom_ddr_active) begin
                if(S_zoom_beat_in_row == 7'd74) begin
                    S_zoom_beat_in_row <= 7'd0;
                    if(!S_zoom_row_copy) begin
                        S_zoom_row_copy <= 1'b1;
                        O_ddr_user_addr <= S_crop_row_start;
                    end
                    else begin
                        S_zoom_row_copy <= 1'b0;
                        S_zoom_source_y<=S_zoom_source_y+11'sd1;
                        if(S_zoom_source_y>=0 && S_zoom_source_y<719) begin
                            S_crop_row_start<=S_crop_row_start+25'd1920;
                            O_ddr_user_addr<=S_crop_row_start+25'd1920;
                        end else O_ddr_user_addr<=S_crop_row_start;
                    end
                end
                else begin
                    S_zoom_beat_in_row <= S_zoom_beat_in_row + 7'd1;
                    O_ddr_user_addr <= O_ddr_user_addr + 25'd8;
                end
            end
            else begin
                O_ddr_user_addr <= O_ddr_user_addr + 25'd8;
            end
        end
    end

    
    assign O_video_out_rd_busy = S_ddr_rd_trig | S_ddr_rd_valid;


    w128_d512_fifo U_w128_d512_fifo(
        .rst        ( S_fifo_rst          ),   

        .clkw       ( I_ddr_clk           ),     
        .we         ( I_ddr_user_rd_valid && !S_fifo_rst && !S_video_frame_start ),
        .di         ( I_ddr_user_rd_data  ),
        .wrusedw    ( S_fifo_wr_num       ),
        .afull      (),
        .full_flag  (),
 
        .clkr       ( I_dsi_clk           ),
        .re         ( S_fifo_rd_en        ), 
        .dout       ( S_fifo_rd_data      ),  
        .rdusedw    (), 
        .valid      (),  
        .empty_flag ( S_fifo_emtpy        ),
        .aempty     ()
    );


   always @(posedge I_dsi_clk or negedge I_rst_n) begin
       if(!I_rst_n) begin
           S_video_vsync_dsi_1d <= 1'b0;
           S_view_packet_dsi<=0;S_out_x<=0;S_out_y<=0;
       end
       else begin
           S_video_vsync_dsi_1d <= I_video_vsync;
           if(S_video_frame_start_dsi) begin
               // Normal label coordinates include two clocks of RGB read
               // latency. A one-source-pixel correction at 2x keeps the
               // enlarged image and the existing geometry on the same grid.
               S_view_packet_dsi<={I_zoom_enable,(I_zoom_src_x[10:0]-11'd1),I_zoom_src_y[10:0]};
               S_out_x<=0;S_out_y<=0;
           end else if(I_video_rd_en) begin
               if(S_out_x==1279) begin S_out_x<=0;S_out_y<=S_out_y+1'b1;end
               else S_out_x<=S_out_x+1'b1;
           end else S_out_x<=0;
       end
   end

   assign S_video_frame_start_dsi = I_video_vsync & ~S_video_vsync_dsi_1d;
   wire [4:0] S_skip_pixels=S_out_y==0?{1'b0,S_view_packet_dsi[14:11]}:5'd16;
   assign S_source_pixel_advance = I_video_rd_en && !S_read_fault &&
       (!S_zoom_dsi_active || S_out_x<S_skip_pixels || (S_out_x>=512 && !S_out_x[0]));
   assign O_zoom_active = S_zoom_dsi_active;
   assign O_zoom_src_x={1'b0,S_view_packet_dsi[21:11]}+12'd1;
   assign O_zoom_src_y=$signed({S_view_packet_dsi[10],S_view_packet_dsi[10:0]});
   wire [12:0] S_pixel_source_x={2'b0,S_view_packet_dsi[21:11]}+{3'd0,S_out_x[10:1]}-13'd256;
   wire signed [12:0] S_pixel_source_y=$signed({{2{S_view_packet_dsi[10]}},S_view_packet_dsi[10:0]})+$signed({4'd0,S_out_y[9:1]});
   wire S_zoom_black=S_zoom_dsi_active &&
       (S_out_x<512 || S_pixel_source_x>=1280 || S_pixel_source_y<0 || S_pixel_source_y>=720);

   always @(posedge I_dsi_clk) begin
       if(S_video_frame_start_dsi)
           S_fifo_rd_cnt <= 4'd0;
       else if(S_source_pixel_advance)
           S_fifo_rd_cnt <= S_fifo_rd_cnt + 'd1;
       else if(!I_video_rd_en && !S_zoom_dsi_active)
           S_fifo_rd_cnt <= 'd0;
   end

   assign S_fifo_rd_en = S_source_pixel_advance && (S_fifo_rd_cnt == 'd0)  ? 1'b1 :
                         S_source_pixel_advance && (S_fifo_rd_cnt == 'd5)  ? 1'b1 :
                         S_source_pixel_advance && (S_fifo_rd_cnt == 'd10) ? 1'b1 : 1'b0;

   // HDMI scanning cannot pause. After a real underflow, blank the rest of
   // this frame instead of continuing with a displaced byte/line phase.
   // VSYNC flushes the FIFO and restores the source phase for the next frame.
   always @(posedge I_dsi_clk or negedge I_rst_n) begin
       if(!I_rst_n) begin
           S_read_fault <= 1'b0;
           S_output_fault_1d <= 1'b0;
       end
       else begin
           if(S_video_frame_start_dsi) S_read_fault <= 1'b0;
           else if(S_fifo_rd_en && S_fifo_emtpy) S_read_fault <= 1'b1;
           S_output_fault_1d <= S_read_fault || (S_fifo_rd_en && S_fifo_emtpy);
       end
   end

   always @(posedge I_dsi_clk) begin
       S_video_rd_en_1d  <= S_source_pixel_advance;
       S_output_pixel_valid_1d <= I_video_rd_en;
       S_zoom_black_1d<=S_zoom_black;
       S_fifo_rd_cnt_1d  <= S_fifo_rd_cnt;
       S_fifo_rd_data_1d <= S_fifo_rd_data;
   end

   always @(posedge I_dsi_clk) begin
       if(S_output_fault_1d || S_zoom_black_1d)
           O_vdieo_data <= 24'd0;
       else if(S_video_rd_en_1d)
           begin
               case(S_fifo_rd_cnt_1d)
                   'd0: O_vdieo_data  <= S_fifo_rd_data[127:104];
                   'd1: O_vdieo_data  <= S_fifo_rd_data[103:80];
                   'd2: O_vdieo_data  <= S_fifo_rd_data[79:56];
                   'd3: O_vdieo_data  <= S_fifo_rd_data[55:32];
                   'd4: O_vdieo_data  <= S_fifo_rd_data[31:8];
                   'd5: O_vdieo_data  <= {S_fifo_rd_data_1d[7:0],S_fifo_rd_data[127:112]};
                   'd6: O_vdieo_data  <= S_fifo_rd_data[111:88];
                   'd7: O_vdieo_data  <= S_fifo_rd_data[87:64];
                   'd8: O_vdieo_data  <= S_fifo_rd_data[63:40];
                   'd9: O_vdieo_data  <= S_fifo_rd_data[39:16];
                   'd10: O_vdieo_data <= {S_fifo_rd_data_1d[15:0],S_fifo_rd_data[127:120]};
                   'd11: O_vdieo_data <= S_fifo_rd_data[119:96];
                   'd12: O_vdieo_data <= S_fifo_rd_data[95:72];
                   'd13: O_vdieo_data <= S_fifo_rd_data[71:48];
                   'd14: O_vdieo_data <= S_fifo_rd_data[47:24];
                   'd15: O_vdieo_data <= S_fifo_rd_data[23:0];
               endcase
           end
       else if(!S_output_pixel_valid_1d)
           O_vdieo_data <= 'd0;
   end

    
endmodule
