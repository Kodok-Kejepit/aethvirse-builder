extends GutTest
## Gate dungeon layout: rooms on a grid joined by tunnels, all reachable on foot,
## abstract (not round) rooms, wards / doors at the mouths.


func test_every_room_is_reachable_and_boss_is_last_on_the_main_path() -> void:
	for s: int in 20:
		var plan: DungeonPlan = DungeonPlan.make(6, 3, s * 31 + 7)
		assert_true(plan.all_reachable(), "seed %d" % s)
		assert_eq(plan.rooms[plan.boss_index].kind, DungeonPlan.Kind.BOSS)
		assert_eq(plan.rooms[0].kind, DungeonPlan.Kind.START)
		assert_eq(plan.rooms[0].enemy_count, 0, "start room is calm")


func test_rooms_have_their_own_cells() -> void:
	for s: int in 20:
		var plan: DungeonPlan = DungeonPlan.make(9, 2, s)
		var seen: Dictionary = {}
		for room: DungeonPlan.Room in plan.rooms:
			assert_false(seen.has(room.cell), "seed %d: two rooms on one cell" % s)
			seen[room.cell] = true


func test_side_rooms_are_dead_ends() -> void:
	var plan: DungeonPlan = DungeonPlan.make(9, 2, 5)
	var sides: int = 0
	for i: int in plan.rooms.size():
		if plan.rooms[i].kind == DungeonPlan.Kind.SIDE:
			sides += 1
			assert_eq(plan.neighbours(i).size(), 1)
	assert_gt(sides, 0, "long runs branch")


func test_links_mix_doors_open_tunnels_and_breaches() -> void:
	var kinds: Dictionary = {}
	for s: int in 30:
		for link: Dictionary in DungeonPlan.make(7, 2, s).links:
			kinds[link["kind"]] = true
	assert_eq(kinds.size(), 3)


func test_same_seed_same_dungeon() -> void:
	var a: DungeonPlan = DungeonPlan.make(6, 3, 1234)
	var b: DungeonPlan = DungeonPlan.make(6, 3, 1234)
	assert_eq(a.rooms.size(), b.rooms.size())
	for i: int in a.rooms.size():
		assert_eq(a.rooms[i].cell, b.rooms[i].cell)
		assert_almost_eq(a.rooms[i].radius, b.rooms[i].radius, 0.0001)


func test_whole_dungeon_is_walkable_from_the_start() -> void:
	for s: int in 6:
		var plan: DungeonPlan = DungeonPlan.make(6, 2, s * 7 + 1, 2)
		var field: DungeonField = DungeonField.build(plan, s)
		var open: Dictionary = field.reachable_from(plan.center(0))
		for i: int in plan.rooms.size():
			assert_true(open.has(field.index_of(plan.center(i))), "seed %d: room %d reachable" % [s, i])
		for e: Dictionary in field.niches:
			var centre: Vector2 = e["center"]
			assert_true(open.has(field.index_of(centre)), "seed %d: cache niche open behind its crack" % s)
		for d: Dictionary in field.dead_ends:
			var end_at: Vector2 = d["end"]
			var dir: Vector2 = d["dir"]
			assert_gt(field.value_at(end_at - dir * 2.0), 0.0, "seed %d: dead end open in front of the door" % s)


func test_mouths_sit_just_outside_their_rooms() -> void:
	var plan: DungeonPlan = DungeonPlan.make(6, 2, 99)
	var field: DungeonField = DungeonField.build(plan, 3)
	for t: Dictionary in field.tunnels:
		for end: String in ["a", "b"]:
			var room: int = t[end]
			var mouth: Vector2 = t["mouth_" + end]
			var dir: Vector2 = t["dir_" + end]
			assert_lt(field.room_value(room, mouth), 0.0, "mouth outside the room shape")
			assert_gt(field.room_value(room, mouth - dir * 3.0), -0.2, "and right at its edge")
			assert_gt(field.value_at(mouth), 0.0, "the tunnel is open there")


func test_rooms_are_not_plain_circles() -> void:
	var plan: DungeonPlan = DungeonPlan.make(5, 2, 42)
	var field: DungeonField = DungeonField.build(plan, 42)
	for i: int in plan.rooms.size():
		var c: Vector2 = plan.center(i)
		var reach: Array[float] = []
		for k: int in 16:
			var dir: Vector2 = Vector2.from_angle(TAU * float(k) / 16.0)
			var dist: float = 0.0
			while dist < 60.0 and field.room_value(i, c + dir * dist) > 0.0:
				dist += 0.5
			reach.append(dist)
		var longest: float = reach.max()
		var shortest: float = reach.min()
		assert_gt(longest / maxf(shortest, 0.5), 1.25, "room %d has an uneven outline" % i)


func test_mystery_box_can_hold_a_gate_key() -> void:
	var inv: Inventory = Inventory.new(ItemDatabase.new())
	var keys: int = 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	for _i: int in 40:
		inv.add(&"mystery_box")
		var result: Dictionary = ItemActions.open_mystery_box(inv, inv.first_stack(&"mystery_box"), 5, rng)
		var got_key: bool = result["key"]
		if got_key:
			keys += 1
	assert_gt(keys, 0)
	assert_lt(keys, 40)
	assert_eq(inv.count_of(&"gate_key"), keys)
