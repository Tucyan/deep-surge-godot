from pathlib import Path
import hashlib,json
from PIL import Image
r=Path(__file__).resolve().parents[1];p=r/'assets/manifest.json';m=json.loads(p.read_text(encoding='utf-8'))
entries={'ui.hud.status':('addons/deep_surge_status/status_hud.gd',[]),'ui.hud.action-points':('addons/deep_surge_status/action_points_hud.gd',[]),'ui.hud.event-choices':('addons/deep_surge_status/event_choice_panel.gd',[]),'ui.hud.voyage-adapter':('pages/voyage_hud.gd',['ui.hud.status','ui.hud.action-points','ui.hand.fan']),'ui.hud.story-adapter':('pages/flow_story.gd',['ui.hud.event-choices'])}
for id,(file,deps) in entries.items():
 m['assets'][id]={'path':'res://'+file,'version':2,'sha256':hashlib.sha256((r/file).read_bytes()).hexdigest(),'source':['asset-sources/hud-visual-v2/deep_surge_hud_godot4_v2_visual_match.zip',file],'dependencies':deps,'license':'user-supplied HUD package; no explicit upstream license supplied, project adaptations','visual_random':'none','role':'presentation-only; draws current read-only session view; native choices dispatch existing commands'}
for name in ['status_art','ap_art','ap_orb_full','ap_orb_empty','event_art']:
 file='addons/deep_surge_status/textures/'+name+'.png'
 id='texture.hud.'+name.replace('_','-')
 m['assets'][id]={'path':'res://'+file,'version':2,'sha256':hashlib.sha256((r/file).read_bytes()).hexdigest(),'dimensions':list(Image.open(r/file).size),'source':'asset-sources/hud-visual-v2/deep_surge_hud_godot4_v2_visual_match.zip','dependencies':[],'license':'user supplied visual v2 pack; upstream license not specified'}
m['assets']['texture.hud.event-art']['atlas_regions']={'header':[0,0,678,282],'choices':[[48,489,560,65],[48,561,560,65],[48,633,560,65]]}
for id,names in {'ui.hud.status':['status-art'],'ui.hud.action-points':['ap-art','ap-orb-full','ap-orb-empty'],'ui.hud.event-choices':['event-art']}.items():
 m['assets'][id]['dependencies']=['texture.hud.'+n for n in names]
m['assets']['texture.hud.status-art']['atlas_regions']={'bars':[[181,45+y,501,112] for y in [0,160,321,485]],'medallions':{'centers':[[108,104+y] for y in [0,160,321,485]],'radius':86},'layout':'satiety,water,sanity top row; health second row in column 2; action points to its right; 682x190 design cells with 27.28-unit horizontal gaps'}
frame_file='presentation/hud_frame.gd'
m['assets']['ui.hud.frame']={'path':'res://'+frame_file,'source':frame_file,'version':1,'sha256':hashlib.sha256((r/frame_file).read_bytes()).hexdigest(),'dependencies':[],'license':'project-authored procedural double-line frame and diamond corners','visual_random':'none'}
for id in ['ui.hud.event-choices','ui.hud.voyage-adapter']:
 m['assets'][id]['dependencies'].append('ui.hud.frame')
for id in ['ui.hud.status','ui.hud.event-choices','ui.hud.voyage-adapter']:
 m['assets'][id]['version']=4
p.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
s=r/'asset-sources/hud-visual-v2';inventory={'archive_sha256':hashlib.sha256((s/'deep_surge_hud_godot4_v2_visual_match.zip').read_bytes()).hexdigest(),'original_files':{str(f.relative_to(s)):hashlib.sha256(f.read_bytes()).hexdigest() for f in (s/'original').rglob('*') if f.is_file()},'runtime_assets':list(entries)+['texture.hud.'+n for n in ['status-art','ap-art','ap-orb-full','ap-orb-empty','event-art']],'notes':'Visual v2 status and AP art, event header and choice frame atlas regions integrated. Native event buttons retain all options and disabled guards; compact layout for 4+ choices, details in tooltips. Original plugin/demo retained as ignored source. Chinese inherited font; original viewport stretch retained.'}
(s/'inventory.json').write_text(json.dumps(inventory,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('HUD REGISTERED',len(entries))
