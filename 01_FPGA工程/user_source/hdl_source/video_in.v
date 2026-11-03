module video_in (
    input wire         I_rst_n,

    input wire         I_camera_clk,
    input wire         I_camera_frame_start,
    input wire[23:0]   I_camera_frame_bcd,
    input wire         I_camera_valid,
    input wire[127:0]  I_camera_data,
    input wire         I_mipi_rx_error,

    input wire         I_ddr_clk,

    input wire         I_display_pause,
    input wire         I_video_out_rd_busy,
    output reg[23:0]   O_video_out_frame_bcd,
    output wire        O_video_in_wr_busy,
    output reg[1:0]    O_video_out_rp,

    output reg         O_ddr_user_wr_en,
    output reg[24:0]   O_ddr_user_addr,
    output reg[127:0]  O_ddr_user_wr_data,
    input wire         I_ddr_user_ready,
    output wire[8:0]   O_diag_fifo_level,
    output wire[8:0]   O_diag_burst_count,
    output wire        O_diag_burst_active,
    output reg[17:0]   O_diag_ddr_frame
);
    reg         S_camera_first_pending;
    reg         S_camera_frame_open;
    reg[23:0]   S_camera_frame_bcd;
    wire        S_camera_first = I_camera_frame_start | S_camera_first_pending;
    wire[23:0]  S_camera_word_bcd = I_camera_frame_start ?
                                     I_camera_frame_bcd : S_camera_frame_bcd;
    wire        S_camera_wr_en = I_camera_valid &&
                                (I_camera_frame_start || S_camera_frame_open);
    wire[152:0] S_fifo_rd_data;
    wire[8:0]   S_fifo_rd_num;
    wire        S_fifo_rd_en;
    wire        S_fifo_rd_valid;
    wire        S_fifo_full;
    reg         S_ddr_wr_valid;
    reg[9:0]    S_ddr_wr_cnt;
    reg[24:0]   S_next_addr;
    reg[1:0]    S_video_in_wp;
    reg[23:0]   S_frame_bcd_0,S_frame_bcd_1,S_frame_bcd_2,S_frame_bcd_3;
    reg[17:0]   S_ddr_frame_count;
    wire        S_frame_start = S_fifo_rd_valid && S_fifo_rd_data[152];

    localparam IMAGE_BASE_ADDR_0 = 25'd0;
    localparam IMAGE_BASE_ADDR_1 = 25'd7000000;
    localparam IMAGE_BASE_ADDR_2 = 25'd14000000;
    localparam IMAGE_BASE_ADDR_3 = 25'd21000000;

    function [24:0] F_image_base;
        input [1:0] index;
        begin
            case(index)
                2'd0: F_image_base=IMAGE_BASE_ADDR_0;
                2'd1: F_image_base=IMAGE_BASE_ADDR_1;
                2'd2: F_image_base=IMAGE_BASE_ADDR_2;
                2'd3: F_image_base=IMAGE_BASE_ADDR_3;
            endcase
        end
    endfunction
    wire[24:0] S_frame_base = F_image_base(I_mipi_rx_error ?
                                            S_video_in_wp-2'd1 : S_video_in_wp);

    // SOF can precede the first packed word. Keep it until that word is written.
    always @(posedge I_camera_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_camera_first_pending<=0;
            S_camera_frame_open<=0;
            S_camera_frame_bcd<=0;
        end else begin
            if(I_camera_frame_start) begin
                S_camera_first_pending<=1;
                S_camera_frame_open<=1;
                S_camera_frame_bcd<=I_camera_frame_bcd;
            end
            if(S_camera_wr_en) S_camera_first_pending<=0;
        end
    end

    // The processed image can trail the next raw CSI header. Resetting this
    // FIFO at that header discards the previous image's delayed final rows.
    // Carry SOF and frame identity in the same FIFO as the pixels instead.
    soft_fifo_al_4057d6b76aa6 #(
        .DATA_WIDTH_W(153),.DATA_WIDTH_R(153),
        .ADDR_WIDTH_W(9),.ADDR_WIDTH_R(9),
        .AL_FULL_NUM(253),.AL_EMPTY_NUM(2),
        .SHOW_AHEAD_EN(0),.OUTREG_EN("NOREG")
    ) u_camera_frame_fifo (
        .rst(~I_rst_n),.clkw(I_camera_clk),.clkr(I_ddr_clk),
        .we(S_camera_wr_en),.di({S_camera_first,S_camera_word_bcd,I_camera_data}),
        .full_flag(S_fifo_full),.afull(),.wrusedw(),
        .re(S_fifo_rd_en),.dout(S_fifo_rd_data),.valid(S_fifo_rd_valid),
        .rdusedw(S_fifo_rd_num),.empty_flag(),.aempty()
    );

    // Keep read arbitration blocked until the registered final write drains.
    assign O_video_in_wr_busy = S_ddr_wr_valid | S_fifo_rd_valid | O_ddr_user_wr_en;
    assign O_diag_fifo_level = S_fifo_rd_num;
    assign O_diag_burst_count = S_ddr_wr_cnt[8:0];
    assign O_diag_burst_active = S_ddr_wr_valid;

    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) S_ddr_wr_valid<=0;
        else if(S_ddr_wr_valid && I_ddr_user_ready && S_ddr_wr_cnt==10'd239)
            S_ddr_wr_valid<=0;
        else if(S_fifo_rd_num>=9'd240 && !I_video_out_rd_busy)
            S_ddr_wr_valid<=1;
    end
    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) S_ddr_wr_cnt<=0;
        else if(!S_ddr_wr_valid) S_ddr_wr_cnt<=0;
        else if(I_ddr_user_ready) S_ddr_wr_cnt<=S_ddr_wr_cnt+1'b1;
    end
    assign S_fifo_rd_en = S_ddr_wr_valid && I_ddr_user_ready;

    // Register data and its address together. The controller's ready interface
    // reserves eight trailing words; this path has two registered stages.
    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_ddr_user_wr_en<=0;O_ddr_user_addr<=0;O_ddr_user_wr_data<=0;
            S_next_addr<=0;
        end else begin
            O_ddr_user_wr_en<=S_fifo_rd_valid;
            if(S_fifo_rd_valid) begin
                O_ddr_user_wr_data<=S_fifo_rd_data[127:0];
                O_ddr_user_addr<=S_frame_start ? S_frame_base : S_next_addr;
                S_next_addr<=(S_frame_start ? S_frame_base : S_next_addr)+25'd8;
            end
        end
    end

    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_video_in_wp<=0;O_video_out_rp<=0;
        end else if(S_frame_start && !I_display_pause) begin
            if(!I_mipi_rx_error) S_video_in_wp<=S_video_in_wp+1'b1;
            O_video_out_rp<=S_video_in_wp-2'd2;
        end
    end
    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_frame_bcd_0<=0;S_frame_bcd_1<=0;S_frame_bcd_2<=0;S_frame_bcd_3<=0;
        end else if(S_frame_start && !I_mipi_rx_error) begin
            case(S_video_in_wp)
                2'd0: S_frame_bcd_0<=S_fifo_rd_data[151:128];
                2'd1: S_frame_bcd_1<=S_fifo_rd_data[151:128];
                2'd2: S_frame_bcd_2<=S_fifo_rd_data[151:128];
                2'd3: S_frame_bcd_3<=S_fifo_rd_data[151:128];
            endcase
        end
    end
    always @(*) begin
        case(O_video_out_rp)
            2'd0: O_video_out_frame_bcd=S_frame_bcd_0;
            2'd1: O_video_out_frame_bcd=S_frame_bcd_1;
            2'd2: O_video_out_frame_bcd=S_frame_bcd_2;
            2'd3: O_video_out_frame_bcd=S_frame_bcd_3;
        endcase
    end
    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin S_ddr_frame_count<=0;O_diag_ddr_frame<=0;end
        else if(S_frame_start) begin
            O_diag_ddr_frame<=S_ddr_frame_count;
            S_ddr_frame_count<=18'd1;
        end else if(S_fifo_rd_valid) S_ddr_frame_count<=S_ddr_frame_count+1'b1;
    end
endmodule
