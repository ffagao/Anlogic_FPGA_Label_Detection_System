from pathlib import Path
import re,json,bisect
from collections import defaultdict
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator
R=Path(__file__).resolve().parent
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':11})

def read(name):
    scopes=[];ids={};history=defaultdict(list);width={};t=0;end=0
    with (R/(name+'.vcd')).open() as f:
        for line in f:
            s=line.strip()
            if s.startswith('$dumpoff'):break
            if s.startswith('$scope'):scopes.append(s.split()[2])
            elif s.startswith('$upscope'):scopes.pop()
            elif s.startswith('$var'):
                z=s.split();w=int(z[2]);code=z[3];ref=z[4];idx=None
                if w==1 and len(z)>6 and re.fullmatch(r'\[\d+\]',z[5]):idx=int(z[5][1:-1])
                path='.'.join(scopes[1:]+[ref]);ids[code]=(path,w,idx);width[path]=max(width.get(path,0),(idx+1 if idx is not None else w))
            elif s.startswith('#'):t=int(s[1:])/1000;end=t
            elif s and not s.startswith('$'):
                if s[0] in 'bB':
                    z=s[1:].split()
                    if len(z)!=2:continue
                    value,code=z
                elif s[0] in '01xXzZ':value,code=s[0].lower(),s[1:]
                else:continue
                if code in ids:
                    path,w,idx=ids[code];history[path].append((t,value,idx))
    signals={}
    for path,events in history.items():
        w=width[path];bits=['x']*w;out=[]
        for ti,value,idx in events:
            if idx is not None:bits[w-1-idx]=value
            else:bits=list(value.zfill(w))
            val=''.join(bits)
            if out and out[-1][0]==ti:out[-1]=(ti,val)
            elif not out or out[-1][1]!=val:out.append((ti,val))
        signals[path]=(w,out)
    return signals,end

def val(bits,fmt='hex'):
    if any(c in bits.lower() for c in 'xz'):return 'X' if 'x' in bits.lower() else 'Z'
    n=int(bits,2)
    return str(n) if fmt=='dec' else f'{n:0{(len(bits)+3)//4}X}'

def edges(signals,key,num):return [t for t,b in signals[key][1] if not any(c in b.lower() for c in 'xz') and int(b,2)==num]

def plot(name,rows,limits,filename,title,notes='',markers=()):
    s,end=DATA[name];lo,hi=limits
    fig,ax=plt.subplots(figsize=(16,max(5,0.47*len(rows)+1.9)),dpi=170)
    fig.patch.set_facecolor('#f5f8fc');ax.set_facecolor('white')
    labels=[]
    for i,row in enumerate(rows):
        key,fmt,label=row if len(row)==3 else (*row,row[0])
        w,ev=s[key];y=len(rows)-1-i;labels.append(label)
        ax.axhspan(y-.46,y+.46,color=('#f2f6fb' if i%2==0 else '#fff'),zorder=0)
        times=[x[0] for x in ev];j=max(0,bisect.bisect_right(times,lo)-1)
        subset=ev[j:bisect.bisect_right(times,hi)]
        if not subset:continue
        if w==1:
            xx=[max(lo,t) for t,b in subset]+[hi];bb=[(int(b,2) if b in ('0','1') else .5) for t,b in subset];yy=[y-.28+.56*v for v in bb]+[y-.28+.56*bb[-1]]
            ax.step(xx,yy,where='post',color='#006c67',lw=1)
        else:
            for k,(t,b) in enumerate(subset):
                a=max(lo,t);z=min(hi,subset[k+1][0] if k+1<len(subset) else hi)
                ax.plot([a,z],[y-.27,y-.27],color='#205a9e',lw=.8);ax.plot([a,z],[y+.27,y+.27],color='#205a9e',lw=.8)
                ax.plot([a,a],[y-.27,y+.27],color='#205a9e',lw=.6)
                if z-a>(hi-lo)*.018:ax.text((a+z)/2,y,val(b,fmt),ha='center',va='center',fontsize=9,color='#123d67',clip_on=True)
    for t,text in markers:
        if lo<=t<=hi:
            ax.axvline(t,color='#c04d22',lw=1,ls='--',alpha=.7)
            ax.text(t,len(rows)-.35,text,ha='center',va='bottom',color='#a63811',fontsize=9)
    ax.set_yticks(range(len(rows)-1,-1,-1),labels)
    ax.set_xlim(lo,hi);ax.set_ylim(-.6,len(rows)+.2)
    ax.xaxis.set_major_locator(MaxNLocator(10));ax.grid(axis='x',alpha=.18)
    ax.set_xlabel('Simulation time (ns)');ax.tick_params(axis='y',length=0,pad=10)
    for side in ['top','right','left']:ax.spines[side].set_visible(False)
    fig.suptitle(title,x=.03,ha='left',fontsize=16,fontweight='bold',color='#173858')
    fig.text(.03,.018,'Actual ModelSim VCD data, rendered for clarity | PASS | '+notes,fontsize=9,color='#43546c')
    fig.subplots_adjust(left=.20,right=.98,top=.88,bottom=.13 if len(rows)<22 else .07)
    fig.savefig(R/(filename+'.png'));plt.close(fig)

