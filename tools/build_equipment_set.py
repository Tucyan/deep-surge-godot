"""Build staged equipment artwork, one asset per Blender invocation. No game rules."""
import sys, math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
from equipment_model_lib import *
from mathutils import Euler

def shield_rack(m):
    for i,x in enumerate([-.48,.48]):
        box('splayed-foot'+str(i),(x,.12,.22),(.16,.83,.12),m['dark'],rotation=(0,0,(-1 if i else 1)*.04))
        beam('leaning-post'+str(i),(x,.37,.25),(x*.92,.19,1.20-i*.06),.105,.11,m['grey'])
        beam('back-brace'+str(i),(x,.48,.27),(x*.92,.19,.91),.07,.075,m['warm'])
    for z in [.42,.94]:beam('crossbar'+str(z),(-.56,.25,z),(.55,.25,z+.025),.10,.09,m['dark'])
    for index,(cx,cy,cz,r,angles) in enumerate([(-.22,-.10,.82,.41,(.12,-.09,-.06)),(.35,.03,.74,.31,(.16,.10,.08))]):
        frame=Matrix.Translation((cx,cy,cz))@Euler(angles).to_matrix().to_4x4()
        outline=[(r*math.cos(a*math.tau/32),r*math.sin(a*math.tau/32)) for a in range(32)] if index==0 else [(-r,.23),(-.27,.34),(.21,.36),(r,.20),(.25,-.08),(.02,-.43),(-.24,-.10)]
        xmin=min(p[0] for p in outline);xmax=max(p[0] for p in outline)
        for i in range(5):
            lo=xmin+(xmax-xmin)*i/5+.002;hi=xmin+(xmax-xmin)*(i+1)/5-.002
            poly=clip_x(clip_x(outline,lo,True),hi,False)
            if len(poly)>2:panel('shield-plank%d-%d'%(index,i),poly,.054,m[['warm','grey','warm','dark','warm'][i]],frame)
        rim=tube('forged-rim'+str(index),[(x,-.004,z) for x,z in outline],.027,m['iron'],6,True);rim.matrix_world=frame
        boss=sphere('shield-boss'+str(index),(0,0,0),(.13,.073,.13),m['rim']);boss.matrix_world=frame@Matrix.Translation((0,-.065,0))
        for j,(x,z) in enumerate(outline[::4] if index==0 else outline):
            rivet=sphere('rim-rivet%d-%d'%(index,j),(0,0,0),(.018,.012,.018),m['brass']);rivet.matrix_world=frame@Matrix.Translation((x*.94,-.033,z*.94))
        for z in [-.15,.16]:
            bar=box('rear-shield-strap',(0,0,0),(r*1.5,.025,.055),m['iron']);bar.matrix_world=frame@Matrix.Translation((0,.042,z))
    tube('hanging-leather-loop',[(.49,.12,.98),(.61,.08,.89),(.57,.06,.77),(.48,.07,.82)],.02,m['hemp'])

def generator(m):
    for i,x in enumerate([-.43,.43]):box('skid'+str(i),(x,.02,.22),(.17,1.02,.15),m['dark'],rotation=(0,0,.025 if i else -.035))
    for i,y in enumerate([-.35,.34]):box('bed-plank'+str(i),(0,y,.31),(1.11,.18,.07),m['warm'],rotation=(0,.012,(-1 if i else 1)*.02))
    for x in [-.32,.32]:
        beam('machine-foot',(x,-.14,.34),(x,-.06,.64),.08,.09,m['iron'])
        beam('rear-foot',(x,.3,.34),(x,.24,.65),.07,.08,m['iron'])
    cylinder('alternator-barrel',(0,-.12,.70),(0,.32,.70),.265,m['teal'],20)
    for y in [-.13,.33]:cylinder('endplate',(0,y-.025,.70),(0,y+.025,.70),.285,m['iron'],20)
    for i in range(8):
        a=math.tau*i/8;x=.275*math.cos(a);z=.70+.275*math.sin(a)
        cylinder('cage-rod',(x,-.12,z),(x,.33,z),.017,m['brass'],8)
    for i in range(12):
        y=-.055+i*.027
        tube('copper-winding'+str(i),[(.271*math.cos(j*math.tau/24),y,.70+.271*math.sin(j*math.tau/24)) for j in range(24)],.012,m['brass'],5,True)
    cylinder('shaft',(0,-.43,.70),(0,.38,.70),.048,m['rim'])
    tube('flywheel',[(.335*math.cos(j*math.tau/40),-.37,.70+.335*math.sin(j*math.tau/40)) for j in range(40)],.045,m['iron'],8,True)
    for i in range(5):
        a=i*math.tau/5;beam('flywheel-spoke',(0,-.37,.70),(.31*math.cos(a),-.37,.70+.31*math.sin(a)),.041,.035,m['rim'])
    cylinder('hub',(0,-.44,.70),(0,-.31,.70),.095,m['brass'])
    beam('crank-arm',(0,-.46,.70),(.15,-.46,.83),.045,.035,m['iron'])
    cylinder('crank-grip',(.15,-.47,.83),(.15,-.61,.83),.032,m['dark'],12)
    box('control-box',(.40,.15,.82),(.27,.34,.43),m['teal'],.025,rotation=(0,-.08,0))
    cylinder('gauge-rim',(.40,-.042,.91),(.40,-.064,.91),.082,m['brass'])
    cylinder('gauge-face',(.40,-.065,.91),(.40,-.069,.91),.063,m['ivory'])
    beam('gauge-pointer',(.40,-.074,.91),(.428,-.074,.944),.009,.008,m['iron'])
    cylinder('toggle',(.40,-.05,.70),(.44,-.13,.76),.014,m['rim'],8)
    sphere('toggle-knob',(.44,-.13,.76),(.024,.024,.024),m['rubber'])
    sphere('indicator',(.47,-.035,.80),(.022,.012,.022),m['gauge'])
    tube('insulated-cable',[(.48,.31,.68),(.57,.35,.52),(.44,.39,.40),(.10,.36,.39),(-.20,.30,.54)],.016,m['rubber'],6)
    # Single open holder suggests stored output without inventing a card or its effect.
    box('output-tray',(-.43,.09,.43),(.23,.35,.045),m['grey'])
    for x in [-.55,-.31]:box('tray-side',(x,.09,.49),(.025,.35,.13),m['iron'])
    box('tray-back',(-.43,.265,.49),(.25,.025,.13),m['iron'])
    for x in [-.43,.43]:
        for y in [-.35,.34]:sphere('bed-bolt',(x,y,.36),(.022,.022,.012),m['rim'])

