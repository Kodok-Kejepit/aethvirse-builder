#!/usr/bin/env python3
"""M9 world expansion (Big Phase 1 graybox): Region 2 Verdant Hollow + Region 3 Crimson Dunes.

Run from the project root:  python3 tools/gen_m9_world.py
Writes enemies, Gates, NPCs, secrets, lore, region data, region scenes and chunks.
Edit here, not the generated files. Region 1 chunks still come from gen_ashfall_chunks.py.
"""
import os
import math
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import gen_ashfall_chunks as ga  # noqa: E402
import world_dressing as wd  # noqa: E402

FOREST = "Color(0.22, 0.38, 0.22, 1)"
BARK = "Color(0.32, 0.24, 0.18, 1)"
LEAF = "Color(0.25, 0.5, 0.28, 1)"
ROOT = "Color(0.4, 0.3, 0.22, 1)"
POND = "Color(0.18, 0.3, 0.32, 1)"
SAND = "Color(0.72, 0.42, 0.3, 1)"
DUNE = "Color(0.78, 0.5, 0.35, 1)"
STONE = "Color(0.62, 0.52, 0.45, 1)"
OASIS = "Color(0.2, 0.45, 0.5, 1)"

ga.EXT["waystone"] = ("PackedScene", "res://scenes/world/props/waystone.tscn")


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


# --- enemies -------------------------------------------------------------------------------

ENEMIES = {
    # id: (name, level, color, element, tier, extra fields)
    "thorn_stalker": ("Thorn Stalker", 12, "Color(0.3, 0.55, 0.25, 1)", 3, 0, {"hp_scale": 0.9, "chase_speed": 5.2, "attack_windup_s": 0.55}),
    "moss_brute": ("Moss Brute", 16, "Color(0.35, 0.45, 0.3, 1)", 4, 0, {"hp_scale": 1.6, "chase_speed": 3.4, "attack_windup_s": 0.95,
                                                                        "attack_multiplier": 1.3, "poise": 60.0}),
    "rootheart_elder": ("Rootheart Elder", 22, "Color(0.45, 0.32, 0.2, 1)", 4, 2, {"hp_scale": 0.25, "attack_scale": 0.85, "poise": 140.0,
                                                                                  "attack_range": 2.8, "attack_windup_s": 0.9,
                                                                                  "attack_hitbox_size": "Vector3(3.2, 1.8, 2.8)",
                                                                                  "telegraph_radius": 2.8, "aggro_radius": 40.0, "leash_radius": 80.0}),
    "dune_scuttler": ("Dune Scuttler", 27, "Color(0.8, 0.55, 0.35, 1)", 4, 0, {"hp_scale": 0.85, "chase_speed": 6.0, "attack_windup_s": 0.5}),
    "sand_wraith": ("Sand Wraith", 31, "Color(0.85, 0.75, 0.6, 1)", 3, 0, {"hp_scale": 1.1, "chase_speed": 4.6, "attack_windup_s": 0.7,
                                                                           "attack_multiplier": 1.2}),
    "crimson_burrower": ("Crimson Burrower", 36, "Color(0.7, 0.2, 0.18, 1)", 1, 2, {"hp_scale": 0.3, "attack_scale": 0.9, "poise": 160.0,
                                                                                   "attack_range": 3.0, "attack_windup_s": 1.0,
                                                                                   "attack_hitbox_size": "Vector3(3.6, 2, 3)",
                                                                                   "telegraph_radius": 3.0, "aggro_radius": 40.0, "leash_radius": 80.0}),
}


def enemy_tres(eid, row):
    name, level, color, element, tier, extra = row
    lines = "\n".join(f"{k} = {v}" for k, v in extra.items())
    return f'''[gd_resource type="Resource" script_class="EnemyData" format=3]

[ext_resource type="Script" path="res://scripts/resources/enemy_data.gd" id="1"]
[ext_resource type="Script" path="res://scripts/resources/combat_stats.gd" id="2"]

[sub_resource type="Resource" id="stats"]
script = ExtResource("2")
crit_chance = 0.05
element = {element}

[resource]
script = ExtResource("1")
id = &"{eid}"
display_name = "{name}"
level = {level}
stats = SubResource("stats")
body_color = {color}
tier = {tier}
{lines}
'''


# --- gates ---------------------------------------------------------------------------------

