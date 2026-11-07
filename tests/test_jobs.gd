extends GutTest
## Job Change I/II, hidden jobs, Summoner familiars, Necromancer shadow army.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const CLASSES: Array[StringName] = [&"vanguard", &"phantom", &"arcanist", &"ranger"]

func after_each() -> void:
	GameState.progression = null
	GameState.class_id = &"vanguard"
	GameState.job_id = &""
	GameState.shadows = ShadowArmy.new()
	GameState.world_flags.clear()


var no_flags: Callable = func(_f: StringName) -> bool: return false
var all_flags: Callable = func(_f: StringName) -> bool: return true


func test_every_job_is_valid() -> void:
	var jobs: Array[JobData] = JobRegistry.all()
	assert_gte(jobs.size(), 20, "many jobs")
	for job: JobData in jobs:
		assert_ne(job.display_name, "", String(job.id))
		assert_false(job.skills.is_empty(), "%s has skills" % job.id)
		if job.parent != &"":
			assert_not_null(JobRegistry.get_job(job.parent), "%s parent exists" % job.id)
		for skill: SkillData in job.skills:
			assert_gte(skill.unlock_level, job.required_level, "%s unlocks with the job" % skill.id)
			if skill.kind == SkillData.Kind.SUMMON:
				assert_not_null(skill.summon, "%s has summon data" % skill.id)
			elif skill.kind in [SkillData.Kind.MELEE, SkillData.Kind.DASH, SkillData.Kind.AOE, SkillData.Kind.PROJECTILE]:
				assert_not_null(skill.attack, "%s has attack data" % skill.id)


func test_no_job_change_before_30() -> void:
	for cls: StringName in CLASSES:
		assert_true(JobRegistry.options(cls, &"", 29, all_flags).is_empty())


func test_every_class_gets_two_branches_plus_summoner() -> void:
	for cls: StringName in CLASSES:
		var ids: Array[StringName] = []
		for job: JobData in JobRegistry.options(cls, &"", 30, no_flags):
			ids.append(job.id)
		assert_eq(ids.size(), 3, "%s: 2 class branches + Summoner (%s)" % [cls, ids])
		assert_true(&"summoner" in ids)


func test_tier_two_needs_parent_and_level_60() -> void:
	assert_true(JobRegistry.options(&"vanguard", &"berserker", 59, no_flags).is_empty())
	var ids: Array[StringName] = []
	for job: JobData in JobRegistry.options(&"vanguard", &"berserker", 60, no_flags):
		ids.append(job.id)
	assert_eq(ids, [&"warlord"] as Array[StringName])


func test_necromancer_is_hidden_until_the_mission() -> void:
	var has: Callable = func(f: StringName) -> bool: return f == &"necromancer_awakened"
	var before: Array[StringName] = []
	for job: JobData in JobRegistry.options(&"phantom", &"summoner", 40, no_flags):
		before.append(job.id)
	assert_false(&"necromancer" in before)
	var after: Array[StringName] = []
	for job: JobData in JobRegistry.options(&"phantom", &"summoner", 40, has):
		after.append(job.id)
	assert_true(&"necromancer" in after)
	assert_true(JobRegistry.has_shadow_army(&"necromancer"))
	assert_true(JobRegistry.has_shadow_army(&"shadow_sovereign"))
	assert_false(JobRegistry.has_shadow_army(&"summoner"))
	assert_false(JobRegistry.has_shadow_army(&""))


func test_shadow_army_roster() -> void:
	var army: ShadowArmy = ShadowArmy.new()
	assert_eq(ShadowArmy.slots_for_level(1), 3)
	assert_eq(ShadowArmy.slots_for_level(500), ShadowArmy.MAX_SLOTS)
	for i: int in 3:
		assert_true(army.add(&"ash_hound", "Ash Hound", 0, 5))
	assert_false(army.add(&"ash_hound", "Ash Hound", 0, 5), "full at 3 slots on Lv 5")
	army.release(0)
	assert_true(army.add(&"ash_hound_alpha", "Alpha", 2, 5))
	var top: int = army.sorted_by_power()[0]["tier"]
	assert_eq(top, 2, "strongest first")
	var copy: ShadowArmy = ShadowArmy.new()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(army.to_dict()))
	copy.load_dict(parsed)
	assert_eq(copy.soldiers.size(), 3)
	assert_gt(ShadowArmy.tier_power(2), ShadowArmy.tier_power(0))
	assert_gt(ShadowArmy.bind_chance(0), ShadowArmy.bind_chance(2))


func test_job_and_shadows_are_saved() -> void:
	var tuning: StatTuning = load("res://data/balancing/stat_tuning.tres") as StatTuning
	GameState.new_game(&"arcanist", tuning)
	GameState.job_id = &"necromancer"
	GameState.shadows.add(&"gate_husk", "Gate Husk", 0, 36)
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	GameState.new_game(&"vanguard", tuning)
	GameState.load_dict(data, tuning)
	assert_eq(GameState.job_id, &"necromancer")
	assert_eq(GameState.shadows.soldiers.size(), 1)
	GameState.progression = null
	GameState.job_id = &""


func test_summon_cap_grows_with_skill_level() -> void:
	var call_skill: SkillData = load("res://data/skills/jobs/call_familiar.tres") as SkillData
	assert_eq(call_skill.summon_cap(1), 1, "the Summoner starts with one familiar")
	assert_eq(call_skill.summon_cap(5), 2)
	assert_true(call_skill.is_instant())


