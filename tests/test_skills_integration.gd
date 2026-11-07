extends GutTest
## Real player: casting skills, MP, cooldowns, buffs, XP → level up, stat allocation.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var player: Player


func before_each() -> void:
	TimeFx.reset()
	GameState.progression = null
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(100.0, 1.0, 100.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	world.add_child(floor_body)
	player = PLAYER_SCENE.instantiate() as Player
	world.add_child(player)
	player.global_position = Vector3(0.0, 0.05, 0.0)
	await wait_physics_frames(10)


func after_each() -> void:
	for action: StringName in [&"skill_1", &"skill_2", &"skill_4"]:
		Input.action_release(action)
	TimeFx.reset()


func _press(action: StringName) -> void:
	Input.action_press(action)
	await wait_physics_frames(2)
	Input.action_release(action)


func test_new_game_starts_level1_with_starting_skills() -> void:
	assert_eq(GameState.progression.level, 1)
	var rending: int = GameState.skill_levels.get(&"rending_slash", 0)
	assert_eq(rending, 1)
	assert_eq(GameState.skill_slots[0], &"rending_slash")
	var earth_before: int = GameState.skill_levels.get(&"earthsplitter", 0)
	assert_eq(earth_before, 0, "unlocks at Lv3")
	assert_eq(player.health.max_health, 330, "Vanguard Lv1 HP from sheet")


func test_cast_skill_uses_mp_and_cooldown() -> void:
	var mp_before: float = player.mana.current
	await _press(&"skill_1")
	assert_eq(player.state_machine.get_state_name(), &"Attack")
	assert_not_null(player.combat.current_skill)
	assert_lt(player.mana.current, mp_before)
	var skill: SkillData = player.skills.get_slot_skill(0)
	assert_gt(player.skills.get_cooldown_remaining(skill), 0.0)
	await wait_physics_frames(60)
	assert_eq(player.skills.try_cast_slot(0), SkillCaster.CastResult.COOLDOWN)


func test_not_enough_mp() -> void:
	player.mana.current = 0.0
	assert_eq(player.skills.try_cast_slot(0), SkillCaster.CastResult.NO_MP)


func test_xp_levels_up_and_unlocks_skills() -> void:
	var hp_before: int = player.health.max_health
	EventBus.xp_gained.emit(Progression.xp_needed(1, player.stats.tuning) + Progression.xp_needed(2, player.stats.tuning))
	await wait_physics_frames(1)
	assert_eq(GameState.progression.level, 3)
	assert_gt(player.health.max_health, hp_before)
	var earth_after: int = GameState.skill_levels.get(&"earthsplitter", 0)
	assert_eq(earth_after, 1, "unlocked at Lv3")
	assert_true(&"earthsplitter" in GameState.skill_slots)


func test_buff_skill_raises_attack() -> void:
	DebugConsole.run("level 5")
	await wait_physics_frames(1)
	var slot: int = GameState.skill_slots.find(&"war_cry")
	assert_ne(slot, -1, "war cry slotted at Lv5")
	var atk_before: float = player.combat.stats.attack
	assert_eq(player.skills.try_cast_slot(slot), SkillCaster.CastResult.OK)
	assert_gt(player.combat.stats.attack, atk_before)


func test_allocating_str_raises_attack() -> void:
	EventBus.xp_gained.emit(100)
	await wait_physics_frames(1)
	var atk_before: float = player.combat.stats.attack
	assert_true(player.stats.allocate(StatBlock.Stat.STR))
	assert_gt(player.combat.stats.attack, atk_before)


func test_skill_combo_triggers() -> void:
	watch_signals(EventBus)
	assert_eq(player.skills.try_cast_slot(GameState.skill_slots.find(&"iron_charge")), SkillCaster.CastResult.OK)
	await wait_physics_frames(50)
	assert_eq(player.skills.try_cast_slot(GameState.skill_slots.find(&"rending_slash")), SkillCaster.CastResult.OK)
	assert_signal_emitted(EventBus, "skill_combo_triggered")
