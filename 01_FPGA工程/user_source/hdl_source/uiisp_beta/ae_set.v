/*******************************MILIANKE*******************************
* Automatic exposure controller for the SC500 720p30/60 capture path.
* KEY0/KEY1 adjust the desired image brightness. The controller uses
* exposure first in dark scenes and analogue gain only after exposure
* reaches its limit.
*********************************************************************/

module ae_set
(
    input  wire        I_clk,
    input  wire        I_rst,
    input  wire [1:0]  I_btn,
    input  wire        I_fps_60,
    input  wire [7:0]  I_frame_luma,
    input  wire        I_luma_toggle,
    input  wire        I_ae_cfg_done,
    input  wire        I_ae_error,
    input wire I_lock,
    output reg O_locked,
    input  wire        I_cam_cfg_done,
    output wire        O_ae_req,
    output wire [15:0] O_ae,
    output wire [15:0] O_ag,
    output wire [71:0] O_debug,
    output wire O_debug_toggle,
    input wire I_remote_dec,I_remote_inc
);

localparam [15:0] AE_MIN = 16'd32;
// SC500CS manual exposure limit: 2 * frame_length - 10 half-lines.
localparam [15:0] AE_MAX_30 = 16'd3990; // VTS 2000
localparam [15:0] AE_MAX_60 = 16'd1990; // VTS 1000
localparam [15:0] AG_MIN = 16'd16;
// G=143 reaches 15.75x analog gain; G=191 adds digital gain through 3x.
localparam [15:0] AG_MAX = 16'd191;
localparam [7:0]  TARGET_DEFAULT = 8'd96;
localparam [7:0]  TARGET_MIN = 8'd48;
localparam [7:0]  TARGET_MAX = 8'd160;
localparam [7:0]  TARGET_STEP = 8'd8;
localparam [7:0]  AE_DEADBAND = 8'd6;

