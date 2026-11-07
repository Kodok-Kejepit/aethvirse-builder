extends GutTest
## Far, calm enemies sleep (no AI / animation) and wake when the player returns or hits them.

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")

var _player: Node3D
var _saved: Node3D


func before_each() -> void:
	_saved = GameState.player
	_player = Node3D.new()
	add_child_autofree(_player)
	GameState.player = _player


func after_each() -> void:
	GameState.player = _saved


func _spawn(at: Vector3) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
	enemy.data = load("res://data/enemies/ash_hound.tres") as EnemyData
	add_child_autofree(enemy)
	enemy.global_position = at
	return enemy


func test_far_enemy_sleeps_and_wakes_when_near() -> void:
	var enemy: Enemy = _spawn(Vector3(Enemy.SLEEP_DISTANCE_M + 20.0, 0.0, 0.0))
	await wait_physics_frames(3)
	assert_true(enemy.asleep, "far and idle → asleep")
	assert_eq(enemy.state_machine.process_mode, Node.PROCESS_MODE_DISABLED)
	_player.global_position = enemy.global_position + Vector3(5, 0, 0)
	await wait_seconds(Enemy.SLEEP_CHECK_S + 0.2)
	assert_false(enemy.asleep, "player came back → awake")


func test_near_enemy_stays_awake() -> void:
	var enemy: Enemy = _spawn(Vector3(6.0, 0.0, 0.0))
	await wait_physics_frames(3)
	assert_false(enemy.asleep)
