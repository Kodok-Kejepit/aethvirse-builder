extends GutTest
## Real scenes, simulated input, real physics: player vs dummy, enemy vs player.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const DUMMY_SCENE: PackedScene = preload("res://scenes/enemies/training_dummy.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")

var world: Node3D
var player: Player


func before_each() -> void:
	TimeFx.reset()
	world = Node3D.new()
	add_child_autofree(world)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	world.add_child(floor_body)
	player = PLAYER_SCENE.instantiate() as Player
	world.add_child(player)
	player.global_position = Vector3(0.0, 0.05, 0.0)
	await wait_physics_frames(10)


func after_each() -> void:
	for action: StringName in [&"attack_light", &"attack_heavy", &"dodge", &"lock_on"]:
		Input.action_release(action)
	TimeFx.reset()


func _press(action: StringName, frames: int = 2) -> void:
	Input.action_press(action)
	await wait_physics_frames(frames)
	Input.action_release(action)


func test_light_attack_damages_dummy_in_front() -> void:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate() as TrainingDummy
	world.add_child(dummy)
	var forward: Vector3 = player.get_facing()
	dummy.global_position = player.global_position + forward * 1.4
	await wait_physics_frames(5)
	var before: int = dummy.health.current
	await _press(&"attack_light")
	assert_eq(player.state_machine.get_state_name(), &"Attack")
	await wait_physics_frames(25)
	assert_lt(dummy.health.current, before, "dummy took damage")
	assert_gt(player.combat.tracker.count, 0, "combo counted")


func test_lock_on_picks_dummy() -> void:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate() as TrainingDummy
	world.add_child(dummy)
	dummy.global_position = player.global_position + player.get_facing() * 5.0
	await wait_physics_frames(3)
	await _press(&"lock_on")
	assert_eq(player.lock_on.target, dummy)
	await _press(&"lock_on")
	assert_null(player.lock_on.target, "toggle off")


func test_enemy_chases_and_hits_player() -> void:
	var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
	world.add_child(enemy)
	enemy.global_position = player.global_position + Vector3(0.0, 0.05, -6.0)
	enemy.home = enemy.global_position
	var before: int = player.health.current
	await wait_physics_frames(60 * 4)
	assert_lt(player.health.current, before, "enemy reached and hit the player")


func test_dodge_iframes_prevent_damage() -> void:
	var info: DamageInfo = DamageInfo.new()
	info.amount = 50
	await _press(&"dodge")
	assert_true(player.is_invulnerable)
	var before: int = player.health.current
	player.health.take_damage(info)
	assert_eq(player.health.current, before)
	await wait_physics_frames(2)
	assert_gt(Engine.time_scale, 0.0)
