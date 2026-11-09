"""Rig a Meshy serpent for the game: bone chain + weights + clips, exported as GLB.

    blender -b -P tools/blender/rig_serpent.py -- in.glb out.glb body 3.2
    blender -b -P tools/blender/rig_serpent.py -- in.glb out.glb neck 4.5

Works for any body shape (straight, U-shaped, coiled): the centre line is found by walking
the mesh surface from the tail tip to the head (shortest paths over the welded mesh), so
the bone chain follows the body wherever it bends. The chain's root is the tail, the head
bones are the leaves (striking moves the head, not the whole snake).

body: a crawling snake (size = body length, m). Clips: Idle, Walk (travelling S-wave =
      slither), Attack (rear up, strike), Hit_Reaction, Dead.
neck: a coiled serpent with a raised neck, the boss (size = height, m). The coil barely
      moves; the neck sways, rears back and strikes, recoils, collapses.

Weights are computed here (two bones per vertex, smooth blend) instead of Blender's
automatic weights, which fail on Meshy's non-manifold meshes. The head is turned to face
glTF +Z, the Meshy convention the game expects.
"""
import heapq
import math
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

BONES = 14
WELD = 1000.0  # 1 mm grid (after scaling to metres the mesh is re-welded anyway)


def args():
    a = sys.argv[sys.argv.index("--") + 1:]
    return a[0], a[1], a[2], float(a[3])


