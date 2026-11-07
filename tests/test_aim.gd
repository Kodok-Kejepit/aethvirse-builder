extends GutTest
## Attack aim: camera / movement modes and the soft aim assist.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")

var _player: Player
var _mode: int = 0


func before_each() -> void:
	_mode = Settings.aim_mode
	_player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(_player)
	await wait_physics_frames(2)


func after_each() -> void:
	Settings.aim_mode = _mode


func test_camera_mode_ignores_movement_input() -> void:
	Settings.aim_mode = 0
	_player.input_direction = Vector3.RIGHT
	_player.input_magnitude = 1.0
	var cam_fwd: Vector3 = -_player.camera_rig.get_camera().global_basis.z
	cam_fwd.y = 0.0
	assert_almost_eq(_player.aim_direction().dot(cam_fwd.normalized()), 1.0, 0.01)


func test_movement_mode_uses_input() -> void:
	Settings.aim_mode = 1
	_player.input_direction = Vector3.RIGHT
	_player.input_magnitude = 1.0
	assert_almost_eq(_player.aim_direction().dot(Vector3.RIGHT), 1.0, 0.01)


func test_assist_snaps_to_enemy_in_cone() -> void:
	Settings.aim_mode = 1
	var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
	enemy.data = load("res://data/enemies/ash_hound.tres") as EnemyData
	add_child_autofree(enemy)
	enemy.global_position = _player.global_position + Vector3(5.0, 0.0, 1.5)
	await wait_physics_frames(1)
	_player.input_direction = Vector3.RIGHT
	_player.input_magnitude = 1.0
	var expected: Vector3 = Vector3(5.0, 0.0, 1.5).normalized()
	assert_almost_eq(_player.aim_direction().dot(expected), 1.0, 0.01, "pulled toward the enemy")
	_player.input_direction = Vector3.LEFT
	assert_almost_eq(_player.aim_direction().dot(Vector3.LEFT), 1.0, 0.01, "outside the cone: no pull")
