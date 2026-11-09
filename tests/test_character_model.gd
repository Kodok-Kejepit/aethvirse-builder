extends GutTest
## Procedural heroine: rig build, pose library, pose selection, spirit dragon triggers.

var _player: Player


func before_each() -> void:
	GameState.class_id = &"vanguard"
	GameState.job_id = &""
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child_autofree(_player)
	await wait_physics_frames(2)


func test_rig_builds_all_joints_and_chains() -> void:
	var rig: CharacterRig = CharacterRig.new()
	add_child_autofree(rig)
	rig.build(CharacterRig.Weapon.STAFF, false)
	assert_eq(rig.joints.size(), CharacterRig.JOINTS.size())
	assert_gt(rig.chains.size(), 6, "hair + sashes")
	assert_not_null(rig.weapon_tip)


func test_static_parts_are_merged() -> void:
	var rig: CharacterRig = CharacterRig.new()
	add_child_autofree(rig)
	rig.build(CharacterRig.Weapon.SWORD, false)
	var chest_meshes: int = 0
	for child: Node in rig.joints[&"chest"].get_children():
		if child is MeshInstance3D:
			chest_meshes += 1
	assert_eq(chest_meshes, 1, "chest parts baked into one mesh")


func test_every_named_pose_has_all_keys() -> void:
	for id: StringName in CharacterPoses.NAMES:
		var pose: Dictionary[StringName, Vector3] = CharacterPoses.named(id, 0.4, 0)
		for key: StringName in CharacterPoses.KEYS:
			assert_true(pose.has(key), "%s has %s" % [id, key])


func test_weapon_follows_class() -> void:
	assert_eq(CharacterRig.weapon_for_class(&"arcanist"), CharacterRig.Weapon.STAFF)
	assert_eq(CharacterRig.weapon_for_class(&"ranger"), CharacterRig.Weapon.BOW)
	assert_eq(CharacterRig.weapon_for_class(&"vanguard"), CharacterRig.Weapon.SWORD)


func test_player_uses_heroine_and_hides_graybox() -> void:
	assert_not_null(_player.model)
	assert_false((_player.visual.get_node("Body") as Node3D).visible)
	_player.set_graybox_visible(true)
	assert_false(_player.model.visible)


func test_attack_pose_without_dragon() -> void:
	await wait_process_frames(2)
	assert_eq(_player.model.pose_name, &"fall", "no ground in this test: airborne")
	_player.combat.pending_attack = _player.combat.combo.resolve_next(null, false)
	_player.state_machine.transition_to(PlayerState.ATTACK)
	await wait_process_frames(2)
	assert_eq(_player.model.pose_name, &"attack")
	assert_null(_player.model.dragon, "basic attacks never summon the dragon")


func test_skill_summons_dragon_that_vanishes() -> void:
	var skill: SkillData = _player.skills.get_slot_skill(0)
	assert_not_null(skill)
	EventBus.skill_used.emit(skill.id)
	assert_not_null(_player.model.dragon)
	var dragon: SpiritDragon = _player.model.dragon
	assert_false(dragon.is_finished())
	dragon.elapsed = dragon.duration_s
	await wait_process_frames(2)
	assert_false(is_instance_valid(dragon), "dragon frees itself")


func test_dragon_path_coils_then_strikes_forward() -> void:
	var d: SpiritDragon = SpiritDragon.new()
	add_child_autofree(d)
	d.setup(false)
	var start: Vector3 = d.head_position(0.0)
	var top: Vector3 = d.head_position(SpiritDragon.COIL_S - 0.01)
	var strike: Vector3 = d.head_position(SpiritDragon.COIL_S + SpiritDragon.REAR_S + SpiritDragon.STRIKE_S - 0.01)
	assert_gt(top.y, start.y + 2.0, "rises while coiling")
	assert_lt(strike.z, -5.0, "strikes forward (-Z)")


func test_heroes_load_and_differ() -> void:
	var maiden: HeroData = HeroData.load_hero(&"dragon_maiden")
	var blade: HeroData = HeroData.load_hero(&"starblade")
	assert_true(maiden.has_dragon)
	assert_false(blade.has_dragon)
	assert_eq(blade.hair, HeroData.Hair.SHORT)
	assert_eq(HeroData.load_hero(&"nope").id, HeroData.DEFAULT_ID, "unknown id falls back")


func test_short_hair_hero_never_summons_dragon() -> void:
	var model: CharacterModel = CharacterModel.new()
	add_child_autofree(model)
	model.setup(_player, CharacterRig.Weapon.SWORD, true, HeroData.load_hero(&"starblade"))
	var skill: SkillData = _player.skills.get_slot_skill(0)
	EventBus.skill_used.emit(skill.id)
	assert_null(model.dragon)


func test_hero_id_survives_save_round_trip() -> void:
	var cls: StringName = GameState.class_id
	GameState.class_id = &"ranger"
	GameState.hero_id = &"starblade"
	var data: Dictionary = GameState.to_dict()
	GameState.hero_id = &"dragon_maiden"
	GameState.load_dict(data, _player.stats.tuning)
	assert_eq(GameState.hero_id, &"starblade")
	GameState.hero_id = HeroData.DEFAULT_ID
	GameState.class_id = cls
