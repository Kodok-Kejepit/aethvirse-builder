extends GutTest
## M8: every class plays: starter weapon, combo graph, projectiles, stealth, passives.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const DUMMY_SCENE: PackedScene = preload("res://scenes/enemies/training_dummy.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")

var world: Node3D
var player: Player


func _spawn(class_id: StringName) -> void:
	TimeFx.reset()
	GameState.progression = null
	GameState.class_id = class_id
	world = Node3D.new()
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
	await wait_physics_frames(8)


func after_each() -> void:
	for action: StringName in [&"attack_light", &"attack_heavy"]:
		Input.action_release(action)
	GameState.class_id = &"vanguard"
	TimeFx.reset()


func _press(action: StringName) -> void:
	Input.action_press(action)
	await wait_physics_frames(2)
	Input.action_release(action)


func test_each_class_loads_with_its_weapon_and_combo() -> void:
	var weapons: Dictionary[StringName, StringName] = {&"vanguard": &"issued_greatsword", &"phantom": &"issued_daggers",
		&"arcanist": &"issued_staff", &"ranger": &"issued_bow"}
	for class_id: StringName in weapons:
		await _spawn(class_id)
		assert_eq(player.stats.class_data.id, class_id)
		assert_eq(GameState.inventory.get_equipped_item(ItemData.Slot.WEAPON).id, weapons[class_id])
		assert_eq(player.combat.combo, player.stats.class_data.combo)
		world.queue_free()
		await wait_physics_frames(2)


func test_arcanist_uses_magic_attack() -> void:
	await _spawn(&"arcanist")
	assert_almost_eq(player.combat.stats.attack, player.stats.derived.magic_attack, 0.01)


func test_ranger_arrow_hits_dummy_at_range() -> void:
	await _spawn(&"ranger")
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate() as TrainingDummy
	world.add_child(dummy)
	dummy.global_position = player.global_position + player.get_facing() * 10.0
	await wait_physics_frames(3)
	var before: int = dummy.health.current
	await _press(&"attack_light")
	await wait_physics_frames(40)
	assert_lt(dummy.health.current, before, "arrow flew 10 m and hit")


func test_phantom_stealth_drops_aggro_and_breaks_with_crit() -> void:
	await _spawn(&"phantom")
	var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
	world.add_child(enemy)
	enemy.global_position = player.global_position + Vector3(0, 0.05, -4)
	await wait_physics_frames(3)
	assert_not_null(enemy.get_target())
	DebugConsole.run("level 3")
	assert_eq(player.skills.try_cast_slot(GameState.skill_slots.find(&"smoke_veil")), SkillCaster.CastResult.OK)
	assert_null(enemy.get_target(), "stealthed")
	await _press(&"attack_light")
	assert_false(player.stats.has_buff(&"stealth"), "attacking breaks stealth")
	assert_true(player.combat.is_counter_ready(), "next hit is a guaranteed crit")


func test_passives_raise_stats_when_learned() -> void:
	await _spawn(&"vanguard")
	var def_before: float = player.stats.derived.defense
	DebugConsole.run("level 2")
	await wait_physics_frames(1)
	var iron: int = GameState.skill_levels.get(&"iron_body", 0)
	assert_eq(iron, 1, "unlocked at Lv2")
	assert_false(&"iron_body" in GameState.skill_slots, "passives are never slotted")
	assert_gt(player.stats.derived.defense, def_before)
