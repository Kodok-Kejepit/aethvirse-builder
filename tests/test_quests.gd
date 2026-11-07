extends GutTest

var overpass: QuestData = load("res://data/quests/q_r1_overpass.tres") as QuestData


func test_quest_data_valid_and_translated() -> void:
	TranslationServer.set_locale("en")
	for file: String in DirAccess.get_files_at("res://data/quests/"):
		if not file.ends_with(".tres"):
			continue
		var q: QuestData = load("res://data/quests/" + file) as QuestData
		assert_false(q.objectives.is_empty(), file)
		assert_false(q.rewards.is_empty(), file)
		assert_ne(tr(q.title), String(q.title), "%s title translated" % file)
		for o: QuestObjective in q.objectives:
			assert_ne(tr(o.text), String(o.text), "%s objective translated" % file)
			assert_gt(o.count, 0)


func test_sequential_objectives() -> void:
	var log_state: QuestLog = QuestLog.new()
	assert_true(log_state.start(overpass))
	assert_false(log_state.start(overpass), "cannot start twice")
	assert_false(log_state.notify(overpass, QuestObjective.Type.KILL, &"ash_hound"), "wrong step ignored")
	assert_eq(log_state.progress(overpass.id), 0)
	log_state.notify(overpass, QuestObjective.Type.TALK, &"bread_seller")
	for i: int in 4:
		log_state.notify(overpass, QuestObjective.Type.KILL, &"ash_hound")
	assert_eq(log_state.progress(overpass.id), 4)
	log_state.notify(overpass, QuestObjective.Type.KILL, &"ash_hound")
	assert_eq(log_state.current_objective(overpass).type, QuestObjective.Type.CLEAR_GATE)
	assert_true(log_state.notify(overpass, QuestObjective.Type.CLEAR_GATE, &"gate_r1_e_overpass"))
	assert_true(overpass.id in log_state.completed)
	assert_false(log_state.active.has(overpass.id))


func test_quest_log_roundtrip() -> void:
	var log_state: QuestLog = QuestLog.new()
	log_state.start(overpass)
	log_state.notify(overpass, QuestObjective.Type.TALK, &"bread_seller")
	log_state.notify(overpass, QuestObjective.Type.KILL, &"ash_hound")
	var copy: QuestLog = QuestLog.new()
	var data: Dictionary = JSON.parse_string(JSON.stringify(log_state.to_dict()))
	copy.load_dict(data)
	assert_eq(copy.progress(overpass.id), 1)
	assert_eq(copy.current_objective(overpass).type, QuestObjective.Type.KILL)
	assert_eq(copy.tracked, overpass.id)


func test_quest_system_rewards() -> void:
	GameState.player = null
	GameState.new_game(&"vanguard", load("res://data/balancing/stat_tuning.tres") as StatTuning)
	var tracker: SecretTracker = SecretTracker.new()
	add_child_autofree(tracker)
	var system: QuestSystem = QuestSystem.new()
	add_child_autofree(system)
	assert_true(GameState.quests.active.has(&"q_r1_safe_road"), "auto-started")
	for i: int in 6:
		EventBus.enemy_killed.emit(&"gate_husk", Vector3.ZERO)
	EventBus.npc_talked.emit(&"camp_kid")
	assert_true(&"q_r1_safe_road" in GameState.quests.completed)
	assert_true(GameState.inventory.has(&"silver_band"))
