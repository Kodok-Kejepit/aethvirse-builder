class_name BossPhases
extends Node
## Multi-phase boss (§6): at 70% / 40% / 15% HP the boss gets faster, telegraphs shorter,
## and phase 2 calls adds. Drives the big HUD boss bar.

signal phase_changed(phase: int)

const THRESHOLDS: Array[float] = [0.7, 0.4, 0.15]
const SPEED_STEP: float = 1.15
const WINDUP_STEP: float = 0.85
const ADD_PHASE: int = 2

@export var add_data: EnemyData
@export var add_count: int = 2

var enemy: Enemy
var phase: int = 0
var _enemy_scene: PackedScene = preload("res://scenes/enemies/enemy.tscn")


func attach(boss: Enemy) -> void:
	enemy = boss
	enemy.health.changed.connect(_on_health_changed)
	enemy.health.died.connect(func() -> void: EventBus.boss_ended.emit(enemy, true))
	EventBus.boss_started.emit(enemy)


static func phase_for_ratio(ratio: float) -> int:
	var p: int = 0
	for t: float in THRESHOLDS:
		if ratio <= t:
			p += 1
	return p


func _on_health_changed(current: int, maximum: int) -> void:
	EventBus.boss_health_changed.emit(current, maximum)
	var target: int = phase_for_ratio(float(current) / float(maximum))
	while phase < target:
		phase += 1
		enemy.speed_multiplier *= SPEED_STEP
		enemy.windup_multiplier *= WINDUP_STEP
		phase_changed.emit(phase)
		Codex.notify(tr(&"CODEX_MSG_BOSS_PHASE") % (phase + 1), &"warning")
		if phase == ADD_PHASE and add_data != null:
			_spawn_adds()


func _spawn_adds() -> void:
	for i: int in add_count:
		var add: Enemy = _enemy_scene.instantiate() as Enemy
		add.data = add_data
		add.position = enemy.global_position + Vector3(cos(i * PI) * 4.0, 0.3, sin(i * PI) * 4.0)
		enemy.get_parent().add_child(add)
