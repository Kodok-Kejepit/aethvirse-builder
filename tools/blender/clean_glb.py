"""Cleans a Meshy / AI GLB for the game (run headless):
    blender -b --python tools/blender/clean_glb.py -- in.glb out.glb [--angle 40]
- merge by distance (welds split seams that are not real UV / sharp edges)
- recalculate normals outside, smooth shading by angle (sharp edges stay sharp)
- apply all transforms (scale 1,1,1), keep armature, skin weights and animations
- export with normals + tangents, animations sampled at 60 fps
"""
import math
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]
angle = float(argv[argv.index("--angle") + 1]) if "--angle" in argv else 40.0

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
bpy.context.scene.render.fps = 60

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for obj in bpy.context.scene.objects:
    obj.select_set(obj.type in ("MESH", "ARMATURE"))
bpy.context.view_layer.objects.active = meshes[0] if meshes else None
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

for obj in meshes:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0001, use_sharp_edge_from_normals=True)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle), keep_sharp_edges=True)
    print(f"{obj.name}: {len(obj.data.polygons)} faces, smooth <{angle}°")

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(
    filepath=dst, export_format="GLB", export_normals=True, export_tangents=True,
    export_apply=True, export_animations=True, export_force_sampling=True,
    export_frame_step=1, export_optimize_animation_size=False,
)
print("written", dst)
