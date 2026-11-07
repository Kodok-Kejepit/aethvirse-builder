extends GutTest


func _objective(type: QuestObjective.Type, target: StringName, count: int, stage: int, optional: bool = false) -> QuestObjective:
	var o: QuestObjective = QuestObjective.new()
	o.type = type
	o.target = target
	o.count = count
	o.stage = stage
	o.optional = optional
	o.text = &"QO_KILL_HUSKS"
	return o


func _quest() -> QuestData:
	var q: QuestData = QuestData.new()
	q.id = &"graph_test"
	q.objectives = [
		_objective(QuestObjective.Type.KILL, &"gate_husk", 2, 0),
		_objective(QuestObjective.Type.TALK, &"camp_kid", 1, 0),
		_objective(QuestObjective.Type.COLLECT, &"herb", 1, 0, true),
		_objective(QuestObjective.Type.CLEAR_GATE, &"g", 1, 1),
	]
	return q


func test_parallel_stage_needs_all_required() -> void:
	var q: QuestData = _quest()
	var log_state: QuestLog = QuestLog.new()
	log_state.start(q)
	assert_eq(log_state.open_objectives(q).size(), 3, "3 objectives open in stage 0")
	log_state.notify(q, QuestObjective.Type.TALK, &"camp_kid")
	log_state.notify(q, QuestObjective.Type.KILL, &"gate_husk")
	assert_eq(log_state.stage_of(q.id), 0)
	log_state.notify(q, QuestObjective.Type.KILL, &"gate_husk")
	assert_eq(log_state.stage_of(q.id), 1, "optional herb not needed")
	assert_true(log_state.notify(q, QuestObjective.Type.CLEAR_GATE, &"g"))
	assert_true(q.id in log_state.completed)


func test_untargeted_objectives_accept_any_target() -> void:
	var q: QuestData = QuestData.new()
	q.id = &"any"
	q.objectives = [_objective(QuestObjective.Type.KILL, &"", 3, 0)]
	var log_state: QuestLog = QuestLog.new()
	log_state.start(q)
	log_state.notify(q, QuestObjective.Type.KILL, &"ash_hound")
	log_state.notify(q, QuestObjective.Type.KILL, &"gate_husk")
	assert_true(log_state.notify(q, QuestObjective.Type.KILL, &"drowned_rat"))


func test_fail_and_roundtrip() -> void:
	var q: QuestData = _quest()
	var log_state: QuestLog = QuestLog.new()
	log_state.start(q, 12.0)
	log_state.notify(q, QuestObjective.Type.KILL, &"gate_husk")
	var copy: QuestLog = QuestLog.new()
	var data: Dictionary = JSON.parse_string(JSON.stringify(log_state.to_dict()))
	copy.load_dict(data)
	assert_eq(copy.objective_progress(q.id, 0), 1)
	copy.fail(q.id)
	assert_true(q.id in copy.failed)


func test_daily_quest_is_deterministic_and_scaled() -> void:
	var a: QuestData = DailyQuests.build(5, 1)
	var b: QuestData = DailyQuests.build(5, 1)
	assert_eq(a.objectives.size(), 3)
	for i: int in 3:
		assert_eq(a.objectives[i].type, b.objectives[i].type)
	var high: QuestData = DailyQuests.build(5, 60)
	for i: int in 3:
		if high.objectives[i].type == a.objectives[i].type:
			assert_gte(high.objectives[i].count, a.objectives[i].count)
	assert_eq(a.kind, QuestData.Kind.DAILY)


func test_daily_quests_vary_beyond_training() -> void:
	var kinds: Dictionary = {}
	for day: int in range(1, 41):
		var q: QuestData = DailyQuests.build(day, 10)
		assert_eq(q.objectives.size(), 3)
		var gathering: QuestObjective = q.objectives[2]
		assert_true(gathering.type in [QuestObjective.Type.PICKUP, QuestObjective.Type.CRAFT,
			QuestObjective.Type.USE_ITEM], "third task is always gathering / crafting")
		kinds[str(gathering.type) + String(gathering.target)] = true
	assert_gte(kinds.size(), 3, "several different gathering tasks over 40 days")


func test_no_gate_task_before_level_3() -> void:
	for day: int in range(1, 60):
		var q: QuestData = DailyQuests.build(day, 1)
		assert_ne(q.objectives[1].type, QuestObjective.Type.CLEAR_GATE)


func test_craft_objective_counts_crafting() -> void:
	var q: QuestData = QuestData.new()
	q.id = &"t_craft"
	var o: QuestObjective = QuestObjective.new()
	o.type = QuestObjective.Type.CRAFT
	o.count = 2
	q.objectives.append(o)
	var ql: QuestLog = QuestLog.new()
	ql.start(q)
	ql.notify(q, QuestObjective.Type.CRAFT, &"potion_small")
	assert_eq(ql.objective_progress(q.id, 0), 1)
	assert_true(ql.notify(q, QuestObjective.Type.CRAFT, &"potion_large"), "any recipe counts")


func test_daily_caps_match_spec() -> void:
	var q: QuestData = DailyQuests.build(9, 100)
	for o: QuestObjective in q.objectives:
		match o.type:
			QuestObjective.Type.ATTACK:
				assert_eq(o.count, 100)
			QuestObjective.Type.DODGE:
				assert_eq(o.count, 50)
			QuestObjective.Type.DISTANCE:
				assert_eq(o.count, 5000)


func test_guild_rank_thresholds() -> void:
	assert_eq(GuildRank.rank_for(0), GuildRank.Rank.E)
	assert_eq(GuildRank.rank_for(100), GuildRank.Rank.D)
	assert_eq(GuildRank.rank_for(2999), GuildRank.Rank.A)
	assert_eq(GuildRank.rank_for(3000), GuildRank.Rank.S)


func test_npc_schedule() -> void:
	var npc: NpcData = load("res://data/dialogs/bread_seller.tres") as NpcData
	assert_true(npc.is_away(23))
	assert_true(npc.is_away(3))
	assert_false(npc.is_away(12))
	var marrow: NpcData = load("res://data/dialogs/marrow.tres") as NpcData
	assert_false(marrow.is_away(3), "Marrow is always under the bridge")