GATES = {
    # id: (name key, rank, seed, rooms, pool, boss, min guild rank, gold, items)
    "gate_r1_e_culvert": ("GATE_R1_E_CULVERT", 0, 1311, 3, ["drowned_rat", "ash_hound"], "ash_hound_alpha", 0, 110, {"potion_small": 2}),
    "gate_r2_d_thicket": ("GATE_R2_D_THICKET", 1, 2207, 4, ["thorn_stalker", "moss_brute"], "rootheart_elder", 0, 380, {"potion_small": 3}),
    "gate_r2_c_rootheart": ("GATE_R2_C_ROOTHEART", 2, 2291, 5, ["moss_brute", "thorn_stalker"], "rootheart_elder", 1, 620, {"potion_small": 4}),
    "gate_r3_c_mirage": ("GATE_R3_C_MIRAGE", 2, 3103, 5, ["dune_scuttler", "sand_wraith"], "crimson_burrower", 1, 900, {"potion_small": 4}),
    "gate_r3_b_tomb": ("GATE_R3_B_TOMB", 3, 3177, 6, ["sand_wraith", "dune_scuttler"], "crimson_burrower", 2, 1400, {"potion_small": 5}),
}


def enemy_path(eid):
    return f"res://data/enemies/{eid}.tres"


def gate_tres(gid, row):
    key, rank, seed, rooms, pool, boss, guild, gold, items = row
    ext = ['[ext_resource type="Script" path="res://scripts/resources/gate_data.gd" id="1"]',
           '[ext_resource type="Script" path="res://scripts/resources/enemy_data.gd" id="2"]']
    for i, e in enumerate(pool):
        ext.append(f'[ext_resource type="Resource" path="{enemy_path(e)}" id="e{i}"]')
    ext.append(f'[ext_resource type="Resource" path="{enemy_path(boss)}" id="boss"]')
    pool_s = ", ".join(f'ExtResource("e{i}")' for i in range(len(pool)))
    items_s = ", ".join(f'&"{k}": {v}' for k, v in items.items())
    return f'''[gd_resource type="Resource" script_class="GateData" format=3]

{chr(10).join(ext)}

[resource]
script = ExtResource("1")
id = &"{gid}"
display_name = &"{key}"
rank = {rank}
seed_value = {seed}
room_count = {rooms}
enemy_pool = Array[ExtResource("2")]([{pool_s}])
enemies_per_room = 3
boss = ExtResource("boss")
rules = Array[StringName]([])
min_guild_rank = {guild}
completes_secret = &""
reward_gold = {gold}
reward_items = Dictionary[StringName, int]({{{items_s}}})
'''


# --- NPCs, lore, secrets -------------------------------------------------------------------

NPCS = {
    # id: (name key, color, [line keys])
    "warden_sela": ("NPC_SELA", "Color(0.35, 0.6, 0.4, 1)", ["DLG_SELA_1", "HINT_SEC_R2_06_1"]),
    "root_monk": ("NPC_ROOT_MONK", "Color(0.55, 0.45, 0.3, 1)", ["DLG_MONK_1", "HINT_SEC_R2_07_1"]),
    "trader_kadir": ("NPC_KADIR", "Color(0.75, 0.55, 0.3, 1)", ["DLG_KADIR_1", "HINT_SEC_R3_01_1"]),
    "dune_cartographer": ("NPC_CARTOGRAPHER", "Color(0.6, 0.5, 0.65, 1)", ["DLG_CARTO_1", "HINT_SEC_R3_09_1"]),
}


def npc_tres(nid, row):
    key, color, lines = row
    lines_s = ", ".join(f'&"{k}"' for k in lines)
    return f'''[gd_resource type="Resource" script_class="NpcData" format=3]

[ext_resource type="Script" path="res://scripts/resources/npc_data.gd" id="1"]
[ext_resource type="Script" path="res://scripts/resources/condition_data.gd" id="2"]
[ext_resource type="Script" path="res://scripts/resources/dialog_effect.gd" id="3"]
[ext_resource type="Script" path="res://scripts/resources/dialog_choice.gd" id="4"]
[ext_resource type="Script" path="res://scripts/resources/dialog_entry.gd" id="5"]

[sub_resource type="Resource" id="s1"]
script = ExtResource("5")
id = &"default"
conditions = Array[ExtResource("2")]([])
lines = Array[StringName]([{lines_s}])
daily_variants = Array[StringName]([])
on_show = Array[ExtResource("3")]([])
choices = Array[ExtResource("4")]([])

[resource]
script = ExtResource("1")
id = &"{nid}"
display_name = &"{key}"
body_color = {color}
entries = Array[ExtResource("5")]([SubResource("s1")])
attacked_flag = &""
hidden_when_flag = &""
'''


