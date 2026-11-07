class_name WorldGateManager
extends Node3D
## Region-side driver of WorldGates: shows portals for open dynamic Gates, rolls new ones
## over game time and runs Dungeon Break waves when a Gate is left alone too long.

const PORTAL_SCENE: PackedScene = preload("res://scenes/world/gates/gate_portal.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const TICK_S: float = 1.0
const WAVE_RADIUS_M: float = 7.0

var region: RegionData
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _portals: Dictionary[int, GatePortal] = {}
## uid -> enemies still alive in that Gate's break wave.
var _waves: Dictionary[int, int] = {}
var _timer: float = 0.0


func setup(region_data: RegionData) -> void:
	region = region_data
	name = "WorldGates"
	rng.randomize()
	for entry: Dictionary in WorldGates.entries_in(region.id):
		_show(entry)
		if WorldGates.is_broken(entry):
			_start_break.call_deferred(entry)


func _process(delta: float) -> void:
	_timer += delta
	if _timer < TICK_S or region == null or GameState.player == null:
		return
	_timer = 0.0
	var now: float = GameState.clock.total_minutes
	var entry: Dictionary = WorldGates.try_spawn(region, now, rng)
	if not entry.is_empty():
		_show(entry)
		var gate: GateData = WorldGates.gate_data(entry)
		Codex.notify(tr(&"CODEX_MSG_GATE_OPENED") % [tr(gate.display_name), GateData.Rank.keys()[gate.rank]], &"warning")
	for e: Dictionary in WorldGates.entries_in(region.id):
		_show(e)
		if WorldGates.is_break_due(e, now):
			_start_break(e)


func portal_count() -> int:
	return _portals.size()


func _point(entry: Dictionary) -> Vector3:
	var i: int = WorldGates.point_of(entry)
	return region.gate_points[i] if i < region.gate_points.size() else Vector3.ZERO


func _show(entry: Dictionary) -> void:
	var gate: GateData = WorldGates.gate_data(entry)
	var uid: int = WorldGates.uid_of(entry)
	if gate == null or _portals.has(uid):
		return
	var portal: GatePortal = PORTAL_SCENE.instantiate() as GatePortal
	portal.gate = gate
	portal.closes_when_cleared = false
	portal.world_gate_uid = uid
	portal.position = _point(entry)
	add_child(portal)
	_portals[uid] = portal


func _start_break(entry: Dictionary) -> void:
	var uid: int = WorldGates.uid_of(entry)
	if _waves.has(uid) or region.break_pool.is_empty():
		return
	entry["broken"] = true
	var gate: GateData = WorldGates.gate_data(entry)
	var rank: int = gate.rank if gate != null else 0
	var count: int = WorldGates.break_wave_size(rank)
	var center: Vector3 = _point(entry)
	var level: int = maxi(region.level_min, GameState.progression.level if GameState.progression != null else 1)
	_waves[uid] = count
	for i: int in count:
		var data: EnemyData = region.break_pool[i % region.break_pool.size()].duplicate() as EnemyData
		data.level = level
		data.aggro_radius = 60.0
		data.leash_radius = 120.0
		var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
		enemy.data = data
		var a: float = TAU * float(i) / float(count)
		enemy.position = center + Vector3(cos(a), 0.3, sin(a)) * WAVE_RADIUS_M
		add_child(enemy)
		enemy.tree_exited.connect(_on_wave_enemy_gone.bind(uid), CONNECT_ONE_SHOT)
	if _portals.has(uid):
		_portals[uid].set_breaking(true)
	Codex.notify(tr(&"CODEX_MSG_DUNGEON_BREAK") % tr(gate.display_name if gate != null else &""), &"anomaly")
	EventBus.dungeon_break_started.emit(uid)


func _on_wave_enemy_gone(uid: int) -> void:
	if not is_inside_tree() or not _waves.has(uid):
		return
	_waves[uid] -= 1
	if _waves[uid] > 0:
		return
	_waves.erase(uid)
	var gate: GateData = WorldGates.gate_data(WorldGates.find(uid))
	var rank: int = gate.rank if gate != null else 0
	EventBus.gold_gained.emit(WorldGates.break_reward_gold(rank))
	EventBus.xp_gained.emit(200 * (rank + 1))
	GuildRank.add_points(15 * (rank + 1))
	WorldGates.remove(uid)
	if _portals.has(uid):
		_portals[uid].queue_free()
		_portals.erase(uid)
	Codex.notify(tr(&"CODEX_MSG_BREAK_REPELLED"), &"reward")
	EventBus.dungeon_break_ended.emit(uid)
