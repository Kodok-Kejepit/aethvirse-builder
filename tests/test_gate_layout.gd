extends GutTest
## Gate size scales with level/rank; Double Gate rules.

var gate: GateData


func before_each() -> void:
	gate = load("res://data/gates/gate_r1_e_overpass.tres") as GateData


func test_low_level_gate_stays_short() -> void:
	assert_eq(GateLayout.room_count(gate, 1), gate.room_count)


func test_rooms_grow_with_level_and_cap() -> void:
	assert_gt(GateLayout.room_count(gate, 30), GateLayout.room_count(gate, 1))
	assert_eq(GateLayout.room_count(gate, 100), GateLayout.MAX_ROOMS)
	var s_rank: GateData = gate.duplicate() as GateData
	s_rank.rank = GateData.Rank.S
	assert_gt(GateLayout.room_count(s_rank, 1), GateLayout.room_count(gate, 1), "higher rank, longer gate")


func test_enemies_keep_up_with_player() -> void:
	assert_eq(GateLayout.enemy_level(3, 1), 3, "never below the data level")
	assert_eq(GateLayout.enemy_level(3, 30), 28)
	assert_eq(GateLayout.enemy_level(3, 30, 4), 32)
	assert_lte(GateLayout.enemies_per_room(gate, 100), GateLayout.MAX_ENEMIES_PER_ROOM)


func test_double_gate_appears_on_some_days_only() -> void:
	var hits: int = 0
	for day: int in range(1, 201):
		if GateLayout.has_double_gate(gate, day):
			hits += 1
	assert_between(hits, 40, 110, "roughly 35% of days")
	assert_eq(GateLayout.has_double_gate(gate, 5), GateLayout.has_double_gate(gate, 5), "deterministic")


func test_double_gate_room_is_never_the_first() -> void:
	for day: int in range(1, 100):
		var room: int = GateLayout.double_gate_room(5, day)
		assert_between(room, 1, 4)


func test_make_double_is_harder_and_has_no_nested_double() -> void:
	var inner: GateData = GateLayout.make_double(gate, 3)
	assert_eq(inner.rank, gate.rank + 1)
	assert_true(inner.has_rule(&"double"))
	assert_false(GateLayout.has_double_gate(inner, 3), "no Double Gate inside a Double Gate")
	assert_eq(inner.room_count, GateLayout.DOUBLE_ROOMS)
	assert_true(inner.reward_items.has(&"mystery_box"))
	assert_eq(gate.room_count, 3, "the outer gate data is untouched")


func test_double_session_keeps_the_way_home() -> void:
	var outer: GateSession = GateSession.new()
	outer.gate = gate
	outer.return_scene = "res://scenes/world/regions/ashfall.tscn"
	outer.return_position = Vector3(1, 2, 3)
	var inner: GateSession = GateLayout.double_session(outer, 2)
	assert_eq(inner.return_scene, outer.return_scene)
	assert_eq(inner.return_position, outer.return_position)
	assert_eq(inner.enemy_level_bonus, GateLayout.DOUBLE_LEVEL_BONUS)
	assert_true(inner.has_rule(&"double"))


func test_dungeon_has_a_winged_door_that_wants_a_key() -> void:
	var session: GateSession = GateSession.new()
	session.gate = gate
	session.force_double = true
	GameState.gate_session = session
	var dungeon: GateDungeon = (load(GateDungeon.SCENE) as PackedScene).instantiate() as GateDungeon
	add_child_autofree(dungeon)
	await wait_physics_frames(3)
	var double_door: DungeonDoor = null
	for node: Node in dungeon.find_children("*", "StaticBody3D", true, false):
		var door: DungeonDoor = node as DungeonDoor
		if door == null:
			continue
		var at: Vector2 = Vector2(door.global_position.x, door.global_position.z)
		assert_gt(dungeon.field.value_at(at), 0.0, "door stands in an open tunnel")
		if door.is_double:
			double_door = door
	assert_not_null(double_door, "forced Double Gate door exists")
	double_door.used.disconnect(dungeon._on_door_used)
	watch_signals(double_door)
	GameState.inventory.remove(DungeonDoor.KEY_ITEM, GameState.inventory.count_of(DungeonDoor.KEY_ITEM))
	double_door._on_use(null)
	assert_signal_not_emitted(double_door, "used", "no key, no way in")
	GameState.inventory.add(DungeonDoor.KEY_ITEM)
	double_door._on_use(null)
	assert_signal_emitted(double_door, "used")
	assert_eq(GameState.inventory.count_of(DungeonDoor.KEY_ITEM), 0, "the key is used up")
	GameState.gate_session = null


func test_dying_in_a_later_room_respawns_in_the_shown_start_room() -> void:
	var session: GateSession = GateSession.new()
	session.gate = gate
	GameState.gate_session = session
	GameState.respawn_waystone = &""
	var dungeon: GateDungeon = (load(GateDungeon.SCENE) as PackedScene).instantiate() as GateDungeon
	add_child_autofree(dungeon)
	await wait_physics_frames(3)
	var far: int = dungeon.plan.boss_index
	dungeon.debug_goto(far)
	assert_false(dungeon._groups[0].visible, "start room hidden while away")
	dungeon.player.respawn()
	await wait_physics_frames(2)
	assert_true(dungeon._groups[0].visible, "start room shown again")
	assert_false(dungeon._groups[far].visible)
	var start: Vector3 = dungeon._rooms[0].global_position
	assert_lt(Vector2(dungeon.player.global_position.x - start.x, dungeon.player.global_position.z - start.z).length(), 15.0, "back in the start room")
	GameState.gate_session = null
