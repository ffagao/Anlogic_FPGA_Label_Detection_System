from pathlib import Path
import re
T=Path(__file__).resolve().parent
s=(T.parent/'user_source/hdl_source/label_scene_overlay_v4.v').read_text(encoding='utf-8')
a=s.index('    function rect_from_lower;');b=s.index('    wire [11:0] left_x=',a)
body=s[a:b]
set_bounds='\n'.join(line for line in re.findall(r'            ref_(?:left|top)_(?:pos|neg)<=.*?;',s) if '$signed' in line)
assert len(set_bounds.splitlines())==4
(T/'v35_ref_fixture.sv').write_text("module v35_ref_fixture(input signed [15:0] pr2,qr2,rp,rq,input [11:0] rhw,rhh,input sq,output edge_hit);\nreg signed [16:0] ref_left_pos,ref_left_neg,ref_top_pos,ref_top_neg;\nwire [11:0] rw=rhw,rh=rhh;\nalways @* begin\n"+set_bounds.replace('<=','=')+"\nend\n"+body+"assign edge_hit=ref_edge;\nendmodule\n",encoding='utf-8')