LORE = {"LORE-R2-01": "r2_verdant", "LORE-R2-02": "r2_verdant", "LORE-R3-01": "r3_dunes", "LORE-R3-02": "r3_dunes"}

# id: (region, kind, tier, conditions [(type, key, values, value)], hints, rewards [(type, key, amount)])
# Condition types: 0 FLAG, 1 WEATHER, 3 IS_NIGHT, 4 IN_AREA. Reward types: 1 GOLD, 2 XP, 5 LORE, 0 ITEM.
SECRETS = {
    "SEC-R2-07": ("r2_verdant", 0, 0, [(0, "r2_root_wall_broken", [], 0)], ["HINT_SEC_R2_07_1", "HINT_SEC_R2_07_2"],
                  [(5, "LORE-R2-01", 1), (1, "", 400), (0, "potion_small", 3)]),
    "SEC-R2-06": ("r2_verdant", 0, 1, [(4, "sec_r2_06_lake", [], 0), (3, "", [], 0), (1, "", ["fog"], 0)],
                  ["HINT_SEC_R2_06_1", "HINT_SEC_R2_06_2"], [(5, "LORE-R2-02", 1), (2, "", 1500), (1, "", 600)]),
    "SEC-R3-01": ("r3_dunes", 0, 1, [(4, "sec_r3_01_storm", [], 0), (1, "", ["storm"], 0)],
                  ["HINT_SEC_R3_01_1", "HINT_SEC_R3_01_2"], [(5, "LORE-R3-01", 1), (2, "", 3000), (1, "", 900)]),
    "SEC-R3-09": ("r3_dunes", 0, 0, [(0, "r3_tomb_wall_broken", [], 0)], ["HINT_SEC_R3_09_1", "HINT_SEC_R3_09_2"],
                  [(5, "LORE-R3-02", 1), (1, "", 1200), (0, "potion_small", 5)]),
}


def secret_tres(sid, row):
    region, kind, tier, conds, hints, rewards = row
    subs = []
    cids = []
    for i, (ctype, key, values, value) in enumerate(conds):
        vals = ", ".join(f'&"{v}"' for v in values)
        subs.append(f'''[sub_resource type="Resource" id="c{i}"]
script = ExtResource("2")
type = {ctype}
key = &"{key}"
values = Array[StringName]([{vals}])
value = {float(value)}
value2 = 0.0
negate = false
''')
        cids.append(f'SubResource("c{i}")')
    rids = []
    for i, (rtype, key, amount) in enumerate(rewards):
        subs.append(f'''[sub_resource type="Resource" id="r{i}"]
script = ExtResource("3")
type = {rtype}
key = &"{key}"
amount = {amount}
text = &""
''')
        rids.append(f'SubResource("r{i}")')
    hints_s = ", ".join(f'&"{h}"' for h in hints)
    return f'''[gd_resource type="Resource" script_class="SecretData" format=3]

[ext_resource type="Script" path="res://scripts/resources/secret_data.gd" id="1"]
[ext_resource type="Script" path="res://scripts/resources/condition_data.gd" id="2"]
[ext_resource type="Script" path="res://scripts/resources/reward_data.gd" id="3"]

{chr(10).join(subs)}
[resource]
script = ExtResource("1")
id = &"{sid}"
display_name = &"SECRET_{sid.replace('-', '_')}"
kind = {kind}
tier = {tier}
region = &"{region}"
trigger = 0
mission = &""
conditions = Array[ExtResource("2")]([{", ".join(cids)}])
hints = Array[StringName]([{hints_s}])
rewards = Array[ExtResource("3")]([{", ".join(rids)}])
unlocks = Array[StringName]([])
fail_conditions = Array[ExtResource("2")]([])
'''


# --- regions -------------------------------------------------------------------------------