def load_mesh(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.parent = None
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    return obj


def bake(obj, m):
    obj.data.transform(m)
    obj.data.update()


def welded_graph(obj):
    """Vertex -> welded node id, and adjacency between nodes with edge lengths."""
    verts = obj.data.vertices
    node_of = []
    key_to_node = {}
    pos = []
    for v in verts:
        k = (round(v.co.x * WELD), round(v.co.y * WELD), round(v.co.z * WELD))
        n = key_to_node.get(k)
        if n is None:
            n = len(pos)
            key_to_node[k] = n
            pos.append(v.co.copy())
        node_of.append(n)
    adj = [dict() for _ in pos]
    for e in obj.data.edges:
        a, b = node_of[e.vertices[0]], node_of[e.vertices[1]]
        if a != b:
            d = (pos[a] - pos[b]).length
            adj[a][b] = d
            adj[b][a] = d
    return node_of, pos, adj


def dijkstra(adj, start):
    dist = [math.inf] * len(adj)
    dist[start] = 0.0
    heap = [(0.0, start)]
    while heap:
        d, n = heapq.heappop(heap)
        if d > dist[n]:
            continue
        for m, w in adj[n].items():
            nd = d + w
            if nd < dist[m]:
                dist[m] = nd
                heapq.heappush(heap, (nd, m))
    return dist


def largest_component_start(adj):
    seen = [False] * len(adj)
    best, best_size = 0, -1
    for s in range(len(adj)):
        if seen[s]:
            continue
        stack, size = [s], 0
        seen[s] = True
        while stack:
            n = stack.pop()
            size += 1
            for m in adj[n]:
                if not seen[m]:
                    seen[m] = True
                    stack.append(m)
        if size > best_size:
            best, best_size = s, size
    return best


def centre_line(obj):
    """Per-vertex position along the body (0 = tail tip, 1 = head) and the chain points."""
    node_of, pos, adj = welded_graph(obj)
    start = largest_component_start(adj)
    d0 = dijkstra(adj, start)
    a = max((i for i in range(len(pos)) if d0[i] < math.inf), key=lambda i: d0[i])
    da = dijkstra(adj, a)
    b = max((i for i in range(len(pos)) if da[i] < math.inf), key=lambda i: da[i])
    db = dijkstra(adj, b)
    length = da[b]

    def end_score(dist_from_end):
        sel = [pos[i] for i in range(len(pos)) if dist_from_end[i] < length * 0.08]
        c = sum(sel, Vector()) / max(len(sel), 1)
        radius = sum((p - c).length for p in sel) / max(len(sel), 1)
        return radius + 0.3 * c.z

    # The head is the thicker (or higher) end.
    tail_dist = da if end_score(db) > end_score(da) else db
    t_node = [min(tail_dist[i] / length, 1.0) if tail_dist[i] < math.inf else 0.0 for i in range(len(pos))]
    t_vert = [t_node[n] for n in node_of]
    chain = []
    for k in range(BONES + 1):
        f = k / BONES
        sel = [pos[i] for i in range(len(pos)) if abs(t_node[i] - f) < 0.5 / BONES]
        if not sel:
            sel = [pos[min(range(len(pos)), key=lambda i: abs(t_node[i] - f))]]
        chain.append(sum(sel, Vector()) / len(sel))
    return t_vert, chain, length


def make_armature(points):
    arm_data = bpy.data.armatures.new("Rig")
    arm = bpy.data.objects.new("Rig", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    prev = None
    for i in range(len(points) - 1):
        b = arm_data.edit_bones.new("b%02d" % i)
        b.head = points[i]
        b.tail = points[i + 1] if (points[i + 1] - points[i]).length > 1e-4 else points[i] + Vector((0, 0, 0.01))
        if prev is not None:
            b.parent = prev
        prev = b
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def weight(obj, arm, t_vert):
    n = len(arm.data.bones)
    groups = [obj.vertex_groups.new(name="b%02d" % i) for i in range(n)]
    for vi, t in enumerate(t_vert):
        x = min(max(t * n - 0.5, 0.0), n - 1.0)
        i = int(x)
        f = x - i
        if i + 1 < n and f > 0.0:
            groups[i].add([vi], 1.0 - f, "REPLACE")
            groups[i + 1].add([vi], f, "REPLACE")
        else:
            groups[i].add([vi], 1.0, "REPLACE")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    obj.parent = arm


def normalise(obj, mode, size):
    pts = [v.co for v in obj.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centre = Vector(((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, lo.z))
    bake(obj, Matrix.Translation(-centre))
    if mode == "neck":
        bake(obj, Matrix.Scale(size / max(hi.z - lo.z, 1e-4), 4))
        return
    _, _, length = centre_line(obj)
    bake(obj, Matrix.Scale(size / max(length, 1e-4), 4))


def face_forward(obj, chain):
    """Turn the model so the head looks along Blender -Y (glTF +Z)."""
    head = chain[-1] - chain[-3]
    head.z = 0.0
    if head.length < 1e-4:
        return chain
    angle = math.atan2(head.x, -head.y)
    rot = Matrix.Rotation(angle, 4, "Z")
    bake(obj, rot)
    return [rot @ p for p in chain]


# --- clips -------------------------------------------------------------------------------

def axis_in_bone(pb, world_axis):
    m = pb.bone.matrix_local.to_3x3().inverted()
    return (m @ world_axis).normalized()


def key_frame(arm, frame, angles):
    """angles: {bone index: (yaw_deg, pitch_deg)} around world up / the bone's side axis."""
    for i, pb in enumerate(arm.pose.bones):
        pb.rotation_mode = "QUATERNION"
        yaw, pitch = angles.get(i, (0.0, 0.0))
        up = axis_in_bone(pb, Vector((0, 0, 1)))
        direction = (pb.bone.tail_local - pb.bone.head_local).normalized()
        side_world = direction.cross(Vector((0, 0, 1)))
        if side_world.length < 1e-3:
            side_world = Vector((1, 0, 0))
        side = axis_in_bone(pb, side_world.normalized())
        q = Quaternion(up, math.radians(yaw)) @ Quaternion(side, math.radians(pitch))
        pb.rotation_quaternion = q
        pb.keyframe_insert("rotation_quaternion", frame=frame)


def clip(arm, name, frames, pose_at):
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = action
    for f in range(0, frames + 1, 2):
        key_frame(arm, f, pose_at(f / frames))
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 0, action)
    arm.animation_data.action = None


def crawl_clips(arm):
    n = len(arm.pose.bones)

    def wave(t, amp):
        # Travelling wave from head to tail (phase grows toward the tail) = forward slither.
        return {i: (amp * math.sin(2 * math.pi * (t + (n - i) / 5.0)), 0.0) for i in range(n)}

    clip(arm, "Idle", 60, lambda t: wave(t, 4.0))
    clip(arm, "Walk", 30, lambda t: wave(t, 11.0))
    clip(arm, "Attack", 24, lambda t: _strike(n, t, 3, 32.0))
    clip(arm, "Hit_Reaction", 12, lambda t: {i: (14.0 * math.sin(t * math.pi) * (1 if i % 2 else -1), 0.0) for i in range(n - 4, n)})
    clip(arm, "Dead", 30, lambda t: {i: (10.0 * t * math.sin(i * 1.3), -6.0 * t if i >= n - 3 else 0.0) for i in range(n)})


def _strike(n, t, head_bones, power):
    """Rear the head bones up and back, then snap forward and down."""
    out = {}
    if t < 0.45:
        k = math.sin(t / 0.45 * math.pi * 0.5)
        pitch = -power * k
    elif t < 0.65:
        pitch = -power + (power * 1.6) * (t - 0.45) / 0.2
    else:
        pitch = power * 0.6 * (1.0 - (t - 0.65) / 0.35)
    for i in range(n - head_bones, n):
        out[i] = (0.0, pitch / head_bones)
    return out


def coil_clips(arm):
    n = len(arm.pose.bones)
    neck = max(4, n // 3)

    def sway(t, amp):
        out = {}
        for i in range(n - neck, n):
            k = (i - (n - neck) + 1) / neck
            out[i] = (amp * k * math.sin(2 * math.pi * t - i * 0.4), 2.0 * math.sin(4 * math.pi * t + i))
        for i in range(n - neck):
            out[i] = (1.2 * math.sin(2 * math.pi * t + i * 0.7), 0.0)
        return out

    clip(arm, "Idle", 90, lambda t: sway(t, 7.0))
    clip(arm, "Walk", 45, lambda t: sway(t, 10.0))
    clip(arm, "Attack", 36, lambda t: _strike(n, t, neck, 60.0))
    clip(arm, "Hit_Reaction", 14, lambda t: {i: (0.0, -8.0 * math.sin(t * math.pi)) for i in range(n - neck, n)})
    clip(arm, "Dead", 45, lambda t: {i: (6.0 * t, 14.0 * t) for i in range(n - neck, n)})


def main():
    src, out, mode, size = args()
    obj = load_mesh(src)
    normalise(obj, mode, size)
    t_vert, chain, _ = centre_line(obj)
    chain = face_forward(obj, chain)
    arm = make_armature(chain)
    weight(obj, arm, t_vert)
    (crawl_clips if mode == "body" else coil_clips)(arm)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animation_mode="NLA_TRACKS",
                              export_skins=True, export_yup=True, export_apply=False)
    print("rigged %s -> %s (%d bones)" % (src, out, len(arm.data.bones)))


main()
