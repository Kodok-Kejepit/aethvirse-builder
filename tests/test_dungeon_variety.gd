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


func test_every_map_shape_is_whole_and_walkable() -> void:
	for shape: StringName in DungeonPlan.LAYOUTS:
		for s: int in 12:
			var plan: DungeonPlan = DungeonPlan.make(4 + s % 7, 2, s * 53 + 1, 2, &"ruins", shape)
			var tag: String = "%s seed %d" % [shape, s]
			assert_true(plan.all_reachable(), tag)
			assert_eq(plan.rooms[0].kind, DungeonPlan.Kind.START, tag)
			assert_eq(plan.rooms[plan.boss_index].kind, DungeonPlan.Kind.BOSS, tag)
			var cells: Dictionary = {}
			for room: DungeonPlan.Room in plan.rooms:
				assert_false(cells.has(room.cell), "%s: one room per cell" % tag)
				cells[room.cell] = true
			for link: Dictionary in plan.links:
				var a: int = link["a"]
				var b: int = link["b"]
				var d: Vector2i = plan.rooms[a].cell - plan.rooms[b].cell
				assert_eq(absi(d.x) + absi(d.y), 1, "%s: tunnels join neighbouring cells" % tag)
			assert_eq(plan.neighbours(plan.boss_index).size(), 1, "%s: one way into the boss hall" % tag)


func test_loop_and_fork_offer_two_ways() -> void:
	var loop: DungeonPlan = DungeonPlan.make(8, 2, 9, -1, &"ruins", &"loop")
	assert_eq(loop.layout, &"loop")
	assert_eq(loop.neighbours(0).size(), 2, "the start room opens both ways round the ring")
	var fork: DungeonPlan = DungeonPlan.make(8, 2, 9, -1, &"ruins", &"fork")
	assert_eq(fork.layout, &"fork")
	assert_gte(fork.neighbours(0).size(), 2, "two routes leave the start")
	var hub: DungeonPlan = DungeonPlan.make(8, 2, 9, -1, &"halls", &"hub")
	assert_eq(hub.neighbours(1).size(), 4, "the great hall: start + three spokes")
	assert_eq(DungeonPlan.make(3, 2, 9, -1, &"ruins", &"fork").layout, &"winding", "too short to fork")


func test_kinds_choose_their_own_shapes() -> void:
	var seen: Dictionary = {}
	for s: int in 60:
		seen[DungeonPlan.make(8, 2, s, -1, &"crypt").layout] = true
	assert_gt(seen.size(), 1, "a kind of place is built in several shapes")
	for id: StringName in DungeonArchetype.ALL:
		for shape: StringName in DungeonArchetype.spec(id).get("layouts", []):
			assert_true(shape in DungeonPlan.LAYOUTS, "%s uses a known shape" % id)


func test_region_gates_open_into_their_own_kind() -> void:
	assert_eq(DungeonArchetype.region_of("gate_r3_c_mirage"), "r3")
	assert_eq(DungeonArchetype.region_of("hidden_gate_r1"), "r1")
	assert_eq(DungeonArchetype.region_of("trial_tier_1"), "")
	for region: String in ["gate_r3_b_tomb", "gate_r4_a_mirror", "gate_r5_a_tidal", "gate_r6_s_fracture"]:
		var own: StringName = DungeonArchetype.BY_REGION[StringName(DungeonArchetype.region_of(region))]
		var hits: int = 0
		for s: int in 60:
			if DungeonArchetype.pick(3, s * 13 + 1, region) == own:
				hits += 1
		assert_gt(hits, 10, "%s often opens into %s" % [region, own])
	for id: StringName in DungeonArchetype.ALL:
		var name_key: StringName = DungeonArchetype.spec(id)["name"]
		assert_ne(tr(name_key), String(name_key), "%s has a name" % id)
	for shape: StringName in DungeonPlan.LAYOUTS:
		if shape != &"winding":
			var key: String = "DUNGEON_LAYOUT_" + String(shape).to_upper()
			assert_ne(tr(key), key, "%s is described" % shape)