REGIONS = {
    # id: dict
    "r1_ashfall": dict(name="REGION_R1", lv=(1, 10), secrets=13, missions=3, scene="res://scenes/main/game.tscn",
                       spawn=(0, 0.2, 12), weather={"clear": 50.0, "rain": 35.0, "fog": 10.0, "storm": 5.0},
                       waystones={"r1_camp": (6, 0, 12), "r1_overpass": (136, 0, -10)},
                       gates=["gate_r1_e_overpass", "gate_r1_e_culvert"],
                       points=[(128, 0, 128), (-128, 0, -128), (128, 0, -128), (0, 0, 128)],
                       breakers=["ash_hound", "gate_husk"]),
    "r2_verdant": dict(name="REGION_R2", lv=(10, 25), secrets=31, missions=6, scene="res://scenes/world/regions/verdant.tscn",
                       spawn=(0, 0.3, 10), weather={"clear": 35.0, "rain": 30.0, "fog": 30.0, "storm": 5.0},
                       waystones={"r2_glade": (0, 0, 6), "r2_roots": (128, 0, 14)},
                       gates=["gate_r2_d_thicket", "gate_r2_c_rootheart"],
                       points=[(-128, 0, 128), (-128, 0, -128), (128, 0, 128), (0, 0, 128)],
                       breakers=["thorn_stalker", "moss_brute"]),
    "r3_dunes": dict(name="REGION_R3", lv=(25, 40), secrets=33, missions=6, scene="res://scenes/world/regions/dunes.tscn",
                     spawn=(0, 0.3, 10), weather={"clear": 55.0, "rain": 5.0, "fog": 10.0, "storm": 30.0},
                     waystones={"r3_oasis": (0, 0, 6), "r3_ruins": (128, 0, 14)},
                     gates=["gate_r3_c_mirage", "gate_r3_b_tomb"],
                     points=[(-128, 0, 128), (-128, 0, -128), (128, 0, 128), (0, 0, 128)],
                     breakers=["dune_scuttler", "sand_wraith"]),
}


def vec(p):
    return "Vector3(%g, %g, %g)" % p


def region_tres(rid, r):
    ext = ['[ext_resource type="Script" path="res://scripts/resources/region_data.gd" id="1"]',
           '[ext_resource type="Script" path="res://scripts/resources/weather_table.gd" id="2"]',
           '[ext_resource type="Script" path="res://scripts/resources/gate_data.gd" id="3"]',
           '[ext_resource type="Script" path="res://scripts/resources/enemy_data.gd" id="4"]']
    for i, g in enumerate(r["gates"]):
        ext.append(f'[ext_resource type="Resource" path="res://data/gates/{g}.tres" id="g{i}"]')
    for i, e in enumerate(r["breakers"]):
        ext.append(f'[ext_resource type="Resource" path="{enemy_path(e)}" id="b{i}"]')
    weights = ", ".join(f'&"{k}": {v}' for k, v in r["weather"].items())
    ways = ", ".join(f'&"{k}": {vec(v)}' for k, v in r["waystones"].items())
    pts = ", ".join("%g, %g, %g" % p for p in r["points"])
    gates = ", ".join(f'ExtResource("g{i}")' for i in range(len(r["gates"])))
    breakers = ", ".join(f'ExtResource("b{i}")' for i in range(len(r["breakers"])))
    return f'''[gd_resource type="Resource" script_class="RegionData" format=3]

{chr(10).join(ext)}

[sub_resource type="Resource" id="weather"]
script = ExtResource("2")
weights = Dictionary[StringName, float]({{{weights}}})
min_duration_minutes = 90.0
max_duration_minutes = 240.0

[resource]
script = ExtResource("1")
id = &"{rid}"
display_name = &"{r["name"]}"
level_min = {r["lv"][0]}
level_max = {r["lv"][1]}
secret_total = {r["secrets"]}
mission_total = {r["missions"]}
weather = SubResource("weather")
scene_path = "{r["scene"]}"
spawn = {vec(r["spawn"])}
waystones = Dictionary[StringName, Vector3]({{{ways}}})
gate_table = Array[ExtResource("3")]([{gates}])
gate_points = PackedVector3Array({pts})
max_world_gates = {r.get("max_gates", 2)}
break_pool = Array[ExtResource("4")]([{breakers}])
'''


