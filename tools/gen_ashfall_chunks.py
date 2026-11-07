#!/usr/bin/env python3
"""Generates the Big Phase 1 graybox chunks of Region 1 (Ashfall Outskirts).

Run from the project root:  python3 tools/gen_ashfall_chunks.py
Output: scenes/world/chunks/r1/chunk_<x>_<z>.tscn (128 m chunks, centered on chunk coords).
Edit the layout here, not the generated scenes.
"""
import math

import world_dressing as wd  # noqa: F401
import ashfall_city as city

ASPHALT = "Color(0.32, 0.33, 0.36, 1)"
CONCRETE = "Color(0.55, 0.53, 0.5, 1)"
RUST = "Color(0.5, 0.35, 0.25, 1)"
TENT = "Color(0.35, 0.5, 0.45, 1)"
WATER = "Color(0.2, 0.35, 0.5, 1)"
BUILDING = "Color(0.45, 0.42, 0.48, 1)"

EXT = {
    "gb": ("Script", "res://scripts/systems/world/graybox_block.gd"),
    "spawner": ("Script", "res://scripts/systems/enemy/enemy_spawner.gd"),
    "enemy": ("PackedScene", "res://scenes/enemies/enemy.tscn"),
    "npc": ("PackedScene", "res://scenes/npc/npc.tscn"),
    "area": ("Script", "res://scripts/systems/secrets/secret_area.gd"),
    "marker": ("Script", "res://scripts/systems/secrets/secret_marker.gd"),
    "grate": ("PackedScene", "res://scenes/world/props/rain_grate.tscn"),
    "patience": ("PackedScene", "res://scenes/world/props/patience_chest.tscn"),
    "mimic": ("PackedScene", "res://scenes/world/props/mimic_chest.tscn"),
    "lore": ("PackedScene", "res://scenes/world/props/lore_pickup.tscn"),
    "sign": ("PackedScene", "res://scenes/world/props/hint_sign.tscn"),
    "wall": ("PackedScene", "res://scenes/world/props/breakable_wall.tscn"),
    "portal": ("PackedScene", "res://scenes/world/gates/gate_portal.tscn"),
    "dummy": ("PackedScene", "res://scenes/enemies/training_dummy.tscn"),
    "waystone": ("PackedScene", "res://scenes/world/props/waystone.tscn"),
    "hollow": ("Script", "res://scripts/systems/world/hollow_gate.gd"),
    "tree": ("Script", "res://scripts/systems/world/tree_prop.gd"),
    "grass": ("Script", "res://scripts/systems/world/grass_field.gd"),
    "decor": ("Script", "res://scripts/systems/world/decor_prop.gd"),
    "prop": ("Script", "res://scripts/systems/world/prop_instance.gd"),
    "terrain": ("Script", "res://scripts/systems/world/terrain_patch.gd"),
}
DATA = {
    "gate_husk": "res://data/enemies/gate_husk.tres",
    "ash_hound": "res://data/enemies/ash_hound.tres",
    "drowned_rat": "res://data/enemies/drowned_rat.tres",
    "marrow": "res://data/dialogs/marrow.tres",
    "camp_kid": "res://data/dialogs/camp_kid.tres",
    "bread_seller": "res://data/dialogs/bread_seller.tres",
    "appraiser": "res://data/dialogs/appraiser.tres",
    "quartermaster": "res://data/dialogs/quartermaster.tres",
    "hidden_gate_r1": "res://data/gates/hidden_gate_r1.tres",
    "gate_r1_e_overpass": "res://data/gates/gate_r1_e_overpass.tres",
}


