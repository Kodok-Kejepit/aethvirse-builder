extends GutTest
## Things spawned "at a world position" land there even when their parent is moved
## (chunks sit at chunk_x * 128 m, dungeon niches are rotated); chests always give
## something; waystone data matches where the waystones really stand.

const CHUNK_SIZE_M: float = 128.0


func _offset_parent() -> Node3D:
	var parent: Node3D = Node3D.new()
	parent.position = Vector3(128.0, 0.0, -256.0)
	parent.rotation.y = 0.7
	add_child_autofree(parent)
	return parent


func after_each() -> void:
	for child: Node in get_children():
		if child is Enemy:
			child.queue_free()


func test_pickup_lands_at_the_world_position() -> void:
	var parent: Node3D = _offset_parent()
	var at: Vector3 = Vector3(140.0, 1.0, -250.0)
	var pickup: WorldPickup = WorldPickup.spawn(parent, at, ItemStack.make(&"herb", 1, GameState.items.get_item(&"herb")))
	assert_almost_eq(pickup.global_position, at, Vector3.ONE * 0.01)


func test_spawner_enemy_appears_at_the_spawner() -> void:
	var parent: Node3D = _offset_parent()
	var spawner: EnemySpawner = EnemySpawner.new()
	spawner.enemy_scene = load("res://scenes/enemies/enemy.tscn") as PackedScene
	spawner.enemy_data = load("res://data/enemies/gate_husk.tres") as EnemyData
	spawner.spawn_on_ready = false
	spawner.position = Vector3(10.0, 0.0, 5.0)
	parent.add_child(spawner)
	var enemy: Enemy = spawner.spawn()
	var flat: Vector3 = enemy.global_position - spawner.global_position
	flat.y = 0.0
	assert_lt(flat.length(), 0.01, "enemy stands on its spawner")
	enemy.queue_free()


func test_chest_always_gives_loot_next_to_it() -> void:
	for kind: StringName in [&"supply", &"treasure"]:
		for i: int in 12:
			var parent: Node3D = _offset_parent()
			var chest: LootChest = LootChest.new()
			chest.chest_id = StringName("test_chest_%s_%d" % [kind, i])
			chest.kind = kind
			chest.persistent = false
			chest.position = Vector3(3.0, 0.0, 4.0)
			parent.add_child(chest)
			chest._open(null)
			var pickups: Array[WorldPickup] = []
			for node: Node in parent.get_children():
				if node is WorldPickup:
					pickups.append(node)
			assert_gt(pickups.size(), 0, "%s chest %d gives something" % [kind, i])
			var has_gear: bool = false
			for p: WorldPickup in pickups:
				assert_lt(p.global_position.distance_to(chest.global_position), 3.0, "loot lies at the chest")
				var item: ItemData = GameState.items.get_item(p.stack.item_id)
				if item != null and item.is_equipment():
					has_gear = true
			if kind == &"treasure":
				assert_true(has_gear, "treasure chests always hold equipment")


func test_waystone_data_matches_the_chunks() -> void:
	for rid: StringName in RegionData.IDS:
		var region: RegionData = RegionData.load_region(rid)
		var placed: Dictionary = _placed_waystones("res://scenes/world/chunks/%s/" % String(rid).substr(0, 2))
		for wid: StringName in region.waystones:
			if not placed.has(wid):
				continue
			var data_pos: Vector3 = region.waystones[wid]
			var real: Vector3 = placed[wid]
			assert_lt(Vector2(data_pos.x - real.x, data_pos.z - real.z).length(), 1.0, "%s data %s vs chunk %s" % [wid, data_pos, real])


## waystone id -> world position, read from the chunk scene files.
func _placed_waystones(dir_path: String) -> Dictionary:
	var out: Dictionary = {}
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	for file: String in dir.get_files():
		if not file.ends_with(".tscn"):
			continue
		var parts: PackedStringArray = file.get_basename().split("_")
		var origin: Vector3 = Vector3(parts[1].to_float(), 0.0, parts[2].to_float()) * CHUNK_SIZE_M
		var text: String = FileAccess.get_file_as_string(dir_path + file)
		var transform_line: String = ""
		for line: String in text.split("\n"):
			if line.begins_with("[node"):
				transform_line = ""
			elif line.begins_with("transform = Transform3D("):
				transform_line = line
			elif line.begins_with("waystone_id = &\"") and transform_line != "":
				var id: StringName = StringName(line.get_slice("\"", 1))
				var nums: PackedStringArray = transform_line.get_slice("(", 1).get_slice(")", 0).split(",")
				out[id] = origin + Vector3(nums[9].to_float(), nums[10].to_float(), nums[11].to_float())
	return out


func test_spawner_level_overrides_the_data_level() -> void:
	var parent: Node3D = _offset_parent()
	var spawner: EnemySpawner = EnemySpawner.new()
	spawner.enemy_scene = load("res://scenes/enemies/enemy.tscn") as PackedScene
	spawner.enemy_data = load("res://data/enemies/ash_hound.tres") as EnemyData
	spawner.spawn_on_ready = false
	spawner.level = 27
	parent.add_child(spawner)
	var enemy: Enemy = spawner.spawn()
	assert_eq(enemy.data.level, 27)
	assert_eq(spawner.enemy_data.level, 3, "the shared data resource is untouched")
	var weak: Enemy = (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
	weak.data = spawner.enemy_data
	parent.add_child(weak)
	assert_gt(enemy.health.max_health, weak.health.max_health * 3, "a Lv 27 hound is far tougher")
	enemy.queue_free()
	weak.queue_free()


func test_region_one_spans_level_1_to_50() -> void:
	var region: RegionData = RegionData.load_region(&"r1_ashfall")
	assert_eq(region.level_min, 1)
	assert_eq(region.level_max, 50)
