from pathlib import Path
import json,hashlib
r=Path(__file__).resolve().parents[1];p=r/'assets/manifest.json';m=json.loads(p.read_text(encoding='utf-8'))
a=m['assets']['shader.raft.wet-wood'];a.update(version=2,sha256=hashlib.sha256((r/'assets/shaders/wet_wood.gdshader').read_bytes()).hexdigest(),source='assets/shaders/wet_wood.gdshader',visual_random='Deterministic object-space wood hash; no gameplay RNG',parameters={'grain_strength':0.40,'knot_strength':0.30},description='Longitudinal grain, sparse knots, end splits, variable roughness and existing wet waterline; no added geometry or texture sampling')
p.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