class Chunk:
    def __init__(self, name):
        self.name = name
        self.nodes = []
        self.subs = []
        self.used = set()
        self.count = 0
        # Flatten discs for the terrain (x, z, radius) and the ground slab nodes it replaces.
        self.points = []
        self.ground_nodes = []

    def point(self, pos, r):
        self.points.append((pos[0], pos[2], r))

    def _id(self, prefix):
        self.count += 1
        return f"{prefix}{self.count}"

    def ext(self, key):
        self.used.add(key)
        return f'ExtResource("{key}")'

    def data(self, key):
        self.used.add("d_" + key)
        return f'ExtResource("d_{key}")'

    def tf(self, pos, rot_y=0.0, rot_x=0.0):
        cy, sy = math.cos(math.radians(rot_y)), math.sin(math.radians(rot_y))
        cx, sx = math.cos(math.radians(rot_x)), math.sin(math.radians(rot_x))
        # R = Ry * Rx, written row-major for .tscn
        r = [[cy, sy * sx, sy * cx], [0, cx, -sx], [-sy, cy * sx, cy * cx]]
        vals = [r[0][0], r[0][1], r[0][2], r[1][0], r[1][1], r[1][2], r[2][0], r[2][1], r[2][2]]
        return "Transform3D(%s, %g, %g, %g)" % (", ".join("%.5g" % v for v in vals), *pos)

    def block(self, size, pos, color=CONCRETE, rot_y=0.0, rot_x=0.0, solid=True):
        n = self._id("B")
        if size[0] >= 120 and size[2] >= 120:
            self.ground_nodes.append(len(self.nodes))
        elif max(size[0], size[2]) < 70:
            self.point(pos, 0.6 * math.hypot(size[0], size[2]) + 0.5)
        self.nodes.append(f'[node name="{n}" type="StaticBody3D" parent="."]\ntransform = {self.tf(pos, rot_y, rot_x)}\n'
                          f'script = {self.ext("gb")}\nsize = Vector3({size[0]}, {size[1]}, {size[2]})\ncolor = {color}\n'
                          f'solid = {"true" if solid else "false"}\n')

    def instance(self, key, pos, props="", rot_y=0.0, name=None):
        n = name or self._id(key.capitalize())
        self.point(pos, 4.0)
        self.nodes.append(f'[node name="{n}" parent="." instance={self.ext(key)}]\ntransform = {self.tf(pos, rot_y)}\n{props}')
        return n

    def npc(self, data_key, pos, rot_y=0.0):
        self.instance("npc", pos, f"data = {self.data(data_key)}\n", rot_y, name=f"Npc_{data_key}")

    def spawner(self, enemy_key, pos, respawn=20.0):
        n = self._id("Spawn")
        self.nodes.append(f'[node name="{n}" type="Marker3D" parent="."]\ntransform = {self.tf(pos)}\nscript = {self.ext("spawner")}\n'
                          f'enemy_scene = {self.ext("enemy")}\nenemy_data = {self.data(enemy_key)}\nrespawn_s = {respawn}\n')

    def secret_area(self, area_id, size, pos):
        n = self._id("Area")
        self.point(pos, max(size[0], size[2]) * 0.5 + 1.0)
        sid = self._id("shape")
        self.subs.append(f'[sub_resource type="BoxShape3D" id="{sid}"]\nsize = Vector3({size[0]}, {size[1]}, {size[2]})\n')
        self.nodes.append(f'[node name="{n}" type="Area3D" parent="."]\ntransform = {self.tf(pos)}\nscript = {self.ext("area")}\narea_id = &"{area_id}"\n')
        self.nodes.append(f'[node name="Shape" type="CollisionShape3D" parent="{n}"]\nshape = SubResource("{sid}")\n')

    def marker(self, secret_id, pos):
        n = self._id("Marker")
        self.nodes.append(f'[node name="{n}" type="Node3D" parent="."]\ntransform = {self.tf(pos)}\nscript = {self.ext("marker")}\nsecret_id = &"{secret_id}"\n')

    def tree(self, kind, pos, height, seed, snowy=False):
        n = self._id("Tree")
        self.nodes.append(f'[node name="{n}" type="StaticBody3D" parent="."]\ntransform = {self.tf(pos)}\nscript = {self.ext("tree")}\n'
                          f'kind = &"{kind}"\nheight = {height:.2f}\nseed_value = {seed}\nsnowy = {"true" if snowy else "false"}\n')

    def grass(self, color, blades=5000, seed=1, area=(124, 124), pos=(0, 0, 0)):
        n = self._id("Grass")
        self.nodes.append(f'[node name="{n}" type="MultiMeshInstance3D" parent="."]\ntransform = {self.tf(pos)}\nscript = {self.ext("grass")}\n'
                          f'area = Vector2({area[0]}, {area[1]})\nblades = {blades}\ncolor = {color}\nseed_value = {seed}\n')

    def decor(self, kind, pos, tint="Color(1, 0.75, 0.4, 1)", rot_y=0.0, seed=1):
        n = self._id("Decor")
        self.point(pos, 1.5)
        self.nodes.append(f'[node name="{n}" type="StaticBody3D" parent="."]\ntransform = {self.tf(pos, rot_y)}\nscript = {self.ext("decor")}\n'
                          f'kind = &"{kind}"\ntint = {tint}\nseed_value = {seed}\n')

    def prop(self, prop_id, pos, size, color, rot_y=0.0):
        """Asset slot: the owner's imported model `prop_id`, or a graybox block of `size` until it exists."""
        n = self._id("Prop")
        self.point(pos, 0.6 * max(size[0], size[2]) + 1.0)
        self.nodes.append(f'[node name="{n}" type="StaticBody3D" parent="."]\ntransform = {self.tf(pos, rot_y)}\nscript = {self.ext("prop")}\n'
                          f'prop_id = &"{prop_id}"\nfallback_size = Vector3({size[0]}, {size[1]}, {size[2]})\nfallback_color = {color}\n')

    def label(self, text, pos, size=48):
        n = self._id("Label")
        self.nodes.append(f'[node name="{n}" type="Label3D" parent="."]\ntransform = {self.tf(pos)}\nbillboard = 1\n'
                          f'text = "{text}"\nfont_size = {size}\noutline_size = 10\npixel_size = 0.01\n')

    def room(self, center, size, height, color, door_side=None, door_width=3.0):
        """Four walls; door_side in 'n','s','e','w' leaves a gap in that wall."""
        cx, cy, cz = center
        sx, sz = size
        t = 0.6
        walls = {
            "n": ((sx, height, t), (cx, cy + height / 2, cz - sz / 2)),
            "s": ((sx, height, t), (cx, cy + height / 2, cz + sz / 2)),
            "w": ((t, height, sz), (cx - sx / 2, cy + height / 2, cz)),
            "e": ((t, height, sz), (cx + sx / 2, cy + height / 2, cz)),
        }
        for side, (wsize, wpos) in walls.items():
            if side != door_side:
                self.block(wsize, wpos, color)
                continue
            if side in "ns":
                part = (sx - door_width) / 2
                for sign in (-1, 1):
                    self.block((part, height, t), (cx + sign * (door_width / 2 + part / 2), wpos[1], wpos[2]), color)
            else:
                part = (sz - door_width) / 2
                for sign in (-1, 1):
                    self.block((t, height, part), (wpos[0], wpos[1], cz + sign * (door_width / 2 + part / 2)), color)

    def write(self, path):
        head = ['[gd_scene format=3]', '']
        for key in sorted(self.used):
            if key.startswith("d_"):
                head.append(f'[ext_resource type="Resource" path="{DATA[key[2:]]}" id="{key}"]')
            else:
                kind, p = EXT[key]
                head.append(f'[ext_resource type="{kind}" path="{p}" id="{key}"]')
        body = [f'[node name="{self.name}" type="Node3D"]', '']
        with open(path, "w") as f:
            f.write("\n".join(head) + "\n\n" + "\n".join(self.subs) + "\n" + "\n".join(body) + "\n" + "\n".join(self.nodes))


