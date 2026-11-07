extends GutTest
## M10: shadow ranks and Job Change trials.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")


func after_each() -> void:
	GameState.class_id = &"vanguard"
	GameState.job_id = &""
	GameState.shadows = ShadowArmy.new()


func test_rank_thresholds() -> void:
	assert_eq(ShadowArmy.rank_for_xp(0), 0)
	assert_eq(ShadowArmy.rank_for_xp(ShadowArmy.RANK_XP[1]), 1)
	assert_eq(ShadowArmy.rank_for_xp(99999), ShadowArmy.RANK_MARSHAL)
	for i: int in range(1, ShadowArmy.RANK_POWER.size()):
		assert_gt(ShadowArmy.RANK_POWER[i], ShadowArmy.RANK_POWER[i - 1])


func test_add_xp_ranks_up_once() -> void:
	var army: ShadowArmy = ShadowArmy.new()
	army.add(&"ash_hound", "Ash Hound", 0, 40)
	var uid: int = army.last_uid()
	assert_eq(army.add_xp(uid, ShadowArmy.RANK_XP[1] - 1), -1)
	assert_eq(army.add_xp(uid, 1), 1, "reached Knight")
	assert_eq(army.add_xp(uid, 1), -1, "no second announcement")
	assert_eq(army.add_xp(999, 50), -1, "unknown uid")


func test_ranked_soldier_sorts_first() -> void:
	var army: ShadowArmy = ShadowArmy.new()
	army.add(&"a", "A", 0, 40)
	army.add(&"b", "B", 0, 40)
	army.add_xp(army.last_uid(), ShadowArmy.RANK_XP[3])
	var top: Dictionary = army.sorted_by_power()[0]
	var top_name: String = top["name"]
	assert_eq(top_name, "B")


func test_old_saves_get_uids_and_ranks() -> void:
	var army: ShadowArmy = ShadowArmy.new()
	army.load_dict({"soldiers": [{"enemy_id": "x", "name": "X", "tier": 1, "level": 30}, {"enemy_id": "y", "name": "Y", "tier": 0, "level": 31, "xp": 70}]})
	assert_eq(army.soldiers.size(), 2)
	var u0: int = army.soldiers[0]["uid"]
	var u1: int = army.soldiers[1]["uid"]
	var r1: int = army.soldiers[1]["rank"]
	assert_ne(u0, u1)
	assert_eq(r1, 2)
	army.add(&"z", "Z", 0, 40)
	var uids: Array = []
	for s: Dictionary in army.soldiers:
		assert_false(uids.has(s["uid"]), "uids stay unique after load")
		uids.append(s["uid"])


func test_trials_cover_normal_jobs_only() -> void:
	for job: JobData in JobRegistry.all():
		if job.hidden:
			assert_false(JobTrial.needs_trial(job), "%s skips the trial" % job.id)
		else:
			assert_true(JobTrial.needs_trial(job), "%s has a trial" % job.id)
			var gate: GateData = JobTrial.gate_for(job)
			assert_not_null(gate)
			assert_true(gate.has_rule(&"trial"))
			assert_false(GateLayout.has_double_gate(gate, 3), "no Double Gate in trials")


func test_completing_trial_grants_job() -> void:
	GameState.class_id = &"vanguard"
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	await wait_physics_frames(1)
	while GameState.progression.level < 30:
		player.stats.add_xp(GameState.progression.xp_to_next() - GameState.progression.xp)
	assert_true(JobTrial.complete(&"berserker"))
	assert_eq(GameState.job_id, &"berserker")
	assert_false(JobTrial.complete(&"archmage"), "not offered to a Vanguard at 30")
