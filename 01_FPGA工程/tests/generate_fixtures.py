from pathlib import Path
import re
T=Path(__file__).resolve().parent
H=T.parent/'user_source/hdl_source'
def read(p):return p.read_text(encoding='utf-8-sig')
def write(p,s):p.write_text(s,encoding='utf-8',newline='\n')

top=read(H/'design_top_wrapper.v')
keys=re.search(r'// BEGIN V25 KEY CONTROL.*?// END V25 KEY CONTROL',top,re.S)[0]
learn=re.search(r'    // Learning is controlled.*?(?=    // The mode counter)',top,re.S)[0]
fixture='''module v34_keys_fixture(input S_hdmi_pixel_clk,S_hdmi_rst_n,input [3:0] S_switch_hdmi_sync,S_servo_state,input S_color_key_dec,S_color_key_inc,S_algo_key_dec,S_algo_key_inc,output reg [3:0] S_algo_mode,output reg [2:0] S_track_color,output reg [1:0] S_track_shape,output reg S_learn_prepare,S_learn_start);
''' + "wire S_remote_valid=0;wire [1:0] S_remote_kind=0;wire [3:0] S_remote_value=0;\n"+keys+'\n'+learn+'\nendmodule\n'
control=re.search(r'// BEGIN V32 SWITCH ROUTING.*?// END V32 SWITCH ROUTING',top,re.S)[0]
fps=re.search(r'    always @\(posedge S_24m_clk or negedge S_rst_n\) begin\n        if\(!S_rst_n\) begin\n            S_fps60_switch_meta.*?(?=    // K1 cycles)',top,re.S)[0]
fixture+='''module v34_control_fixture(input I_sys_clk,S_100m_clk,S_hdmi_pixel_clk,S_24m_clk,S_rst_n,S_hdmi_rst_n,I_uart_rx,input [3:0] I_switch,output [3:0] O_effective_switch,O_switch_hdmi,output [7:0] O_segment_n,O_digit_n,output O_track,O_motion,O_black,O_fps60,O_ae_blocked);
reg S_track_enable_async,S_motion_enable_async,S_black_enable_async,S_fps60_switch_meta,S_fps60_switch_sync;
wire [1:0] S_label_result_hdmi=0;wire [3:0] S_switch_hdmi_sync;wire [7:0] S_mode_segment_n,S_mode_digit_n;
'''+control+'\n'+fps+'''
assign O_effective_switch=S_effective_switch;assign O_switch_hdmi=S_switch_hdmi_sync;
assign O_segment_n=S_mode_segment_n;assign O_digit_n=S_mode_digit_n;
assign O_track=S_track_enable_async;assign O_motion=S_motion_enable_async;assign O_black=S_black_enable_async;
assign O_fps60=S_fps60_switch_sync;assign O_ae_blocked=S_ae_buttons_blocked_sync;
endmodule
'''
isp=read(H/'isp/isp_top.v');mux=re.search(r'    assign algo_mode_pending =.*?(?=  //assign m_aixs_tready)',isp,re.S)[0]
fixture+='''module v34_mux_fixture(input axi4s_video_aclk,I_rst_n,input [3:0] I_algo_mode,input [4:0] frame_starts,output [127:0] O_tdata,output O_tvalid,O_tuser,O_tlast);
reg [3:0] algo_mode_active;wire algo_mode_pending;wire edge_frame_red=I_algo_mode==4'd5;
'''
for name in ('edge','gray','binary','histogram','normal'):fixture+=f'wire switch_to_{name},select_{name};\n'
for i,name in enumerate(('normal','edge','gray','binary','histogram')):
    data='histogram_data_128' if i==4 else name+'_O_tdata_128'
    user='histogram_user_128' if i==4 else name+'_O_tuser_128'
    valid='histogram_valid_128' if i==4 else name+'_O_tvalid_128'
    fixture+=f"wire [127:0] {data}=128'd{i};wire {user}=frame_starts[{i}],{valid}=1'b1;\n"
fixture+="wire edge_O_tlast=1'b1,histogram_chart_last=1'b1,awb_O_tlast=1'b1;\n"+mux+'\nendmodule\n'
write(T/'v34_fixtures.sv',fixture)


# Compile the actual histogram/plot/pack instances from the current ISP source.
a=isp.index('    histogram_equalizer4 u_histogram_equalizer4 (')
b=isp.index('    wire [23:0]  gray_pix0',a)
hist="module v34_histogram_pipeline_fixture(input axi4s_video_aclk,I_rst_n,input [95:0] awb_O_tdata,input awb_O_tvalid,awb_O_tuser,awb_O_tlast,output [127:0] histogram_data_128,output histogram_user_128,histogram_valid_128);\nwire [3:0] I_algo_mode=4'd4,algo_mode_active=4'd4;\nwire [95:0] histogram_rgb,histogram_chart_rgb;\nwire histogram_valid,histogram_user,histogram_last,histogram_chart_valid,histogram_chart_user,histogram_chart_last;\nwire histogram_bin_valid,histogram_done;wire [7:0] histogram_bin_index;\nwire [17:0] histogram_bin_count,histogram_after_count;\n"
write(T/'v34_fixtures.sv',fixture+hist+isp[a:b]+'\nendmodule\n')