def finish_region(chunks, folder, style, amp, seed, outcrop_id=None, outcrops=0, skip=()):
    """Adds rolling terrain (flattened around content, also near neighbours' content) and
    rocky outcrops from the owner's ground tiles to every chunk, then writes them."""
    import random
    for (x, z), c in chunks.items():
        if (x, z) not in skip:
            pts = list(c.points)
            for (nx, nz), other in chunks.items():
                if (nx, nz) == (x, z):
                    continue
                ox, oz = (nx - x) * 128, (nz - z) * 128
                for (px, pz, r) in other.points:
                    qx, qz = px + ox, pz + oz
                    if abs(qx) < 64 + r + 14 and abs(qz) < 64 + r + 14:
                        pts.append((qx, qz, r))
            if outcrop_id:
                rng = random.Random(seed * 1000 + x * 31 + z * 17)
                placed = 0
                for _ in range(60):
                    if placed >= outcrops:
                        break
                    px, pz = rng.uniform(-50, 50), rng.uniform(-50, 50)
                    sc = rng.uniform(1.3, 2.3)
                    clear = 9.0 * sc + 6
                    if any(math.hypot(px - qx, pz - qz) < r + clear for (qx, qz, r) in pts):
                        continue
                    sink = -6.0 * sc * rng.uniform(0.45, 0.7)
                    n = c._id("Outcrop")
                    c.nodes.append(f'[node name="{n}" type="StaticBody3D" parent="."]\ntransform = {c.tf((px, sink, pz), rng.uniform(0, 360))}\n'
                                   f'script = {c.ext("prop")}\nprop_id = &"{outcrop_id}"\nfallback_size = Vector3(12, 6, 12)\n'
                                   f'fallback_color = Color(0.4, 0.4, 0.38, 1)\nsize_scale = {sc:.3f}\nfit_height = false\n')
                    pts.append((px, pz, 9.0 * sc))
                    placed += 1
            flat = ", ".join("%g, %g, %g" % (px, pz, r) for (px, pz, r) in pts)
            c.nodes.append(f'[node name="Terrain" type="StaticBody3D" parent="."]\nscript = {c.ext("terrain")}\n'
                           f'style = &"{style}"\namplitude = {amp}\nseed_value = {seed}\n'
                           f'flatten = PackedVector3Array({flat})\n')
            for i in c.ground_nodes:
                c.nodes[i] += "visible = false\n"
        c.write(f"scenes/world/chunks/{folder}/chunk_{x}_{z}.tscn")


