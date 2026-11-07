class_name WorldGates
extends RefCounted
## Dynamic Gates in the open world (§7): they open at random spots of a region over game
## time and, if left alone for a game day, break — monsters pour out (Dungeon Break).
## State lives in GameState.world_gates (saved): {uid, gate, region, point, opened_at, broken}.

## Game minutes between spawn rolls per region, and the chance per roll.
const CHECK_EVERY_MIN: float = 120.0
const SPAWN_CHANCE: float = 0.5
## An untouched Gate breaks after one game day.
const BREAK_AFTER_MIN: float = 1440.0


static func uid_of(e: Dictionary) -> int:
	var v: int = e.get("uid", -1)
	return v


static func point_of(e: Dictionary) -> int:
	var v: int = e.get("point", 0)
	return v


static func region_of(e: Dictionary) -> StringName:
	var v: String = e.get("region", "")
	return StringName(v)


static func is_broken(e: Dictionary) -> bool:
	var v: bool = e.get("broken", false)
	return v


static func entries_in(region_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in GameState.world_gates:
		if region_of(e) == region_id:
			out.append(e)
	return out


static func find(uid: int) -> Dictionary:
	for e: Dictionary in GameState.world_gates:
		if uid_of(e) == uid:
			return e
	return {}


static func remove(uid: int) -> void:
	for i: int in GameState.world_gates.size():
		if uid_of(GameState.world_gates[i]) == uid:
			GameState.world_gates.remove_at(i)
			return


## Rolls for a new Gate in `region` if its check interval passed. Returns the new entry or {}.
static func try_spawn(region: RegionData, now: float, rng: RandomNumberGenerator) -> Dictionary:
	var key: String = String(region.id)
	var last: float = GameState.world_gate_clock.get(key, -INF)
	if now - last < CHECK_EVERY_MIN:
		return {}
	GameState.world_gate_clock[key] = now
	var existing: Array[Dictionary] = entries_in(region.id)
	if existing.size() >= region.max_world_gates or region.gate_table.is_empty():
		return {}
	if rng.randf() > SPAWN_CHANCE:
		return {}
	var used: Array[int] = []
	for e: Dictionary in existing:
		used.append(point_of(e))
	var free: Array[int] = []
	for i: int in region.gate_points.size():
		if not used.has(i):
			free.append(i)
	if free.is_empty():
		return {}
	var gate: GateData = region.gate_table[rng.randi_range(0, region.gate_table.size() - 1)]
	GameState.next_gate_uid += 1
	var entry: Dictionary = {
		"uid": GameState.next_gate_uid, "gate": String(gate.id), "region": key,
		"point": free[rng.randi_range(0, free.size() - 1)], "opened_at": now, "broken": false,
	}
	GameState.world_gates.append(entry)
	return entry


static func is_break_due(entry: Dictionary, now: float) -> bool:
	var opened: float = entry.get("opened_at", now)
	return not is_broken(entry) and now - opened >= BREAK_AFTER_MIN


static func gate_data(entry: Dictionary) -> GateData:
	var gid: String = entry.get("gate", "")
	var path: String = "res://data/gates/%s.tres" % gid
	return load(path) as GateData if ResourceLoader.exists(path) else null


## Size of the Dungeon Break wave for a Gate rank.
static func break_wave_size(rank: int) -> int:
	return 4 + rank * 2


static func break_reward_gold(rank: int) -> int:
	return 150 * (rank + 1)
