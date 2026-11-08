extends GutTest
## Several kinds of Gate dungeon per rank, and room challenges.


func after_each() -> void:
	for child: Node in get_children():
		if child is Enemy:
			child.queue_free()


func test_each_rank_picks_from_its_own_kinds_and_varies() -> void:
	for rank: int in DungeonArchetype.BY_RANK.size():
		var seen: Dictionary = {}
		for s: int in 40:
			var kind: StringName = DungeonArchetype.pick(rank, s * 97 + 5)
			assert_true(kind in DungeonArchetype.BY_RANK[rank], "rank %d gets its own kinds" % rank)
			seen[kind] = true
		assert_gt(seen.size(), 1, "rank %d is not always the same place" % rank)


func test_kind_shapes_the_rooms() -> void:
	var halls: DungeonPlan = DungeonPlan.make(6, 2, 77, -1, &"halls")
	var warrens: DungeonPlan = DungeonPlan.make(6, 2, 77, -1, &"warrens")
	var hall_rooms: int = 0
	for room: DungeonPlan.Room in halls.rooms:
		if room.style == &"hall":
			hall_rooms += 1
	var cave_rooms: int = 0
	for room: DungeonPlan.Room in warrens.rooms:
		if room.style == &"cave":
			cave_rooms += 1
	assert_gt(hall_rooms, 0, "halls are mostly halls")
	assert_gt(cave_rooms, 0, "warrens are mostly caves")


func test_challenges_only_in_fight_rooms() -> void:
	var with_challenge: int = 0
	for s: int in 20:
		var plan: DungeonPlan = DungeonPlan.make(7, 3, s)
		for room: DungeonPlan.Room in plan.rooms:
			if room.challenge != &"":
				with_challenge += 1
				assert_eq(room.kind, DungeonPlan.Kind.FIGHT)
				assert_true(room.challenge in DungeonArchetype.CHALLENGES)
	assert_gt(with_challenge, 10, "plenty of rooms get a challenge")


func test_waves_split_the_enemies() -> void:
	var husk: EnemyData = load("res://data/enemies/gate_husk.tres") as EnemyData
	var list: Array[EnemyData] = [husk, husk, husk, husk, husk]
	var waves: Array[Array] = GateRoom.split_waves(list, true)
	assert_eq(waves.size(), 3)
	var total: int = 0
	for w: Array in waves:
		assert_gt(w.size(), 0)
		total += w.size()
	assert_eq(total, 5)
	assert_eq(GateRoom.split_waves(list, false).size(), 1)


func test_next_wave_comes_after_the_first_falls() -> void:
	var room: GateRoom = GateRoom.new()
	var husk: EnemyData = load("res://data/enemies/gate_husk.tres") as EnemyData
	room.enemies = [husk, husk, husk, husk]
	room.challenge = &"waves"
	room.spawn_points = [Vector3(0, 0.3, 0)]
	add_child_autofree(room)
	watch_signals(room)
	room.start()
	await wait_physics_frames(2)
	var first: int = room._living.size()
	assert_between(first, 1, 3, "only the first wave")
	for e: Enemy in room._living.duplicate():
		e.queue_free()
	await wait_seconds(GateRoom.WAVE_DELAY_S + 0.5)
	assert_signal_not_emitted(room, "cleared", "not cleared while waves remain")
	assert_gt(room._living.size(), 0, "the next wave arrived")
