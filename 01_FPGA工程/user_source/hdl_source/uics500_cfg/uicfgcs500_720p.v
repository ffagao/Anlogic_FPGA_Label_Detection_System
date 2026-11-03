`timescale 1ns / 1ns

module uicfgcs500_720p #(
    parameter CLK_DIV = 16'd239
)(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_fps_60,
    input  wire        I_ae_req,
    input  wire [15:0] I_ae,
    input  wire [15:0] I_ag,
    output wire        O_cam_scl,
    inout  wire        IO_cam_sda,
    output reg         O_cfg_done,
    output reg         O_ae_cfg_done,
    output reg         O_ae_error
);

localparam CAM_ID = 8'h6c;
localparam [17:0] POST_STREAM_DELAY = 18'd240000;

reg [7:0]  rst_cnt = 8'd0;
reg        iic_req;
wire       iic_busy;
wire       iic_bus_error;
// Keep any post-initialization NACK visible until the next power/reset.
always @(posedge I_clk or negedge I_rst_n) begin
    if(!I_rst_n) O_ae_error<=0;
    else if(O_cfg_done && iic_bus_error) O_ae_error<=1;
end
reg [31:0] wr_data;
reg [1:0]  state;
reg [8:0]  reg_index;
reg [17:0] delay_cnt;
reg        fps_update_active;
reg        fps_target;
reg        fps_mode_applied;

wire [23:0] init_data;
wire [8:0]  init_size;
wire [23:0] ae_data;
wire [8:0]  ae_size;
wire [23:0] fps_ae_data;
wire [8:0]  fps_size = 9'd9;
wire [15:0] fps_safe_ae = (fps_target && (I_ae > 16'd1990)) ?
                          16'd1990 : I_ae;
wire [23:0] fps_data = (reg_index < 9'd7) ? fps_ae_data :
                        (reg_index == 9'd7) ?
                            {16'h320e, (fps_target ? 8'h03 : 8'h07)} :
                            {16'h320f, (fps_target ? 8'he8 : 8'hd0)};
wire [23:0] selected_data = !O_cfg_done ? init_data :
                            fps_update_active ? fps_data : ae_data;
wire [8:0]  selected_size = !O_cfg_done ? init_size :
                            fps_update_active ? fps_size : ae_size;

always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n)
        rst_cnt <= 8'd0;
    else if (!rst_cnt[7])
        rst_cnt <= rst_cnt + 1'b1;
end

always @(posedge I_clk) begin
    if (!rst_cnt[7]) begin
        reg_index     <= 9'd0;
        iic_req       <= 1'b0;
        wr_data       <= 32'd0;
        O_cfg_done    <= 1'b0;
        O_ae_cfg_done <= 1'b0;
        delay_cnt     <= 18'd0;
        fps_update_active <= 1'b0;
        fps_target        <= 1'b0;
        fps_mode_applied  <= 1'b0;
        state         <= 2'd0;
    end else begin
        case (state)
            2'd0: begin
                iic_req <= 1'b0;
                if (!O_cfg_done) begin
                    if ((reg_index == 9'd118) && (delay_cnt < POST_STREAM_DELAY))
                        delay_cnt <= delay_cnt + 1'b1;
                    else if (reg_index == init_size) begin
                        O_cfg_done    <= 1'b1;
                        O_ae_cfg_done <= 1'b1;
                        reg_index     <= 9'd0;
                    end else
                        state <= 2'd1;
                end else if (fps_update_active) begin
                    if (reg_index == selected_size) begin
                        fps_mode_applied   <= fps_target;
                        fps_update_active <= 1'b0;
                        O_ae_cfg_done     <= 1'b1;
                        reg_index         <= 9'd0;
                    end else
                        state <= 2'd1;
                end else if (I_ae_req) begin
                    O_ae_cfg_done <= 1'b0;
                    reg_index     <= 9'd0;
                end else if (fps_mode_applied != I_fps_60) begin
                    // First write a frame-rate-safe exposure and the current
                    // gain, then update VTS.  This prevents an exposure longer
                    // than one 60 FPS frame during a live mode transition.
                    fps_target        <= I_fps_60;
                    fps_update_active <= 1'b1;
                    O_ae_cfg_done     <= 1'b0;
                    reg_index         <= 9'd0;
                end else if (!O_ae_cfg_done) begin
                    if (reg_index == ae_size)
                        O_ae_cfg_done <= 1'b1;
                    else
                        state <= 2'd1;
                end
            end
            2'd1: begin
                if (!iic_busy) begin
                    iic_req        <= 1'b1;
                    wr_data[7:0]   <= CAM_ID;
                    wr_data[15:8]  <= selected_data[23:16];
                    wr_data[23:16] <= selected_data[15:8];
                    wr_data[31:24] <= selected_data[7:0];
                    state          <= 2'd2;
                end
            end
            2'd2: begin
                if (iic_busy) begin
                    iic_req <= 1'b0;
                    state   <= 2'd3;
                end
            end
            2'd3: begin
                if (!iic_busy) begin
                    reg_index <= reg_index + 1'b1;
                    state     <= 2'd0;
                end
            end
        endcase
    end
end

uii2c #(
    .WMEN_LEN (4),
    .RMEN_LEN (1),
    .CLK_DIV  (CLK_DIV)
) u_i2c (
    .I_clk      (I_clk),
    .I_rstn     (rst_cnt[7]),
    .O_iic_scl  (O_cam_scl),
    .IO_iic_sda (IO_cam_sda),
    .I_wr_data  (wr_data),
    .I_wr_cnt   (8'd4),
    .O_rd_data  (),
    .I_rd_cnt   (8'd0),
    .I_iic_mode (1'b0),
    .I_iic_req  (iic_req),
    .O_iic_bus_error(iic_bus_error),
    .O_iic_busy (iic_busy)
);

uics500reg_720p60 u_init_table (
    .REG_INDEX (reg_index),
    .REG_DATA  (init_data),
    .REG_SIZE  (init_size)
);

wire [15:0] gain_value;
wire [7:0] digital_gain_index = (I_ag > 16'd143) ? (I_ag - 16'd143) : 8'd0;
wire [4:0] digital_fine_step = (digital_gain_index <= 8'd31) ? digital_gain_index[4:0] :
                                  (digital_gain_index <= 8'd63) ? (digital_gain_index - 8'd32) :
                                  (digital_gain_index - 8'd64);
wire [7:0] digital_gain_coarse = (digital_gain_index < 8'd32) ? 8'h00 :
                                    (digital_gain_index < 8'd64) ? 8'h01 : 8'h03;
wire [15:0] digital_gain_value = (digital_gain_index == 0) ? 16'h0080 :
                                  {digital_gain_coarse, (8'h80 + {1'b0,digital_fine_step,2'b00})};
wire [6:0] analog_gain_index = (I_ag > 16'd143) ? 7'd127 : (I_ag - 16'd16);
SC500GainTbl u_gain_table (
    .I_clk  (I_clk),
    .I_rstn (rst_cnt[7]),
    .I      (analog_gain_index),
    .O      (gain_value)
);

uics500regAE u_ae_table (
    .REG_INDEX (reg_index),
    .REG_DATA  (ae_data),
    .REG_SIZE  (ae_size),
    .I_AG      (gain_value),
    .I_DG      (digital_gain_value),
    .I_AE      (I_ae)
);

uics500regAE u_fps_ae_table (
    .REG_INDEX (reg_index),
    .REG_DATA  (fps_ae_data),
    .REG_SIZE  (),
    .I_AG      (gain_value),
    .I_DG      (digital_gain_value),
    .I_AE      (fps_safe_ae)
);

endmodule
