extends GutTest
## Enemies target minions that are clearly closer; minions take damage and die.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")

var _player: Player
var _enemy: Enemy


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(_player)
	_player.global_position = Vector3(0, 0, 0)
	_enemy = ENEMY_SCENE.instantiate() as Enemy
	_enemy.data = load("res://data/enemies/ash_hound.tres") as EnemyData
	add_child_autofree(_enemy)
	_enemy.global_position = Vector3(0, 0, -10)
	await wait_physics_frames(2)


func _minion(at: Vector3) -> Minion:
	var data: SummonData = load("res://data/summons/familiar_wisp.tres") as SummonData
	var m: Minion = Minion.create(data, _player, 1.0, "")
	m.add_to_group(Minion.GROUP)
	add_child_autofree(m)
	m.global_position = at
	return m


func test_player_is_default_target() -> void:
	assert_eq(_enemy.get_target(), _player)


func test_closer_minion_draws_aggro() -> void:
	var m: Minion = _minion(Vector3(0, 0, -8))
	assert_eq(_enemy.get_target(), m)
	var far: Minion = _minion(Vector3(0, 0, -1))
	assert_eq(_enemy.get_target(), m, "only the nearest counts")
	assert_ne(_enemy.get_target(), far)


func test_minion_has_hp_and_dies() -> void:
	var m: Minion = _minion(Vector3(0, 0, -8))
	assert_true(m.is_alive())
	assert_gt(m.health.max_health, 1)
	var info: DamageInfo = DamageInfo.new()
	info.amount = m.health.max_health + 5
	m.hurtbox.receive(info)
	assert_false(m.is_alive())
	await wait_process_frames(2)
	assert_false(is_instance_valid(m), "dead minions vanish")
	assert_eq(_enemy.get_target(), _player)
