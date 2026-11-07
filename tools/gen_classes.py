#!/usr/bin/env python3
"""Generates class data for Phantom, Arcanist and Ranger (+ passives for Vanguard).

Run from the project root:  python3 tools/gen_classes.py
Writes data/combat/<weapon>_combo.tres, data/skills/<class>/*.tres, data/classes/<class>.tres,
data/items/issued_*.tres. Stats mirror ASCENDANT_Balancing.xlsx sheet "Kelas".
Edit numbers here, not in the generated files.
"""
import os

# AttackData swing: 0 H, 1 V, 2 SPIN, 3 THRUST. Element: 0 phys 1 fire 2 ice 3 wind 4 earth 5 lightning 6 shadow 7 light.
# SkillData kind: 0 MELEE 1 DASH 2 AOE 3 BUFF 4 PROJECTILE 5 PASSIVE.


def attack(id, name, mult, heavy, st, ac, rc, size, off, kb, sg, hs, lg, sw, el=0, nl=None, nh=None, proj=None):
    return dict(id=id, name=name, mult=mult, heavy=heavy, st=st, ac=ac, rc=rc, size=size, off=off, kb=kb,
                sg=sg, hs=hs, lg=lg, sw=sw, el=el, nl=nl, nh=nh, proj=proj)


def proj(speed=28.0, range_m=30.0, radius=0.3, pierce=0, explode=0.0, count=1, spread=0.0, homing=False,
         lifetime=0.0, color="Color(0.7, 0.9, 1, 1)"):
    return dict(speed=speed, range_m=range_m, radius=radius, pierce=pierce, explode=explode, count=count,
                spread=spread, homing=homing, lifetime=lifetime, color=color)


class Tres:
    """Collects sub-resources for one .tres file."""

    def __init__(self, script_class):
        self.script_class = script_class
        self.ext = {}
        self.subs = []
        self.n = 0

    def ext_id(self, kind, path):
        if path not in self.ext:
            self.ext[path] = (kind, f"e{len(self.ext) + 1}")
        return f'ExtResource("{self.ext[path][1]}")'

    def sub(self, lines):
        self.n += 1
        sid = f"s{self.n}"
        self.subs.append("\n".join([f'[sub_resource type="Resource" id="{sid}"]'] + lines + [""]))
        return f'SubResource("{sid}")'

    def projectile(self, p):
        script = self.ext_id("Script", "res://scripts/resources/projectile_data.gd")
        return self.sub([f"script = {script}", f"speed = {p['speed']}", f"range_m = {p['range_m']}",
                         f"radius = {p['radius']}", f"pierce = {p['pierce']}", f"explode_radius = {p['explode']}",
                         f"count = {p['count']}", f"spread_degrees = {p['spread']}",
                         f"homing = {'true' if p['homing'] else 'false'}", f"lifetime_s = {p['lifetime']}",
                         f"color = {p['color']}"])

    def attack(self, a, refs=None):
        script = self.ext_id("Script", "res://scripts/resources/attack_data.gd")
        total = a["st"] + a["ac"] + a["rc"]
        lines = [f"script = {script}", f'id = &"{a["id"]}"', f'display_name = "{a["name"]}"',
                 f"damage_multiplier = {a['mult']}", f"is_heavy = {'true' if a['heavy'] else 'false'}",
                 f"element = {a['el']}", f"startup_s = {a['st']}", f"active_s = {a['ac']}", f"recovery_s = {a['rc']}",
                 f"combo_window_s = {round(a['st'] + a['ac'] + a['rc'] * 0.35, 3)}",
                 f"dodge_cancel_s = {round(a['st'] + a['ac'], 3)}",
                 "hitbox_size = Vector3(%s, %s, %s)" % a["size"], "hitbox_offset = Vector3(%s, %s, %s)" % a["off"],
                 f"knockback = {a['kb']}", f"stagger = {float(a['sg'])}", f"hit_stop_s = {a['hs']}",
                 f"lunge_speed = {a['lg']}", f"swing = {a['sw']}"]
        if a["proj"]:
            lines.append(f"projectile = {self.projectile(a['proj'])}")
        if refs:
            if a["nl"]:
                lines.append(f"next_light = {refs[a['nl']]}")
            if a["nh"]:
                lines.append(f"next_heavy = {refs[a['nh']]}")
        assert total > 0
        return self.sub(lines)

    def write(self, path, resource_lines):
        head = [f'[gd_resource type="Resource" script_class="{self.script_class}" format=3]', ""]
        for p, (kind, eid) in self.ext.items():
            head.append(f'[ext_resource type="{kind}" path="{p}" id="{eid}"]')
        with open(path, "w") as f:
            f.write("\n".join(head) + "\n\n" + "\n".join(self.subs) + "\n[resource]\n" + "\n".join(resource_lines) + "\n")