def region_scene(name, rid, chunk_dir, sky_top, horizon, fog_density, sun_color, spawn):
    return f'''[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/systems/world/region_controller.gd" id="1"]
[ext_resource type="Resource" path="res://data/regions/{rid}.tres" id="2"]
[ext_resource type="PackedScene" path="res://scenes/player/player.tscn" id="3"]
[ext_resource type="PackedScene" path="res://scenes/main/game_shell.tscn" id="4"]
[ext_resource type="Script" path="res://scripts/systems/world/environment_controller.gd" id="5"]

[sub_resource type="ProceduralSkyMaterial" id="Sky_mat"]
sky_top_color = {sky_top}
sky_horizon_color = {horizon}
ground_horizon_color = {horizon}

[sub_resource type="Sky" id="Sky_main"]
sky_material = SubResource("Sky_mat")

[sub_resource type="Environment" id="Environment_main"]
background_mode = 2
sky = SubResource("Sky_main")
ambient_light_source = 3
tonemap_mode = 2
fog_enabled = true
fog_light_color = {horizon}
fog_density = {fog_density}

[sub_resource type="ParticleProcessMaterial" id="PPM_rain"]
emission_shape = 3
emission_box_extents = Vector3(18, 1, 18)
direction = Vector3(0, -1, 0)
spread = 3.0
initial_velocity_min = 22.0
initial_velocity_max = 26.0

[sub_resource type="StandardMaterial3D" id="M_rain"]
transparency = 1
shading_mode = 0
albedo_color = Color(0.7, 0.8, 1, 0.45)
billboard_mode = 2

[sub_resource type="QuadMesh" id="Q_rain"]
material = SubResource("M_rain")
size = Vector2(0.02, 0.5)

[node name="{name}" type="Node3D"]
script = ExtResource("1")
region = ExtResource("2")
chunk_dir = "{chunk_dir}"

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_main")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.866025, -0.25, 0.433013, 0, 0.866025, 0.5, -0.5, -0.433013, 0.75, 0, 20, 0)
light_color = {sun_color}
shadow_enabled = true
directional_shadow_max_distance = 120.0

[node name="Environment" type="Node" parent="." node_paths=PackedStringArray("sun", "world_environment", "rain")]
script = ExtResource("5")
sun = NodePath("../Sun")
world_environment = NodePath("../WorldEnvironment")
rain = NodePath("../Rain")
day_fog_color = {horizon}

[node name="Rain" type="GPUParticles3D" parent="."]
emitting = false
amount = 1500
lifetime = 1.2
visibility_aabb = AABB(-20, -30, -20, 40, 32, 40)
process_material = SubResource("PPM_rain")
draw_pass_1 = SubResource("Q_rain")

[node name="Chunks" type="Node3D" parent="."]
unique_name_in_owner = true

[node name="Player" parent="." instance=ExtResource("3")]
unique_name_in_owner = true
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {spawn[0]}, {spawn[1]}, {spawn[2]})

[node name="GameShell" parent="." instance=ExtResource("4")]
'''


# --- chunk content -------------------------------------------------------------------------

def waystone(c, wid, pos):
    c.instance("waystone", pos, f'waystone_id = &"{wid}"\n')


def road(c, target, pos):
    c.instance("waystone", pos, f'road_to = &"{target}"\n')


def walls(c, center, size, height, color, doors):
    """Four walls; `doors` maps side ('n','s','e','w') -> gap width."""
    cx, cy, cz = center
    sx, sz = size
    t = 0.6
    for side in "nsew":
        gap = doors.get(side, 0.0)
        if side in "ns":
            z = cz - sz / 2 if side == "n" else cz + sz / 2
            part = (sx - gap) / 2
            for sign in ((-1, 1) if gap else (0,)):
                w = part if gap else sx
                c.block((w, height, t), (cx + sign * (gap / 2 + part / 2), cy + height / 2, z), color)
        else:
            x = cx - sx / 2 if side == "w" else cx + sx / 2
            part = (sz - gap) / 2
            for sign in ((-1, 1) if gap else (0,)):
                w = part if gap else sz
                c.block((t, height, w), (x, cy + height / 2, cz + sign * (gap / 2 + part / 2)), color)


def tree(c, rng, pos, scale=1.0, kind="oak"):
    c.tree(kind, (pos[0], 0, pos[1]), rng.uniform(7, 14) * scale, rng.randint(1, 1 << 30))


def forest_ground(c):
    c.block((128, 1, 128), (0, -0.5, 0), FOREST)
    c.grass("Color(0.26, 0.5, 0.26, 1)", 40000, sum(ord(ch) * (i + 1) for i, ch in enumerate(c.name)) % 100000)


def sand_ground(c):
    c.block((128, 1, 128), (0, -0.5, 0), SAND)


