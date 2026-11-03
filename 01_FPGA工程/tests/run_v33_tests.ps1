param([string]$ModelSimBin = 'E:\modelsim\win64')
$ErrorActionPreference = 'Stop'
$testRoot = $PSScriptRoot
$simDir = Join-Path $testRoot 'sim_out'
New-Item -ItemType Directory -Force $simDir | Out-Null
$oldTemp = $env:TEMP
$oldTmp = $env:TMP
$taskTemp = Join-Path $simDir 'temp'
New-Item -ItemType Directory -Force $taskTemp | Out-Null
$env:TEMP = $taskTemp
$env:TMP = $taskTemp
Push-Location $simDir
try {
    if (!(Test-Path 'modelsim.ini')) {
        $installRoot = Split-Path $ModelSimBin -Parent
        $ini = [IO.File]::ReadAllText((Join-Path $installRoot 'modelsim.ini'))
        $ini = $ini.Replace('$MODEL_TECH/../', ($installRoot.Replace('\','/') + '/'))
        [IO.File]::WriteAllText((Join-Path $simDir 'modelsim.ini'), $ini)
    }
    if (!(Test-Path 'v33_work')) { & (Join-Path $ModelSimBin 'vlib.exe') v33_work }
    & (Join-Path $ModelSimBin 'vmap.exe') v33_work v33_work
    $topSource = [IO.File]::ReadAllText((Join-Path $testRoot '../user_source/hdl_source/design_top_wrapper.v'))
    $keyBlock = [regex]::Match($topSource, '(?s)// BEGIN V25 KEY CONTROL.*?// END V25 KEY CONTROL').Value
    if (!$keyBlock) { throw 'Top-level key control block missing' }
    $fixture = 'module v25_key_control_fixture(input S_hdmi_pixel_clk,S_hdmi_rst_n,input [3:0] S_switch_hdmi_sync,S_servo_state,input S_color_key_dec,S_color_key_inc,S_algo_key_dec,S_algo_key_inc,output reg [3:0] S_algo_mode,output reg [2:0] S_track_color,output reg [1:0] S_track_shape);wire S_remote_valid=0;wire [15:0] S_remote_command=0;' + "`n" + $keyBlock + "`nendmodule"
    $learnBlock=[regex]::Match($topSource,'(?s)    // Delay learning pulses.*?(?=    // The mode counter)').Value
    $remotePause=[regex]::Match($topSource,'wire S_remote_pause=.*?;').Value
    $remoteStart=[regex]::Match($topSource,'wire S_remote_start=.*?;').Value
    if(!$learnBlock -or !$remotePause -or !$remoteStart) { throw 'Learning/remote routing missing' }
    $teachFixture='module v33_keys_fixture(input S_hdmi_pixel_clk,S_hdmi_rst_n,input [3:0] S_switch_hdmi_sync,S_servo_state,input S_color_key_dec,S_color_key_inc,S_algo_key_dec,S_algo_key_inc,S_remote_valid,input [15:0] S_remote_command,output reg [3:0] S_algo_mode,output reg [2:0] S_track_color,output reg [1:0] S_track_shape,output reg S_learn_prepare,S_learn_start,output O_pause,O_start);'
    $teachFixture+="`n"+$keyBlock+"`n"+$learnBlock+"`n"+$remotePause+"`n"+$remoteStart+"`nassign O_pause=S_remote_pause;assign O_start=S_remote_start;endmodule`n"
    [IO.File]::WriteAllText((Join-Path $simDir 'v33_keys_fixture.sv'),$teachFixture)
    $aeRoute = [regex]::Match($topSource, '\.I_btn\((.*?)\),').Groups[1].Value
    if (!$aeRoute) { throw 'Top-level AE button routing missing' }
    $aeDecode=[regex]::Match($topSource,'S_ae_buttons_blocked_sys<=\((.*?)\);').Groups[1].Value.Replace('S_effective_switch','I_switch')
    if (!$aeDecode) { throw 'Actual AE mode decode missing' }
    $fixture += "`nmodule v25_ae_key_route(input [3:0] I_switch,I_button,output [1:0] buttons); wire S_ae_buttons_blocked_sync=(" + $aeDecode + "); assign buttons=" + $aeRoute + "; endmodule`n"
    [IO.File]::WriteAllText((Join-Path $simDir 'v25_key_control_fixture.sv'), $fixture)
    $control=[regex]::Match($topSource,'(?s)// BEGIN V32 SWITCH ROUTING.*?// END V32 SWITCH ROUTING').Value
    $fps=[regex]::Match($topSource,'(?s)    always @\(posedge S_24m_clk or negedge S_rst_n\) begin\s*if\(!S_rst_n\) begin\s*S_fps60_switch_meta.*?(?=    // K1 cycles)').Value
    if (!$control -or !$fps) { throw 'Actual UART control/routing block missing' }
    $routeFixture='module v32_control_fixture(input I_sys_clk,S_100m_clk,S_hdmi_pixel_clk,S_24m_clk,S_rst_n,S_hdmi_rst_n,I_uart_rx,input [3:0] I_switch,I_button,output [3:0] O_effective_switch,O_switch_hdmi,output [7:0] O_segment_n,O_digit_n,output O_track,O_motion,O_black,O_fps60,output [1:0] O_ae_buttons); reg S_track_enable_async,S_motion_enable_async,S_black_enable_async,S_fps60_switch_meta,S_fps60_switch_sync;wire [3:0] S_switch_hdmi_sync;wire S_command_valid_sys;wire [15:0] S_command_sys;'
    $routeFixture+="`n"+$control+"`n"+$fps+"`nassign O_effective_switch=S_effective_switch;assign O_switch_hdmi=S_switch_hdmi_sync;assign O_track=S_track_enable_async;assign O_motion=S_motion_enable_async;assign O_black=S_black_enable_async;assign O_fps60=S_fps60_switch_sync;assign O_ae_buttons="+$aeRoute+";endmodule`n"
    [IO.File]::WriteAllText((Join-Path $simDir 'v32_control_fixture.sv'),$routeFixture)
    $ispSource=[IO.File]::ReadAllText((Join-Path $testRoot '../user_source/hdl_source/isp/isp_top.v'))
    $muxBlock=[regex]::Match($ispSource,'(?s)    assign algo_mode_pending =.*?(?=  //assign m_aixs_tready)').Value
    if (!$muxBlock) { throw 'Actual ISP mux block missing' }
    $mux='module v29_mux_fixture(input axi4s_video_aclk,I_rst_n,input [3:0] I_algo_mode,input [8:0] frame_starts,output [127:0] O_tdata,output O_tvalid,O_tuser,O_tlast); reg [3:0] algo_mode_active; wire algo_mode_pending;'
    foreach ($name in @('edge','gray','binary','rededge','cartoon','histogram','gaussian','ink','normal')) { $mux+='wire switch_to_'+$name+',select_'+$name+';' }
    $dataNames=@('normal_O_tdata_128','edge_O_tdata_128','gray_O_tdata_128','binary_O_tdata_128','rededge_O_tdata_128','cartoon_O_tdata_128','histogram_data_128')
    $userNames=@('normal_O_tuser_128','edge_O_tuser_128','gray_O_tuser_128','binary_O_tuser_128','rededge_O_tuser_128','cartoon_O_tuser_128','histogram_user_128')
    $validNames=@('normal_O_tvalid_128','edge_O_tvalid_128','gray_O_tvalid_128','binary_O_tvalid_128','rededge_O_tvalid_128','cartoon_O_tvalid_128','histogram_valid_128')
    for($index=0;$index -lt 7;$index++) {
        $mux+='wire [127:0] '+$dataNames[$index]+'=128''d'+$index+';wire '+$userNames[$index]+'=frame_starts['+$index+'];wire '+$validNames[$index]+'=1''b1;'
    }
    $mux+='wire [127:0] spatial_data_128=select_ink ? 128''d8 : 128''d7;wire spatial_user_128=frame_starts[7]|frame_starts[8],spatial_valid_128=1''b1;'
    $mux+='wire edge_O_tlast=1''b1,histogram_chart_last=1''b1,spatial_last=1''b1,spatial_last_128=1''b1,awb_O_tlast=1''b1;'+"`n"+$muxBlock+"`nendmodule"
    [IO.File]::WriteAllText((Join-Path $simDir 'v32_mux_fixture.sv'),$mux)
    $hdl = '../../user_source/hdl_source'
    $sources = @(
        "$hdl/video_in.v", "$hdl/../ip_source/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "$hdl/hdmi_mixer.v", "$hdl/design_top_wrapper.v", "$hdl/isp/isp_top.v",
        "$hdl/uiisp_beta/ae_set.v", "$hdl/key_remove_shakes.v",
        "$hdl/osd_char_lib.v", "$hdl/anlogic_logo_rom.v",
        "$hdl/uics500_cfg/uicfgcs500_720p.v", "$hdl/uics500_cfg/uii2c.v",
        "$hdl/uics500_cfg/uics500reg_720p60.v", "$hdl/uics500_cfg/uics500regAE.v",
        "$hdl/uics500_cfg/SC500GainTbl.v", "$hdl/awb.v", '../tb_v20_camera.sv',
        '../tb_v20_osd.sv', '../tb_v20_ae_latency.sv', '../tb_servo_pan_tracker_modes.sv', '../tb_v20_ae_chain.sv',
        '../tb_v21_gain_table.sv', '../tb_v23_awb_green_bias.sv', '../tb_v24_region_fill.sv', '../tb_v25_histogram.sv', '../tb_v25_histogram_continuous.sv', '../tb_v25_target_selection.sv', '../tb_v25_keys.sv', '../tb_v25_measure_guard.sv', 'v25_key_control_fixture.sv', '../tb_v29_spatial.sv', '../tb_v29_dual_histogram.sv', '../tb_v29_histogram_commit.sv', '../tb_v29_mux.sv', '../tb_v29_gearbox.sv', 'v32_mux_fixture.sv', '../tb_v31_spatial_ddr.sv', '../tb_v31_video_in.sv', '../tb_v32_control.sv', '../tb_v32_display.sv', '../tb_v32_zoom_alarm.sv', '../tb_v32_banner.sv', 'v32_control_fixture.sv', '../tb_v33_learning.sv', '../tb_v33_uart.sv', '../tb_v33_overlay.sv', '../tb_v33_integration.sv', '../tb_v33_control.sv', '../tb_v33_mixer.sv', '../tb_v33_panel_font.sv', '../v32_reference_mixer.sv', '../tb_v33_osd_stream.sv', '../tb_v33_native_uart.sv', 'v33_keys_fixture.sv'
    )
    & (Join-Path $ModelSimBin 'vlog.exe') -sv -work v33_work -l v33_compile.log @sources
    if ($LASTEXITCODE -ne 0) { throw 'Compilation failed' }
    foreach ($test in @('tb_v20_ae_latency','tb_v20_camera','tb_v20_osd','tb_servo_pan_tracker_modes','tb_v20_ae_chain','tb_v21_gain_table','tb_v23_awb_green_bias','tb_v24_region_fill','tb_v25_histogram','tb_v25_histogram_continuous','tb_v25_target_selection','tb_v25_keys','tb_v25_measure_guard','tb_v27_spatial','tb_v27_dual_histogram','tb_v27_histogram_commit','tb_v29_mux','tb_v29_gearbox','tb_v31_spatial_ddr','tb_v31_video_in','tb_v32_control','tb_v32_display','tb_v32_zoom_alarm','tb_v32_banner','tb_v33_learning','tb_v33_uart','tb_v33_overlay','tb_v33_integration','tb_v33_control','tb_v33_mixer','tb_v33_panel_font','tb_v33_osd_stream','tb_v33_native_uart')) {
        & (Join-Path $ModelSimBin 'vsim.exe') -c -lib v33_work -l "${test}_final.log" -do 'run -all; quit -f' $test
        $logText = [IO.File]::ReadAllText((Join-Path $simDir "${test}_final.log"))
        if ($LASTEXITCODE -ne 0 -or $logText -notmatch 'Errors: 0' -or $logText -match '\*\* Fatal:|\*\* Error:') {
            throw "Simulation failed: $test"
        }
        if ($logText -notmatch 'PASS') { throw "No PASS marker: $test" }
    }
    & (Join-Path $ModelSimBin 'vsim.exe') -c -lib v33_work -l tb_v31_spatial_ddr_720p_final.log -gH=720 -gF=3 -do 'run -all; quit -f' tb_v31_spatial_ddr
    $fullLog = [IO.File]::ReadAllText((Join-Path $simDir 'tb_v31_spatial_ddr_720p_final.log'))
    if ($LASTEXITCODE -ne 0 -or $fullLog -notmatch 'Errors: 0' -or $fullLog -notmatch 'PASS tb_v31_spatial_ddr' -or $fullLog -match '\*\* Fatal:|\*\* Error:') {
        throw 'Full 1280x720 spatial/DDR integration failed'
    }
} finally { Pop-Location; $env:TEMP=$oldTemp; $env:TMP=$oldTmp }