def write_combo(name, attacks, light_start, heavy_start):
    t = Tres("ComboData")
    refs = {}
    # Leaves first so references exist.
    pending = list(attacks)
    while pending:
        progressed = False
        for a in list(pending):
            deps = [d for d in (a["nl"], a["nh"]) if d]
            if all(d in refs for d in deps):
                refs[a["id"]] = t.attack(a, refs)
                pending.remove(a)
                progressed = True
        assert progressed, "combo graph has a cycle"
    script = t.ext_id("Script", "res://scripts/resources/combo_data.gd")
    path = f"data/combat/{name}_combo.tres"
    t.write(path, [f"script = {script}", f"light_start = {refs[light_start]}", f"heavy_start = {refs[heavy_start]}",
                   "chain_grace_s = 0.35"])
    return path


def write_skill(cls, s):
    t = Tres("SkillData")
    script = t.ext_id("Script", "res://scripts/resources/skill_data.gd")
    lines = [f"script = {script}", f'id = &"{s["id"]}"', f'display_name = "{s["name"]}"', f'description = "{s["desc"]}"',
             f"kind = {s['kind']}", f"is_ultimate = {'true' if s.get('ult') else 'false'}", f"icon_color = {s['color']}",
             f"unlock_level = {s['unlock']}", f"mp_cost = {s.get('mp', 0)}", f"cooldown_s = {s.get('cd', 1.0)}"]
    if s.get("attack"):
        lines += [f"attack = {t.attack(s['attack'])}", f"damage_multiplier = {s['mult']}",
                  f"multiplier_per_level = {s.get('per', 0.1)}"]
    if s["kind"] in (3, 5):
        lines += [f'buff_stat = &"{s["stat"]}"', f"buff_amount = {s['amount']}",
                  f"buff_duration_s = {s.get('duration', 10.0)}", f"buff_amount_per_level = {s.get('amount_per', 0.01)}"]
    os.makedirs(f"data/skills/{cls}", exist_ok=True)
    path = f"data/skills/{cls}/{s['id']}.tres"
    t.write(path, lines)
    return path


def write_class(cls, display, desc, magic, base, growth, split, combo_path, skills, combos):
    t = Tres("ClassData")
    script = t.ext_id("Script", "res://scripts/resources/class_data.gd")
    block = t.ext_id("Script", "res://scripts/resources/stat_block.gd")
    skill_script = t.ext_id("Script", "res://scripts/resources/skill_data.gd")
    combo_script = t.ext_id("Script", "res://scripts/resources/skill_combo_data.gd")

    def stats(v):
        return t.sub([f"script = {block}", f"strength = {float(v[0])}", f"agility = {float(v[1])}",
                      f"intelligence = {float(v[2])}", f"vitality = {float(v[3])}", f"sense = {float(v[4])}"])

    skill_refs = [t.ext_id("Resource", "res://" + write_skill(cls, s)) for s in skills]
    combo_refs = [t.sub([f"script = {combo_script}", f'id = &"{c[0]}"', f'display_name = "{c[1]}"', f'first = &"{c[2]}"',
                         f'second = &"{c[3]}"', f"window_s = {c[4]}", f"bonus_multiplier = {c[5]}",
                         f"force_crit = {'true' if c[6] else 'false'}", f"extra_stagger = {c[7]}"]) for c in combos]
    combo = t.ext_id("Resource", "res://" + combo_path)
    t.write(f"data/classes/{cls}.tres", [
        f"script = {script}", f'id = &"{cls}"', f'display_name = "{display}"', f'description = "{desc}"',
        f"magic_damage = {'true' if magic else 'false'}", f"base_stats = {stats(base)}", f"growth = {stats(growth)}",
        f"recommended_split = {stats(split)}", f"combo = {combo}",
        f"skills = Array[{skill_script}]([{', '.join(skill_refs)}])",
        f"skill_combos = Array[{combo_script}]([{', '.join(combo_refs)}])"])


