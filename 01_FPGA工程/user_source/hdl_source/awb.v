/*****************************************************************
Company : MiLianKe Electronic Technology Co., Ltd.
WebSite:https://www.milianke.com
TechWeb:https://www.uisrc.com
tmall-shop:https://milianke.tmall.com
jd-shop:https://milianke.jd.com
taobao-shop: https://milianke.taobao.com
Description: 
The reference demo provided by Milianke is only used for learning. 
We cannot ensure that the demo itself is free of bugs, so users 
should be responsible for the technical problems and consequences
caused by the use of their own products.
@Author      :   XiaoQingquan 
@Time        :   2024/10 
version:     :   
@Description :   在原基础上删去了一些赘余的代码，并且优化了时序，加入BRAM IP核，
                 让从除法器出来的每一个数据都可以对上相应的像素数据进行增益，使
                 得它的适用行更加广泛了。
*****************************************************************/
module awb  #(   
    parameter IMG_HEIGHT = 1080,
    parameter IMG_WIDTH  = 1920
) 
(
    input                   I_clk  ,
    input                   I_rst_n,
    input I_lock,
    output reg O_locked,


    input                   I_tlast  ,
    input                   I_tuser  ,
    input [95:0]            I_tdata  ,
    input                   I_tvalid , 
    output                  I_tready ,

    output                  O_tlast  ,
    output                  O_tuser  ,
    output [95:0]           O_tdata  ,
    output                  O_tvalid ,
    input                   O_tready
);

/*****************************************************************
                          RGB565תRGB888                                        
*****************************************************************/

    // //RGB565??????888
    // wire [4:0]  rgb565_r   = I_st_data[11+:5];
    // wire [5:0]  rgb565_g   = I_st_data[5+:6];
    // wire [4:0]  rgb565_b   = I_st_data[0+:5];
    
    // wire [23:0] rgb888     = {{rgb565_r[4:0],rgb565_r[2:0]},{rgb565_g[5:0],rgb565_g[1:0]},{rgb565_b[4:0],rgb565_b[2:0]}};
    
    // wire [7:0]  rgb888_r   = rgb888[16+:8];
    // wire [7:0]  rgb888_g   = rgb888[8+:8] ;
    // wire [7:0]  rgb888_b   = rgb888[0+:8] ;
    
  /*****************************************************************
                          中间信号                                        
*****************************************************************/


  reg         I_tvalid_r0,I_tvalid_r1;
  reg  [95:0] I_tdata_d0,I_tdata_d1;


  //累加RGB通道的�??
  reg  [31:0]         sum_r[0:3];
  reg  [31:0]         sum_g[0:3];
  reg  [31:0]         sum_b[0:3];

  
  wire  [95:0]        data_d0 ;
  wire                valid_d0;
  wire                I_tuser_r0;    

  reg                 I_tuser_r1;

  reg   [95:0]        data_d1 ;
  reg                 valid_d1;
  reg   [9:0]         rgb_sum[0:3];//每个像素点RGB的和
  /*****************************************************************
                            平均值计�??                                      
*****************************************************************/

// 对输入数据和有效信号进行寄存，形成流水线
always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
        I_tdata_d0  <= 0;
        I_tdata_d1  <= 0;
        {I_tvalid_r0,I_tvalid_r1} <= 0;
    end else begin
        I_tdata_d0  <= I_tdata   ;
        I_tdata_d1  <= I_tdata_d0;
        I_tvalid_r0 <= I_tvalid;
        I_tvalid_r1 <= I_tvalid_r0;
    end
end

// 将输入数据拆分为4个像素的RGB分量
wire [7:0] rgb888_r_d[0:3];
wire [7:0] rgb888_g_d[0:3];
wire [7:0] rgb888_b_d[0:3];

assign  rgb888_r_d[0] = I_tdata[16+:8];
assign  rgb888_g_d[0] = I_tdata[8+:8];
assign  rgb888_b_d[0] = I_tdata[0+:8];