def ground(c, color=ASPHALT):
    c.block((128, 1, 128), (0, -0.5, 0), color)


def edges(c, x, z):
    """Boundary walls on the outside of the 3x3 map."""
    if x == -1:
        c.block((1, 6, 128), (-64, 3, 0), CONCRETE)
    if x == 1:
        c.block((1, 6, 128), (64, 3, 0), CONCRETE)
    if z == -1:
        c.block((128, 6, 1), (0, 3, -64), CONCRETE)
    if z == 1:
        c.block((128, 6, 1), (0, 3, 64), CONCRETE)


def camp(c):
    """Refugee camp inside the old city plaza (ring road around it, avenue to the south).
    Layout: paved plaza, rubble/wreck barricade with four street gates, two facing tent
    rows, a market lane under the statue, the campfire in the middle, waystone at the
    south gate. NPCs stand at the thing they run."""
    ground(c)
    c.block((94, 0.1, 94), (0, 0.05, 0), CONCRETE)
    _camp_barricade(c)
    for i, z in enumerate((-22, -8, 6, 20)):
        c.prop("bld_refugee_tent", (-30, 0, z), (6, 3, 5), TENT, rot_y=90)
        c.prop("bld_refugee_tent", (30, 0, z), (6, 3, 5), TENT, rot_y=-90)
    for i, x in enumerate((-16, -7, 7, 16)):
        c.prop("prop_market_stall", (x, 0, -28), (3.7, 3.2, 1.8), "Color(0.45, 0.32, 0.22, 1)", rot_y=180)
    c.block((3.2, 1.0, 3.2), (0, 0.5, -38), CONCRETE)
    c.prop("statue_starblade", (0, 1.0, -38), (1.2, 3.0, 1.2), CONCRETE, rot_y=180)
    c.decor("campfire", (0, 0, 0))
    for i in range(6):
        a = i / 6 * math.tau
        c.decor("barrel" if i % 2 else "crate", (math.cos(a) * 3.6, 0, math.sin(a) * 3.6), seed=40 + i)
    c.prop("prop_well", (16, 0, 14), (2.9, 3.2, 2.5), CONCRETE, rot_y=-30)
    for i, (x, z) in enumerate([(-40, -40), (40, -40), (-40, 40), (40, 40), (-12, -18), (12, -18), (-12, 18), (12, 18)]):
        c.decor("lamp", (x, 0, z), rot_y=(i * 90.0) % 360)
    for i, (x, z, r) in enumerate([(0, -46, 0), (0, 46, 180), (-46, 0, 90), (46, 0, 270)]):
        for dx in (-5.5, 5.5):
            px, pz = (x + dx, z) if r in (0, 180) else (x, z + dx)
            c.decor("banner", (px, 0, pz), "Color(0.25, 0.55, 0.85, 1)", rot_y=r)
    c.npc("bread_seller", (-12, 0, -25), 0)
    c.npc("appraiser", (12, 0, -25), 0)
    c.npc("quartermaster", (-5, 0, -35), 20)
    c.npc("camp_kid", (5, 0, 5), 220)
    c.instance("waystone", (0, 0, 38), 'waystone_id = &"r1_camp"\n')
    c.instance("sign", (7, 0, 40), 'text_key = &"HINT_SM_R1_01_6"\nhint_secret = &"SM-R1-01:3"\n')
    c.instance("dummy", (-20, 0, 34))
    c.label("REFUGEE CAMP", (0, 9, -40), 64)


