class_name Progression
extends RefCounted
## Level / XP / free stat points / skill points. Pure and serializable.

var level: int = 1
var xp: int = 0
var free_points: int = 0
var skill_points: int = 0
var allocated: StatBlock = StatBlock.new()
var tuning: StatTuning


func _init(stat_tuning: StatTuning = null) -> void:
	tuning = stat_tuning if stat_tuning != null else StatTuning.new()


static func xp_needed(lvl: int, t: StatTuning) -> int:
	if lvl >= t.level_cap:
		return 0
	return roundi(t.xp_base * pow(float(lvl), t.xp_exponent))


func xp_to_next() -> int:
	return xp_needed(level, tuning)


## Adds XP, levels up as many times as needed. Returns the number of levels gained.
func add_xp(amount: int) -> int:
	if amount <= 0 or level >= tuning.level_cap:
		return 0
	xp += amount
	var gained: int = 0
	while level < tuning.level_cap and xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		gained += 1
		free_points += tuning.free_points_per_level
		skill_points += tuning.skill_points_per_level
	if level >= tuning.level_cap:
		xp = 0
	return gained


func allocate(stat: StatBlock.Stat, points: int = 1) -> bool:
	if points <= 0 or points > free_points:
		return false
	free_points -= points
	allocated.set_stat(stat, allocated.get_stat(stat) + points)
	return true


## Primary stats = class base + class growth × (level − 1) + allocated points.
func primary_stats(class_data: ClassData) -> StatBlock:
	return class_data.base_stats.plus(class_data.growth, float(level - 1)).plus(allocated)


func to_dict() -> Dictionary:
	return {"level": level, "xp": xp, "free_points": free_points, "skill_points": skill_points,
		"allocated": allocated.to_dict()}


func load_dict(d: Dictionary) -> void:
	var lvl: int = d.get("level", 1)
	var exp_points: int = d.get("xp", 0)
	var points: int = d.get("free_points", 0)
	var skill_pts: int = d.get("skill_points", 0)
	level = lvl
	xp = exp_points
	free_points = points
	skill_points = skill_pts
	var alloc: Dictionary = d.get("allocated", {})
	allocated = StatBlock.from_dict(alloc)
