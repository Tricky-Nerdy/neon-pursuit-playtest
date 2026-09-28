"""Original low-poly world kit, Blender 4.x background export. No downloaded assets."""
import bpy, math, os
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'assets','world');os.makedirs(OUT,exist_ok=True)
M={}
def mat(name,c,metal=0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*c,1);bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=.55
    M[name]=m
for n,c in [('stone',(.65,.66,.57)),('white',(.82,.85,.79)),('teal',(.08,.34,.39)),('glass',(.035,.12,.17)),('steel',(.2,.28,.3)),('orange',(.82,.4,.12)),('bark',(.32,.25,.16)),('leaf',(.16,.36,.18)),('leaflight',(.3,.45,.2))]:mat(n,c,.25 if n in ['steel','glass'] else 0)
def finish(o,m):o.data.materials.append(M[m]);return o
def cube(p,s,m,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.dimensions=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);finish(o,m)
    if bevel:
        mod=o.modifiers.new('Edge chamfers','BEVEL');mod.width=bevel;mod.segments=1;bpy.ops.object.modifier_apply(modifier=mod.name)
    return o
def cyl(p,r,h,m,verts=12,top=None):
    bpy.ops.mesh.primitive_cone_add(vertices=verts,radius1=r,radius2=r if top is None else top,depth=h,location=p);return finish(bpy.context.object,m)
def beam(a,b,w,m):
    a,b=Vector(a),Vector(b);o=cube((a+b)/2,(w,w,(b-a).length),m);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def clear():bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def export(n):
    # One mesh per material reduces each repeated prop's draw calls.
    for m in M.values():
        bpy.ops.object.select_all(action='DESELECT');objs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.materials and o.data.materials[0]==m]
        if objs:
            for o in objs:o.select_set(True)
            bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'tools','blender_source',n+'.blend'))
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,n+'.glb'),export_format='GLB',export_yup=True)
clear()
cyl((0,0,8),1.1,16,'bark',8,top=.45)
for z,r in [(7,5),(11,4.6),(14,3.8),(17,2.8)]:cyl((0,0,z),r,7,'leaf' if z%2 else 'leaflight',9,top=0)
export('pine');clear()
for i in range(6):beam((.15*i,0,i*2),(.15*(i+1),0,(i+1)*2),.55,'bark')
for k in range(7):
    a=k*math.tau/7;u=Vector((math.cos(a),math.sin(a),0));v=Vector((-u.y,u.x,0));base=Vector((.9,0,12));mid=base+u*3+Vector((0,0,1));tip=base+u*6+Vector((0,0,-1.4))
    mesh=bpy.data.meshes.new('Palm frond');mesh.from_pydata([base,mid+v*.85,tip,mid-v*.85],[],[(0,1,2),(0,2,3)]);o=bpy.data.objects.new('Palm frond',mesh);bpy.context.collection.objects.link(o);finish(o,'leaflight' if k%2 else 'leaf')
export('palm');clear()
cyl((0,0,1),8,2,'stone',16);cyl((0,0,17),5,32,'white',16,top=3.2)
for z in [10,22]:cyl((0,0,z),4.5-(z/45),3,'teal',16)
cyl((0,0,34),5.3,2,'stone',16);cyl((0,0,37),3.6,5,'glass',12);cyl((0,0,40.5),5,2,'teal',12,top=.6)
for k in range(12):
    a=k*math.tau/12;x,y=4.8*math.cos(a),4.8*math.sin(a);beam((x,y,34),(x,y,36),.15,'steel')
    b=(k+1)*math.tau/12;beam((x,y,36),(4.8*math.cos(b),4.8*math.sin(b),36),.15,'steel')
cube((0,-4.6,3),(2,.8,5),'glass',.15);export('lighthouse');clear()
for x in [-8,8]:
    for y in [-5,5]:
        beam((x,y,0),(x*.65,y,32),1.5,'orange')
        for z in [5,14,23]:beam((x,y,z),(x*.65,-y,z+8),.45,'steel')
beam((-6,0,32),(35,0,32),2,'orange');beam((-6,0,35),(25,0,35),1,'orange')
for x in range(-5,30,5):beam((x,0,32),(x+5,0,35),.5,'steel')
beam((31,0,32),(31,0,8),.18,'steel');cube((31,0,7),(8,1,1),'orange');cube((-9,0,30),(8,7,5),'teal',.5);cube((4,-4,28),(5,4,4),'glass',.4);export('crane');clear()
# Hull with a pointed bow, layered cabin, glazing, rails and antenna.
verts=[(-3,-10,0),(3,-10,0),(4,6,0),(0,13,0),(-4,6,0),(-2.7,-9,-2),(2.7,-9,-2),(3,5,-2),(0,10,-1.5),(-3,5,-2)]
faces=[(0,1,2,3,4),(5,9,8,7,6)]+[(i,(i+1)%5,(i+1)%5+5,i+5) for i in range(5)]
mesh=bpy.data.meshes.new('Hull');mesh.from_pydata(verts,[],faces);o=bpy.data.objects.new('Hull',mesh);bpy.context.collection.objects.link(o);finish(o,'white')
cube((0,0,1.2),(5,10,2.5),'teal',.6);cube((0,-1,2.8),(4.5,7,1.5),'glass',.5);cube((0,-1,3.8),(5,8,.5),'white',.3)
beam((0,-3,4),(0,-3,7),.15,'steel')
for x in [-2.8,2.8]:
    for y in [-8,-4,0,4]:beam((x,y,0),(x,y,1),.09,'steel')
    beam((x,-8,1),(x,5,1),.09,'steel')
export('yacht');clear()
cyl((0,0,4),2,8,'stone',12);beam((0,0,7),(0,0,12),1,'steel')
# Faceted parabolic dish, aimed obliquely skyward.
vs=[(0,0,12)];fs=[]
for i in range(24):
    a=i*math.tau/24;vs.append((7*math.cos(a),7*math.sin(a),15))
for i in range(24):fs.append((0,i+1,(i+1)%24+1))
mesh=bpy.data.meshes.new('Dish');mesh.from_pydata(vs,[],fs);o=bpy.data.objects.new('Dish',mesh);bpy.context.collection.objects.link(o);finish(o,'white')
for x,y in [(6,0),(-6,0),(0,6),(0,-6)]:beam((x,y,14),(0,0,19),.16,'steel')
cyl((0,0,19),.5,1,'teal');export('radar')
print('WORLD KIT COMPLETE')