// 将输入数据拆分为4个像素的RGB分量
wire [7:0] rgb888_r_d0[0:3];
wire [7:0] rgb888_g_d0[0:3];
wire [7:0] rgb888_b_d0[0:3];

assign  rgb888_r_d0[0] = I_tdata_d0[16+:8];
assign  rgb888_g_d0[0] = I_tdata_d0[8+:8];
assign  rgb888_b_d0[0] = I_tdata_d0[0+:8];


        ///削弱白色
        always @(posedge I_clk or negedge I_rst_n) begin
            if(!I_rst_n) begin
                rgb_sum[0] <= 0;
            end
            else if(I_tvalid)begin
                rgb_sum[0] <= rgb888_r_d[0] + rgb888_g_d[0] + rgb888_b_d[0];
            end
        end

        // 对每个通道的值进行累加，用于计算平均值
        always @(posedge I_clk or negedge I_rst_n) begin
            if (!I_rst_n || I_tuser) begin
                // 复位或行开始信号有效时，清零累加器
                sum_r[0] <= 1;
                sum_g[0] <= 1;
                sum_b[0] <= 1;
            end else if (I_tvalid_r0 && (rgb_sum[0] < 720)) begin
                // 当输入有效时，累加RGB分量的值
                sum_r[0] <= sum_r[0] + rgb888_r_d0[0];
                sum_g[0] <= sum_g[0] + rgb888_g_d0[0];
                sum_b[0] <= sum_b[0] + rgb888_b_d0[0];
            end
        end

  /*****************************************************************
                           计算增益                                       
*****************************************************************/

  wire [47:0] in_r_x1;
  wire [47:0] in_b_x1;
  wire        awb_div_busy;
  wire        awb_div_done;
  reg         awb_div_start;
  reg  [6:0]  awb_update_count;