def glade(c):
    forest_ground(c)
    rng = random.Random(21)
    for i, (x, z) in enumerate([(-16, -8), (16, -10), (-12, 16), (14, 14)]):
        c.prop("bld_glade_hut", (x, 0, z), (6, 5, 6), BARK, rot_y=i * 30)
    for _ in range(14):
        p = (rng.uniform(-58, 58), rng.uniform(-58, 58))
        if abs(p[0]) > 24 or abs(p[1]) > 24:
            tree(c, rng, p)
    c.decor("campfire", (0, 0, -6))
    for i, p in enumerate([(-10, 0, 0), (10, 0, 0), (-8, 0, -18), (8, 0, -18), (0, 0, 20)]):
        c.decor("lantern", p, "Color(0.7, 1, 0.6, 1)", seed=60 + i)
    for i in range(6):
        c.decor("fence", (-22 + i * 3.0, 0, 30), seed=70 + i)
    waystone(c, "r2_glade", (0, 0, 6))
    road(c, "r1_camp", (-8, 0, 24))
    c.npc("warden_sela", (6, 0, -2), 200)
    c.instance("sign", (-4, 0, 26), 'text_key = &"SIGN_R2_ROAD"\n')
    wd.glade(c)
    c.label("MOSSGATE GLADE", (0, 9, -20), 64)


def root_shrine(c):
    forest_ground(c)
    # Great roots arching over a shrine; the back wall of its inner room is cracked.
    for i in range(6):
        c.block((3, 3, 34), (-18 + i * 7, 6, -6), ROOT, rot_y=90, rot_x=0)
    walls(c, (0, 0, -14), (22, 16), 6, ROOT, {"s": 4, "n": 3})
    c.instance("wall", (0, 0, -22), 'save_flag = &"r2_root_wall_broken"\n')
    c.marker("SEC-R2-07", (0, 3, -22))
    walls(c, (0, 0, -28), (10, 12), 5, ROOT, {"s": 3})
    c.instance("lore", (0, 0, -31), 'lore_id = &"LORE-R2-01"\n')
    c.npc("root_monk", (5, 0, -8), 200)
    c.instance("sign", (-6, 0, -9), 'text_key = &"HINT_SEC_R2_07_2"\nhint_secret = &"SEC-R2-07"\nhint_key = &"HINT_SEC_R2_07_2"\n')
    waystone(c, "r2_roots", (0, 0, 14))
    c.instance("portal", (24, 0, 20), f'gate = {c.data("gate_r2_d_thicket")}\n')
    for p in [(30, 0.3, 30), (-30, 0.3, 26)]:
        c.spawner("thorn_stalker", p)
    wd.root_shrine(c)
    c.label("ROOT SHRINE", (0, 14, -14), 64)


def fog_lake(c):
    forest_ground(c)
    c.block((60, 0.2, 40), (0, 0.05, -6), POND, solid=False)
    c.block((6, 0.6, 30), (0, 0.3, -6), BARK)
    c.block((8, 0.6, 8), (0, 0.4, -24), BARK)
    c.secret_area("sec_r2_06_lake", (8, 4, 8), (0, 2, -24))
    c.marker("SEC-R2-06", (0, 2, -24))
    c.instance("lore", (-34, 0, 20), 'lore_id = &"LORE-R2-02"\nhint_secret = &"SEC-R2-06"\nhint_key = &"HINT_SEC_R2_06_2"\n')
    rng = random.Random(7)
    for _ in range(12):
        p = (rng.uniform(-58, 58), rng.uniform(-58, 58))
        if abs(p[0]) > 34 or abs(p[1] + 6) > 24:
            tree(c, rng, p, 1.2)
    c.spawner("moss_brute", (30, 0.3, 30))
    # World boss: respawns after half a real hour.
    c.spawner("rootheart_elder", (-30, 0.3, -40), 1800.0)
    wd.fog_lake(c)
    c.label("MISTLAKE", (0, 10, 20), 64)


def forest_filler(c, seed, enemy, road_to=None):
    forest_ground(c)
    rng = random.Random(seed)
    for _ in range(16):
        p = (rng.uniform(-58, 58), rng.uniform(-58, 58))
        if abs(p[0]) < 12 and abs(p[1]) < 12:
            continue
        tree(c, rng, p)
    for _ in range(3):
        c.spawner(enemy, (rng.uniform(-40, 40), 0.3, rng.uniform(-40, 40)))
    if road_to:
        road(c, road_to, (0, 0, 0))


