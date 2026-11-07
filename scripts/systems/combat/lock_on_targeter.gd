class_name LockOnTargeter
extends Node
## Lock-on: picks a target from the "lockable" group, switches left/right, drops lost targets.
## Lockable nodes are Node3D with `is_lockable() -> bool` and `get_lock_point() -> Vector3`.

const GROUP: StringName = &"lockable"
const ACTION_TOGGLE: StringName = &"lock_on"
const ACTION_NEXT: StringName = &"lock_next"
const ACTION_PREV: StringName = &"lock_prev"

@export var player: Player
@export var camera: ThirdPersonCamera
@export var marker: Node3D
@export var max_distance: float = 22.0
## Targets outside this cone (degrees from camera forward) are only used if nothing is inside.
@export var preferred_cone_degrees: float = 70.0
@export var angle_weight: float = 8.0
@export var marker_height: float = 0.7
@export var stick_flick_threshold: float = 0.75

var target: Node3D = null
var _stick_armed: bool = true


func _ready() -> void:
	if marker != null:
		marker.top_level = true
		marker.visible = false


## Lower is better. Pure scoring used by pick_best (unit tested).
static func score(origin: Vector3, forward: Vector3, candidate: Vector3, weight: float) -> float:
	var to: Vector3 = candidate - origin
	to.y = 0.0
	var flat_forward: Vector3 = Vector3(forward.x, 0.0, forward.z).normalized()
	var angle: float = flat_forward.angle_to(to.normalized()) if to.length_squared() > 0.0001 else 0.0
	return to.length() + angle * weight


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed(ACTION_TOGGLE):
		set_target(null if target != null else pick_best(null))
	elif target != null:
		if Input.is_action_just_pressed(ACTION_NEXT):
			switch_target(1)
		elif Input.is_action_just_pressed(ACTION_PREV):
			switch_target(-1)
		_handle_stick_switch()
	if target != null and not _is_valid(target):
		set_target(null)


func _process(_delta: float) -> void:
	if marker != null and target != null and is_instance_valid(target):
		marker.global_position = _lock_point(target) + Vector3.UP * marker_height


func set_target(new_target: Node3D) -> void:
	target = new_target
	camera.lock_target = new_target
	if marker != null:
		marker.visible = new_target != null
	EventBus.lock_target_changed.emit(new_target)


func pick_best(exclude: Node3D) -> Node3D:
	var origin: Vector3 = player.global_position
	var forward: Vector3 = -camera.global_basis.z
	var best: Node3D = null
	var best_score: float = INF
	var best_in_cone: bool = false
	for candidate: Node3D in _candidates():
		if candidate == exclude:
			continue
		var point: Vector3 = _lock_point(candidate)
		var to: Vector3 = point - origin
		var in_cone: bool = rad_to_deg(Vector3(forward.x, 0.0, forward.z).angle_to(Vector3(to.x, 0.0, to.z))) <= preferred_cone_degrees
		var s: float = score(origin, forward, point, angle_weight)
		if (in_cone and not best_in_cone) or (in_cone == best_in_cone and s < best_score):
			best = candidate
			best_score = s
			best_in_cone = in_cone
	return best


## direction +1 = next target to the right on screen, -1 = to the left.
func switch_target(direction: int) -> void:
	if target == null:
		return
	var origin: Vector3 = camera.global_position
	var right: Vector3 = camera.global_basis.x
	var current_side: float = right.dot(_lock_point(target) - origin)
	var best: Node3D = null
	var best_delta: float = INF
	for candidate: Node3D in _candidates():
		if candidate == target:
			continue
		var delta: float = (right.dot(_lock_point(candidate) - origin) - current_side) * direction
		if delta > 0.0 and delta < best_delta:
			best = candidate
			best_delta = delta
	if best != null:
		set_target(best)


func _handle_stick_switch() -> void:
	var x: float = Input.get_axis(&"camera_left", &"camera_right")
	if absf(x) < stick_flick_threshold * 0.5:
		_stick_armed = true
	elif _stick_armed and absf(x) >= stick_flick_threshold:
		_stick_armed = false
		switch_target(1 if x > 0.0 else -1)


func _candidates() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var node_3d: Node3D = node as Node3D
		if node_3d != null and _is_valid(node_3d):
			result.append(node_3d)
	return result


func _is_valid(candidate: Node3D) -> bool:
	if not is_instance_valid(candidate) or not candidate.is_inside_tree():
		return false
	if candidate.has_method(&"is_lockable"):
		var lockable: bool = candidate.call(&"is_lockable")
		if not lockable:
			return false
	return player.global_position.distance_to(candidate.global_position) <= max_distance


static func _lock_point(candidate: Node3D) -> Vector3:
	if candidate.has_method(&"get_lock_point"):
		var point: Vector3 = candidate.call(&"get_lock_point")
		return point
	return candidate.global_position
