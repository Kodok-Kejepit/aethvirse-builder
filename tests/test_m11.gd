extends GutTest
## M11: Red Gates, Hollow Throne keys, endings, tide, gravity zones, main story chain.

var _flags: Dictionary[StringName, bool] = {}


func before_each() -> void:
	_flags = GameState.world_flags.duplicate()


func after_each() -> void:
	GameState.world_flags = _flags
	GameState.shadows = ShadowArmy.new()


func test_red_gates_are_marked() -> void:
	var red: GateData = load("res://data/gates/gate_r6_s_red_rift.tres") as GateData
	assert_true(red.has_rule(&"red"))
	assert_false(GateLayout.has_double_gate(red, 5))
	var normal: GateData = load("res://data/gates/gate_r6_s_fracture.tres") as GateData
	assert_false(normal.has_rule(&"red"))


func test_hollow_gate_needs_keys_and_hour() -> void:
	for f: StringName in HollowGate.KEY_FLAGS:
		GameState.world_flags.erase(f)
	assert_eq(HollowGate.keys_held(), 0)
	for f: StringName in HollowGate.KEY_FLAGS:
		GameState.set_flag(f)
	assert_eq(HollowGate.keys_held(), HollowGate.KEY_FLAGS.size())
	var saved: float = GameState.clock.total_minutes
	GameState.clock.total_minutes = 3 * 60 + 33
	assert_true(HollowGate.is_open_now())
	GameState.clock.total_minutes = 12 * 60
	assert_false(HollowGate.is_open_now())
	GameState.clock.total_minutes = saved


func test_ending_choices() -> void:
	assert_eq(EndingPanel.ending_for(0), &"a")
	assert_eq(EndingPanel.ending_for(2), &"a", "no resonance yet")
	for i: int in EndingPanel.RESONANCE_NEEDED:
		GameState.shadows.soldiers.append({"uid": i, "tier": 0, "rank": 0})
	assert_eq(EndingPanel.ending_for(2), &"b")
	var found_before: Dictionary[StringName, bool] = GameState.secrets.found.duplicate()
	GameState.secrets.found.clear()
	assert_eq(EndingPanel.ending_for(3), &"a", "will too low")
	for i: int in EndingPanel.WILL_NEEDED:
		GameState.secrets.found[StringName("X%d" % i)] = true
	assert_eq(EndingPanel.ending_for(3), &"c")
	GameState.secrets.found = found_before


func test_tide_is_lowest_mid_afternoon() -> void:
	var low: float = TideWater.level_at(15.0, -1.0, 2.0)
	var high: float = TideWater.level_at(21.0, -1.0, 2.0)
	assert_almost_eq(low, -1.0, 0.01)
	assert_almost_eq(high, 2.0, 0.01)


func test_gravity_scale_slows_falls() -> void:
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child_autofree(player)
	await wait_physics_frames(1)
	player.velocity = Vector3.ZERO
	player.gravity_scale = 0.3
	player.apply_gravity(0.1)
	var light: float = player.velocity.y
	player.velocity = Vector3.ZERO
	player.gravity_scale = 1.0
	player.apply_gravity(0.1)
	assert_gt(light, player.velocity.y, "lighter gravity falls slower")


func test_main_story_chains_chapter_flags() -> void:
	var prev_flag: StringName = &"main_ch1_done"
	for ch: int in range(2, 8):
		var q: QuestData = load("res://data/quests/q_main_ch%d.tres" % ch) as QuestData
		assert_not_null(q)
		assert_eq(q.start_conditions[0].key, prev_flag, "chapter %d starts after %d" % [ch, ch - 1])
		var gives: StringName = &""
		for r: RewardData in q.rewards:
			if r.type == RewardData.Type.FLAG:
				gives = r.key
		assert_eq(gives, StringName("main_ch%d_done" % ch))
		prev_flag = gives


func test_secret_bosses_set_their_flags() -> void:
	assert_eq((load("res://data/enemies/echo_king.tres") as EnemyData).death_flag, &"echo_king_answered")
	assert_eq((load("res://data/enemies/the_unwritten.tres") as EnemyData).death_flag, &"unwritten_defeated")