def _camp_barricade(c):
    """Rubble, crates and wrecks along the plaza edge, open at the four street gates."""
    import random
    rng = random.Random(77)
    for side in range(4):
        v = -44.0
        while v <= 44.0:
            if abs(v) > 7.0:
                x, z = [(v, -46), (v, 46), (-46, v), (46, v)][side]
                roll = rng.random()
                yaw = (0 if side < 2 else 90) + rng.uniform(-10, 10)
                if roll < 0.25:
                    c.prop("prop_car_rusted", (x, 0, z), (4, 1.45, 2.0), RUST, rot_y=yaw)
                elif roll < 0.6:
                    c.prop("rock_pile", (x, 0, z), (3, rng.uniform(1.2, 1.9), 3), CONCRETE, rot_y=rng.uniform(0, 360))
                else:
                    c.decor("crate" if roll < 0.8 else "barrel", (x, 0, z), seed=int(v * 7 + side))
            v += 4.4


def overpass_and_culvert(c):
    ground(c)
    # Collapsed highway: raised deck with a broken ramp.
    c.block((16, 1, 120), (24, 8, 0), CONCRETE)
    for z in (-50, -20, 10, 40):
        c.block((3, 8, 3), (24, 4, z), CONCRETE)
    c.block((16, 1, 30), (24, 3.8, -62), CONCRETE, rot_x=-15)
    # Culvert: tunnel from the grate (west) to the pump room (east).
    c.block((24, 0.6, 5), (-14, 4, 20), CONCRETE)
    c.block((24, 4, 0.6), (-14, 2, 17.5), CONCRETE)
    c.block((24, 4, 0.6), (-14, 2, 22.5), CONCRETE)
    c.instance("grate", (-26, 0, 20), rot_y=90)
    c.marker("SEC-R1-01", (-26, 3, 20))
    c.room((8, 0, 20), (20, 20), 5, CONCRETE, door_side="w", door_width=4)
    c.block((20, 0.6, 20), (8, 5, 20), CONCRETE)
    c.secret_area("sec_r1_01_pump_room", (19, 5, 19), (8, 2.5, 20))
    c.instance("patience", (14, 0, 27), rot_y=180)
    c.marker("MC-R1-01", (14, 2, 27))
    c.instance("lore", (2, 0, 13), 'lore_id = &"LORE-R1-01"\nhint_secret = &"SM-R1-02:1"\nhint_key = &"HINT_SM_R1_02_1"\n')
    c.instance("portal", (10, 0, 18), f'gate = {c.data("hidden_gate_r1")}\nrequired_flag = &"r1_hidden_gate_open"\nrequires_wet_weather = true\n')
    c.marker("SM-R1-02:1", (8, 3, 20))
    c.spawner("drowned_rat", (4, 0.3, 24), 900.0)
    c.spawner("drowned_rat", (12, 0.3, 14), 900.0)
    # Rank E Gate near the overpass.
    c.instance("portal", (-10, 0, -40), f'gate = {c.data("gate_r1_e_overpass")}\n')
    for p in [(-20, 0.3, -30), (0, 0.3, -30), (-10, 0.3, -52)]:
        c.spawner("ash_hound", p)
    for z in (-40, -10, 20, 50):
        c.decor("lamp", (14, 0, z), rot_y=180.0)
    for i, z in enumerate((-48, -6, 36)):
        c.prop("prop_car_rusted", (35 + i * 2, 0, z), (4, 1.45, 1.9), RUST, rot_y=80 + i * 25)
    c.label("OVERPASS", (24, 12, 0), 64)
    c.instance("waystone", (8, 0, -10), 'waystone_id = &"r1_overpass"\n')
    # Where the prologue Double Gate stood: the Hollow Throne opens here at 03:xx (M11).
    c.point((2, 0, 40), 5.0)
    c.nodes.append(f'[node name="HollowGate" type="Node3D" parent="."]\ntransform = {c.tf((2, 0, 40))}\nscript = {c.ext("hollow")}\n')


