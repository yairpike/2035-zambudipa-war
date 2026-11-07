"""Render a group of Tripo GLBs as one transparent hero shot (app icon, boot splash).

blender -b --python tools/brand/render_scene.py -- <scene.json>

scene.json keys:
  out, res [w, h], export_root (media/3d-export), yaw_table (splits.json),
  camera {yaw, pitch, lens, target [x, y, z], fill}, samples, silhouette (bool),
  units: [{path: "gtfc/amber_tank", size: metres, fit: "length"|"height", at: [x, y, z], turn: deg, rim: [r, g, b] 0-255}]
Tripo models face +X in Blender; turning them 90 + yaw-table degrees puts the front on +Y (the camera side).
"""
import bpy, sys, json, math, os
from mathutils import Vector, Matrix
from bpy_extras.object_utils import world_to_camera_view

cfg = json.load(open(sys.argv[-1]))
yaws = {}
if cfg.get("yaw_table") and os.path.exists(cfg["yaw_table"]):
    yaws = {k: v.get("yaw", 0) for k, v in json.load(open(cfg["yaw_table"])).items()}


def lin(c):
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


def area(name, loc, target, size, power, color):
    d = bpy.data.lights.new(name, 'AREA'); d.shape = 'DISK'; d.size = size; d.energy = power; d.color = color
    o = bpy.data.objects.new(name, d); o.location = loc
    o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.collection.objects.link(o)


bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
all_verts = []
for u in cfg["units"]:
    mid = u["path"].split("/")[-1]
    before = set(sc.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(cfg["export_root"], u["path"], mid + ".glb"))
    new = [o for o in sc.objects if o not in before]
    meshes = [o for o in new if o.type == 'MESH']
    for o in meshes:
        mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = mw
    for o in new:
        if o.type != 'MESH':
            bpy.data.objects.remove(o)
    rot = Matrix.Rotation(math.radians(90 + yaws.get(mid, 0) + u.get("turn", 0)), 4, 'Z')
    for o in meshes:
        o.data.transform(rot @ o.matrix_world); o.matrix_world = Matrix.Identity(4)
    vs = [v.co.copy() for o in meshes for v in o.data.vertices]
    lo = Vector([min(v[i] for v in vs) for i in range(3)]); hi = Vector([max(v[i] for v in vs) for i in range(3)])
    dim = hi - lo
    ref = dim.z if u.get("fit") == "height" else max(dim.x, dim.y)
    s = u["size"] / ref
    at = Vector(u.get("at", (0, 0, 0)))
    m = Matrix.Translation(at) @ Matrix.Scale(s, 4) @ Matrix.Translation(-Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z)))
    for o in meshes:
        o.data.transform(m)
        if cfg.get("silhouette"):
            o.data.materials.clear()
    all_verts += [m @ v for v in vs[::4]]

sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = cfg.get("samples", 96)
sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = cfg["res"]
sc.render.film_transparent = True
sc.render.image_settings.file_format = 'PNG'
sc.render.image_settings.color_mode = 'RGBA'
sc.view_settings.view_transform = 'AgX'
sc.view_settings.look = 'AgX - Medium High Contrast'
sc.view_settings.exposure = cfg.get("exposure", -1.0)
world = bpy.data.worlds.new("w"); sc.world = world; world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (0.5, 0.52, 0.55, 1)
world.node_tree.nodes['Background'].inputs[1].default_value = 0.08

cam_cfg = cfg["camera"]
target = Vector(cam_cfg.get("target", (0, 0, 0.8)))
yaw, pitch = math.radians(cam_cfg["yaw"]), math.radians(cam_cfg["pitch"])
cdir = Vector((math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch)))
side = Vector((cdir.y, -cdir.x, 0)).normalized()
back = Vector((-cdir.x, -cdir.y, 0)).normalized()
span = max((v - target).length for v in all_verts)
k = span / 2.0
if not cfg.get("silhouette"):
    area("key", target + (cdir * 4 - side * 3.2 + Vector((0, 0, 3.4))) * k, target, 3.0 * k, 850 * k * k, (1.0, 0.96, 0.9))
    area("fill", target + (cdir * 4 + side * 3.5 + Vector((0, 0, 0.6))) * k, target, 4.0 * k, 150 * k * k, (0.85, 0.9, 1.0))
    area("top", target + Vector((0, 0, 5)) * k, target, 4.0 * k, 140 * k * k, (1, 1, 1))
    for u in cfg["units"]:
        if "rim" in u:
            at = Vector(u.get("at", (0, 0, 0))) + Vector((0, 0, u["size"] * 0.5))
            for sgn in (-1, 1):
                area("rim", at + (back * 3.4 + side * 1.7 * sgn + Vector((0, 0, 1.6))) * (u["size"] / 2), at,
                     1.2 * u["size"] / 2, 2200 * (u["size"] / 2) ** 2, lin([c / 255 for c in u["rim"]]))
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, 0))
    bpy.context.active_object.is_shadow_catcher = True

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.lens = cam_cfg.get("lens", 50); cam.data.sensor_fit = 'HORIZONTAL'
sc.collection.objects.link(cam); sc.camera = cam
cam.rotation_euler = (-cdir).to_track_quat('-Z', 'Y').to_euler()
fill = cam_cfg.get("fill", 0.85)
d = span * 4
aspect = cfg["res"][0] / cfg["res"][1]
for _ in range(6):
    cam.location = target + cdir * d
    bpy.context.view_layer.update()
    pts = [world_to_camera_view(sc, cam, v) for v in all_verts]
    ex = max(max(p.x for p in pts) - min(p.x for p in pts), (max(p.y for p in pts) - min(p.y for p in pts)) / aspect * aspect)
    ey = max(p.y for p in pts) - min(p.y for p in pts)
    d *= max(ex / fill, ey / cam_cfg.get("fill_y", fill))
cam.location = target + cdir * d
bpy.context.view_layer.update()
pts = [world_to_camera_view(sc, cam, v) for v in all_verts]
cx = (max(p.x for p in pts) + min(p.x for p in pts)) / 2
cy = (max(p.y for p in pts) + min(p.y for p in pts)) / 2
cam.data.shift_x = (cx - 0.5 - cam_cfg.get("offset_x", 0))
cam.data.shift_y = (cy - 0.5 - cam_cfg.get("offset_y", 0)) / aspect
sc.render.filepath = cfg["out"]
bpy.ops.render.render(write_still=True)
print("RENDERED", cfg["out"])
