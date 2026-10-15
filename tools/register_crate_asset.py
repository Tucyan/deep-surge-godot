"""Register the crate as a staged prop; do not create gameplay content or raft slots."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
def register(manifest):
    dependencies=[]
    for name in ['wood-albedo','wood-dark-albedo','wood-grey-albedo','wood-roughness','wood-normal']:
        p=ROOT/'assets/textures/wooden-crate-v1'/(name+'.png');key='texture.prop.crate.'+name
        manifest['assets'][key]={'path':'res://'+p.relative_to(ROOT).as_posix(),'source':'tools/generate_crate_textures.py',
            'version':1,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'dimensions':[512,512],
            'dependencies':[],'visual_seed':35104,'color_space':'sRGB' if 'albedo' in name else 'Non-Color',
            'license':'project-authored procedural weathered timber'}
        dependencies.append(key)
    # Godot's normal glTF importer writes embedded-image derivatives beside the GLB.
    # Register these too, including its packed metallic/roughness derivative.
    for p in sorted((ROOT/'assets/models/props').glob('wooden-crate_*.png')):
        name=p.stem.removeprefix('wooden-crate_');key='texture.prop.crate.imported.'+name
        manifest['assets'][key]={'path':'res://'+p.relative_to(ROOT).as_posix(),
            'source':'Godot glTF importer: assets/models/props/wooden-crate.glb',
            'version':1,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'dimensions':[512,512],
            'dependencies':['texture.prop.crate.'+name],'generated_by':'Godot embedded-image extraction',
            'color_space':'sRGB' if 'albedo' in name else 'Non-Color',
            'channels':'glTF packed metallic/roughness' if 'roughness' in name else 'RGB',
            'license':'project-authored image import derivative'}
        dependencies.append(key)
    p=ROOT/'assets/models/props/wooden-crate.glb'
    manifest['assets']['model.prop.wooden-crate']={'path':'res://'+p.relative_to(ROOT).as_posix(),
        'source':'asset-sources/wooden-crate-v1/wooden_crate_v001.blend','version':1,
        'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'dependencies':dependencies,
        'generator':'tools/build_wooden_crate.py','visual_seed':35104,
        'license':'project-authored Blender mesh and procedural textures',
        'status':'staged-not-integrated','units':'metres, Y-up, base at 0; CrateBody and separate rear-hinged CrateLid',
        'scope':'model only; no inventory capacity, crafting, installation, persistence or gameplay storage'}
    from register_stylized_wood import register as register_stylized
    register_stylized(manifest)
if __name__=='__main__':
    p=ROOT/'assets/manifest.json';m=json.loads(p.read_text(encoding='utf-8'));register(m)
    p.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