def bridge(c):
    ground(c)
    # The river runs through the whole district (see river_reach for the side chunks).
    c.block((128, 0.2, 16), (0, 0.05, 0), WATER, solid=False)
    c.block((6, 5, 20), (-12, 2.5, 0), CONCRETE)
    c.block((6, 5, 20), (12, 2.5, 0), CONCRETE)
    c.block((40, 1, 10), (0, 5.5, 0), CONCRETE)
    c.npc("marrow", (0, 0, 2), 180)
    c.marker("SM-R1-01:1", (0, 3, 2))
    c.spawner("gate_husk", (-30, 0.3, -30))
    c.spawner("gate_husk", (30, 0.3, -24))
    c.label("BRIDGE", (0, 10, 0), 64)


def apartment(c):
    ground(c)
    # Leaning apartment block (graybox): lobby on the ground, 4th floor reached by a long ramp.
    c.room((0, 0, 20), (24, 14), 4, BUILDING, door_side="s", door_width=4)
    c.instance("sign", (0, 0, 15), 'text_key = &"SIGN_MAILBOX_404"\nhint_secret = &"SEC-R1-02"\nhint_key = &"HINT_SEC_R1_02_1"\n')
    floor_y = 12.0
    c.block((40, 1, 4), (-22, floor_y / 2, 34), CONCRETE, rot_y=0, rot_x=0)
    ramp_len = 44.0
    angle = math.degrees(math.atan2(floor_y, ramp_len))
    c.block((4, 0.6, math.hypot(ramp_len, floor_y)), (-34, floor_y / 2, 10), CONCRETE, rot_x=-angle)
    # 4th floor: corridor along x with rooms 403 | 404 (sealed) | 405 on the north side.
    c.block((44, 0.6, 26), (-12, floor_y - 0.3, -10), BUILDING)
    c.block((44, 4, 0.6), (-12, floor_y + 2, 3), BUILDING)
    c.block((0.6, 4, 26), (-34, floor_y + 2, -10), BUILDING)
    c.block((0.6, 4, 26), (10, floor_y + 2, -10), BUILDING)
    c.block((44, 4, 0.6), (-12, floor_y + 2, -23), BUILDING)
    for x, label in [(-24, "403"), (0, "405")]:
        c.block((10, 4, 0.6), (x, floor_y + 2, -6), BUILDING)
        c.label(label, (x, floor_y + 3.4, -5.5), 40)
    c.block((3.5, 4, 0.6), (-17.25 + 0.0, floor_y + 2, -6), BUILDING)
    c.block((3.5, 4, 0.6), (-6.75, floor_y + 2, -6), BUILDING)
    c.instance("wall", (-12, floor_y, -6), 'save_flag = &"r1_wall_404_broken"\n')
    c.marker("SEC-R1-02", (-12, floor_y + 3, -6))
    c.block((0.6, 4, 16), (-19, floor_y + 2, -15), BUILDING)
    c.block((0.6, 4, 16), (-5, floor_y + 2, -15), BUILDING)
    c.instance("mimic", (-12, floor_y, -19))
    c.marker("MC-R1-02", (-12, floor_y + 2, -19))
    c.instance("lore", (-16, floor_y, -12), 'lore_id = &"LORE-R1-02"\n')
    c.label("APARTMENTS", (0, 22, 0), 64)


