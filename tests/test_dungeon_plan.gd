extends GutTest
## Gate dungeon layout: branching rooms, doors back and forth, irregular outlines.


func test_every_room_is_reachable_and_boss_is_last_on_the_main_path() -> void:
	for s: int in 20:
		var plan: DungeonPlan = DungeonPlan.make(6, 3, s * 31 + 7)
		assert_true(plan.all_reachable(), "seed %d" % s)
		assert_eq(plan.rooms[plan.boss_index].kind, DungeonPlan.Kind.BOSS)
		assert_eq(plan.rooms[0].kind, DungeonPlan.Kind.START)
		assert_eq(plan.rooms[0].enemy_count, 0, "start room is calm")


func test_doors_lead_back() -> void:
	var plan: DungeonPlan = DungeonPlan.make(7, 2, 99)
	for i: int in plan.rooms.size():
		for door: Dictionary in plan.rooms[i].doors:
			var to: int = door["to"]
			assert_gt(plan.door_back(i, to), -1, "room %d -> %d has a way back" % [i, to])


func test_side_rooms_are_dead_ends() -> void:
	var plan: DungeonPlan = DungeonPlan.make(9, 2, 5)
	var sides: int = 0
	for room: DungeonPlan.Room in plan.rooms:
		if room.kind == DungeonPlan.Kind.SIDE:
			sides += 1
			assert_eq(room.doors.size(), 1)
	assert_gt(sides, 0, "long runs branch")


func test_same_seed_same_dungeon() -> void:
	var a: DungeonPlan = DungeonPlan.make(6, 3, 1234)
	var b: DungeonPlan = DungeonPlan.make(6, 3, 1234)
	assert_eq(a.rooms.size(), b.rooms.size())
	for i: int in a.rooms.size():
		assert_eq(a.rooms[i].style, b.rooms[i].style)
		assert_almost_eq(a.rooms[i].radius, b.rooms[i].radius, 0.0001)


func test_double_door_sits_in_the_chosen_room() -> void:
	var plan: DungeonPlan = DungeonPlan.make(5, 2, 8, 2)
	assert_true(plan.rooms[2].has_double_door)
	assert_false(plan.rooms[0].has_double_door)


func test_outline_has_a_straight_doorway_per_door() -> void:
	var angles: Array[float] = [PI * 0.5, -PI * 0.5, -PI * 0.2]
	for style: StringName in DungeonPlan.STYLES:
		var pts: Array[Dictionary] = DungeonRoomShape.outline(15.0, style, angles, 77)
		var door_edges: int = 0
		for i: int in pts.size():
			if DungeonRoomShape.is_door_edge(pts, i):
				door_edges += 1
				var a: Vector2 = pts[i]["p"]
				var b: Vector2 = pts[(i + 1) % pts.size()]["p"]
				assert_almost_eq(a.distance_to(b), DungeonRoomShape.DOOR_HALF_M * 2.0, 0.3, "door is door-wide")
		assert_eq(door_edges, angles.size(), String(style))
		assert_true(DungeonRoomShape.contains(pts, Vector2.ZERO), "centre is inside")
		assert_false(DungeonRoomShape.contains(pts, Vector2(40.0, 0.0)))


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
