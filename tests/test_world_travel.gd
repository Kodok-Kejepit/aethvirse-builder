extends GutTest
## M9 world: region data, waystones, fast travel bookkeeping.


func after_each() -> void:
	for rid: StringName in RegionData.IDS:
		for wid: StringName in RegionData.load_region(rid).waystones:
			GameState.world_flags.erase(WorldTravel.flag_for(wid))


func test_every_region_is_complete() -> void:
	for rid: StringName in RegionData.IDS:
		var r: RegionData = RegionData.load_region(rid)
		assert_not_null(r, String(rid))
		assert_true(ResourceLoader.exists(r.scene_path), "%s scene" % rid)
		assert_gt(r.waystones.size(), 0, "%s waystones" % rid)
		if r.max_world_gates > 0:
			assert_gt(r.gate_table.size(), 0, "%s gate table" % rid)
			assert_gt(r.gate_points.size(), r.max_world_gates - 1, "%s gate points" % rid)
		assert_gt(r.break_pool.size(), 0, "%s break pool" % rid)
		assert_lt(r.level_min, r.level_max)


func test_regions_chain_by_level() -> void:
	var prev_max: int = 0
	for rid: StringName in RegionData.IDS:
		var r: RegionData = RegionData.load_region(rid)
		assert_true(r.level_min >= prev_max - 1, "%s follows the previous region" % rid)
		prev_max = r.level_max


func test_waystone_lookup_and_unlock() -> void:
	assert_eq(RegionData.region_of_waystone(&"r3_ruins").id, &"r3_dunes")
	assert_null(RegionData.region_of_waystone(&"nowhere"))
	assert_false(WorldTravel.is_unlocked(&"r2_glade"))
	assert_true(WorldTravel.unlock(&"r2_glade"))
	assert_false(WorldTravel.unlock(&"r2_glade"), "second unlock is a no-op")
	var ids: Array[StringName] = []
	for row: Array in WorldTravel.unlocked_list():
		ids.append(row[1])
	assert_eq(ids, [&"r2_glade"] as Array[StringName])


func test_region_survives_save_round_trip() -> void:
	var before: StringName = GameState.current_region
	GameState.current_region = &"r2_verdant"
	var data: Dictionary = GameState.to_dict()
	GameState.current_region = &""
	var tuning: StatTuning = load("res://data/balancing/stat_tuning.tres") as StatTuning
	var prog: Progression = GameState.progression
	GameState.load_dict(data, tuning)
	assert_eq(GameState.current_region, &"r2_verdant")
	assert_eq(SaveManager.region_scene(&"r2_verdant"), "res://scenes/world/regions/verdant.tscn")
	assert_eq(SaveManager.region_scene(&"bogus"), SaveManager.GAME_SCENE)
	GameState.current_region = before
	GameState.progression = prog