def filler(c, seed, enemy):
    ground(c)
    import random
    rng = random.Random(seed)
    for _ in range(10):
        s = (rng.uniform(3, 10), rng.uniform(1, 6), rng.uniform(3, 10))
        p = (rng.uniform(-50, 50), s[1] / 2, rng.uniform(-50, 50))
        if abs(p[0]) < 10 and abs(p[2]) < 10:
            continue
        c.block(s, p, CONCRETE, rot_y=rng.uniform(0, 90))
    for _ in range(2):
        c.spawner(enemy, (rng.uniform(-40, 40), 0.3, rng.uniform(-40, 40)))
    for i in range(5):
        p = (rng.uniform(-56, 56), 0, rng.uniform(-56, 56))
        if abs(p[0]) > 12 or abs(p[2]) > 12:
            c.tree("dead", p, rng.uniform(5, 9), seed * 100 + i)


def ruins(c, x, z):
    """Owner's Meshy ruins/cars dressing the open Ashfall chunks (graybox until imported)."""
    import random
    rng = random.Random(x * 101 + z * 37 + 5)
    for i in range(2):
        p = (rng.choice([-46, 46]) + rng.uniform(-6, 6), 0, rng.uniform(-44, 44))
        c.prop("r1_apartment_ruin_a", p, (12, 18, 12), BUILDING, rot_y=rng.choice([0, 90, 180, 270]) + rng.uniform(-8, 8))
    for i in range(4):
        p = (rng.uniform(-36, 36), 0, rng.uniform(-36, 36))
        if abs(p[0]) < 8 and abs(p[2]) < 8:
            continue
        c.prop("prop_car_rusted", p, (4, 1.45, 1.9), RUST, rot_y=rng.uniform(0, 360))
    if (x, z) in ((0, 1), (1, 1), (-1, -1)):
        c.prop("landmark_overpass_cracked", (0, 0, rng.choice([-30, 30])), (30, 11, 8), CONCRETE, rot_y=rng.choice([0, 90]))


def river_reach(c):
    """The river continues east and west of the bridge chunk, between low concrete banks."""
    c.block((128, 0.2, 16), (0, 0.05, 0), WATER, solid=False)
    for side in (-1, 1):
        c.block((128, 0.8, 1.2), (0, 0.4, side * 8.6), CONCRETE)


LAYOUT = {
    (0, 0): camp,
    (1, 0): overpass_and_culvert,
    (0, -1): bridge,
    (-1, 0): apartment,
}

if __name__ == "__main__":
    import random
    built = {}
    for x in (-1, 0, 1):
        for z in (-1, 0, 1):
            chunk = Chunk(f"Chunk_{x}_{z}")
            builder = LAYOUT.get((x, z))
            if builder:
                builder(chunk)
            else:
                ground(chunk)
                rng = random.Random(x * 31 + z * 7)
                enemy = "gate_husk" if (x + z) % 2 == 0 else "ash_hound"
                for _ in range(2):
                    chunk.spawner(enemy, (rng.uniform(-40, 40), 0.3, rng.uniform(-40, 40)))
                if (x, z) == (-1, 1):
                    # Road north-west to Region 2.
                    chunk.instance("waystone", (0, 0, 0), 'road_to = &"r2_glade"\n')
            # The broken ends of the elevated highway, north and south of its intact deck.
            if z == -1 and x != 0:
                river_reach(chunk)
            if (x, z) in ((1, 1), (1, -1)):
                chunk.prop("landmark_overpass_cracked", (24, 0, -34 if z > 0 else 34), (30, 11, 8), CONCRETE, rot_y=90)
            city.dress_chunk(chunk, x * 128, z * 128, 900 + x * 31 + z * 17)
            built[(x, z)] = chunk
    finish_region(built, "r1", "ashfall", 1.2, 101)
    print("chunks written")