def write_weapon(id, name, desc, per_level):
    with open(f"data/items/{id}.tres", "w") as f:
        f.write(f'''[gd_resource type="Resource" script_class="ItemData" format=3]

[ext_resource type="Script" path="res://scripts/resources/item_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"{id}"
display_name = "{name}"
description = "{desc}"
kind = 2
slot = 1
attack_per_level = {per_level}
sell_price = 5
''')


def passive(id, name, desc, stat, amount, per, unlock, color):
    return dict(id=id, name=name, desc=desc, kind=5, color=color, unlock=unlock, stat=stat, amount=amount, amount_per=per)


ARROW = "Color(0.85, 0.95, 0.7, 1)"
ORB = "Color(0.6, 0.7, 1, 1)"


def phantom():
    combo = [
        attack("pd_l1", "Quick Cut", 0.55, False, 0.05, 0.07, 0.14, (1.8, 1.4, 1.6), (0, 1, -0.9), 0.8, 5, 0.03, 4.0, 0, nl="pd_l2", nh="pd_twin_fang"),
        attack("pd_l2", "Quick Cut II", 0.6, False, 0.05, 0.07, 0.14, (1.8, 1.4, 1.6), (0, 1, -0.9), 0.8, 5, 0.03, 4.0, 0, nl="pd_l3", nh="pd_blade_flurry"),
        attack("pd_l3", "Cross Cut", 0.65, False, 0.06, 0.08, 0.15, (2.0, 1.4, 1.7), (0, 1, -1.0), 1.0, 6, 0.03, 4.0, 0, nl="pd_l4", nh="pd_shadow_cut"),
        attack("pd_l4", "Cross Cut II", 0.7, False, 0.06, 0.08, 0.15, (2.0, 1.4, 1.7), (0, 1, -1.0), 1.0, 6, 0.03, 4.0, 0, nl="pd_l5"),
        attack("pd_l5", "Rising Fangs", 0.8, False, 0.07, 0.1, 0.18, (2.2, 1.6, 1.8), (0, 1, -1.0), 1.5, 8, 0.04, 4.5, 1, nl="pd_l6"),
        attack("pd_l6", "Whirling Edge", 1.2, False, 0.1, 0.16, 0.3, (3.4, 1.5, 3.4), (0, 1, 0), 3.0, 18, 0.06, 2.0, 2),
        attack("pd_backstab", "Backstab Lunge", 1.8, True, 0.16, 0.1, 0.32, (1.4, 1.4, 2.2), (0, 1, -1.2), 2.5, 22, 0.07, 14.0, 3),
        attack("pd_twin_fang", "Twin Fang", 1.5, True, 0.12, 0.12, 0.3, (2.0, 1.4, 2.0), (0, 1, -1.1), 2.0, 20, 0.06, 6.0, 0),
        attack("pd_blade_flurry", "Blade Flurry", 1.4, True, 0.1, 0.28, 0.3, (3.6, 1.5, 3.6), (0, 1, 0), 2.0, 16, 0.05, 1.5, 2),
        attack("pd_shadow_cut", "Shadow Cut", 2.0, True, 0.14, 0.12, 0.34, (2.2, 1.6, 2.4), (0, 1, -1.3), 3.0, 26, 0.08, 8.0, 0, el=6),
    ]
    path = write_combo("dual_dagger", combo, "pd_l1", "pd_backstab")
    shadow = "Color(0.55, 0.35, 0.9, 1)"
    skills = [
        dict(id="shadow_step", name="Shadow Step", desc="Slip through the shadows behind your foe.", kind=1, color=shadow, unlock=1, mp=12, cd=5.0, mult=1.4, per=0.1,
             attack=attack("shadow_step", "Shadow Step", 1, True, 0.04, 0.22, 0.2, (1.6, 1.6, 1.8), (0, 1, -0.6), 2.0, 20, 0.05, 24.0, 3, el=6)),
        dict(id="venom_fang", name="Venom Fang", desc="A precise strike at a weak point.", kind=0, color="Color(0.5, 0.9, 0.4, 1)", unlock=1, mp=14, cd=5.0, mult=2.0, per=0.14,
             attack=attack("venom_fang", "Venom Fang", 1, True, 0.08, 0.1, 0.26, (1.8, 1.4, 2.0), (0, 1, -1.1), 2.0, 22, 0.07, 6.0, 3)),
        dict(id="smoke_veil", name="Smoke Veil", desc="Vanish. Enemies lose you; your next strike crits.", kind=3, color="Color(0.6, 0.6, 0.7, 1)", unlock=3, mp=20, cd=18.0, stat="stealth", amount=1.0, duration=6.0, amount_per=0.0),
        dict(id="blade_dance", name="Blade Dance", desc="A storm of cuts around you.", kind=2, color="Color(0.85, 0.85, 1, 1)", unlock=5, mp=24, cd=9.0, mult=2.2, per=0.15,
             attack=attack("blade_dance", "Blade Dance", 1, True, 0.1, 0.4, 0.3, (5.0, 1.6, 5.0), (0, 1, 0), 3.0, 24, 0.05, 1.0, 2)),
        dict(id="marked_for_death", name="Marked for Death", desc="Sharpen your senses. Crit chance up.", kind=3, color="Color(1, 0.3, 0.4, 1)", unlock=8, mp=18, cd=25.0, stat="crit", amount=0.15, duration=10.0, amount_per=0.01),
        dict(id="thousand_cuts", name="Thousand Cuts", desc="Ultimate. Become a blur of steel.", kind=2, ult=True, color="Color(1, 0.85, 0.3, 1)", unlock=10, mp=60, cd=60.0, mult=5.5, per=0.35,
             attack=attack("thousand_cuts", "Thousand Cuts", 1, True, 0.3, 0.6, 0.5, (7.0, 2.0, 7.0), (0, 1, 0), 6.0, 80, 0.12, 0.0, 2, el=6)),
        passive("phantom_instinct", "Assassin's Instinct", "Passive. Crit chance up.", "crit", 0.03, 0.005, 2, shadow),
        passive("light_feet", "Light Feet", "Passive. Move speed up.", "mspd", 0.05, 0.01, 4, shadow),
        passive("swift_hands", "Swift Hands", "Passive. Attack speed up.", "aspd", 0.05, 0.01, 6, shadow),
    ]
    combos = [("shadow_venom", "Ambush", "shadow_step", "venom_fang", 2.0, 1.0, True, 0.0),
              ("veil_dance", "Phantom Waltz", "smoke_veil", "blade_dance", 4.0, 1.4, False, 0.0),
              ("marked_cuts", "Execution", "marked_for_death", "thousand_cuts", 6.0, 1.3, False, 0.0)]
    write_class("phantom", "Phantom", "Assassin. Fast daggers, crits, stealth.", False,
                (7, 13, 3, 6, 7), (0.9, 2, 0.2, 0.7, 1), (0.2, 0.5, 0, 0.1, 0.2), path, skills, combos)
    write_weapon("issued_daggers", "Issued Twin Daggers", "Light, fast, and easy to lose.", 3.6)


