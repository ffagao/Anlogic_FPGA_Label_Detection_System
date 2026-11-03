from pathlib import Path
import subprocess, os, re, shutil, json, hashlib

ROOT=Path(__file__).resolve().parent
PROJECT=Path(r'E:/90806/codex/2026-11-01/ni-x/work/v45_project/fpga')
BIN=Path(r'E:/modelsim/win64')
CASES=['tb_v42_dynamic_controller','tb_v43_barcode_pixels','tb_uart_telemetry','tb_v43_barcode']
RTL=['label_scene_controller.v','label_barcode_session.v','barcode_station.v','barcode_code128_pattern.v','label_char_lib.v','uart_telemetry.v']
os.chdir(ROOT)
(ROOT/'rtl').mkdir(exist_ok=True);(ROOT/'testbenches').mkdir(exist_ok=True)
hashes={}
for name in RTL:
    p=PROJECT/'user_source/hdl_source'/name
    shutil.copy2(p,ROOT/'rtl'/name)
    hashes['rtl/'+name]=hashlib.sha256(p.read_bytes()).hexdigest()
for name in CASES:
    p=PROJECT/'tests'/(name+'.sv')
    shutil.copy2(p,ROOT/'testbenches'/p.name)
    hashes['testbenches/'+p.name]=hashlib.sha256(p.read_bytes()).hexdigest()
    if name=='tb_uart_telemetry':
        aliases='\n'.join(f' wire [7:0] rx_data{i:02d}=data[{i}];' for i in range(36))
        (ROOT/'testbenches'/p.name).write_text(p.read_text().replace('endmodule',aliases+'\nendmodule'))
(ROOT/'source_hashes.json').write_text(json.dumps(hashes,indent=2),encoding='utf-8')
def run(exe,args,log):
    p=subprocess.run([str(BIN/exe),*args],stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    out=p.stdout.decode('utf-8',errors='replace')
    (ROOT/log).write_text(out,encoding='utf-8')
    if p.returncode or re.search(r'\*\* (?:Error|Fatal):',out):
        raise RuntimeError(out[-5000:])
    return out
if not (ROOT/'work').exists():run('vlib.exe',['work'],'vlib.log')
# Explicit ini avoids dependence on the original project's simulation database.
ini=(BIN.parent/'modelsim.ini').read_text(errors='replace').replace('$MODEL_TECH/../',BIN.parent.as_posix()+'/')
(ROOT/'modelsim.ini').write_text(ini)
sources=[str(ROOT/'rtl'/name) for name in RTL]+[str(ROOT/'testbenches'/(n+'.sv')) for n in CASES]
run('vlog.exe',['-sv','-work','work',*sources],'compile.log')
summary={}
for name in CASES:
    # Log the unchanged benches; include unpacked receiver-memory words explicitly.
    commands=['onerror {quit -code 1 -f}', 'onfinish stop', 'log -r /*',f'vcd file {name}.vcd',f'vcd add /{name}/*']
    if name=='tb_v42_dynamic_controller':
        commands += [f'vcd add /{name}/dut/auto_phase /{name}/dut/auto_count']
    if name=='tb_v43_barcode':
        commands += [f'vcd add /{name}/dut/decoder_hit /{name}/dut/confirmed /{name}/dut/done /{name}/dut/order /{name}/dut/counter']
    commands += ['run -all','vcd flush','vcd off','quit -f']
    (ROOT/(name+'_capture.do')).write_text('\n'.join(commands)+'\n')
    out=run('vsim.exe',['-c','-voptargs=+acc','-wlf',name+'.wlf','-do','do '+name+'_capture.do','work.'+name],name+'.log')
    if 'PASS' not in out: raise RuntimeError('PASS missing: '+name)
    warnings=len(re.findall(r'\*\* Warning:',out))
    summary[name]={'pass':True,'warnings':warnings,'errors':len(re.findall(r'\*\* (?:Error|Fatal):',out))}
    fields={
      'tb_v42_dynamic_controller':['clk','rst_n','learn','sample','valid','reference_set','dut/auto_phase','dut/auto_count','result','locked','total','passes','unknowns'],
      'tb_v43_barcode_pixels':['clk','rst','de','x','y','rgb','candidate','hit','payload'],
      'tb_uart_telemetry':['clk','rst','tx']+[f'rx_data{i:02d}' for i in range(36)]+['checksum'],
      'tb_v43_barcode':['clk','rst','pass','key','ticket','active','dut/decoder_hit','dut/confirmed','dut/done','dut/order','dut/counter'],
    }[name]
    load=[f'# Use the ModelSim GUI (not -c), in this directory: do {name}_load.do','view wave','catch {dataset close captured}',f'dataset open {name}.wlf captured']
    for field in fields:
        label='data['+str(int(field[-2:]))+']' if field.startswith('rx_data') else field.replace('/','.')
        load.append(f'add wave -radix hexadecimal -label {{{label}}} captured:/{name}/{field}')
    load.append('wave zoom full')
    (ROOT/(name+'_load.do')).write_text('\n'.join(load)+'\n')
(ROOT/'results.json').write_text(json.dumps(summary,indent=2))
print(json.dumps(summary,indent=2))
