#!/usr/bin/env python3
"""Generates job data (§8 Job Change I/II + hidden jobs), job skills and summon data.

Run from the project root:  python3 tools/gen_jobs.py
Writes data/jobs/<id>.tres, data/skills/jobs/<id>.tres, data/summons/<id>.tres.
Edit numbers here, not in the generated files.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from gen_classes import Tres, attack, proj, passive, write_skill  # noqa: E402

# SkillData kind: 0 MELEE 1 DASH 2 AOE 3 BUFF 4 PROJECTILE 5 PASSIVE 6 SUMMON 7 SHADOW_EXTRACT 8 SHADOW_CALL

SUMMONS = {
    # id: name, color, height, power, range, interval, speed, duration, element
    "familiar_wisp": ("Familiar Wisp", "Color(0.55, 0.85, 1, 0.8)", 0.8, 0.22, 1.6, 1.3, 7.0, 25.0, 3),
    "shadow_soldier": ("Shadow Soldier", "Color(0.35, 0.15, 0.55, 0.9)", 1.6, 0.4, 1.9, 1.0, 7.5, 0.0, 6),
}


def write_summon(sid):
    name, color, height, power, rng, interval, speed, duration, element = SUMMONS[sid]
    os.makedirs("data/summons", exist_ok=True)
    with open(f"data/summons/{sid}.tres", "w") as f:
        f.write(f'''[gd_resource type="Resource" script_class="SummonData" format=3]

[ext_resource type="Script" path="res://scripts/resources/summon_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"{sid}"
display_name = "{name}"
body_color = {color}
height = {height}
power = {power}
attack_range = {rng}
attack_interval_s = {interval}
move_speed = {speed}
duration_s = {duration}
element = {element}
''')
    return f"data/summons/{sid}.tres"


def write_special_skill(s):
    """SUMMON / SHADOW skills (write_skill in gen_classes does not know the summon fields)."""
    t = Tres("SkillData")
    script = t.ext_id("Script", "res://scripts/resources/skill_data.gd")
    lines = [f"script = {script}", f'id = &"{s["id"]}"', f'display_name = "{s["name"]}"', f'description = "{s["desc"]}"',
             f"kind = {s['kind']}", f"is_ultimate = {'true' if s.get('ult') else 'false'}", f"icon_color = {s['color']}",
             f"unlock_level = {s['unlock']}", f"mp_cost = {s.get('mp', 0)}", f"cooldown_s = {s.get('cd', 1.0)}",
             f"multiplier_per_level = {s.get('per', 0.08)}", f"max_summons = {s.get('max', 1)}",
             f"extra_summon_every = {s.get('every', 0)}"]
    if s.get("summon"):
        lines.append(f"summon = {t.ext_id('Resource', 'res://' + write_summon(s['summon']))}")
    os.makedirs("data/skills/jobs", exist_ok=True)
    path = f"data/skills/jobs/{s['id']}.tres"
    t.write(path, lines)
    return path


def skill_path(s):
    if s["kind"] >= 6:
        return write_special_skill(s)
    return write_skill("jobs", s)


def job(jid, name, desc, base, tier, level, skills, parent="", hidden=False, flag="", stats=(0, 0, 0, 0, 0),
        atk=0.0, df=0.0, hp=0.0, mp_mult=1.0, shadow=False):
    t = Tres("JobData")
    script = t.ext_id("Script", "res://scripts/resources/job_data.gd")
    block = t.ext_id("Script", "res://scripts/resources/stat_block.gd")
    skill_script = t.ext_id("Script", "res://scripts/resources/skill_data.gd")
    refs = [t.ext_id("Resource", "res://" + skill_path(s)) for s in skills]
    bonus = t.sub([f"script = {block}", f"strength = {float(stats[0])}", f"agility = {float(stats[1])}",
                   f"intelligence = {float(stats[2])}", f"vitality = {float(stats[3])}", f"sense = {float(stats[4])}"])
    os.makedirs("data/jobs", exist_ok=True)
    t.write(f"data/jobs/{jid}.tres", [
        f"script = {script}", f'id = &"{jid}"', f'display_name = "{name}"', f'description = "{desc}"',
        f'base_class = &"{base}"', f"tier = {tier}", f"required_level = {level}", f'parent = &"{parent}"',
        f"hidden = {'true' if hidden else 'false'}", f'required_flag = &"{flag}"', f"stat_bonus = {bonus}",
        f"attack_bonus = {atk}", f"defense_bonus = {df}", f"hp_bonus = {hp}", f"mp_cost_multiplier = {mp_mult}",
        f"skills = Array[{skill_script}]([{', '.join(refs)}])", f"shadow_army = {'true' if shadow else 'false'}"])


def buff(id, name, desc, stat, amount, duration, unlock, color, mp=25, cd=24.0, per=0.02):
    return dict(id=id, name=name, desc=desc, kind=3, color=color, unlock=unlock, mp=mp, cd=cd, stat=stat,
                amount=amount, duration=duration, amount_per=per)


def strike(id, name, desc, kind, unlock, color, mult, mp, cd, el=0, size=(3.0, 2.0, 3.0), off=(0, 1, -1.5),
           lunge=0.0, proj_data=None, ult=False):
    a = attack(id, name, 1, True, 0.18, 0.15, 0.3, size, off, 4.0, 30, 0.07, lunge, 2 if kind == 2 else 0,
               el=el, proj=proj_data)
    return dict(id=id, name=name, desc=desc, kind=kind, color=color, unlock=unlock, mp=mp, cd=cd, mult=mult,
                per=0.15, attack=a, ult=ult)


RED, BLUE, GREEN, GOLD, VIOLET = ("Color(0.95, 0.35, 0.3, 1)", "Color(0.4, 0.6, 1, 1)", "Color(0.5, 0.9, 0.5, 1)",
                                  "Color(1, 0.85, 0.35, 1)", "Color(0.6, 0.3, 0.9, 1)")


def vanguard_jobs():
    job("berserker", "Berserker", "Rage-fuelled destroyer. Attack up, defense down.", "vanguard", 1, 30,
        [buff("blood_frenzy", "Blood Frenzy", "Attack up sharply for a short time.", "attack", 0.35, 8.0, 30, RED),
         strike("rampage", "Rampage", "Spin through everything around you.", 2, 33, RED, 3.2, 30, 9.0, size=(6, 2, 6), off=(0, 1, 0))],
        stats=(6, 2, 0, 0, 0), atk=0.12, df=-0.05)
    job("guardian", "Guardian", "Unbreakable wall. Defense and HP up.", "vanguard", 1, 30,
        [buff("bulwark", "Bulwark", "Defense up greatly.", "defense", 0.6, 10.0, 30, BLUE),
         strike("shield_slam", "Shield Slam", "A crushing bash that staggers.", 0, 33, BLUE, 2.6, 22, 7.0, el=4)],
        stats=(2, 0, 0, 6, 0), df=0.15, hp=0.12)
    job("warlord", "Warlord", "Berserker who commands the battlefield.", "vanguard", 2, 60,
        [strike("cataclysm", "Cataclysm", "Ultimate. The ground breaks in a wide ring.", 2, 60, RED, 8.0, 80, 55.0, el=4, size=(12, 3, 12), off=(0, 1, 0), ult=True)],
        parent="berserker", stats=(10, 4, 0, 2, 0), atk=0.12)
    job("bastion", "Bastion", "Guardian who cannot fall.", "vanguard", 2, 60,
        [buff("aegis", "Aegis", "Defense and attack up together.", "defense", 0.8, 12.0, 60, BLUE, mp=40, cd=35.0)],
        parent="guardian", stats=(4, 0, 0, 10, 0), df=0.15, hp=0.15)


def phantom_jobs():
    job("shadowblade", "Shadowblade", "Lethal duelist. Crits and burst.", "phantom", 1, 30,
        [passive("killing_intent", "Killing Intent", "Passive. Crit chance up.", "crit", 0.05, 0.008, 30, VIOLET),
         strike("night_cut", "Night Cut", "Dash through a target in the dark.", 1, 33, VIOLET, 3.0, 22, 6.0, el=6, lunge=28.0)],
        stats=(2, 6, 0, 0, 2), atk=0.1)
    job("trickster", "Trickster", "Slippery fighter. Speed and evasion.", "phantom", 1, 30,
        [passive("slipstream", "Slipstream", "Passive. Move speed up.", "mspd", 0.06, 0.008, 30, GREEN),
         strike("mirage_strike", "Mirage Strike", "Afterimages slash around you.", 2, 33, GREEN, 2.8, 26, 8.0, el=3, size=(5, 2, 5), off=(0, 1, 0))],
        stats=(0, 6, 0, 0, 4))
    job("nightreaper", "Nightreaper", "Shadowblade who ends fights in a breath.", "phantom", 2, 60,
        [strike("final_hour", "Final Hour", "Ultimate. One cut for every second left.", 1, 60, VIOLET, 9.0, 80, 55.0, el=6, lunge=34.0, ult=True)],
        parent="shadowblade", stats=(4, 10, 0, 0, 4), atk=0.12)
    job("illusionist", "Illusionist", "Trickster whose enemies fight ghosts.", "phantom", 2, 60,
        [buff("hall_of_mirrors", "Hall of Mirrors", "Move speed up and nothing can follow.", "mspd", 0.4, 10.0, 60, GREEN, mp=35, cd=30.0)],
        parent="trickster", stats=(0, 10, 2, 0, 6))


def arcanist_jobs():
    job("elementalist", "Elementalist", "Master of the elemental cycle.", "arcanist", 1, 30,
        [strike("meteor", "Meteor", "A falling star that explodes.", 4, 30, "Color(1, 0.45, 0.15, 1)", 3.4, 34, 9.0, el=1,
                proj_data=proj(20.0, 32.0, 0.6, 0, 4.0, color="Color(1, 0.45, 0.15, 1)")),
         strike("glacial_wave", "Glacial Wave", "A wave of frost around you.", 2, 33, "Color(0.6, 0.9, 1, 1)", 2.8, 28, 8.0, el=2, size=(7, 2, 7), off=(0, 1, 0))],
        stats=(0, 0, 8, 0, 0), atk=0.1)
    job("sage", "Sage", "Scholar of the Codex itself. Cooldowns and mana.", "arcanist", 1, 30,
        [buff("arcane_surge", "Arcane Surge", "Magic attack up.", "attack", 0.3, 12.0, 30, BLUE),
         passive("deep_well", "Deep Well", "Passive. Defense up.", "defense", 0.06, 0.01, 33, BLUE)],
        stats=(0, 0, 6, 2, 2), mp_mult=0.85)
    job("archmage", "Archmage", "Elementalist who bends storms.", "arcanist", 2, 60,
        [strike("tempest", "Tempest", "Ultimate. A storm of every element.", 2, 60, GOLD, 8.5, 90, 55.0, el=5, size=(12, 4, 12), off=(0, 1, -2), ult=True)],
        parent="elementalist", stats=(0, 2, 12, 0, 2), atk=0.12)
    job("oracle", "Oracle", "Sage who reads the next moment.", "arcanist", 2, 60,
        [passive("foresight", "Foresight", "Passive. Crit chance up.", "crit", 0.06, 0.01, 60, GOLD)],
        parent="sage", stats=(0, 2, 10, 2, 6), mp_mult=0.85)


def ranger_jobs():
    job("sharpshooter", "Sharpshooter", "Long-range precision.", "ranger", 1, 30,
        [strike("piercing_bolt", "Piercing Bolt", "An arrow that passes through a line of foes.", 4, 30, GOLD, 3.0, 22, 6.0,
                proj_data=proj(48.0, 44.0, 0.3, 8, color="Color(1, 0.9, 0.5, 1)")),
         passive("dead_calm", "Dead Calm", "Passive. Attack up.", "attack", 0.05, 0.01, 33, GOLD)],
        stats=(2, 6, 0, 0, 2), atk=0.1)
    job("trapper", "Trapper", "Controls the ground with snares.", "ranger", 1, 30,
        [strike("spike_field", "Spike Field", "Spikes burst from the ground around you.", 2, 30, GREEN, 2.6, 24, 8.0, el=4, size=(6, 2, 6), off=(0, 1, 0)),
         passive("hunters_ground", "Hunter's Ground", "Passive. Defense up.", "defense", 0.06, 0.01, 33, GREEN)],
        stats=(0, 4, 0, 4, 2), df=0.08)
    job("deadeye", "Deadeye", "Sharpshooter who never misses.", "ranger", 2, 60,
        [strike("heartseeker", "Heartseeker", "Ultimate. A homing arrow of light.", 4, 60, GOLD, 9.0, 80, 50.0, el=7,
                proj_data=proj(36.0, 60.0, 0.5, 3, 3.0, homing=True, color="Color(1, 0.95, 0.6, 1)"), ult=True)],
        parent="sharpshooter", stats=(4, 10, 0, 0, 4), atk=0.12)
    job("beastwarden", "Beastwarden", "Trapper who fights beside the wild.", "ranger", 2, 60,
        [buff("pack_instinct", "Pack Instinct", "Attack and speed up.", "attack", 0.3, 12.0, 60, GREEN)],
        parent="trapper", stats=(2, 6, 0, 6, 2), df=0.08)


def summoner_line():
    # Weakest start: low damage, mana-hungry, only one or two familiars. The road to the
    # Necromancer is a sealed mission (see ascendant-dev MYSTERY_BIBLE: necromancer_path).
    job("summoner", "Summoner", "Calls small familiars to fight. Weak and mana-hungry... at first.", "", 1, 30,
        [dict(id="call_familiar", name="Call Familiar", desc="Call a familiar wisp. Two at skill Lv 5.", kind=6,
              color="Color(0.55, 0.85, 1, 1)", unlock=30, mp=40, cd=6.0, per=0.08, max=1, every=5, summon="familiar_wisp"),
         buff("spirit_tether", "Spirit Tether", "Share your guard with your familiars. Defense up.", "defense", 0.2, 10.0, 32, BLUE, mp=30)],
        stats=(0, 0, 4, 0, 2), atk=-0.1, mp_mult=1.5)
    job("conjurer", "Conjurer", "Summoner who never walks alone.", "", 2, 60,
        [dict(id="familiar_host", name="Familiar Host", desc="Call a host of wisps (up to four).", kind=6,
              color="Color(0.55, 0.85, 1, 1)", unlock=60, mp=60, cd=12.0, per=0.1, max=3, every=10, summon="familiar_wisp")],
        parent="summoner", stats=(0, 0, 8, 2, 2), mp_mult=1.3)
    job("necromancer", "Necromancer", "Binds the fallen as shadow soldiers.", "", 3, 35,
        [dict(id="rise_echo", name="Rise, Echo", desc="Bind a freshly fallen enemy as a shadow soldier.", kind=7,
              color="Color(0.6, 0.3, 0.9, 1)", unlock=35, mp=30, cd=2.0),
         dict(id="answer_me", name="Answer Me", desc="Call your strongest shadows (more with skill level).", kind=8,
              color="Color(0.45, 0.2, 0.75, 1)", unlock=35, mp=50, cd=15.0, per=0.05, max=3, every=2),
         passive("grave_chill", "Grave Chill", "Passive. Attack up.", "attack", 0.06, 0.01, 36, VIOLET)],
        parent="summoner", hidden=True, flag="necromancer_awakened", stats=(2, 2, 8, 2, 4), atk=0.15,
        mp_mult=1.0, shadow=True)
    job("shadow_sovereign", "Shadow Sovereign", "The army answers before you speak.", "", 3, 60,
        [buff("sovereign_aura", "Sovereign Aura", "Your presence sharpens every blade nearby.", "attack", 0.4, 15.0, 60, VIOLET, mp=60, cd=40.0)],
        parent="necromancer", hidden=True, flag="shadow_sovereign_awakened", stats=(4, 4, 12, 4, 6), atk=0.15,
        df=0.1, shadow=True)


if __name__ == "__main__":
    vanguard_jobs()
    phantom_jobs()
    arcanist_jobs()
    ranger_jobs()
    summoner_line()
    write_summon("shadow_soldier")
    print("jobs written")