def arcanist():
    bolt = proj(26.0, 26.0, 0.3, 0, 0.0, color=ORB)
    combo = [
        attack("ar_l1", "Arcane Bolt", 0.8, False, 0.12, 0.05, 0.22, (1, 1, 1), (0, 1, -1), 1.0, 6, 0.03, 0.0, 3, nl="ar_l2", nh="ar_frost_shard", proj=bolt),
        attack("ar_l2", "Arcane Bolt II", 0.85, False, 0.12, 0.05, 0.22, (1, 1, 1), (0, 1, -1), 1.0, 6, 0.03, 0.0, 3, nl="ar_l3", nh="ar_chain_spark", proj=bolt),
        attack("ar_l3", "Arcane Orb", 1.3, False, 0.18, 0.05, 0.3, (1, 1, 1), (0, 1, -1), 3.0, 14, 0.05, 0.0, 3, proj=proj(18.0, 22.0, 0.45, 0, 2.5, color=ORB)),
        attack("ar_burst", "Arcane Burst", 1.6, True, 0.25, 0.12, 0.35, (5.0, 2.0, 5.0), (0, 1, 0), 5.0, 25, 0.06, 0.0, 1),
        attack("ar_frost_shard", "Frost Shard", 1.4, True, 0.18, 0.05, 0.32, (1, 1, 1), (0, 1, -1), 1.5, 15, 0.05, 0.0, 3, el=2, proj=proj(30.0, 28.0, 0.3, 2, color="Color(0.6, 0.9, 1, 1)")),
        attack("ar_chain_spark", "Chain Spark", 1.5, True, 0.2, 0.05, 0.34, (1, 1, 1), (0, 1, -1), 1.5, 15, 0.05, 0.0, 3, el=5, proj=proj(34.0, 30.0, 0.25, 4, color="Color(1, 0.95, 0.4, 1)")),
    ]
    path = write_combo("staff", combo, "ar_l1", "ar_burst")
    skills = [
        dict(id="fireball", name="Fireball", desc="A burning orb that explodes on impact.", kind=4, color="Color(1, 0.5, 0.15, 1)", unlock=1, mp=16, cd=4.0, mult=2.2, per=0.15,
             attack=attack("fireball", "Fireball", 1, True, 0.2, 0.05, 0.3, (1, 1, 1), (0, 1, -1), 4.0, 20, 0.06, 0.0, 3, el=1, proj=proj(22.0, 30.0, 0.5, 0, 3.0, color="Color(1, 0.5, 0.15, 1)"))),
        dict(id="frost_lance", name="Frost Lance", desc="A piercing spear of ice.", kind=4, color="Color(0.6, 0.9, 1, 1)", unlock=1, mp=14, cd=5.0, mult=1.9, per=0.13,
             attack=attack("frost_lance", "Frost Lance", 1, True, 0.15, 0.05, 0.28, (1, 1, 1), (0, 1, -1), 2.0, 18, 0.05, 0.0, 3, el=2, proj=proj(40.0, 34.0, 0.35, 5, color="Color(0.6, 0.9, 1, 1)"))),
        dict(id="thunder_step", name="Thunder Step", desc="Blink forward as a bolt of lightning.", kind=1, color="Color(1, 0.95, 0.4, 1)", unlock=3, mp=18, cd=7.0, mult=1.5, per=0.1,
             attack=attack("thunder_step", "Thunder Step", 1, True, 0.04, 0.2, 0.22, (2.0, 1.8, 2.0), (0, 1, -0.6), 3.0, 25, 0.05, 26.0, 3, el=5)),
        dict(id="flame_pillar", name="Flame Pillar", desc="Fire erupts all around you.", kind=2, color="Color(1, 0.35, 0.1, 1)", unlock=5, mp=26, cd=10.0, mult=2.4, per=0.16,
             attack=attack("flame_pillar", "Flame Pillar", 1, True, 0.3, 0.3, 0.35, (6.0, 3.0, 6.0), (0, 1, 0), 5.0, 30, 0.08, 0.0, 1, el=1)),
        dict(id="mana_shield", name="Mana Shield", desc="Arcane barrier. Defense up.", kind=3, color="Color(0.5, 0.6, 1, 1)", unlock=8, mp=22, cd=22.0, stat="defense", amount=0.4, duration=10.0, amount_per=0.03),
        dict(id="starfall", name="Starfall", desc="Ultimate. Call down the sky.", kind=2, ult=True, color="Color(1, 0.85, 0.3, 1)", unlock=10, mp=70, cd=60.0, mult=6.0, per=0.4,
             attack=attack("starfall", "Starfall", 1, True, 0.7, 0.3, 0.6, (12.0, 4.0, 12.0), (0, 1, -2), 8.0, 90, 0.14, 0.0, 1, el=7)),
        passive("arcane_mind", "Arcane Mind", "Passive. Magic attack up.", "attack", 0.05, 0.01, 2, ORB),
        passive("flow", "Flow", "Passive. Attack speed up.", "aspd", 0.04, 0.008, 4, ORB),
        passive("ward", "Ward", "Passive. Defense up.", "defense", 0.05, 0.01, 6, ORB),
    ]
    combos = [("superconduct_step", "Superconduct Step", "frost_lance", "thunder_step", 2.5, 1.3, False, 10.0),
              ("inferno", "Inferno", "fireball", "flame_pillar", 3.0, 1.4, False, 0.0),
              ("shielded_star", "Guarded Heavens", "mana_shield", "starfall", 6.0, 1.25, False, 0.0)]
    write_class("arcanist", "Arcanist", "Caster. Elemental bolts and area spells, uses magic attack.", True,
                (3, 5, 14, 6, 8), (0.2, 0.6, 2.2, 0.8, 1), (0, 0.1, 0.6, 0.15, 0.15), path, skills, combos)
    write_weapon("issued_staff", "Issued Focus Staff", "A guild staff with a cheap crystal.", 3.8)


