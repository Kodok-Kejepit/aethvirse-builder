extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const WALL_SCENE: PackedScene = preload("res://scenes/world/props/breakable_wall.tscn")

var world: Node3D
var player: Player


func before_each() -> void:
	TimeFx.reset()
	GameState.progression = null
	GameState.world_flags.clear()
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
	await wait_physics_frames(10)


func after_each() -> void:
	for action: StringName in [&"interact", &"attack_light", &"attack_heavy"]:
		Input.action_release(action)
	TimeFx.reset()


func _press(action: StringName) -> void:
	Input.action_press(action)
	await wait_physics_frames(2)
	Input.action_release(action)


func test_glow_strength() -> void:
	assert_eq(SecretGlow.glow_strength(5.0, 1.0, 8.0, 6.0, 0.5), 0.0, "SEN too low")
	assert_almost_eq(SecretGlow.glow_strength(8.0, 3.0, 8.0, 6.0, 0.5), 0.5, 0.001)
	assert_gt(SecretGlow.glow_strength(20.0, 8.0, 8.0, 6.0, 0.5), 0.0, "high SEN sees further")


func test_interactable_prompt_and_use() -> void:
	var thing: Interactable = Interactable.new()
	thing.prompt_key = &"PROMPT_READ"
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.5
	shape.shape = sphere
	thing.add_child(shape)
	world.add_child(thing)
	thing.global_position = player.global_position + player.get_facing() * 1.2 + Vector3.UP
	watch_signals(thing)
	await wait_physics_frames(4)
	await _press(&"interact")
	assert_signal_emitted(thing, "interacted")


func test_wall_breaks_only_on_heavy() -> void:
	var wall: Breakable = WALL_SCENE.instantiate() as Breakable
	wall.save_flag = &"test_wall_broken"
	world.add_child(wall)
	wall.global_position = player.global_position + player.get_facing() * 1.6
	wall.look_at(player.global_position, Vector3.UP)
	await wait_physics_frames(4)
	await _press(&"attack_light")
	await wait_physics_frames(30)
	assert_false(GameState.has_flag(&"test_wall_broken"), "light attack does nothing")
	watch_signals(wall)
	await _press(&"attack_heavy")
	await wait_physics_frames(45)
	assert_signal_emitted(wall, "broken")
	assert_true(GameState.has_flag(&"test_wall_broken"), "remembered for saves")
