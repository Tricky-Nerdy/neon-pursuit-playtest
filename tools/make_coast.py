"""Original low polygon rock cluster, built with Blender in background mode."""
import bpy, os, random
random.seed(18)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
mat = bpy.data.materials.new('Coastal granite')
mat.diffuse_color = (0.28, 0.36, 0.38, 1)
for i in range(5):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1,
        location=(random.uniform(-20,20), random.uniform(-15,15), random.uniform(8,18)))
    obj = bpy.context.object
    obj.scale = (random.uniform(17,32), random.uniform(15,30), random.uniform(23,50))
    obj.data.materials.append(mat)
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.export_scene.gltf(filepath=os.path.join(root,'assets','coast_rocks.glb'), export_format='GLB')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root,'tools','blender_source','coast_rocks.blend'))
