"""Register replaceable hand UI procedural assets and their source ownership."""
import pathlib,json,hashlib
root=pathlib.Path(__file__).resolve().parents[1]
p=root/'assets/manifest.json'; data=json.loads(p.read_text(encoding='utf-8'))
for asset,path,deps in [
 ('shader.ui.hand-glass','assets/shaders/hand_glass.gdshader',[]),
 ('ui.hand.border','presentation/hand_border.gd',[]),
 ('ui.hand.fan','presentation/hand_fan.gd',['shader.ui.hand-glass','ui.hand.border','ui.card.front'])]:
 data['assets'][asset]={'path':'res://'+path,'source':path,'version':7 if asset=='ui.hand.fan' else 1,'sha256':hashlib.sha256((root/path).read_bytes()).hexdigest(),'dependencies':deps,'license':'project-authored shader and deterministic procedural ornament; no external artwork'}
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
