#!/usr/bin/env python3
"""M11 (Big Phase 1 graybox): Regions 4–6, the Hidden Region (Hollow Throne), Red Gates,
the Shadow Sovereign keys and the main story chapters 1–7.

Run from the project root after gen_m9_world.py:  python3 tools/gen_m11_world.py
Edit here, not the generated files.
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import gen_ashfall_chunks as ga  # noqa: E402
import gen_m9_world as w  # noqa: E402
import world_dressing as wd  # noqa: E402

SNOW = "Color(0.72, 0.77, 0.85, 1)"
ICE = "Color(0.55, 0.75, 0.92, 1)"
ROCK = "Color(0.45, 0.48, 0.55, 1)"
WATERSTONE = "Color(0.35, 0.42, 0.48, 1)"
SHELF = "Color(0.42, 0.3, 0.22, 1)"
VOIDWHITE = "Color(0.95, 0.95, 0.97, 1)"
RIFT = "Color(0.35, 0.25, 0.5, 1)"
NEG = "Color(0.12, 0.1, 0.16, 1)"
NEG_EDGE = "Color(0.85, 0.85, 0.9, 1)"

ga.EXT["gravity"] = ("Script", "res://scripts/systems/world/gravity_zone.gd")
ga.EXT["flagdoor"] = ("Script", "res://scripts/systems/world/flag_door.gd")
ga.EXT["tide"] = ("Script", "res://scripts/systems/world/tide_water.gd")
ga.EXT["ending"] = ("Script", "res://scripts/systems/world/ending_trigger.gd")

ENEMIES = {
    "frost_yeti": ("Frost Yeti", 44, "Color(0.85, 0.88, 0.95, 1)", 2, 0, {"hp_scale": 1.4, "chase_speed": 4.0, "attack_windup_s": 0.8, "attack_multiplier": 1.25}),
    "ice_wyvernling": ("Ice Wyvernling", 48, "Color(0.5, 0.75, 0.95, 1)", 2, 0, {"hp_scale": 0.9, "chase_speed": 6.0, "attack_windup_s": 0.55}),
    "glacier_colossus": ("Glacier Colossus", 54, "Color(0.6, 0.8, 0.95, 1)", 2, 2, {"hp_scale": 0.3, "attack_scale": 0.9, "poise": 180.0, "attack_range": 3.2,
                                                                                   "attack_windup_s": 1.0, "attack_hitbox_size": "Vector3(4, 2, 3.4)",
                                                                                   "telegraph_radius": 3.2, "aggro_radius": 30.0, "leash_radius": 70.0}),
    "echo_king": ("Echo King", 55, "Color(0.25, 0.2, 0.35, 1)", 6, 2, {"hp_scale": 0.35, "attack_scale": 1.0, "poise": 200.0, "attack_range": 3.0,
                                                                     "attack_windup_s": 0.7, "attack_hitbox_size": "Vector3(3.6, 2, 3)",
                                                                     "telegraph_radius": 3.0, "aggro_radius": 25.0, "leash_radius": 50.0,
                                                                     "death_flag": '&"echo_king_answered"'}),
    "drowned_scribe": ("Drowned Scribe", 58, "Color(0.4, 0.55, 0.65, 1)", 2, 0, {"hp_scale": 1.0, "chase_speed": 4.4, "attack_windup_s": 0.7}),
    "ink_wraith": ("Ink Wraith", 62, "Color(0.1, 0.1, 0.18, 1)", 6, 0, {"hp_scale": 1.1, "chase_speed": 5.2, "attack_windup_s": 0.6, "attack_multiplier": 1.2}),
    "captain_ink": ("Captain Ink", 68, "Color(0.15, 0.2, 0.35, 1)", 6, 2, {"hp_scale": 0.32, "attack_scale": 0.95, "poise": 200.0, "attack_range": 3.0,
                                                                         "attack_windup_s": 0.85, "attack_hitbox_size": "Vector3(3.6, 2, 3)",
                                                                         "telegraph_radius": 3.0, "aggro_radius": 30.0, "leash_radius": 70.0}),
    "void_hollow": ("Void Hollow", 74, "Color(0.9, 0.9, 0.95, 1)", 8, 0, {"hp_scale": 1.2, "chase_speed": 4.8, "attack_windup_s": 0.65}),
    "rift_stalker": ("Rift Stalker", 80, "Color(0.55, 0.4, 0.9, 1)", 5, 0, {"hp_scale": 1.0, "chase_speed": 6.4, "attack_windup_s": 0.5, "attack_multiplier": 1.3}),
    "rift_devourer": ("Rift Devourer", 88, "Color(0.3, 0.2, 0.45, 1)", 8, 2, {"hp_scale": 0.35, "attack_scale": 1.0, "poise": 220.0, "attack_range": 3.4,
                                                                            "attack_windup_s": 0.9, "attack_hitbox_size": "Vector3(4, 2, 3.4)",
                                                                            "telegraph_radius": 3.4, "aggro_radius": 30.0, "leash_radius": 70.0}),
    "hollow_echo": ("Hollow Echo", 86, "Color(0.8, 0.8, 0.85, 1)", 8, 1, {"hp_scale": 0.8, "chase_speed": 5.4, "attack_windup_s": 0.55}),
    "the_unwritten": ("The Unwritten — Avatar", 90, "Color(0.98, 0.98, 1, 1)", 8, 2, {"hp_scale": 0.5, "attack_scale": 1.05, "poise": 260.0, "attack_range": 3.6,
                                                                                    "attack_windup_s": 0.8, "attack_hitbox_size": "Vector3(4.4, 2.4, 3.6)",
                                                                                    "telegraph_radius": 3.6, "aggro_radius": 26.0, "leash_radius": 60.0,
                                                                                    "death_flag": '&"unwritten_defeated"'}),
}

GATES = {
    "gate_r4_b_icecave": ("GATE_R4_B_ICECAVE", 3, 5101, 5, ["frost_yeti", "ice_wyvernling"], "glacier_colossus", 2, 1800, {"potion_small": 5}),
    "gate_r4_a_mirror": ("GATE_R4_A_MIRROR", 4, 5177, 6, ["ice_wyvernling", "frost_yeti"], "glacier_colossus", 3, 2600, {"potion_small": 6}),
    "gate_r5_a_tidal": ("GATE_R5_A_TIDAL", 4, 6101, 6, ["drowned_scribe", "ink_wraith"], "captain_ink", 3, 3400, {"potion_small": 6}),
    "gate_r5_a_red_library": ("GATE_R5_A_RED_LIBRARY", 4, 6188, 7, ["ink_wraith", "drowned_scribe"], "captain_ink", 3, 3600, {"potion_small": 8}),
    "gate_r6_s_fracture": ("GATE_R6_S_FRACTURE", 5, 7101, 7, ["void_hollow", "rift_stalker"], "rift_devourer", 4, 5200, {"potion_small": 8}),
    "gate_r6_s_red_rift": ("GATE_R6_S_RED_RIFT", 5, 7199, 8, ["rift_stalker", "void_hollow"], "rift_devourer", 4, 5600, {"potion_small": 10}),
}
RED = {"gate_r5_a_red_library", "gate_r6_s_red_rift"}

NPCS = {
    "ice_hunter": ("NPC_ICE_HUNTER", "Color(0.7, 0.75, 0.85, 1)", ["DLG_ICE_HUNTER_1", "HINT_SEC_R4_03_1", "HINT_SEC_R4_08_1"]),
    "archive_nun": ("NPC_ARCHIVE_NUN", "Color(0.35, 0.35, 0.5, 1)", ["DLG_NUN_1", "HINT_SEC_R5_03_1", "HINT_SEC_R5_01_1"]),
    "rift_watcher": ("NPC_RIFT_WATCHER", "Color(0.6, 0.5, 0.8, 1)", ["DLG_WATCHER_1", "HINT_SEC_R6_04_1", "HINT_SEC_R6_02_1", "HINT_HOLLOW_1"]),
}

LORE = {"LORE-R4-03": "r4_frostveil", "LORE-R4-08": "r4_frostveil", "LORE-R5-01": "r5_archive", "LORE-R5-UMBRA": "r5_archive",
        "LORE-R6-02": "r6_fracture", "LORE-R6-03": "r6_fracture", "LORE-HT-04": "r7_hollow_throne"}

# Condition types: 0 FLAG, 1 WEATHER, 2 HOUR_RANGE, 4 IN_AREA. Rewards: 1 GOLD, 2 XP, 3 FLAG, 5 LORE.
SECRETS = {
    "SEC-R4-03": ("r4_frostveil", 0, 2, [(4, "sec_r4_03_summit", [], 0, 0), (1, "", ["storm"], 0, 0)], ["HINT_SEC_R4_03_1", "HINT_SEC_R4_03_2"],
                  [(5, "LORE-R4-03", 1), (2, "", 12000), (1, "", 3000)]),
    "SEC-R4-08": ("r4_frostveil", 1, 2, [(0, "echo_king_answered", [], 0, 0)], ["HINT_SEC_R4_08_1", "HINT_SEC_R4_08_2"],
                  [(5, "LORE-R4-08", 1), (2, "", 20000), (1, "", 5000)]),
    "SEC-R5-01": ("r5_archive", 0, 0, [(4, "sec_r5_01_lower", [], 0, 0), (2, "", [], 12, 18)], ["HINT_SEC_R5_01_1", "HINT_SEC_R5_01_2"],
                  [(5, "LORE-R5-01", 1), (1, "", 4000)]),
    "SEC-R5-03": ("r5_archive", 0, 2, [(4, "sec_r5_03_archive", [], 0, 0)], ["HINT_SEC_R5_03_1", "HINT_SEC_R5_03_2"],
                  [(5, "LORE-R5-UMBRA", 1), (3, "codex_umbra_read", 1), (3, "shadow_sovereign_awakened", 1), (2, "", 25000)]),
    "SEC-R6-02": ("r6_fracture", 0, 1, [(4, "sec_r6_02_erased", [], 0, 0)], ["HINT_SEC_R6_02_1", "HINT_SEC_R6_02_2"],
                  [(5, "LORE-R6-02", 1), (1, "", 6000)]),
    "SEC-R6-04": ("r6_fracture", 0, 2, [(4, "sec_r6_04_tower_top", [], 0, 0)], ["HINT_SEC_R6_04_1", "HINT_SEC_R6_04_2"],
                  [(5, "LORE-R6-03", 1), (3, "fracture_heart", 1), (2, "", 40000)]),
}

REGIONS = {
    "r4_frostveil": dict(name="REGION_R4", lv=(40, 55), secrets=33, missions=6, scene="res://scenes/world/regions/frostveil.tscn",
                         spawn=(0, 0.3, 10), weather={"clear": 40.0, "rain": 5.0, "fog": 25.0, "storm": 30.0},
                         waystones={"r4_lodge": (0, 0, 6), "r4_temple": (128, 0, 14)},
                         gates=["gate_r4_b_icecave", "gate_r4_a_mirror"],
                         points=[(-128, 0, 128), (-128, 0, -128), (128, 0, 128), (0, 0, 128)], breakers=["frost_yeti", "ice_wyvernling"]),
    "r5_archive": dict(name="REGION_R5", lv=(55, 70), secrets=35, missions=7, scene="res://scenes/world/regions/archive.tscn",
                       spawn=(0, 0.3, 10), weather={"clear": 40.0, "rain": 30.0, "fog": 20.0, "storm": 10.0},
                       waystones={"r5_village": (0, 0, 6), "r5_library": (128, 0, 24)},
                       gates=["gate_r5_a_tidal", "gate_r5_a_red_library"],
                       points=[(-128, 0, 128), (-128, 0, -128), (128, 0, 128), (0, 0, 128)], breakers=["drowned_scribe", "ink_wraith"]),
    "r6_fracture": dict(name="REGION_R6", lv=(70, 90), secrets=30, missions=7, scene="res://scenes/world/regions/fracture.tscn",
                        spawn=(0, 0.3, 10), weather={"clear": 50.0, "rain": 0.0, "fog": 30.0, "storm": 20.0},
                        waystones={"r6_edge": (0, 0, 6), "r6_tower": (128, 0, 30)},
                        gates=["gate_r6_s_fracture", "gate_r6_s_red_rift"],
                        points=[(-128, 0, 128), (-128, 0, -128), (128, 0, 128), (0, 0, 128)], breakers=["void_hollow", "rift_stalker"]),
    "r7_hollow_throne": dict(name="REGION_R7", lv=(90, 100), max_gates=0, secrets=22, missions=6, scene="res://scenes/world/regions/hollow_throne.tscn",
                             spawn=(0, 0.3, 30), weather={"clear": 70.0, "fog": 30.0},
                             waystones={"r7_throne": (0, 0, 34)},
                             gates=["gate_r6_s_red_rift"], points=[(-128, 0, 128)], breakers=["hollow_echo"]),
}

# Main story: chapter -> (region first waystone flag, boss to defeat). Chapter 1 is q_r1_overpass.
CHAPTERS = [
    (2, "waystone_r2_glade", "rootheart_elder"),
    (3, "waystone_r3_oasis", "crimson_burrower"),
    (4, "waystone_r4_lodge", "glacier_colossus"),
    (5, "waystone_r5_village", "captain_ink"),
    (6, "waystone_r6_edge", "rift_devourer"),
    (7, "hollow_throne_entered", "the_unwritten"),
]


def secret_tres(sid, row):
    region, kind, tier, conds, hints, rewards = row
    text = w.secret_tres(sid, (region, kind, tier, [(c[0], c[1], c[2], c[3]) for c in conds], hints, rewards))
    for i, c in enumerate(conds):
        if c[4]:
            marker = f'[sub_resource type="Resource" id="c{i}"]'
            head, tail = text.split(marker, 1)
            tail = tail.replace("value2 = 0.0", f"value2 = {float(c[4])}", 1)
            text = head + marker + tail
    return text


def quest_tres(ch, flag, boss):
    prev = f"main_ch{ch - 1}_done"
    return f'''[gd_resource type="Resource" script_class="QuestData" format=3]

[ext_resource type="Script" path="res://scripts/resources/quest_data.gd" id="1"]
[ext_resource type="Script" path="res://scripts/resources/quest_objective.gd" id="2"]
[ext_resource type="Script" path="res://scripts/resources/reward_data.gd" id="3"]
[ext_resource type="Script" path="res://scripts/resources/condition_data.gd" id="4"]

[sub_resource type="Resource" id="c1"]
script = ExtResource("4")
type = 0
key = &"{prev}"
values = Array[StringName]([])
value = 0.0
value2 = 0.0
negate = false

[sub_resource type="Resource" id="o1"]
script = ExtResource("2")
type = 5
target = &"{flag}"
count = 1
text = &"QO_MAIN_{ch}_REACH"
stage = 0

[sub_resource type="Resource" id="o2"]
script = ExtResource("2")
type = 0
target = &"{boss}"
count = 1
text = &"QO_MAIN_{ch}_BOSS"
stage = 1

[sub_resource type="Resource" id="r1"]
script = ExtResource("3")
type = 2
key = &""
amount = {ch * 4000}

[sub_resource type="Resource" id="r2"]
script = ExtResource("3")
type = 3
key = &"main_ch{ch}_done"
amount = 1

[resource]
script = ExtResource("1")
id = &"q_main_ch{ch}"
title = &"QUEST_MAIN_{ch}"
description = &"QUEST_MAIN_{ch}_D"
kind = 0
auto_start = true
start_conditions = Array[ExtResource("4")]([SubResource("c1")])
guild_points = {ch * 15}
objectives = Array[ExtResource("2")]([SubResource("o1"), SubResource("o2")])
rewards = Array[ExtResource("3")]([SubResource("r1"), SubResource("r2")])
'''


def scripted(c, key, node_type, pos, props):
    n = c._id(key.capitalize())
    c.nodes.append(f'[node name="{n}" type="{node_type}" parent="."]\ntransform = {c.tf(pos)}\nscript = {c.ext(key)}\n{props}')


def ground(c, color):
    c.block((128, 1, 128), (0, -0.5, 0), color)


# --- R4 Frostveil ---------------------------------------------------------------------------

def lodge(c):
    ground(c, SNOW)
    rng = random.Random(404)
    for i in range(10):
        p = (rng.uniform(-58, 58), 0, rng.uniform(-58, 58))
        if abs(p[0]) > 22 or abs(p[2]) > 22:
            c.tree("pine", p, rng.uniform(8, 13), 900 + i, True)
    wd.lodge(c)
    c.decor("campfire", (0, 0, -4))
    for i, p in enumerate([(-10, 0, -2), (10, 0, -2), (0, 0, 18)]):
        c.decor("lamp", p, "Color(1, 0.8, 0.55, 1)", rot_y=i * 90.0)
    for i, p in enumerate([(-12, 0, -12), (-11, 0, -13.5), (13, 0, -12)]):
        c.decor("crate", p, seed=110 + i)
    w.waystone(c, "r4_lodge", (0, 0, 6))
    w.road(c, "r3_ruins", (-8, 0, 24))
    c.npc("ice_hunter", (6, 0, -2), 200)
    c.label("HUNTER'S LODGE", (0, 9, -20), 64)


def mirror_temple(c):
    ground(c, SNOW)
    w.walls(c, (0, 0, -10), (24, 18), 7, ICE, {"s": 4, "n": 3})
    c.instance("wall", (0, 0, -19), 'save_flag = &"r4_mirror_wall_broken"\n')
    w.walls(c, (0, 0, -34), (26, 26), 7, NEG, {"s": 3})
    c.spawner("echo_king", (0, 0.3, -38), 99999.0)
    c.marker("SEC-R4-08", (0, 4, -34))
    c.instance("sign", (-8, 0, -6), 'text_key = &"HINT_SEC_R4_08_2"\nhint_secret = &"SEC-R4-08"\nhint_key = &"HINT_SEC_R4_08_2"\n')
    w.waystone(c, "r4_temple", (0, 0, 14))
    c.instance("portal", (26, 0, 24), f'gate = {c.data("gate_r4_b_icecave")}\n')
    c.spawner("ice_wyvernling", (30, 0.3, -30))
    c.label("MIRROR TEMPLE", (0, 16, -10), 64)


def summit(c):
    ground(c, SNOW)
    # Stepped peak: climb the terraces to the flag at the top.
    for i in range(8):
        size = 44 - i * 5
        c.block((size, 2.5, size), (0, 1.25 + i * 2.5, -10), ROCK if i % 2 else SNOW)
    c.block((1, 4, 1), (0, 22, -10), ROCK)
    c.secret_area("sec_r4_03_summit", (8, 6, 8), (0, 22, -10))
    c.marker("SEC-R4-03", (0, 24, -10))
    c.instance("lore", (3, 20, -10), 'lore_id = &"LORE-R4-03"\nhint_secret = &"SEC-R4-03"\nhint_key = &"HINT_SEC_R4_03_2"\n')
    c.spawner("glacier_colossus", (34, 0.3, 30), 1800.0)
    c.label("FROSTVEIL SUMMIT", (0, 30, -10), 64)


def snow_filler(c, seed, enemy, road_to=None):
    ground(c, SNOW)
    rng = random.Random(seed)
    for _ in range(10):
        s = (rng.uniform(4, 12), rng.uniform(3, 9), rng.uniform(4, 12))
        p = (rng.uniform(-52, 52), s[1] / 2, rng.uniform(-52, 52))
        if abs(p[0]) < 14 and abs(p[2]) < 14:
            continue
        c.block(s, p, ROCK if rng.random() < 0.6 else ICE, rot_y=rng.uniform(0, 90))
    for _ in range(3):
        c.spawner(enemy, (rng.uniform(-40, 40), 0.3, rng.uniform(-40, 40)))
    for i in range(10):
        p = (rng.uniform(-58, 58), 0, rng.uniform(-58, 58))
        if abs(p[0]) > 14 or abs(p[2]) > 14:
            c.tree("pine", p, rng.uniform(8, 14), seed * 70 + i, True)
    if road_to:
        w.road(c, road_to, (0, 0, 0))


# --- R5 Sunken Archive ----------------------------------------------------------------------

def village(c):
    ground(c, WATERSTONE)
    wd.fisher_village(c)
    for i, p in enumerate([(-8, 0, 0), (8, 0, 0), (-8, 0, 18), (8, 0, 18)]):
        c.decor("lamp", p, "Color(0.6, 0.85, 1, 1)", rot_y=i * 90.0)
    for i, p in enumerate([(-18, 0, -2), (-17, 0, -3.5), (18, 0, -2), (18, 0, 10)]):
        c.decor("barrel", p, seed=130 + i)
    w.waystone(c, "r5_village", (0, 0, 6))
    w.road(c, "r4_lodge", (-8, 0, 24))
    c.npc("archive_nun", (6, 0, -2), 200)
    c.label("FISHER VILLAGE", (0, 9, -20), 64)


def library(c):
    ground(c, WATERSTONE)
    # Lower library: a sunken hall (floor at -1); the tide plane covers it at high tide.
    c.block((40, 0.5, 30), (0, -1.0, -14), SHELF)
    for x in (-15, -5, 5, 15):
        c.block((2, 6, 24), (x, 2, -14), SHELF)
    scripted(c, "tide", "Node3D", (0, 0, -14), "size = Vector2(44, 34)\n")
    c.secret_area("sec_r5_01_lower", (8, 3, 6), (0, 0.5, -24))
    c.marker("SEC-R5-01", (0, 2, -24))
    c.instance("lore", (0, -0.7, -26), 'lore_id = &"LORE-R5-01"\n')
    c.instance("sign", (6, 0, 4), 'text_key = &"HINT_SEC_R5_01_2"\nhint_secret = &"SEC-R5-01"\nhint_key = &"HINT_SEC_R5_01_2"\n')
    w.waystone(c, "r5_library", (0, 0, 24))
    c.instance("portal", (28, 0, 20), f'gate = {c.data("gate_r5_a_tidal")}\n')
    c.spawner("drowned_scribe", (30, 0.3, -30))
    c.label("GREAT LIBRARY", (0, 14, -14), 64)


def forbidden_archive(c):
    ground(c, WATERSTONE)
    w.walls(c, (0, 0, -12), (20, 18), 6, NEG, {"s": 3})
    scripted(c, "flagdoor", "StaticBody3D", (0, 0, -3), 'required_flag = &"echo_king_answered"\nsize = Vector3(3, 4, 0.6)\n')
    c.secret_area("sec_r5_03_archive", (6, 3, 6), (0, 1.5, -16))
    c.marker("SEC-R5-03", (0, 3, -16))
    c.instance("sign", (5, 0, 4), 'text_key = &"HINT_SEC_R5_03_2"\nhint_secret = &"SEC-R5-03"\nhint_key = &"HINT_SEC_R5_03_2"\n')
    c.block((20, 3, 6), (30, 1.5, 30), SHELF, rot_y=30)
    c.spawner("captain_ink", (30, 0.3, 22), 1800.0)
    c.label("FORBIDDEN ARCHIVE", (0, 10, -12), 64)


def water_filler(c, seed, enemy, road_to=None):
    ground(c, WATERSTONE)
    rng = random.Random(seed)
    for _ in range(10):
        s = (rng.uniform(4, 10), rng.uniform(2, 8), rng.uniform(4, 10))
        p = (rng.uniform(-52, 52), s[1] / 2, rng.uniform(-52, 52))
        if abs(p[0]) < 14 and abs(p[2]) < 14:
            continue
        c.block(s, p, SHELF if rng.random() < 0.5 else WATERSTONE, rot_y=rng.uniform(0, 90))
    for _ in range(3):
        c.spawner(enemy, (rng.uniform(-40, 40), 0.3, rng.uniform(-40, 40)))
    if road_to:
        w.road(c, road_to, (0, 0, 0))


# --- R6 The Fracture ------------------------------------------------------------------------

def rift_edge(c):
    ground(c, RIFT)
    for i, p in enumerate([(-8, 0, 0), (8, 0, 0), (0, 0, -14)]):
        c.decor("lantern", p, "Color(0.75, 0.55, 1, 1)", seed=150 + i)
    w.waystone(c, "r6_edge", (0, 0, 6))
    w.road(c, "r5_village", (-8, 0, 24))
    c.npc("rift_watcher", (6, 0, -2), 200)
    wd.rift_edge(c)
    c.label("RIFT EDGE", (0, 9, -20), 64)


def inverted_tower(c):
    ground(c, RIFT)
    # Light gravity around the tower: floating platforms spiral up to its crown.
    scripted(c, "gravity", "Area3D", (0, 20, -10), "size = Vector3(60, 44, 60)\ngravity_factor = 0.3\n")
    c.block((6, 40, 6), (0, 20, -10), VOIDWHITE)
    for i in range(12):
        a = i * 0.9
        r = 9.0
        c.block((4, 0.6, 4), (r * __import__("math").cos(a), 2.5 + i * 3.2, -10 + r * __import__("math").sin(a)), RIFT)
    c.block((10, 0.6, 10), (0, 40.3, -10), RIFT)
    c.secret_area("sec_r6_04_tower_top", (8, 4, 8), (0, 42.5, -10))
    c.marker("SEC-R6-04", (0, 43, -10))
    c.instance("lore", (3, 40.6, -10), 'lore_id = &"LORE-R6-03"\n')
    w.waystone(c, "r6_tower", (0, 0, 30))
    c.instance("portal", (30, 0, 28), f'gate = {c.data("gate_r6_s_fracture")}\n')
    c.label("INVERTED TOWER", (0, 48, -10), 64)


def erased_city(c):
    ground(c, VOIDWHITE)
    rng = random.Random(77)
    for _ in range(14):
        s = (rng.uniform(4, 10), rng.uniform(3, 14), rng.uniform(4, 10))
        p = (rng.uniform(-40, 40), s[1] / 2, rng.uniform(-40, 40))
        if abs(p[0]) < 10 and abs(p[2]) < 10:
            continue
        c.block(s, p, VOIDWHITE, rot_y=rng.uniform(0, 90))
    scripted(c, "gravity", "Area3D", (-30, 6, 30), "size = Vector3(30, 12, 30)\ngravity_factor = 1.9\ntint = Color(0.5, 0.3, 0.6, 0.1)\n")
    c.secret_area("sec_r6_02_erased", (6, 4, 6), (0, 2, 0))
    c.marker("SEC-R6-02", (0, 3, 0))
    c.instance("lore", (0, 0, 2), 'lore_id = &"LORE-R6-02"\nhint_secret = &"SEC-R6-02"\nhint_key = &"HINT_SEC_R6_02_2"\n')
    c.spawner("rift_devourer", (34, 0.3, -34), 1800.0)
    c.label("ERASED CITY", (0, 18, 0), 64)


def rift_filler(c, seed, enemy):
    ground(c, RIFT)
    rng = random.Random(seed)
    for _ in range(10):
        s = (rng.uniform(4, 10), rng.uniform(2, 6), rng.uniform(4, 10))
        p = (rng.uniform(-52, 52), rng.uniform(2, 14), rng.uniform(-52, 52))
        if abs(p[0]) < 14 and abs(p[2]) < 14:
            continue
        c.block(s, p, RIFT if rng.random() < 0.6 else VOIDWHITE, rot_y=rng.uniform(0, 90))
    for _ in range(3):
        c.spawner(enemy, (rng.uniform(-40, 40), 0.3, rng.uniform(-40, 40)))
    for i in range(6):
        p = (rng.uniform(-56, 56), 0, rng.uniform(-56, 56))
        if abs(p[0]) > 14 or abs(p[2]) > 14:
            c.tree("crystal", p, rng.uniform(3, 6), seed * 40 + i)


# --- R7 Hollow Throne -----------------------------------------------------------------------

def throne(c):
    ground(c, NEG)
    w.walls(c, (0, 0, -6), (40, 40), 9, NEG_EDGE, {"s": 6})
    c.block((10, 3, 4), (0, 1.5, -22), NEG_EDGE)
    c.block((4, 8, 1), (0, 6, -24), NEG_EDGE)
    c.spawner("the_unwritten", (0, 0.3, -14), 99999.0)
    for p in [(-12, 0.3, -4), (12, 0.3, -4)]:
        c.spawner("hollow_echo", p, 120.0)
    scripted(c, "ending", "Node3D", (0, 0, 0), "")
    c.instance("lore", (-15, 0, 12), 'lore_id = &"LORE-HT-04"\n')
    w.waystone(c, "r7_throne", (0, 0, 34))
    wd.throne(c)
    c.label("HOLLOW THRONE", (0, 14, -24), 72)


def void_filler(c):
    ground(c, NEG)


def main():
    for k in ENEMIES:
        ga.DATA[k] = w.enemy_path(k)
    for k in list(GATES) + list(w.GATES):
        ga.DATA[k] = f"res://data/gates/{k}.tres"
    for k in NPCS:
        ga.DATA[k] = f"res://data/dialogs/{k}.tres"
    for eid, row in ENEMIES.items():
        name, level, color, element, tier, extra = row
        w.write(f"data/enemies/{eid}.tres", w.enemy_tres(eid, row))
    for gid, row in GATES.items():
        text = w.gate_tres(gid, row)
        if gid in RED:
            text = text.replace("rules = Array[StringName]([])", 'rules = Array[StringName]([&"red", &"no_double"])')
        w.write(f"data/gates/{gid}.tres", text)
    for nid, row in NPCS.items():
        w.write(f"data/dialogs/{nid}.tres", w.npc_tres(nid, row))
    for lid, region in LORE.items():
        key = lid.replace("-", "_")
        w.write(f"data/lore/{lid}.tres", f'''[gd_resource type="Resource" script_class="LoreData" format=3]

[ext_resource type="Script" path="res://scripts/resources/lore_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"{lid}"
title = &"{key}_T"
text = &"{key}"
region = &"{region}"
''')
    for sid, row in SECRETS.items():
        folder = row[0][:2]
        w.write(f"data/secrets/{folder}/{sid}.tres", secret_tres(sid, row))
    # Region data and the R4-R6 chunks: tools/gen_region_towns.py (5x5 since 2026-11-10).
    for ch, flag, boss in CHAPTERS:
        w.write(f"data/quests/q_main_ch{ch}.tres", quest_tres(ch, flag, boss))
    scenes = [
        ("frostveil.tscn", "Frostveil", "r4_frostveil", "r4", "Color(0.55, 0.65, 0.8, 1)", "Color(0.82, 0.87, 0.93, 1)", 0.01, "Color(0.9, 0.95, 1, 1)"),
        ("archive.tscn", "Archive", "r5_archive", "r5", "Color(0.3, 0.4, 0.5, 1)", "Color(0.55, 0.62, 0.68, 1)", 0.009, "Color(0.85, 0.92, 1, 1)"),
        ("fracture.tscn", "Fracture", "r6_fracture", "r6", "Color(0.25, 0.15, 0.4, 1)", "Color(0.75, 0.7, 0.85, 1)", 0.004, "Color(0.95, 0.9, 1, 1)"),
        ("hollow_throne.tscn", "HollowThrone", "r7_hollow_throne", "r7", "Color(0.05, 0.04, 0.08, 1)", "Color(0.85, 0.85, 0.9, 1)", 0.008, "Color(0.8, 0.8, 1, 1)"),
    ]
    for fname, node, rid, folder, top, hor, fog, sun in scenes:
        w.write(f"scenes/world/regions/{fname}", w.region_scene(node, rid, f"res://scenes/world/chunks/{folder}", top, hor, fog, sun, REGIONS[rid]["spawn"]))
        os.makedirs(f"scenes/world/chunks/{folder}", exist_ok=True)
    w.region_chunks("r7", {(0, 0): throne}, lambda c, x, z: void_filler(c))
    print("m11 world written")


if __name__ == "__main__":
    main()
