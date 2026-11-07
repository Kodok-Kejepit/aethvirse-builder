extends GutTest
## Integration: real Player scene on a floor, simulated input, real physics frames.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SETTLE_FRAMES: int = 20

var player: Player


func before_each() -> void:
	var world: Node3D = Node3D.new()
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
	await wait_physics_frames(SETTLE_FRAMES)


func after_each() -> void:
	for action: StringName in [&"move_forward", &"jump", &"dodge", &"sprint"]:
		Input.action_release(action)


func test_settles_idle_on_floor() -> void:
	assert_true(player.is_on_floor())
	assert_eq(player.state_machine.get_state_name(), &"Idle")


func test_forward_input_moves_along_camera_forward() -> void:
	var start: Vector3 = player.global_position
	Input.action_press(&"move_forward")
	await wait_physics_frames(30)
	var forward: Vector3 = -player.camera_rig.global_basis.z
	forward.y = 0.0
	var moved: Vector3 = player.global_position - start
	assert_eq(player.state_machine.get_state_name(), &"Move")
	assert_gt(moved.dot(forward.normalized()), 1.0, "moved forward over 0.5 s")


func test_jump_leaves_floor_and_lands() -> void:
	Input.action_press(&"jump")
	await wait_physics_frames(3)
	assert_eq(player.state_machine.get_state_name(), &"Air")
	assert_gt(player.velocity.y, 0.0)
	Input.action_release(&"jump")
	await wait_physics_frames(90)
	assert_true(player.is_on_floor())


func test_dodge_spends_stamina_and_grants_iframes() -> void:
	var before: float = player.stamina.current
	Input.action_press(&"dodge")
	await wait_physics_frames(2)
	assert_eq(player.state_machine.get_state_name(), &"Dodge")
	assert_true(player.is_invulnerable)
	assert_lt(player.stamina.current, before)
	Input.action_release(&"dodge")
	await wait_physics_frames(40)
	assert_false(player.is_invulnerable)
	assert_ne(player.state_machine.get_state_name(), &"Dodge")


func test_sprint_is_unlimited() -> void:
	Input.action_press(&"move_forward")
	await wait_physics_frames(5)
	Input.action_press(&"sprint")
	await wait_physics_frames(60)
	player.stamina.current = 0.0
	await wait_physics_frames(60)
	assert_true(player.is_sprinting, "still sprinting with empty stamina")
	Input.action_release(&"sprint")
	Input.action_release(&"move_forward")


func test_air_dash_once_per_jump() -> void:
	Input.action_press(&"jump")
	await wait_physics_frames(6)
	Input.action_release(&"jump")
	Input.action_press(&"dodge")
	await wait_physics_frames(2)
	assert_eq(player.state_machine.get_state_name(), &"Dodge", "dash in the air")
	assert_true(player.air_dash_used)
	Input.action_release(&"dodge")
	await wait_physics_frames(30)
	Input.action_press(&"dodge")
	await wait_physics_frames(2)
	Input.action_release(&"dodge")
	assert_ne(player.state_machine.get_state_name(), &"Dodge", "no second air dash")
	await wait_physics_frames(120)
	assert_true(player.is_on_floor())
	assert_false(player.air_dash_used, "reset on landing")


func test_sprint_and_dash_are_separate_keys() -> void:
	var before: float = player.stamina.current
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await wait_physics_frames(20)
	assert_true(player.is_sprinting)
	assert_ne(player.state_machine.get_state_name(), &"Dodge", "sprint never dashes")
	assert_eq(player.stamina.current, before, "sprint is free")
	Input.action_release(&"sprint")
	Input.action_press(&"dodge")
	await wait_physics_frames(2)
	assert_eq(player.state_machine.get_state_name(), &"Dodge")
	await wait_physics_frames(40)
	assert_false(player.is_sprinting, "holding dash does not sprint")
	Input.action_release(&"dodge")
	Input.action_release(&"move_forward")


func test_dash_cancels_into_attack() -> void:
	Input.action_press(&"dodge")
	await wait_physics_frames(2)
	Input.action_release(&"dodge")
	assert_eq(player.state_machine.get_state_name(), &"Dodge")
	var guard: int = 0
	while not player.dodge_cancel_open and guard < 60:
		await wait_physics_frames(1)
		guard += 1
	Input.action_press(&"attack_light")
	await wait_physics_frames(2)
	Input.action_release(&"attack_light")
	assert_eq(player.state_machine.get_state_name(), &"Attack", "dash attack")
