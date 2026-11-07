extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var player: Player


func before_each() -> void:
	TimeFx.reset()
	GameState.progression = null
	GameState.class_id = &"vanguard"
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	world.add_child(floor_body)
	player = PLAYER_SCENE.instantiate() as Player
	world.add_child(player)
	player.global_position = Vector3(0.0, 0.05, 0.0)
	await wait_physics_frames(10)


func after_each() -> void:
	for action: StringName in [&"attack_light", &"jump", &"move_forward"]:
		Input.action_release(action)
	TimeFx.reset()


func test_touch_mode_removes_mouse_from_gameplay_actions() -> void:
	var saved: Array[InputEvent] = InputMap.action_get_events(&"attack_light")
	Settings.strip_mouse_buttons_from_actions()
	for event: InputEvent in InputMap.action_get_events(&"attack_light"):
		assert_false(event is InputEventMouseButton, "a touch (fake left click) must not attack")
	assert_gt(InputMap.action_get_events(&"attack_light").size(), 0, "keyboard/gamepad bindings stay")
	InputMap.action_erase_events(&"attack_light")
	for event: InputEvent in saved:
		InputMap.action_add_event(&"attack_light", event)


func test_can_walk_while_attacking() -> void:
	Input.action_press(&"move_forward")
	await wait_physics_frames(20)
	var start: Vector3 = player.global_position
	Input.action_press(&"attack_light")
	await wait_physics_frames(2)
	Input.action_release(&"attack_light")
	assert_eq(player.state_machine.get_state_name(), &"Attack")
	await wait_physics_frames(8)
	assert_gt(player.global_position.distance_to(start), 0.6, "kept moving during the attack")


func test_attack_in_the_air() -> void:
	Input.action_press(&"jump")
	await wait_physics_frames(4)
	Input.action_release(&"jump")
	assert_eq(player.state_machine.get_state_name(), &"Air")
	Input.action_press(&"attack_light")
	await wait_physics_frames(2)
	Input.action_release(&"attack_light")
	assert_eq(player.state_machine.get_state_name(), &"Attack")


func test_falling_out_of_the_world_returns_to_safe_ground() -> void:
	await wait_physics_frames(40)
	var safe: Vector3 = player.last_safe_position
	var hp: int = player.health.current
	player.global_position = Vector3(0, -50, 0)
	await wait_physics_frames(2)
	assert_lt(player.global_position.distance_to(safe), 2.0)
	assert_lt(player.health.current, hp, "small HP cost")
	assert_gt(player.health.current, 0, "never lethal")
