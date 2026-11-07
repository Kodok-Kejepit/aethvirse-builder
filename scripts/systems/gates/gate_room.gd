class_name GateRoom
extends Node3D
## One dungeon room: spawns its enemies when the player enters, locks the exit until cleared.

signal cleared

@export var enemies: Array[EnemyData] = []
@export var size: Vector2 = Vector2(24, 24)

var spawn_points: Array[Vector3] = []
var exit_door: StaticBody3D = null
var _alive: int = 0
var _started: bool = false
var _enemy_scene: PackedScene = preload("res://scenes/enemies/enemy.tscn")


func setup_trigger() -> void:
	var area: Area3D = Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(size.x - 4.0, 4.0, size.y - 4.0)
	shape.shape = box
	shape.position = Vector3(0, 2, 0)
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			# Deferred: spawning enemies (hit/hurtboxes) inside a physics callback is blocked.
			start.call_deferred())


func start() -> void:
	if _started:
		return
	_started = true
	if enemies.is_empty():
		_on_cleared()
		return
	_set_door_locked(true)
	for i: int in enemies.size():
		var enemy: Enemy = _enemy_scene.instantiate() as Enemy
		enemy.data = enemies[i]
		enemy.position = position + spawn_points[i % spawn_points.size()]
		get_parent().add_child(enemy)
		_alive += 1
		enemy.health.died.connect(_on_enemy_died)
		_on_spawned(enemy)


## Hook for subclasses / boss rooms.
func _on_spawned(_enemy: Enemy) -> void:
	pass


func _on_enemy_died() -> void:
	_alive -= 1
	if _alive <= 0:
		_on_cleared()


func _on_cleared() -> void:
	_set_door_locked(false)
	cleared.emit()


func _set_door_locked(locked: bool) -> void:
	if exit_door == null:
		return
	exit_door.visible = locked
	exit_door.collision_layer = 1 if locked else 0
