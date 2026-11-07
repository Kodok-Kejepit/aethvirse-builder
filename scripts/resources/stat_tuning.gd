class_name StatTuning
extends Resource
## Global balancing constants. Values mirror ascendant-dev/docs/ASCENDANT_Balancing.xlsx (sheet Parameter).

@export_group("Leveling")
@export var xp_base: float = 100.0
@export var xp_exponent: float = 1.8
@export var level_cap: int = 100
@export var free_points_per_level: int = 5
@export var skill_points_per_level: int = 1

@export_group("Derived stats")
@export var hp_base: float = 100.0
@export var hp_per_vit: float = 20.0
@export var hp_per_level: float = 10.0
@export var mp_base: float = 50.0
@export var mp_per_int: float = 10.0
@export var mp_per_level: float = 3.0
@export var atk_per_str: float = 2.0
@export var atk_per_agi: float = 0.5
@export var matk_per_int: float = 2.5
@export var def_per_vit: float = 1.0
@export var def_per_str: float = 0.3
@export var crit_base: float = 0.05
@export var crit_per_sen: float = 0.002
@export var crit_per_agi: float = 0.001
@export var crit_cap: float = 0.75
@export var crit_dmg_base: float = 1.5
@export var crit_dmg_per_sen: float = 0.005
@export var aspd_base: float = 1.0
@export var aspd_per_agi: float = 0.002
## Not in the sheet yet (engine defaults, tune later).
@export var mspd_per_agi: float = 0.001
@export var mspd_cap: float = 1.3
@export var cdr_per_int: float = 0.001
@export var cdr_cap: float = 0.4
@export var mp_regen_base: float = 2.0
@export var mp_regen_per_int: float = 0.05

@export_group("Enemy scaling")
@export var def_factor: float = 0.5
@export var hits_to_kill_normal: float = 5.0
@export var elite_hp_mult: float = 4.0
@export var boss_hp_mult: float = 40.0
@export var normal_hits_to_kill_hero: float = 12.0
@export var elite_atk_mult: float = 1.6
@export var boss_atk_mult: float = 2.5
@export var enemy_def_per_level: float = 1.5
@export var kills_per_level_base: float = 15.0
@export var kills_per_level_growth: float = 0.5
@export var elite_xp_mult: float = 5.0
@export var boss_xp_mult: float = 50.0
@export var gold_base: float = 5.0
@export var gold_growth: float = 1.06
## Assumed average (Rare) weapon ATK per level, used for enemy scaling and as the starter weapon.
@export var weapon_atk_per_level: float = 4.0
