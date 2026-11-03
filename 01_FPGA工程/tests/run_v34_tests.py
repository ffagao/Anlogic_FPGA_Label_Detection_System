from pathlib import Path
import subprocess,os,re,json,sys
T=Path(__file__).resolve().parent;H=T.parent/'user_source/hdl_source';S=T/'sim_out'
S.mkdir(exist_ok=True);(S/'temp').mkdir(exist_ok=True)
os.environ['TEMP']=os.environ['TMP']=str(S/'temp')
B=Path(os.environ.get('MODELSIM_BIN','E:/modelsim/win64'))
def run(exe,args,log):
    with (S/log).open('w',encoding='utf-8') as f:
        p=subprocess.run([str(B/exe),*map(str,args)],cwd=S,stdout=f,stderr=subprocess.STDOUT)
    text=(S/log).read_text(encoding='utf-8',errors='replace')
    if p.returncode or re.search(r'\*\* (?:Fatal|Error):',text):
        print(text[-7000:]);raise SystemExit(f'Failed {log}: {p.returncode}')
    return text
if not (S/'modelsim.ini').exists():
    ini=(B.parent/'modelsim.ini').read_text(errors='replace').replace('$MODEL_TECH/../',B.parent.as_posix()+'/')
    (S/'modelsim.ini').write_text(ini)
if not (S/'v34_work').exists():run('vlib.exe',['v34_work'],'vlib.log')
run('vmap.exe',['v34_work','v34_work'],'vmap.log')
top=(H/'awb.v').read_text(encoding='utf-8-sig')
block=re.search(r'    always @\(posedge I_clk or negedge I_rst_n\)begin\s*if\(!I_rst_n\)begin\s*in_r_r1.*?(?=    ////)',top,re.S)[0]
(S/'v34_awb_lock_fixture.sv').write_text('''module v34_awb_lock_fixture(input I_clk,I_rst_n,I_lock,I_tuser,awb_div_done,input [19:0] in_r_wb_gain,in_b_wb_gain,output reg O_locked,output reg [19:0] in_r_r1,in_b_r1);\n'''+block+'\nendmodule\n')
subprocess.run([sys.executable,str(T/'generate_fixtures.py')],check=True)
subprocess.run([sys.executable,str(T/'generate_v35_fixtures.py')],check=True)
manifest=json.loads((T/'v34_test_manifest.json').read_text())
sources=[H/p for p in ['video_in.v','../ip_source/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v','hdmi_mixer.v','design_top_wrapper.v','isp/isp_top.v','isp/data96_128/data96_128.v','uiisp_beta/ae_set.v','key_remove_shakes.v','osd_char_lib.v','anlogic_logo_rom.v','uics500_cfg/uicfgcs500_720p.v','uics500_cfg/uii2c.v','uics500_cfg/uics500reg_720p60.v','uics500_cfg/uics500regAE.v','uics500_cfg/SC500GainTbl.v','awb.v']]
sources+=list(H.glob('label_*.v'))+[H/'v34_logo_rom.v']
sources += [H/'barcode_station.v', H/'barcode_code128_pattern.v']
sources += [T/'tb_v42_dynamic_controller.sv', T/'tb_v43_barcode.sv', T/'tb_v43_barcode_pixels.sv']
sources += [H/'motion_region_counter.v', H/'uart_telemetry.v']
sources += [T/'tb_motion_region_counter.sv', T/'tb_motion_regions_stream.sv', T/'tb_uart_telemetry.sv']
sources += [H/'video_out.v',H/'../ip_source/w128_d512_fifo/w128_d512_fifo.v',T/'v40_tracker_reference.v']
sources+=[T/(name+'.sv') for name in manifest['legacy']+manifest['new']]
sources+=[T/'v34_fixtures.sv',T/'v32_reference_mixer.sv',S/'v34_awb_lock_fixture.sv']
sources+=[T/'label'/(name+'.sv') for name in manifest['label']]
sources+=list((T/'label/reference').glob('*.v'))+[T/'label/label_logo_half_rom.v']
sources += [H/'isp/edge_detect_96.v',T/'edge_detect_96_reference.sv',T/'v35_ref_fixture.sv',T/'v34_scene_controller_baseline.v',T/'v35_mixer_baseline.v',H/'vtc/uivtc.v',T/'v37_servo_baseline.v',T/'v38_servo_baseline.v']
run('vlog.exe',['-sv','-work','v34_work','-l','v34_compile.log',*sources],'compile_console.log')
if '--compile-only' in sys.argv:
    print('COMPILE PASS');sys.exit(0)
chosen=sys.argv[1:] or manifest['new']+manifest['legacy']+manifest['label']
for name in chosen:
    print('Running',name,flush=True)
    result=run('vsim.exe',['-c','-lib','v34_work','-l',name+'.log','-do','onerror {quit -code 1 -f}; run -all; quit -f',name],name+'_console.log')
    if 'PASS' not in result:raise SystemExit('PASS marker absent: '+name)
    print('PASS',name,flush=True)
print('ALL PASS:',len(chosen))
