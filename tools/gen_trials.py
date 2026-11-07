#!/usr/bin/env python3
"""Job Change trial Gates (M10). Run from the project root: python3 tools/gen_trials.py"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import gen_m9_world as w  # noqa: E402

w.ENEMIES = {
    "trial_warden": ("Trial Warden", 30, "Color(0.4, 0.6, 0.95, 1)", 7, 2, {"hp_scale": 0.3, "attack_scale": 0.85, "poise": 150.0,
                                                                           "attack_range": 2.8, "attack_windup_s": 0.85,
                                                                           "attack_hitbox_size": "Vector3(3.2, 1.8, 2.8)",
                                                                           "telegraph_radius": 2.8, "aggro_radius": 40.0, "leash_radius": 80.0}),
    "trial_arbiter": ("Trial Arbiter", 60, "Color(0.85, 0.75, 1, 1)", 7, 2, {"hp_scale": 0.35, "attack_scale": 0.9, "poise": 180.0,
                                                                            "attack_range": 3.0, "attack_windup_s": 0.8,
                                                                            "attack_hitbox_size": "Vector3(3.6, 2, 3)",
                                                                            "telegraph_radius": 3.0, "aggro_radius": 40.0, "leash_radius": 80.0}),
}
TRIALS = {
    "trial_tier_1": ("GATE_TRIAL_1", 2, 4101, 3, ["moss_brute", "thorn_stalker", "gate_husk"], "trial_warden", 0, 0, {}),
    "trial_tier_2": ("GATE_TRIAL_2", 3, 4202, 4, ["sand_wraith", "dune_scuttler", "moss_brute"], "trial_arbiter", 0, 0, {}),
}

if __name__ == "__main__":
    for eid, row in w.ENEMIES.items():
        w.write(f"data/enemies/{eid}.tres", w.enemy_tres(eid, row))
    for gid, row in TRIALS.items():
        text = w.gate_tres(gid, row).replace("rules = Array[StringName]([])", 'rules = Array[StringName]([&"trial", &"no_double"])')
        w.write(f"data/gates/{gid}.tres", text)
    print("trials written")