wire key_target_dec_physical,key_target_inc_physical;
wire key_target_dec=key_target_dec_physical | (I_remote_dec===1'b1);
wire key_target_inc=key_target_inc_physical | (I_remote_inc===1'b1);

key_remove_shakes u_key_target_dec (
    .I_clk          (I_clk),
    .I_rst_n        (~I_rst),
    .I_key_in       (I_btn[0]),
    .O_key_trig_out (key_target_dec_physical)
);

key_remove_shakes u_key_target_inc (
    .I_clk          (I_clk),
    .I_rst_n        (~I_rst),
    .I_key_in       (I_btn[1]),
    .O_key_trig_out (key_target_inc_physical)
);

reg [7:0] target_luma;
always @(posedge I_clk or posedge I_rst) begin
    if(I_rst)
        target_luma <= TARGET_DEFAULT;
    else if(!I_lock && key_target_dec && !key_target_inc)
        target_luma <= (target_luma > TARGET_MIN) ?
                       target_luma - TARGET_STEP : target_luma;
    else if(!I_lock && key_target_inc && !key_target_dec)
        target_luma <= (target_luma < TARGET_MAX) ?
                       target_luma + TARGET_STEP : target_luma;
end

// Synchronize the frame result from the CSI pixel clock domain. The luma
// value is held stable for a complete frame; the toggle marks each update.
reg [7:0] luma_meta;
reg [7:0] luma_sync;
reg       toggle_meta;
reg       toggle_sync;
reg       toggle_sync_d;
wire      new_luma = toggle_sync ^ toggle_sync_d;

always @(posedge I_clk or posedge I_rst) begin
    if(I_rst) begin
        luma_meta     <= 8'd0;
        luma_sync     <= 8'd0;
        toggle_meta   <= 1'b0;
        toggle_sync   <= 1'b0;
        toggle_sync_d <= 1'b0;
    end
    else begin
        luma_meta     <= I_frame_luma;
        luma_sync     <= luma_meta;
        toggle_meta   <= I_luma_toggle;
        toggle_sync   <= toggle_meta;
        toggle_sync_d <= toggle_sync;
    end
end

reg        frame_div;
reg [15:0] r_ae_set;
reg [15:0] r_ag_set;
wire [8:0] luma_error = (target_luma >= luma_sync) ?
                        ({1'b0,target_luma} - {1'b0,luma_sync}) :
                        ({1'b0,luma_sync} - {1'b0,target_luma});
wire [15:0] ae_step = (luma_error > 9'd40) ? 16'd256 :
                      (luma_error > 9'd20) ? 16'd128 : 16'd32;
wire [15:0] ag_step = (luma_error > 9'd40) ? 16'd4 :
                      (luma_error > 9'd20) ? 16'd2 : 16'd1;
wire [15:0] ae_max = I_fps_60 ? AE_MAX_60 : AE_MAX_30;

// Run the controller once every two frames. Exposure is preferred when the
// image is dark; gain is reduced first when it is bright to minimize noise.
always @(posedge I_clk or posedge I_rst) begin
    if(I_rst) begin
        frame_div <= 1'b0;
        r_ae_set  <= 16'd3000;
        r_ag_set  <= 16'd80;
    end
    else if(I_fps_60 && (r_ae_set > AE_MAX_60)) begin
        // Clamp immediately before the camera shortens VTS for 60 FPS.
        r_ae_set <= AE_MAX_60;
    end
    else if(new_luma) begin
        frame_div <= ~frame_div;
        if(!I_lock && frame_div && I_cam_cfg_done && I_ae_cfg_done) begin
            if(({1'b0,luma_sync} + AE_DEADBAND) < {1'b0,target_luma}) begin
                if(r_ae_set < ae_max)
                    r_ae_set <= ((r_ae_set + ae_step) > ae_max) ?
                                ae_max : r_ae_set + ae_step;
                else if(r_ag_set < AG_MAX)
                    r_ag_set <= ((r_ag_set + ag_step) > AG_MAX) ?
                                AG_MAX : r_ag_set + ag_step;
            end
            else if({1'b0,luma_sync} > ({1'b0,target_luma} + AE_DEADBAND)) begin
                if(r_ag_set > AG_MIN)
                    r_ag_set <= (r_ag_set > (AG_MIN + ag_step)) ?
                                r_ag_set - ag_step : AG_MIN;
                else if(r_ae_set > AE_MIN)
                    r_ae_set <= (r_ae_set > (AE_MIN + ae_step)) ?
                                r_ae_set - ae_step : AE_MIN;
            end
        end
    end
end

// Send the five exposure/gain registers only after the previous I2C update
// has completed. The reset values match the 30 FPS initialization table.
reg [15:0] r_ae;
reg [15:0] r_ag;
reg        r_ae_req;
assign O_ae = r_ae;
assign O_ag = r_ag;
assign O_ae_req = r_ae_req;

always @(posedge I_clk or posedge I_rst) begin
    if(I_rst) begin
        r_ae_req <= 1'b0;
        r_ae     <= 16'd3000;
        r_ag     <= 16'd80;
    end
    else if(r_ae_req) begin
        r_ae_req <= 1'b0;
    end
    else if(((r_ae != r_ae_set) || (r_ag != r_ag_set)) &&
            I_cam_cfg_done && I_ae_cfg_done) begin
        r_ae     <= r_ae_set;
        r_ag     <= r_ag_set;
        r_ae_req <= 1'b1;
    end
end

// A lock is acknowledged only after the final requested register set has
// completed I2C. Eight quiet clocks also cover request/done NBA handoff.
reg [3:0] lock_quiet;
always @(posedge I_clk or posedge I_rst) begin
    if(I_rst) begin O_locked<=0;lock_quiet<=0;end
    else if(!I_lock || I_ae_error || !I_cam_cfg_done || !I_ae_cfg_done || r_ae_req ||
            r_ae!=r_ae_set || r_ag!=r_ag_set) begin O_locked<=0;lock_quiet<=0;end
    else if(lock_quiet<8) begin lock_quiet<=lock_quiet+1'b1;O_locked<=0;end
    else O_locked<=1;
end


// Observability: completed I2C sequences are not sensor readback/ACK proof.
reg [7:0] meter_count, write_count;
reg cfg_done_d;
reg [23:0] meter_age;
always @(posedge I_clk or posedge I_rst) begin
    if(I_rst) begin
        meter_count<=0; write_count<=0; cfg_done_d<=0;
        meter_age<=24'hffffff;
    end else begin
        cfg_done_d<=I_ae_cfg_done;
        if(I_cam_cfg_done && I_ae_cfg_done && !cfg_done_d)
            write_count<=write_count+1'b1;
        if(new_luma) begin meter_count<=meter_count+1'b1; meter_age<=0; end
        else if(!(&meter_age)) meter_age<=meter_age+1'b1;
    end
end
wire [3:0] ae_status = I_ae_error ? 4'd6 : O_locked ? 4'd7 : meter_age[23] ? 4'd0 :
    (!I_cam_cfg_done || !I_ae_cfg_done) ? 4'd1 :
    (luma_error<=AE_DEADBAND) ? 4'd5 :
    (luma_sync<target_luma) ?
        ((r_ae>=ae_max && r_ag>=AG_MAX) ? 4'd4 : 4'd2) :
        ((r_ae<=AE_MIN && r_ag<=AG_MIN) ? 4'd4 : 4'd3);
ae_debug_snapshot u_debug_snapshot (
    .I_clk(I_clk), .I_rst(I_rst), .I_luma(luma_sync),
    .I_target(target_luma), .I_exposure(r_ae[11:0]), .I_gain(r_ag[7:0]),
    .I_meter_count(meter_count), .I_write_count(write_count),
    .I_status(ae_status), .O_data(O_debug), .O_toggle(O_debug_toggle)
);

endmodule

// One shared shift/add-3 converter, outside the video pixel path. A bundled
// snapshot is held for 65536 clocks before the next toggle (about 2.7 ms).
module ae_debug_snapshot (
    input wire I_clk, I_rst,
    input wire [7:0] I_luma, I_target, I_gain, I_meter_count, I_write_count,
    input wire [11:0] I_exposure,
    input wire [3:0] I_status,
    output reg [71:0] O_data,
    output reg O_toggle
);
    reg [15:0] timer;
    reg [1:0] field;
    reg [3:0] bit_count;
    reg busy;
    reg [11:0] value;
    reg [15:0] bcd, adjusted;
    reg [7:0] target, gain;
    reg [11:0] exposure;
    reg [71:0] packet;
    integer n;
    always @* begin
        adjusted=bcd;
        for(n=0;n<4;n=n+1)
            if(bcd[n*4+:4]>=5) adjusted[n*4+:4]=bcd[n*4+:4]+4'd3;
    end
    wire [15:0] next_bcd={adjusted[14:0],value[11]};
    always @(posedge I_clk or posedge I_rst) begin
        if(I_rst) begin
            timer<=0; field<=0; bit_count<=0; busy<=0; value<=0;
            bcd<=0; target<=0; gain<=0; exposure<=0; packet<=0;
            O_data<=0; O_toggle<=0;
        end else begin
            timer<=timer+1'b1;
            if(timer==0) begin
                target<=I_target; gain<=I_gain; exposure<=I_exposure;
            packet<={I_status,52'd0,I_meter_count,I_write_count};
                value<={4'd0,I_luma}; bcd<=0; field<=0; bit_count<=0; busy<=1;
            end else if(busy) begin
                bcd<=next_bcd; value<={value[10:0],1'b0};
                if(bit_count==11) begin
                    bit_count<=0; bcd<=0; field<=field+1'b1;
                    case(field)
                        0: begin packet[67:56]<=next_bcd[11:0]; value<={4'd0,target}; end
                        1: begin packet[55:44]<=next_bcd[11:0]; value<=exposure; end
                        2: begin packet[43:28]<=next_bcd; value<={4'd0,gain}; end
                        3: begin
                            O_data<={packet[71:28],next_bcd[11:0],packet[15:0]};
                            O_toggle<=~O_toggle; busy<=0;
                        end
                    endcase
                end else bit_count<=bit_count+1'b1;
            end
        end
    end
endmodule
