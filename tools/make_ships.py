"""Run from the project root: blender --background --python tools/make_ships.py [-- --preview]."""
import bpy
import math
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ASSETS = os.path.join(ROOT, "assets")
os.makedirs(ASSETS, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def material(name, color, glow=False):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = 0.58
    bsdf.inputs["Roughness"].default_value = 0.27
    if glow:
        bsdf.inputs["Emission Color"].default_value = (*color, 1)
        bsdf.inputs["Emission Strength"].default_value = 2.0
    return mat


def part(name, location, scale, mat, objects, bevel=0.12):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(location[0], -location[2], location[1]))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (scale[0], scale[2], scale[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    modifier = obj.modifiers.new("Soft machined edges", "BEVEL")
    modifier.width = bevel
    modifier.segments = 2
    obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    obj.data.materials.append(mat)
    objects.append(obj)
    return obj


schemes = [
    ("Vector", (0.0, 0.84, 1.0), 1.0),
    ("Raptor", (1.0, 0.08, 0.42), 1.25),
    ("Comet", (1.0, 0.55, 0.05), 0.85),
]
for index, (name, tint, width) in enumerate(schemes):
    hull = material(name + " carbon", (0.035, 0.065, 0.11))
    trim = material(name + " ion", tint, True)
    glass = material(name + " glass", (0.02, 0.38, 0.54))
    group = []
    part(name + " fuselage", (0, 0, 0), (2.0, 0.62, 4.4), hull, group)
    part(name + " canopy", (0, 0.55, -0.6), (1.28, 0.48, 1.6), glass, group)
    part(name + " wing", (0, -0.05, 0.7), (5.2 * width, 0.22, 1.2), hull, group)
    for side in (-1, 1):
        part(name + " fin", (side * 1.95 * width, 0.15, 0.95), (0.35, 0.7, 1.5), hull, group)
        part(name + " rail", (side * 1.5 * width, 0.0, 0.45), (0.13, 0.08, 3.7), trim, group, 0.04)
        part(name + " jet", (side * 0.52, -0.1, 2.28), (0.45, 0.24, 0.4), trim, group, 0.08)
    part(name + " crest", (0, 0.41, -1.6), (0.35, 0.12, 1.1), trim, group, 0.04)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in group:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = group[0]
    bpy.ops.export_scene.gltf(filepath=os.path.join(ASSETS, f"ship_{index}.glb"), export_format="GLB", use_selection=True, export_apply=True)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", "blender_source", "neon_pursuit_ships.blend"))

if "--preview" in sys.argv:
    bpy.context.scene.render.engine = "BLENDER_EEVEE_NEXT"
    bpy.context.scene.render.resolution_x = 640
    bpy.context.scene.render.resolution_y = 360
    bpy.context.scene.render.resolution_percentage = 100
    camera_data = bpy.data.cameras.new("Preview camera")
    cam = bpy.data.objects.new("Preview camera", camera_data)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = (7, 6, 9)
    cam.rotation_euler = ((0, 0, 0))
    direction = (-cam.location).to_track_quat("-Z", "Y")
    cam.rotation_euler = direction.to_euler()
    bpy.context.scene.camera = cam
    light_data = bpy.data.lights.new("Softbox", "AREA")
    light = bpy.data.objects.new("Softbox", light_data)
    bpy.context.scene.collection.objects.link(light)
    light.location = (2, 7, 1)
    light_data.energy = 1000
    light_data.shape = "DISK"
    light_data.size = 7
    bpy.context.scene.render.filepath = os.path.join(ASSETS, "ship_preview.png")
    bpy.ops.render.render(write_still=True)