def oasis(c):
    sand_ground(c)
    c.block((26, 0.2, 18), (0, 0.05, -14), OASIS, solid=False)
    for i, (x, z) in enumerate([(-18, 6), (18, 4), (-14, 18), (16, 18)]):
        c.block((5, 3, 5), (x, 1.5, z), STONE, rot_y=i * 17)
    rng = random.Random(33)
    for i in range(9):
        a = i / 9 * 6.283
        c.tree("palm", (math.cos(a) * 17, 0, -14 + math.sin(a) * 12), rng.uniform(6, 9), 300 + i)
    for i, p in enumerate([(-6, 0, 12), (6, 0, 12), (-20, 0, 0), (20, 0, 0)]):
        c.decor("lantern", p, "Color(1, 0.6, 0.3, 1)", seed=80 + i)
    for i, p in enumerate([(-15, 0, 8), (-14, 0, 9.5), (17, 0, 7), (13, 0, 16), (-12, 0, 18)]):
        c.decor("barrel" if i % 2 else "crate", p, seed=90 + i)
    c.decor("banner", (0, 0, 26), "Color(0.85, 0.3, 0.2, 1)")
    waystone(c, "r3_oasis", (0, 0, 6))
    road(c, "r2_roots", (-8, 0, 24))
    c.npc("trader_kadir", (6, 0, 2), 200)
    c.npc("dune_cartographer", (-6, 0, 0), 160)
    c.instance("sign", (8, 0, 24), 'text_key = &"HINT_SEC_R3_01_2"\nhint_secret = &"SEC-R3-01"\nhint_key = &"HINT_SEC_R3_01_2"\n')
    wd.oasis(c)
    c.label("RED OASIS", (0, 9, -28), 64)


def colonnade(c):
    sand_ground(c)
    xs = [-28 + i * 8 for i in range(8)]
    hs = [4 + (i * 37) % 7 for i in range(8)]
    wd.colonnade_pillars(c, xs, -10, hs)
    wd.colonnade_pillars(c, xs, 10, hs)
    # Half-buried tomb with a cracked door.
    walls(c, (0, 0, -36), (18, 14), 5, STONE, {"s": 3})
    c.instance("wall", (0, 0, -29), 'save_flag = &"r3_tomb_wall_broken"\n')
    c.marker("SEC-R3-09", (0, 3, -29))
    c.instance("lore", (0, 0, -38), 'lore_id = &"LORE-R3-02"\n')
    c.instance("sign", (6, 0, -24), 'text_key = &"HINT_SEC_R3_09_2"\nhint_secret = &"SEC-R3-09"\nhint_key = &"HINT_SEC_R3_09_2"\n')
    waystone(c, "r3_ruins", (0, 0, 14))
    c.instance("portal", (26, 0, 22), f'gate = {c.data("gate_r3_c_mirage")}\n')
    for p in [(30, 0.3, 32), (-30, 0.3, 30)]:
        c.spawner("dune_scuttler", p)
    c.label("SUNKEN COLONNADE", (0, 16, 0), 64)


def storm_dune(c):
    sand_ground(c)
    rng = random.Random(55)
    for _ in range(8):
        s = (rng.uniform(10, 24), rng.uniform(2, 5), rng.uniform(10, 24))
        p = (rng.uniform(-48, 48), s[1] / 2, rng.uniform(-48, 48))
        if abs(p[0]) < 14 and abs(p[2]) < 14:
            continue
        c.block(s, p, DUNE, rot_y=rng.uniform(0, 90))
    # A doorway only meaningful in a sandstorm (the area triggers SEC-R3-01).
    c.block((1, 6, 1), (-2.5, 3, 0), STONE)
    c.block((1, 6, 1), (2.5, 3, 0), STONE)
    c.block((6, 1, 1), (0, 6.5, 0), STONE)
    c.secret_area("sec_r3_01_storm", (5, 6, 3), (0, 3, 0))
    c.marker("SEC-R3-01", (0, 3, 0))
    c.instance("lore", (0, 0, -6), 'lore_id = &"LORE-R3-01"\n')
    c.spawner("sand_wraith", (26, 0.3, 26))
    c.spawner("crimson_burrower", (-34, 0.3, -36), 1800.0)
    wd.storm_dune(c)
    c.label("LONE GATEWAY", (0, 10, 0), 64)