def ranger():
    arrow = proj(42.0, 36.0, 0.18, 0, color=ARROW)
    combo = [
        attack("rg_l1", "Quick Shot", 0.7, False, 0.08, 0.04, 0.2, (1, 1, 1), (0, 1, -1), 0.8, 5, 0.02, 0.0, 3, nl="rg_l2", nh="rg_split_shot", proj=arrow),
        attack("rg_l2", "Quick Shot II", 0.75, False, 0.08, 0.04, 0.2, (1, 1, 1), (0, 1, -1), 0.8, 5, 0.02, 0.0, 3, nl="rg_l3", nh="rg_pierce", proj=arrow),
        attack("rg_l3", "Double Shot", 0.6, False, 0.1, 0.04, 0.22, (1, 1, 1), (0, 1, -1), 1.0, 6, 0.03, 0.0, 3, nl="rg_l4", proj=proj(42.0, 36.0, 0.18, 0, 0.0, 2, 8.0, color=ARROW)),
        attack("rg_l4", "Heavy Arrow", 1.3, False, 0.16, 0.04, 0.3, (1, 1, 1), (0, 1, -1), 3.0, 14, 0.05, 0.0, 3, proj=proj(50.0, 40.0, 0.25, 1, color=ARROW)),
        attack("rg_charged", "Charged Shot", 2.0, True, 0.35, 0.04, 0.35, (1, 1, 1), (0, 1, -1), 4.0, 28, 0.07, 0.0, 3, proj=proj(60.0, 45.0, 0.3, 3, color="Color(1, 1, 0.7, 1)")),
        attack("rg_split_shot", "Split Shot", 0.9, True, 0.15, 0.04, 0.3, (1, 1, 1), (0, 1, -1), 1.5, 10, 0.04, 0.0, 3, proj=proj(40.0, 30.0, 0.18, 0, 0.0, 3, 24.0, color=ARROW)),
        attack("rg_pierce", "Piercing Arrow", 1.6, True, 0.2, 0.04, 0.32, (1, 1, 1), (0, 1, -1), 2.5, 18, 0.05, 0.0, 3, proj=proj(55.0, 45.0, 0.22, 5, color=ARROW)),
    ]
    path = write_combo("bow", combo, "rg_l1", "rg_charged")
    green = "Color(0.55, 0.85, 0.45, 1)"
    skills = [
        dict(id="power_shot", name="Power Shot", desc="A heavy arrow that pierces a line of foes.", kind=4, color=green, unlock=1, mp=14, cd=4.0, mult=2.3, per=0.15,
             attack=attack("power_shot", "Power Shot", 1, True, 0.25, 0.04, 0.3, (1, 1, 1), (0, 1, -1), 4.0, 25, 0.06, 0.0, 3, proj=proj(60.0, 48.0, 0.3, 4, color="Color(1, 1, 0.7, 1)"))),
        dict(id="multishot", name="Multishot", desc="Fan out a volley of arrows.", kind=4, color="Color(0.8, 0.95, 0.6, 1)", unlock=1, mp=16, cd=6.0, mult=1.1, per=0.08,
             attack=attack("multishot", "Multishot", 1, True, 0.15, 0.04, 0.3, (1, 1, 1), (0, 1, -1), 1.5, 10, 0.04, 0.0, 3, proj=proj(42.0, 32.0, 0.18, 0, 0.0, 7, 50.0, color=ARROW))),
        dict(id="snare_trap", name="Snare Trap", desc="Place a trap that bursts when an enemy steps on it.", kind=4, color="Color(0.75, 0.55, 0.3, 1)", unlock=3, mp=18, cd=10.0, mult=2.0, per=0.14,
             attack=attack("snare_trap", "Snare Trap", 1, True, 0.2, 0.04, 0.25, (1, 1, 1), (0, 1, -1), 5.0, 40, 0.06, 0.0, 1, el=4, proj=proj(0.0, 0.0, 1.4, 0, 3.5, lifetime=12.0, color="Color(0.75, 0.55, 0.3, 1)"))),
        dict(id="evasive_roll", name="Evasive Roll", desc="Dash and slice anything in the way.", kind=1, color="Color(0.7, 0.9, 0.8, 1)", unlock=5, mp=12, cd=5.0, mult=1.2, per=0.08,
             attack=attack("evasive_roll", "Evasive Roll", 1, True, 0.04, 0.2, 0.18, (1.6, 1.4, 1.6), (0, 1, -0.5), 1.5, 10, 0.04, 20.0, 3)),
        dict(id="hunters_focus", name="Hunter's Focus", desc="Steady breath. Attack up.", kind=3, color="Color(1, 0.6, 0.3, 1)", unlock=8, mp=20, cd=24.0, stat="attack", amount=0.25, duration=10.0, amount_per=0.02),
        dict(id="arrow_rain", name="Arrow Rain", desc="Ultimate. A storm of arrows ahead.", kind=2, ult=True, color="Color(1, 0.85, 0.3, 1)", unlock=10, mp=60, cd=60.0, mult=5.0, per=0.35,
             attack=attack("arrow_rain", "Arrow Rain", 1, True, 0.5, 0.6, 0.5, (10.0, 4.0, 14.0), (0, 1, -8), 4.0, 60, 0.1, 0.0, 1)),
        passive("eagle_eye", "Eagle Eye", "Passive. Crit chance up.", "crit", 0.03, 0.005, 2, green),
        passive("fleet_foot", "Fleet Foot", "Passive. Move speed up.", "mspd", 0.06, 0.01, 4, green),
        passive("steady_aim", "Steady Aim", "Passive. Attack up.", "attack", 0.05, 0.01, 6, green),
    ]
    combos = [("roll_shot", "Point Blank", "evasive_roll", "power_shot", 2.0, 1.0, True, 0.0),
              ("trap_volley", "Killing Field", "snare_trap", "multishot", 4.0, 1.4, False, 0.0),
              ("focus_rain", "Deadeye Storm", "hunters_focus", "arrow_rain", 6.0, 1.3, False, 0.0)]
    write_class("ranger", "Ranger", "Ranged hunter. Bows, traps and mobility.", False,
                (6, 11, 5, 6, 9), (0.7, 1.8, 0.4, 0.7, 1.2), (0.15, 0.45, 0, 0.1, 0.3), path, skills, combos)
    write_weapon("issued_bow", "Issued Hunting Bow", "Guild-standard recurve bow.", 3.9)