func test_summoner_in_game() -> void:
	GameState.progression = null
	GameState.class_id = &"arcanist"
	GameState.job_id = &""
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	var player: Player = PLAYER_SCENE.instantiate() as Player
	world.add_child(player)
	await wait_physics_frames(5)
	assert_false(player.stats.change_job(&"summoner"), "Lv 1 cannot change job")
	while GameState.progression.level < 30:
		player.stats.add_xp(GameState.progression.xp_to_next() - GameState.progression.xp)
	assert_true(player.stats.change_job(&"summoner"))
	assert_eq(GameState.job_id, &"summoner")
	assert_true(GameState.has_flag(&"job_summoner"))
	var call_skill: SkillData = player.stats.find_skill(&"call_familiar")
	assert_not_null(call_skill)
	assert_eq(player.stats.mp_cost(call_skill), roundi(call_skill.mp_cost * 1.5), "Summoners are mana-hungry")
	assert_true(player.stats.assign_slot(&"call_familiar", 0))
	player.mana.set_max(1000, true)
	player.skills.reset_cooldowns()
	assert_eq(player.skills.try_cast_slot(0), SkillCaster.CastResult.OK)
	await wait_physics_frames(2)
	assert_eq(player.summons.active(&"familiar_wisp").size(), 1)
	player.skills.reset_cooldowns()
	player.skills.try_cast_slot(0)
	await wait_physics_frames(2)
	assert_eq(player.summons.active(&"familiar_wisp").size(), 1, "still one at skill Lv 1")
	var enemy: Enemy = (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.data = load("res://data/enemies/ash_hound.tres") as EnemyData
	enemy.position = player.global_position + Vector3(0, 0.2, -4)
	world.add_child(enemy)
	var hp: int = enemy.health.current
	await wait_seconds(3.0)
	assert_lt(enemy.health.current, hp, "the familiar fights")
	GameState.progression = null
	GameState.job_id = &""


func test_codex_shows_shadow_tab_only_for_shadow_line() -> void:
	var fake: Node3D = Node3D.new()
	add_child_autofree(fake)
	GameState.player = fake
	var codex: CodexPanel = CodexPanel.new()
	add_child_autofree(codex)
	GameState.job_id = &"summoner"
	codex._refresh_shadow_tab()
	assert_false(codex.has_tab(&"CODEX_TAB_SHADOWS"))
	GameState.job_id = &"necromancer"
	codex._refresh_shadow_tab()
	assert_true(codex.has_tab(&"CODEX_TAB_SHADOWS"))
	GameState.job_id = &""
	GameState.player = null


func test_necromancer_binds_and_calls_shadows() -> void:
	GameState.progression = null
	GameState.class_id = &"phantom"
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	var player: Player = PLAYER_SCENE.instantiate() as Player
	world.add_child(player)
	await wait_physics_frames(5)
	while GameState.progression.level < 36:
		player.stats.add_xp(GameState.progression.xp_to_next() - GameState.progression.xp)
	assert_true(player.stats.change_job(&"summoner"))
	assert_false(player.stats.change_job(&"necromancer"), "hidden until the sealed mission")
	GameState.set_flag(&"necromancer_awakened")
	assert_true(player.stats.change_job(&"necromancer"))
	assert_not_null(player.stats.find_skill(&"call_familiar"), "keeps the Summoner's skills")
	assert_not_null(player.stats.find_skill(&"rise_echo"))
	assert_eq(GameState.skill_slots[3], &"rise_echo", "new job actives land on the bar")
	assert_eq(GameState.skill_slots[2], &"answer_me")
	player.summons._rng.seed = 7
	var bound: int = 0
	for attempt: int in 12:
		EventBus.enemy_killed.emit(&"ash_hound", player.global_position + Vector3(1, 0, 0))
		player.summons.bind_nearest_corpse()
		bound = GameState.shadows.soldiers.size()
		if bound >= 2:
			break
	assert_gte(bound, 2, "binding succeeds most of the time")
	await wait_physics_frames(2)
	for m: Minion in player.summons.active(&"shadow_soldier"):
		m.queue_free()
	await wait_physics_frames(1)
	player.summons.call_shadows(5, 1)
	await wait_physics_frames(2)
	assert_eq(player.summons.active(&"shadow_soldier").size(), bound, "every bound shadow answers")
	EventBus.enemy_killed.emit(&"ash_hound", player.global_position + Vector3(30, 0, 0))
	var before: int = GameState.shadows.soldiers.size()
	player.summons.bind_nearest_corpse()
	assert_eq(GameState.shadows.soldiers.size(), before, "too far away to bind")
	GameState.progression = null
	GameState.job_id = &""
	GameState.shadows = ShadowArmy.new()
	GameState.world_flags.clear()


func test_summoner_mission_unlocks_necromancer() -> void:
	var db: SecretDatabase = SecretDatabase.new()
	var first: SecretData = db.get_secret(&"SM-JOB-01:1")
	var second: SecretData = db.get_secret(&"SM-JOB-01:2")
	assert_not_null(first)
	assert_not_null(second)
	var ctx: SecretContext = SecretContext.new()
	ctx.flags = {&"job_summoner": true}
	ctx.counters = {&"familiar_kills": 49}
	assert_false(ConditionData.all_true(first.conditions, ctx))
	ctx.counters[&"familiar_kills"] = 50
	assert_true(ConditionData.all_true(first.conditions, ctx))
	var gives_flag: bool = false
	for r: RewardData in second.rewards:
		if r.type == RewardData.Type.FLAG and r.key == &"necromancer_awakened":
			gives_flag = true
	assert_true(gives_flag)
	assert_eq(GateLayout.make_double(load("res://data/gates/gate_r1_e_overpass.tres") as GateData, 1).completes_secret,
		&"SM-JOB-01:2", "finished by clearing a Double Gate")
