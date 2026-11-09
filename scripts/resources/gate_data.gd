class_name GateData
extends Resource
## A Gate (dungeon instance): rank, rules, rooms, enemies, boss, rewards (§7).

enum Rank { E, D, C, B, A, S }

const RANK_COLORS: Dictionary[Rank, Color] = {
	Rank.E: Color(0.7, 0.7, 0.75), Rank.D: Color(0.4, 0.9, 0.5), Rank.C: Color(0.35, 0.6, 1.0),
	Rank.B: Color(0.7, 0.4, 1.0), Rank.A: Color(1.0, 0.6, 0.2), Rank.S: Color(1.0, 0.2, 0.25),
}

@export var id: StringName = &""
@export var display_name: StringName = &""
@export var rank: Rank = Rank.E
@export var seed_value: int = 0
@export var room_count: int = 3
## Enemy data per normal room (picked with the seed).
@export var enemy_pool: Array[EnemyData] = []
@export var enemies_per_room: int = 3
## Gate monsters are never below this level (deep places like the metro Gate).
@export var level_floor: int = 0
@export var boss: EnemyData
## Rule ids: &"no_skills", &"no_potions", &"no_exit" (Red Gate) ...
@export var rules: Array[StringName] = []
## Hunter guild rank needed to enter (GuildRank.Rank).
@export var min_guild_rank: int = 0
## Secret completed when the boss dies (EVENT trigger), optional.
@export var completes_secret: StringName = &""
@export var reward_gold: int = 0
@export var reward_items: Dictionary[StringName, int] = {}
## Given only on the first clear (unique boss drops such as Venomfang).
@export var first_clear_items: Dictionary[StringName, int] = {}


func has_rule(rule: StringName) -> bool:
	return rule in rules