def vanguard_passives():
    red = "Color(0.9, 0.4, 0.3, 1)"
    for p in [passive("iron_body", "Iron Body", "Passive. Defense up.", "defense", 0.06, 0.012, 2, red),
              passive("heavy_hands", "Heavy Hands", "Passive. Attack up.", "attack", 0.04, 0.008, 4, red),
              passive("battle_rhythm", "Battle Rhythm", "Passive. Attack speed up.", "aspd", 0.04, 0.008, 6, red)]:
        write_skill("vanguard", p)
    path = "data/classes/vanguard.tres"
    s = open(path).read()
    if "iron_body" not in s:
        lines = s.split("\n")
        # add ext resources for the passives and append to the skills array
        ids = []
        for i, pid in enumerate(["iron_body", "heavy_hands", "battle_rhythm"]):
            rid = f"p{i}"
            ids.append(rid)
            lines.insert(3, f'[ext_resource type="Resource" path="res://data/skills/vanguard/{pid}.tres" id="{rid}"]')
        s = "\n".join(lines)
        s = s.replace('ExtResource("s5")])', 'ExtResource("s5"), ' + ", ".join(f'ExtResource("{r}")' for r in ids) + "])")
        open(path, "w").write(s)


if __name__ == "__main__":
    phantom()
    arcanist()
    ranger()
    vanguard_passives()
    print("classes written")