def fishing_net(m):
    for x in [-.43,.43]:
        box('deck-foot',(x,.18,.22),(.20,.74,.12),m['dark'],rotation=(0,0,.04 if x>0 else -.03))
        beam('mast',(x,.25,.26),(x,.20,1.19 if x<0 else 1.12),.10,.11,m['grey'])
        beam('outboard-boom',(x,.20,1.10),(x*.97,-.87,.89),.075,.09,m['warm'])
        beam('angled-brace',(x,.42,.28),(x,.18,.85),.065,.07,m['dark'])
        tube('suspension',[(x,.18,1.12),(x*.92,-1.05,.76)],.016,m['hemp'],6)
    beam('rear-bar',(-.47,.24,.89),(.48,.24,.87),.07,.08,m['warm'])
    # The bag hangs outside the deck; below-deck extent is intentional.
    def net_point(a,t):
        return (.59*(1-.80*t)*math.cos(a),-1.01+.37*(1-.80*t)*math.sin(a),.77-.88*t)
    tube('net-mouth',[net_point(j*math.tau/48,0) for j in range(48)],.026,m['hemp'],6,True)
    for handed in [-1,1]:
        for i in range(14):
            tube('diamond-net', [net_point(i*math.tau/14+handed*t*1.65,t) for t in [j/18 for j in range(19)]],.009,m['hemp'],4)
    tube('bag-bottom',[net_point(j*math.tau/20,1) for j in range(20)],.016,m['hemp'],5,True)
    for i in range(7):
        a=i*math.tau/14
        tube('closed-bottom-mesh',[net_point(a,1),(0,-1.01,-.15),net_point(a+math.pi,1)],.009,m['hemp'],4)
    sphere('bottom-knot',(0,-1.01,-.15),(.026,.027,.023),m['hemp'])
    for a in [.35,2.7,4.5]:
        p=net_point(a,0);sphere('cork-float',p,(.062,.055,.072),m['cork'])
    cylinder('winch-axle',(-.30,.25,.65),(.29,.25,.65),.042,m['iron'])
    for x in [-.24,.24]:cylinder('winch-flange',(x-.025,.25,.65),(x+.025,.25,.65),.14,m['dark'])
    for i in range(12):
        x=-.20+i*.036
        tube('winch-rope',[(x,.25+.104*math.cos(j*math.tau/20),.65+.104*math.sin(j*math.tau/20)) for j in range(20)],.016,m['hemp'],5,True)
    tube('hauling-rope',[(0,.15,.65),(.02,-.20,.87),(0,-.65,.91),(0,-1.01,.78)],.015,m['hemp'],6)
    beam('winch-crank',(.33,.25,.65),(.33,.25,.81),.035,.035,m['iron'])
    cylinder('winch-handle',(.33,.25,.81),(.46,.25,.81),.026,m['warm'])

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    key=args[args.index('--asset')+1] if '--asset' in args else 'shieldRack'
    functions={'shieldRack':shield_rack,'generator':generator,'fishingNet':fishing_net}
    if key not in functions:raise ValueError(key)
    scene=bpy.data.scenes.new('Equipment_'+key+'_v001');bpy.context.window.scene=scene
    scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
    functions[key](palette())
    if key=='fishingNet':
        for obj in scene.objects:obj.location.y-=.32
    source=ROOT/'asset-sources/equipment-models-v1';source.mkdir(parents=True,exist_ok=True)
    finalize(scene,key,ROOT/'assets/models/raft-modules'/f'{key}.glb',source/f'{key}_v001.blend')
    print('EQUIPMENT BUILD PASS:',key)
