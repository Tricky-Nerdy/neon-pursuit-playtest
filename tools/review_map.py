"""Blender geometry review of tests/export_geometry.gd output, not a gameplay capture."""
import bpy, os
from mathutils import Vector
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath='/tmp/aurora4_review.glb')
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=16
scene.cycles.use_denoising=True
scene.world.color=(0.34,0.4,0.48)
bpy.ops.object.light_add(type='SUN',location=(0,0,800))
bpy.context.object.rotation_euler=(0.55,-0.35,-0.45)
bpy.context.object.data.energy=3
bpy.ops.object.camera_add(location=(1500,-1700,1800))
cam=bpy.context.object
cam.rotation_euler=(Vector((0,150,0))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO'
cam.data.ortho_scale=2450
cam.data.clip_end=20000
scene.camera=cam
scene.render.resolution_x=1280
scene.render.resolution_y=960
scene.render.resolution_percentage=100
scene.render.filepath='/tmp/aurora4_map_review.png'
if not os.environ.get('REVIEW_ONLY'):
    bpy.ops.render.render(write_still=True)
cam.data.type='PERSP'
cam.data.lens=22
cam.location=(9,-470,6.35)
cam.rotation_euler=(Vector((-10,-470,3.25))-cam.location).to_track_quat('-Z','Y').to_euler()
scene.render.resolution_y=720
scene.render.filepath='/tmp/aurora4_road_review.png'
if not os.environ.get('REVIEW_ONLY'):
    bpy.ops.render.render(write_still=True)
for name,position,target in [
    ('city',(190,-60,8),(255,-145,13)),
    ('canyon',(-230,175,8),(-120,135,16)),
    ('ridge',(-145,765,9),(-60,660,15)),
]:
    if os.environ.get("REVIEW_ONLY") and os.environ["REVIEW_ONLY"] != name:
        continue
    cam.location=position
    cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.lens=25
    scene.render.filepath='/tmp/aurora4_'+name+'_review.png'
    bpy.ops.render.render(write_still=True)
