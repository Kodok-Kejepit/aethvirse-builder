class_name GateRoom
extends Node3D
## One dungeon room: spawns its enemies when the player enters, locks the exit until cleared.

signal cleared

@export var enemies: Array[EnemyData] = []
@export var size: Vector2 = Vector2(24, 24)

var spawn_points: Array[Vector3] = []
var exit_door: StaticBody3D = null
## Doors of this room (dungeon rooms): sealed while enemies are alive.
var doors: Array[DungeonDoor] = []
var _alive: int = 0
var _started: bool = false
var _living: Array[Enemy] = []
var _check: float = 0.0
## Enemies that wander out of the room (knockback, chasing, falling) are put back.
const STRAY_MARGIN_M: float = 3.0
const STRAY_CHECK_S: float = 1.0
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
		_living.append(enemy)
		# Dying or disappearing any other way (falling out, despawn) both count, once.
		enemy.health.died.connect(_on_enemy_gone.bind(enemy), CONNECT_ONE_SHOT)
		enemy.tree_exiting.connect(_on_enemy_gone.bind(enemy), CONNECT_ONE_SHOT)
		_on_spawned(enemy)


## Hook for subclasses / boss rooms.
func _on_spawned(_enemy: Enemy) -> void:
	pass


func _on_enemy_gone(enemy: Enemy) -> void:
	if not _living.has(enemy):
		return
	_living.erase(enemy)
	_alive -= 1
	if _alive <= 0:
		_on_cleared()


func _physics_process(delta: float) -> void:
	if _living.is_empty():
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = STRAY_CHECK_S
	var half: Vector2 = size * 0.5 + Vector2.ONE * STRAY_MARGIN_M
	for enemy: Enemy in _living:
		if not is_instance_valid(enemy) or enemy.health.is_dead():
			continue
		var local: Vector3 = enemy.global_position - global_position
		if absf(local.x) > half.x or absf(local.z) > half.y or local.y < -3.0:
			enemy.global_position = global_position + spawn_points[randi() % spawn_points.size()]
			enemy.velocity = Vector3.ZERO


func _on_cleared() -> void:
	_set_door_locked(false)
	cleared.emit()


func _set_door_locked(locked: bool) -> void:
	for door: DungeonDoor in doors:
		door.set_locked(locked)
	if exit_door == null:
		return
	exit_door.visible = locked
	exit_door.collision_layer = 1 if locked else 0
