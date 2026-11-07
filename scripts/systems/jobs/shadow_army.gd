class_name ShadowArmy
extends RefCounted
## Roster of shadow soldiers bound by the shadow job line (saved). Each soldier remembers the
## enemy it came from; stronger enemies make stronger soldiers. Slots 3 → 30 (MYSTERY_BIBLE 5.6).

const BASE_SLOTS: int = 3
const LEVELS_PER_SLOT: int = 10
const MAX_SLOTS: int = 30
## Bind chance per enemy tier (EnemyScaling.Tier: NORMAL, ELITE, BOSS).
const BIND_CHANCE: Array[float] = [0.75, 0.5, 0.3]
## Damage multiplier per tier for the soldier.
const TIER_POWER: Array[float] = [1.0, 1.6, 2.6]

## Ranks earned by kills: Soldier, Knight, Elite, Commander, Marshal.
const RANK_XP: Array[int] = [0, 20, 60, 150, 320]
const RANK_POWER: Array[float] = [1.0, 1.25, 1.55, 1.9, 2.4]
## Rank abilities (see Minion): Elite+ cleave, Commander+ taunt, Marshal attacks faster.
const RANK_CLEAVE: int = 2
const RANK_TAUNT: int = 3
const RANK_MARSHAL: int = 4

## Each: {"uid": int, "enemy_id": String, "name": String, "tier": int, "level": int, "rank": int, "xp": int}
var soldiers: Array[Dictionary] = []
var next_uid: int = 0


static func slots_for_level(level: int) -> int:
	return mini(BASE_SLOTS + floori(float(maxi(level, 1)) / LEVELS_PER_SLOT), MAX_SLOTS)


static func bind_chance(tier: int) -> float:
	return BIND_CHANCE[clampi(tier, 0, BIND_CHANCE.size() - 1)]


static func tier_power(tier: int) -> float:
	return TIER_POWER[clampi(tier, 0, TIER_POWER.size() - 1)]


static func rank_power(rank: int) -> float:
	return RANK_POWER[clampi(rank, 0, RANK_POWER.size() - 1)]


static func rank_for_xp(xp: int) -> int:
	var rank: int = 0
	for i: int in RANK_XP.size():
		if xp >= RANK_XP[i]:
			rank = i
	return rank


## XP a shadow gets for a kill (stronger prey teaches more).
static func kill_xp(enemy_tier: int) -> int:
	return 1 + enemy_tier * 4


static func soldier_power(s: Dictionary) -> float:
	var tier: int = s.get("tier", 0)
	var rank: int = s.get("rank", 0)
	return tier_power(tier) * rank_power(rank)


func find_index(uid: int) -> int:
	for i: int in soldiers.size():
		var u: int = soldiers[i].get("uid", -1)
		if u == uid:
			return i
	return -1


## Adds XP to a soldier. Returns its new rank if it ranked up, else -1.
func add_xp(uid: int, amount: int) -> int:
	var i: int = find_index(uid)
	if i < 0:
		return -1
	var s: Dictionary = soldiers[i]
	var before: int = s.get("rank", 0)
	var xp: int = s.get("xp", 0)
	xp += amount
	s["xp"] = xp
	var after: int = rank_for_xp(xp)
	s["rank"] = after
	return after if after > before else -1


func is_full(level: int) -> bool:
	return soldiers.size() >= slots_for_level(level)


func add(enemy_id: StringName, display_name: String, tier: int, level: int) -> bool:
	if is_full(level):
		return false
	next_uid += 1
	soldiers.append({"uid": next_uid, "enemy_id": String(enemy_id), "name": display_name, "tier": tier,
		"level": level, "rank": 0, "xp": 0})
	return true


## uid of the most recently bound soldier (-1 if none).
func last_uid() -> int:
	if soldiers.is_empty():
		return -1
	var u: int = soldiers[-1].get("uid", -1)
	return u


func release(index: int) -> void:
	if index >= 0 and index < soldiers.size():
		soldiers.remove_at(index)


## Strongest first, so calling a few always brings the best.
func sorted_by_power() -> Array[Dictionary]:
	var out: Array[Dictionary] = soldiers.duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: float = soldier_power(a)
		var pb: float = soldier_power(b)
		if not is_equal_approx(pa, pb):
			return pa > pb
		var la: int = a["level"]
		var lb: int = b["level"]
		return la > lb)
	return out


func to_dict() -> Dictionary:
	return {"soldiers": soldiers.duplicate(true), "next_uid": next_uid}


func load_dict(data: Dictionary) -> void:
	soldiers.clear()
	var saved_uid: int = data.get("next_uid", 0)
	next_uid = saved_uid
	var list: Array = data.get("soldiers", [])
	for entry: Variant in list:
		if not entry is Dictionary:
			continue
		var d: Dictionary = entry
		var tier: int = d.get("tier", 0)
		var level: int = d.get("level", 1)
		var enemy_id: String = d.get("enemy_id", "")
		var display_name: String = d.get("name", enemy_id)
		var uid: int = d.get("uid", -1)
		if uid < 0:
			next_uid += 1
			uid = next_uid
		next_uid = maxi(next_uid, uid)
		var xp: int = d.get("xp", 0)
		soldiers.append({"uid": uid, "enemy_id": enemy_id, "name": display_name, "tier": tier, "level": level,
			"rank": rank_for_xp(xp), "xp": xp})