def desert_filler(c, seed, enemy, road_to=None):
    sand_ground(c)
    rng = random.Random(seed)
    for _ in range(9):
        s = (rng.uniform(8, 20), rng.uniform(1.5, 4), rng.uniform(8, 20))
        p = (rng.uniform(-50, 50), s[1] / 2, rng.uniform(-50, 50))
        if abs(p[0]) < 14 and abs(p[2]) < 14:
            continue
        c.block(s, p, DUNE, rot_y=rng.uniform(0, 90))
    for _ in range(3):
        c.spawner(enemy, (rng.uniform(-40, 40), 0.3, rng.uniform(-40, 40)))
    for i in range(3):
        p = (rng.uniform(-56, 56), 0, rng.uniform(-56, 56))
        if abs(p[0]) > 14 or abs(p[2]) > 14:
            c.tree("dead", p, rng.uniform(4, 7), seed * 50 + i)
    if road_to:
        road(c, road_to, (0, 0, 0))


TERRAIN = {
    "r2": ("verdant", 6.0, 202, "ground_r2", 3, ()), "r3": ("dunes", 5.0, 303, "ground_r3", 2, ()),
    "r4": ("frost", 7.0, 404, "ground_r4", 3, ()), "r5": ("archive", 2.0, 505, "ground_r1", 1, ((1, 0),)),
    "r6": ("fracture", 3.0, 606, "ground_r7", 2, ()), "r7": ("hollow", 1.5, 707, "ground_r7", 2, ()),
}


def region_chunks(folder, layout, filler):
    built = {}
    for x in (-1, 0, 1):
        for z in (-1, 0, 1):
            c = ga.Chunk(f"Chunk_{x}_{z}")
            builder = layout.get((x, z))
            if builder:
                builder(c)
            else:
                filler(c, x, z)
            ga.edges(c, x, z)
            built[(x, z)] = c
    style, amp, seed, outcrop, count, skip = TERRAIN[folder]
    ga.finish_region(built, folder, style, amp, seed, outcrop, count, skip)


def main():
    for k in ["thorn_stalker", "moss_brute", "rootheart_elder", "dune_scuttler", "sand_wraith", "crimson_burrower"]:
        ga.DATA[k] = enemy_path(k)
    for k in GATES:
        ga.DATA[k] = f"res://data/gates/{k}.tres"
    for k in NPCS:
        ga.DATA[k] = f"res://data/dialogs/{k}.tres"
    for eid, row in ENEMIES.items():
        write(f"data/enemies/{eid}.tres", enemy_tres(eid, row))
    for gid, row in GATES.items():
        write(f"data/gates/{gid}.tres", gate_tres(gid, row))
    for nid, row in NPCS.items():
        write(f"data/dialogs/{nid}.tres", npc_tres(nid, row))
    for lid, region in LORE.items():
        key = lid.replace("-", "_")
        write(f"data/lore/{lid}.tres", f'''[gd_resource type="Resource" script_class="LoreData" format=3]

[ext_resource type="Script" path="res://scripts/resources/lore_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"{lid}"
title = &"{key}_T"
text = &"{key}"
region = &"{region}"
''')
    for sid, row in SECRETS.items():
        folder = "r2" if row[0] == "r2_verdant" else "r3"
        write(f"data/secrets/{folder}/{sid}.tres", secret_tres(sid, row))
    # Region data (.tres) is hand-tuned since 2026-11-08 (levels) and its chunks are 5x5
    # since 2026-11-10: both come from tools/gen_region_towns.py now.
    write("scenes/world/regions/verdant.tscn", region_scene("Verdant", "r2_verdant", "res://scenes/world/chunks/r2",
          "Color(0.25, 0.4, 0.35, 1)", "Color(0.55, 0.65, 0.55, 1)", 0.012, "Color(0.95, 1, 0.85, 1)", REGIONS["r2_verdant"]["spawn"]))
    write("scenes/world/regions/dunes.tscn", region_scene("Dunes", "r3_dunes", "res://scenes/world/chunks/r3",
          "Color(0.45, 0.35, 0.4, 1)", "Color(0.85, 0.6, 0.45, 1)", 0.005, "Color(1, 0.88, 0.75, 1)", REGIONS["r3_dunes"]["spawn"]))
    print("m9 world written")


if __name__ == "__main__":
    main()