/*****************************************************************
                   IP 调用                                    
*****************************************************************/
    //为了保证合理的延迟，这里使用了除法器

    // The RGB statistics change slowly within a frame.  Sample them every
    // 128 pixel groups and reuse one iterative divider for G/R and G/B.
    // The Q16 gain formula is unchanged while two large parallel dividers
    // are removed from the continuously running pixel datapath.
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n || I_tuser) begin
            awb_update_count <= 7'd0;
            awb_div_start    <= 1'b0;
        end
        else begin
            awb_div_start <= 1'b0;
            if(I_tvalid_r1) begin
                if(awb_update_count == 7'd127) begin
                    awb_update_count <= 7'd0;
                    if(!awb_div_busy && !O_locked)
                        awb_div_start <= 1'b1;
                end
                else begin
                    awb_update_count <= awb_update_count + 7'd1;
                end
            end
        end
    end

    awb_shared_divider u_awb_shared_divider (
        .I_clk          (I_clk),
        .I_rst_n        (I_rst_n),
        .I_frame_start  (I_tuser),
        .I_start        (awb_div_start),
        .I_numerator    ({sum_g[0],16'd0}),
        .I_denominator_r(sum_r[0]),
        .I_denominator_b(sum_b[0]),
        .O_busy         (awb_div_busy),
        .O_done         (awb_div_done),
        .O_quotient_r   (in_r_x1),
        .O_quotient_b   (in_b_x1)
    );

     
    wire [19:0] in_r_wb_gain;
    wire [19:0] in_b_wb_gain;
    awb_gain_bias u_awb_r_gain_bias (.I_gain_q16(in_r_x1), .O_gain_q16(in_r_wb_gain));
    awb_gain_bias u_awb_b_gain_bias (.I_gain_q16(in_b_x1), .O_gain_q16(in_b_wb_gain));

    signal_delay #(
        .IMG_HEIGHT   (IMG_HEIGHT),
        .IMG_WIDTH    (IMG_WIDTH ),
        .DATA_WIDTH   (96  ),
        .DELAY_CYCLE  (50)
    )signal_delay_d (
        /*input                       */ .I_clk  (I_clk  ),
        /*input                       */ .I_rst_n(I_rst_n),
        /*input                       */ .I_tuser(I_tuser),  // 
        /*input  wire                 */ .I_valid(I_tvalid_r1),  // 
        /*input  wire [DATA_WIDTH-1:0]*/ .I_data (I_tdata_d1 ),   // 
        /*output wire                 */ .O_valid(valid_d0   ),  // 
        /*output wire [DATA_WIDTH-1:0]*/ .O_data (data_d0    ),   // 
        /*output wire                 */ .O_tuser(I_tuser_r0 )
    );

    

/*****************************************************************
                            ��������                                      
*****************************************************************/

    reg  [19:0]   in_r_r1;
    reg  [19:0]   in_b_r1;
    always @(posedge I_clk or negedge I_rst_n)begin 
        if(!I_rst_n)begin
            in_r_r1 <= 20'h10000;
            in_b_r1 <= 20'h10000;
            O_locked <= 1'b0;
        end
        else if(I_tuser) begin
            O_locked <= (I_lock === 1'b1);
            if(I_lock !== 1'b1) begin in_r_r1<=20'h10000;in_b_r1<=20'h10000;end
        end
        else if(awb_div_done && !O_locked)begin
            in_r_r1 <= in_r_wb_gain;
            in_b_r1 <= in_b_wb_gain;
        end
    end


    ////信号同步
    always @(posedge I_clk or negedge I_rst_n) begin
      if (!I_rst_n) begin
          valid_d1 <= 0;
          data_d1  <= 0;
          I_tuser_r1 <= 0;
      end else begin
          valid_d1 <= valid_d0;
          data_d1  <= data_d0 ;
          I_tuser_r1 <= I_tuser_r0;
      end
    end
/*****************************************************************
                           ��������                                       
*****************************************************************/

    reg [27:0] R_new_r1;
    reg [27:0] G_new_r1;
    reg [27:0] B_new_r1;

    reg [27:0] R_new_r2;
    reg [27:0] G_new_r2;
    reg [27:0] B_new_r2;

    reg [27:0] R_new_r3;
    reg [27:0] G_new_r3;
    reg [27:0] B_new_r3;

    reg [27:0] R_new_r4;
    reg [27:0] G_new_r4;
    reg [27:0] B_new_r4;


    wire   [7:0] rgb888_r_d1[0:3];
    wire   [7:0] rgb888_g_d1[0:3];
    wire   [7:0] rgb888_b_d1[0:3];

    assign  rgb888_r_d1[0] = data_d1[16+:8];
    assign  rgb888_g_d1[0] = data_d1[8+:8];
    assign  rgb888_b_d1[0] = data_d1[0+:8];

    assign  rgb888_r_d1[1] = data_d1[40+:8];
    assign  rgb888_g_d1[1] = data_d1[32+:8];
    assign  rgb888_b_d1[1] = data_d1[24+:8];

    assign  rgb888_r_d1[2] = data_d1[64+:8];
    assign  rgb888_g_d1[2] = data_d1[56+:8];
    assign  rgb888_b_d1[2] = data_d1[48+:8];

    assign  rgb888_r_d1[3] = data_d1[88+:8];
    assign  rgb888_g_d1[3] = data_d1[80+:8];
    assign  rgb888_b_d1[3] = data_d1[72+:8];
    always @(posedge I_clk or negedge I_rst_n)begin 
        if(!I_rst_n)begin
            R_new_r1 <= 0;
            G_new_r1 <= 0;
            B_new_r1 <= 0;

            R_new_r2 <= 0;
            G_new_r2 <= 0;
            B_new_r2 <= 0;

            R_new_r3 <= 0;
            G_new_r3 <= 0;
            B_new_r3 <= 0;

            R_new_r4 <= 0;
            G_new_r4 <= 0;
            B_new_r4 <= 0;
        end
        else if(valid_d1) begin
            R_new_r1 <= in_r_r1 * rgb888_r_d1[0];
            G_new_r1 <=           rgb888_g_d1[0];
            B_new_r1 <= in_b_r1 * rgb888_b_d1[0];

            R_new_r2 <= in_r_r1 * rgb888_r_d1[1];
            G_new_r2 <=           rgb888_g_d1[1];
            B_new_r2 <= in_b_r1 * rgb888_b_d1[1];

            R_new_r3 <= in_r_r1 * rgb888_r_d1[2];
            G_new_r3 <=           rgb888_g_d1[2];
            B_new_r3 <= in_b_r1 * rgb888_b_d1[2];

            R_new_r4 <= in_r_r1 * rgb888_r_d1[3];
            G_new_r4 <=           rgb888_g_d1[3];
            B_new_r4 <= in_b_r1 * rgb888_b_d1[3];
        end
    end

/*****************************************************************
                            �������???                                      
*****************************************************************/

    wire [7:0] R_new_x1;
    wire [7:0] G_new_x1;
    wire [7:0] B_new_x1;

    wire [7:0] R_new_x2;
    wire [7:0] G_new_x2;
    wire [7:0] B_new_x2;

    wire [7:0] R_new_x3;
    wire [7:0] G_new_x3;
    wire [7:0] B_new_x3;

    wire [7:0] R_new_x4;
    wire [7:0] G_new_x4;
    wire [7:0] B_new_x4;

    assign R_new_x1 = (R_new_r1[27:24])?255:R_new_r1[23:16];
    assign G_new_x1 =  G_new_r1;
    assign B_new_x1 = (B_new_r1[27:24])?255:B_new_r1[23:16];

    assign R_new_x2 = (R_new_r2[27:24])?255:R_new_r2[23:16];
    assign G_new_x2 =  G_new_r2;
    assign B_new_x2 = (B_new_r2[27:24])?255:B_new_r2[23:16];

    assign R_new_x3 = (R_new_r3[27:24])?255:R_new_r3[23:16];
    assign G_new_x3 =  G_new_r3;
    assign B_new_x3 = (B_new_r3[27:24])?255:B_new_r3[23:16];

    assign R_new_x4 = (R_new_r4[27:24])?255:R_new_r4[23:16];
    assign G_new_x4 =  G_new_r4;
    assign B_new_x4 = (B_new_r4[27:24])?255:B_new_r4[23:16];
/*****************************************************************
                           ͬ���ź�                                       
*****************************************************************/

    reg valid_d2,I_tuser_r2;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n)begin
            valid_d2 <= 0;
            I_tuser_r2 <= 0;
        end
        else begin
            valid_d2 <= valid_d1;
            I_tuser_r2 <= I_tuser_r1;
        end
    end


    assign  O_tlast  = (valid_d1 == 0) && (valid_d2 == 1);   
    assign  O_tuser  = I_tuser_r2;   
    assign  O_tvalid = valid_d2;

    assign  O_tdata = O_tvalid?{R_new_x4,G_new_x4,B_new_x4,
                       R_new_x3,G_new_x3,B_new_x3,
                       R_new_x2,G_new_x2,B_new_x2,
                       R_new_x1,G_new_x1,B_new_x1}:0;
    // assign O_t_data = {R_new[7-:5],G_new[7-:6],B_new[7-:5]};
    assign  I_tready = O_tready;
 
endmodule


// One restoring divider is reused for both AWB gain ratios.  A complete
// red/blue update takes 96 clocks while video remains one group per clock.
module awb_shared_divider (
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_frame_start,
    input  wire        I_start,
    input  wire [47:0] I_numerator,
    input  wire [31:0] I_denominator_r,
    input  wire [31:0] I_denominator_b,
    output wire        O_busy,
    output reg         O_done,
    output reg  [47:0] O_quotient_r,
    output reg  [47:0] O_quotient_b
);

    localparam STATE_IDLE  = 2'd0;
    localparam STATE_DIV_R = 2'd1;
    localparam STATE_DIV_B = 2'd2;

    reg [1:0]  state;
    reg [5:0]  iteration;
    reg [47:0] numerator_latched;
    reg [31:0] denominator_b_latched;
    reg [47:0] dividend_shift;
    reg [47:0] quotient_shift;
    reg [32:0] remainder_shift;
    reg [31:0] divisor;
    reg [47:0] quotient_r_pending;

    wire [32:0] trial_remainder =
                    {remainder_shift[31:0],dividend_shift[47]};
    wire quotient_bit = trial_remainder >= {1'b0,divisor};
    wire [32:0] next_remainder = quotient_bit ?
                    (trial_remainder - {1'b0,divisor}) : trial_remainder;
    wire [47:0] next_quotient =
                    {quotient_shift[46:0],quotient_bit};

    assign O_busy = (state != STATE_IDLE);

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            state                 <= STATE_IDLE;
            iteration             <= 6'd0;
            numerator_latched     <= 48'd0;
            denominator_b_latched <= 32'd1;
            dividend_shift        <= 48'd0;
            quotient_shift        <= 48'd0;
            remainder_shift       <= 33'd0;
            divisor               <= 32'd1;
            quotient_r_pending    <= 48'd0;
            O_done                <= 1'b0;
            O_quotient_r          <= 48'd0;
            O_quotient_b          <= 48'd0;
        end
        else if(I_frame_start) begin
            state                 <= STATE_IDLE;
            iteration             <= 6'd0;
            numerator_latched     <= 48'd0;
            denominator_b_latched <= 32'd1;
            dividend_shift        <= 48'd0;
            quotient_shift        <= 48'd0;
            remainder_shift       <= 33'd0;
            divisor               <= 32'd1;
            quotient_r_pending    <= 48'd0;
            O_done                <= 1'b0;
            O_quotient_r          <= 48'd0;
            O_quotient_b          <= 48'd0;
        end
        else begin
            O_done <= 1'b0;
            case(state)
                STATE_IDLE: begin
                    if(I_start) begin
                        numerator_latched      <= I_numerator;
                        denominator_b_latched <= (I_denominator_b == 0) ?
                                                  32'd1 : I_denominator_b;
                        dividend_shift  <= I_numerator;
                        quotient_shift  <= 48'd0;
                        remainder_shift <= 33'd0;
                        divisor         <= (I_denominator_r == 0) ?
                                           32'd1 : I_denominator_r;
                        iteration       <= 6'd0;
                        state           <= STATE_DIV_R;
                    end
                end

                STATE_DIV_R,
                STATE_DIV_B: begin
                    dividend_shift  <= {dividend_shift[46:0],1'b0};
                    quotient_shift  <= next_quotient;
                    remainder_shift <= next_remainder;
                    if(iteration == 6'd47) begin
                        if(state == STATE_DIV_R) begin
                            quotient_r_pending <= next_quotient;
                            dividend_shift     <= numerator_latched;
                            quotient_shift     <= 48'd0;
                            remainder_shift    <= 33'd0;
                            divisor            <= denominator_b_latched;
                            iteration          <= 6'd0;
                            state              <= STATE_DIV_B;
                        end
                        else begin
                            O_quotient_r <= quotient_r_pending;
                            O_quotient_b <= next_quotient;
                            O_done       <= 1'b1;
                            state        <= STATE_IDLE;
                        end
                    end
                    else begin
                        iteration <= iteration + 6'd1;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end
endmodule





// Apply a subtle 1/64 red and blue balance lift to reduce the observed green
// cast. Gains use Q16 unity = 0x10000; clamp at the 20-bit maximum.
module awb_gain_bias (
    input  wire [47:0] I_gain_q16,
    output wire [19:0] O_gain_q16
);
    wire [20:0] adjusted_gain = {1'b0,I_gain_q16[19:0]} +
                                 {7'd0,I_gain_q16[19:6]};
    assign O_gain_q16 = ((|I_gain_q16[47:20]) || adjusted_gain[20]) ?
                        20'hfffff : adjusted_gain[19:0];
endmodule
