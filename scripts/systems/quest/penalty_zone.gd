class_name PenaltyZone
extends Node3D
## Penalty Zone (§10): ignored daily quest → survive waves for a while. No exit until then.

const DURATION_S: float = 90.0
const WAVE_INTERVAL_S: float = 15.0
const ARENA_HALF: float = 18.0
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const EXIT_SCENE: PackedScene = preload("res://scenes/world/gates/exit_portal.tscn")

@export var enemy_data: Array[EnemyData] = []

@onready var player: Player = %Player
@onready var timer_label: Label = %TimerLabel

var remaining_s: float = DURATION_S
var _wave_timer: float = 0.0
var _wave: int = 0
var _done: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	AudioManager.set_area_music(&"gate")
	_rng.randomize()
	player.global_position = Vector3(0, 0.3, 0)
	Codex.anomaly(tr(&"CODEX_MSG_PENALTY_START"), 0.1)


func _process(delta: float) -> void:
	if _done:
		return
	remaining_s = maxf(remaining_s - delta, 0.0)
	timer_label.text = "%s  %d:%02d" % [tr(&"PENALTY_SURVIVE"), floori(remaining_s / 60.0), floori(remaining_s) % 60]
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = WAVE_INTERVAL_S
		_spawn_wave()
	if remaining_s <= 0.0:
		_finish()


func _spawn_wave() -> void:
	_wave += 1
	var level: int = GameState.progression.level if GameState.progression != null else 1
	for i: int in 1 + _wave:
		var data: EnemyData = enemy_data[_rng.randi() % enemy_data.size()].duplicate() as EnemyData
		data.level = level
		data.aggro_radius = 60.0
		data.drops_loot = false
		var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
		enemy.data = data
		var angle: float = _rng.randf() * TAU
		enemy.position = Vector3(cos(angle), 0.0, sin(angle)) * (ARENA_HALF - 2.0) + Vector3.UP * 0.3
		add_child(enemy)


func _finish() -> void:
	_done = true
	GameState.daily["penalty_pending"] = false
	timer_label.text = tr(&"PENALTY_DONE")
	Codex.notify(tr(&"CODEX_MSG_PENALTY_DONE"), &"info")
	for node: Node in get_children():
		var enemy: Enemy = node as Enemy
		if enemy != null and not enemy.health.is_dead():
			enemy.queue_free()
	var portal: Node3D = EXIT_SCENE.instantiate() as Node3D
	portal.position = player.global_position + player.get_facing() * 3.0
	add_child(portal)