# Actual shared edge detector / paint / pack instances for streaming verification.
a=isp.index('edge_detect_96 #(');b=isp.index('    data_96bit_to_128bit u_normal_',a)
c=isp.index('    // BEGIN V37 SHARED EDGE PAINT');d=isp.index('    data_96bit_to_128bit u_gray_',c)
edge="module v37_edge_pipeline_fixture(input axi4s_video_aclk,I_rst_n,input [3:0] I_algo_mode,input [95:0] awb_O_tdata,input awb_O_tvalid,awb_O_tuser,awb_O_tlast,output [127:0] edge_O_tdata_128,output edge_O_tvalid_128,edge_O_tuser_128);\nreg edge_frame_red;wire awb_O_tready=1'b1;wire [95:0] edge_O_tdata;wire edge_O_tlast,edge_O_tuser,edge_O_tvalid,edge_O_tready;\n"
with (T/'v34_fixtures.sv').open('a',encoding='utf-8') as f:f.write(edge+isp[a:b]+isp[c:d]+'\nendmodule\n')

# Compile the actual mode/action bridge, key routing and servo instance together.
servo=top[top.index('    servo_pan_tracker u_servo_pan_tracker ('):top.index('    always @(posedge S_hdmi_pixel_clk',top.index('    servo_pan_tracker u_servo_pan_tracker ('))]
remote="""module v38_remote_fixture(input I_sys_clk,S_100m_clk,S_hdmi_pixel_clk,S_24m_clk,S_rst_n,S_hdmi_rst_n,I_uart_rx,input [3:0] I_switch,physical_keys);
reg S_track_enable_async,S_motion_enable_async,S_black_enable_async,S_fps60_switch_meta,S_fps60_switch_sync;
reg [3:0] S_algo_mode;reg [2:0] S_track_color;reg [1:0] S_track_shape;reg S_learn_prepare,S_learn_start;
wire [3:0] S_switch_hdmi_sync,S_servo_state;wire [7:0] S_mode_segment_n,S_mode_digit_n;
wire [1:0] S_label_result_hdmi;wire [11:0] S_pan_pulse_us,S_tilt_pulse_us;
wire S_servo_measure_update=0,S_servo_measure_valid=0,S_servo_measure_large=0;wire signed [12:0] S_servo_measure_dx=0,S_servo_measure_dy=0;
wire O_servo_pan_pwm,O_servo_tilt_pwm,S_servo_buzzer_n;
"""+control+'\n'+fps+"""
wire S_color_key_dec=physical_keys[0]|S_remote_keys[0],S_color_key_inc=physical_keys[1]|S_remote_keys[1];
wire S_algo_key_dec=physical_keys[2]|S_remote_keys[2],S_algo_key_inc=physical_keys[3]|S_remote_keys[3];
"""+keys+'\n'+learn+'\n'+servo+"""
ae_set ae(.I_clk(S_24m_clk),.I_rst(!S_rst_n),.I_btn(2'b11),.I_fps_60(S_fps60_switch_sync),
 .I_frame_luma(8'd96),.I_luma_toggle(1'b0),.I_ae_cfg_done(1'b1),.I_ae_error(1'b0),.I_lock(1'b0),.O_locked(),
 .I_cam_cfg_done(1'b1),.O_ae_req(),.O_ae(),.O_ag(),.O_debug(),.O_debug_toggle(),
 .I_remote_dec(S_remote_ae_dec),.I_remote_inc(S_remote_ae_inc));
wire learned_valid;wire [3:0] learn_status;
target_color_learning learn_engine(.I_clk(S_hdmi_pixel_clk),.I_rst_n(S_hdmi_rst_n),
 .I_selected(S_track_color==5),.I_learn_enable(S_switch_hdmi_sync==4),.I_prepare(S_learn_prepare),.I_start(S_learn_start),
 .I_de(1'b0),.I_x(12'd0),.I_y(12'd0),.I_rgb(24'd0),.I_frame_id(24'd0),.O_valid(learned_valid),
 .O_status(learn_status),.O_rgb(),.O_generation(),.O_mask(),.O_preparing());
label_application lab(.I_clk(S_hdmi_pixel_clk),.I_rst_n(S_hdmi_rst_n),.I_enable(S_switch_hdmi_sync==5),
 .I_de(1'b0),.I_keys_n(4'hf),.I_x(12'd0),.I_y(12'd0),.I_rgb(24'd0),.I_frame_id(24'd0),.I_imaging_locked(1'b1),
 .I_remote_action(S_label_remote_action),.O_imaging_lock(),.O_hit(),.O_color(),.O_buzzer_n(),
 .O_seg_sel(),.O_seg_dig(),.O_display_result(S_label_result_hdmi));
endmodule
"""
with (T/'v34_fixtures.sv').open('a',encoding='utf-8') as f:f.write(remote)