names=['tb_v42_dynamic_controller','tb_v43_barcode_pixels','tb_uart_telemetry','tb_v43_barcode']
DATA={n:read(n) for n in names}
meta={}
d=DATA[names[0]][0];p=edges(d,'result',1)[0];u=edges(d,'result',3)[-1];ref=edges(d,'reference_set',1)[0]
meta['dynamic']={'reference_ns':ref,'pass_ns':p,'unknown_ns':u,'end_ns':DATA[names[0]][1]}
rows=[(k,'dec') for k in ['clk','rst_n','learn','sample','valid','reference_set','dut.auto_phase','dut.auto_count','result','locked','total','passes','unknowns']]
plot(names[0],rows,(0,p+80),'01_dynamic_PASS','Dynamic label inspection: reference learning and five observations','Timing parameters are scaled; not physical inspection latency.',[(ref,'Reference learned'),(p,'PASS latched')])
plot(names[0],rows,(p-80,DATA[names[0]][1]),'02_dynamic_rearm_UNKNOWN','Dynamic label inspection: re-arm and UNKNOWN deadline','result: 0=none, 1=PASS, 3=UNKNOWN.',[(p,'PASS'),(u,'UNKNOWN')])
d,end=DATA[names[1]];hit=edges(d,'hit',1)[0];meta['pixels']={'first_hit_ns':hit,'end_ns':end}
d['order']=(24,[(t,b[-24:]) for t,b in d['payload'][1]])
rows=[(k,'dec') for k in ['clk','rst','de','x','y']]+[('rgb','hex'),('candidate','dec'),('hit','dec'),('order','hex','payload[23:0] (HEX)')]
plot(names[1],rows,(max(0,hit-12000),hit+900),'03_pixels_overview','Pixel-stream barcode decoding: black/white input to valid hit','Input order 100001; module width = 4 pixels.',[(hit,'Order decoded')])
plot(names[1],rows,(hit-140,hit+180),'04_pixels_hit','Pixel-stream decoder: candidate and hit detail','Payload hexadecimal; decoded low 24 bits = 100001.',[(hit,'hit = 1')])
d,end=DATA[names[2]];starts=edges(d,'tx',0);start=next(t for t in starts if t>1000);meta['uart']={'first_start_ns':start,'end_ns':end,'received':[val(d[f'rx_data{i:02d}'][1][-1][1]) for i in range(36)],'checksum':val(d['checksum'][1][-1][1])}
plot(names[2],[('clk','dec'),('rst','dec'),('tx','dec'),('rx_data00','hex','data[0] (HEX)'),('rx_data01','hex','data[1] (HEX)')],(start-20,start+1020),'05_uart_8N1','UART 8N1 detail: first transmitted byte A5','Bit period = 100 ns in this scaled test; data bits transmitted LSB first.',[(start+50,'START'),*[(start+150+i*100,f'D{i}') for i in range(8)],(start+950,'STOP')])
rows=[('clk','dec'),('rst','dec'),('tx','dec')]+[(f'rx_data{i:02d}','hex',f'data[{i}]'+(' HEADER' if i<2 else ' VERSION' if i==2 else ' ORDER' if i in (28,29,30) else ' CHECK' if i==35 else '')) for i in range(36)]+[('checksum','hex')]
plot(names[2],rows,(start-100,end+100),'06_uart_packet','UART telemetry: all 36 received bytes and XOR checksum','Headers A5 5A; version 02; order bytes 10 00 03 (BCD); checksum '+meta['uart']['checksum']+'.')
d,end=DATA[names[3]];meta['session']={'end_ns':end,'done_ns':edges(d,'dut.done',1)}
rows=[(k,'dec') for k in ['clk','rst','pass','key','ticket','active','dut.decoder_hit']]+[('dut.confirmed','hex'),('dut.done','dec'),('dut.order','hex'),('dut.counter','hex')]
plot(names[3],rows,(0,end),'07_barcode_session','Barcode session control: PASS ticket and two matching reads','Decoder hits are injected; this is not the pixel-stream decoder test.')
(R/'waveform_measurements.json').write_text(json.dumps(meta,indent=2))
print(json.dumps(meta,indent=2))
