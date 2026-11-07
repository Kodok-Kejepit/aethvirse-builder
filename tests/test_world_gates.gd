extends GutTest
## Dynamic world Gates + Dungeon Break.

var _region: RegionData
var _rng: RandomNumberGenerator
var _saved: Array[Dictionary] = []


func before_each() -> void:
	_saved = GameState.world_gates.duplicate(true)
	GameState.world_gates.clear()
	GameState.world_gate_clock.clear()
	_region = RegionData.load_region(&"r1_ashfall")
	_rng = RandomNumberGenerator.new()
	_rng.seed = 7


func after_each() -> void:
	GameState.world_gates = _saved
	GameState.world_gate_clock.clear()


func _spawn_until_full(now: float) -> int:
	var made: int = 0
	for i: int in 200:
		GameState.world_gate_clock.erase("r1_ashfall")
		if not WorldGates.try_spawn(_region, now, _rng).is_empty():
			made += 1
	return made


func test_spawn_respects_interval() -> void:
	var first: Dictionary = {}
	for i: int in 50:
		GameState.world_gate_clock.erase("r1_ashfall")
		first = WorldGates.try_spawn(_region, 100.0, _rng)
		if not first.is_empty():
			break
	assert_false(first.is_empty())
	assert_true(WorldGates.try_spawn(_region, 100.0 + WorldGates.CHECK_EVERY_MIN - 1.0, _rng).is_empty(), "too soon")


func test_spawn_caps_and_uses_distinct_points() -> void:
	var made: int = _spawn_until_full(0.0)
	assert_eq(made, _region.max_world_gates)
	var points: Array[int] = []
	for e: Dictionary in WorldGates.entries_in(&"r1_ashfall"):
		assert_false(points.has(WorldGates.point_of(e)))
		points.append(WorldGates.point_of(e))
		assert_not_null(WorldGates.gate_data(e))


func test_break_after_a_day_and_remove() -> void:
	_spawn_until_full(0.0)
	var e: Dictionary = WorldGates.entries_in(&"r1_ashfall")[0]
	assert_false(WorldGates.is_break_due(e, WorldGates.BREAK_AFTER_MIN - 1.0))
	assert_true(WorldGates.is_break_due(e, WorldGates.BREAK_AFTER_MIN + 1.0))
	var uid: int = WorldGates.uid_of(e)
	WorldGates.remove(uid)
	assert_true(WorldGates.find(uid).is_empty())


func test_entries_survive_save_round_trip_as_ints() -> void:
	_spawn_until_full(0.0)
	var json: String = JSON.stringify(GameState.to_dict())
	var parsed: Dictionary = JSON.parse_string(json)
	var count: int = GameState.world_gates.size()
	var prog: Progression = GameState.progression
	GameState.load_dict(parsed, load("res://data/balancing/stat_tuning.tres") as StatTuning)
	assert_eq(GameState.world_gates.size(), count)
	var first: Dictionary = GameState.world_gates[0]
	assert_eq(typeof(first["uid"]), TYPE_INT)
	GameState.progression = prog


func test_break_wave_spawns_and_clears() -> void:
	_spawn_until_full(0.0)
	var manager: WorldGateManager = WorldGateManager.new()
	add_child_autofree(manager)
	manager.setup(_region)
	assert_eq(manager.portal_count(), _region.max_world_gates)
	var e: Dictionary = WorldGates.entries_in(&"r1_ashfall")[0]
	var uid: int = WorldGates.uid_of(e)
	manager._start_break(e)
	assert_true(WorldGates.is_broken(e))
	var enemies: Array[Node] = []
	for child: Node in manager.get_children():
		if child is Enemy:
			enemies.append(child)
	var gate: GateData = WorldGates.gate_data(e)
	assert_eq(enemies.size(), WorldGates.break_wave_size(gate.rank))
	for enemy: Node in enemies:
		enemy.free()
	assert_true(WorldGates.find(uid).is_empty(), "repelled break closes the Gate")
	assert_eq(manager.portal_count(), _region.max_world_gates - 1)
