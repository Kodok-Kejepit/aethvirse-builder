class_name ThirdPersonCamera
extends Node3D
## Orbit camera rig: yaw on this node, pitch on %Pivot, SpringArm3D for wall collision.
## Top-level and updated every rendered frame from the target's interpolated transform.

const MOUSE_RADIANS_PER_PIXEL: float = 0.0025
const TOUCH_RADIANS_PER_PIXEL: float = 0.006

@export var target: Node3D
@export var follow_height: float = 1.45
@export var follow_smoothing: float = 14.0
@export var stick_degrees_per_second: float = 200.0
@export_range(-89.0, 0.0) var pitch_min_degrees: float = -65.0
@export_range(0.0, 89.0) var pitch_max_degrees: float = 45.0
@export var start_pitch_degrees: float = -15.0
@export var base_fov: float = 70.0
@export var sprint_fov: float = 78.0
@export var fov_smoothing: float = 6.0
@export_group("Lock-on")
@export var lock_turn_speed: float = 8.0
@export var lock_pitch_degrees: float = -18.0
@export_group("Shake")
@export var shake_decay: float = 3.0
@export var shake_max_offset: float = 0.35

@onready var _pivot: Node3D = %Pivot
@onready var _arm: SpringArm3D = %SpringArm
@onready var _camera: Camera3D = %Camera

## Set by the player while sprinting.
var fov_boost: bool = false
## Set by LockOnTargeter. While set, the camera turns to frame player + target.
var lock_target: Node3D = null
var _shake: float = 0.0
var _shake_time: float = 0.0
var _yaw: float = 0.0
var _pitch: float = 0.0


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_pitch = deg_to_rad(start_pitch_degrees)
	_arm.spring_length = Settings.camera_distance
	_camera.fov = base_fov
	var body: CollisionObject3D = target as CollisionObject3D
	if body != null:
		_arm.add_excluded_object(body.get_rid())
	EventBus.camera_look_input.connect(_on_touch_look)
	EventBus.settings_changed.connect(func() -> void: _arm.spring_length = Settings.camera_distance)
	if target != null:
		_yaw = target.global_rotation.y
		global_position = _follow_point()
	_apply_rotation()


## Jumps behind the target facing `yaw` (after a teleport: no swoop across the map).
func snap_to(yaw: float) -> void:
	_yaw = yaw
	_apply_rotation()
	if target != null:
		global_position = _follow_point()
	reset_physics_interpolation()


func get_camera() -> Camera3D:
	return _camera


func get_yaw() -> float:
	return _yaw


func _unhandled_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if not _is_locked():
			_rotate_by(motion.relative * MOUSE_RADIANS_PER_PIXEL * Settings.mouse_sensitivity)
		return
	if Settings.is_mobile:
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	var stick: Vector2 = Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down")
	if _is_locked():
		_track_lock_target(delta)
	elif stick != Vector2.ZERO:
		_rotate_by(stick * deg_to_rad(stick_degrees_per_second) * delta)
	_update_shake(delta)
	if target != null:
		var weight: float = 1.0 - exp(-follow_smoothing * delta)
		global_position = global_position.lerp(_follow_point(), weight)
	var fov_target: float = sprint_fov if fov_boost else base_fov
	_camera.fov = lerpf(_camera.fov, fov_target, 1.0 - exp(-fov_smoothing * delta))


func _on_touch_look(relative: Vector2) -> void:
	if not _is_locked():
		_rotate_by(relative * TOUCH_RADIANS_PER_PIXEL * Settings.mouse_sensitivity)


## Adds trauma-style shake (0..1). Decays over time.
func shake(amount: float) -> void:
	_shake = clampf(_shake + amount, 0.0, 1.0)


func _is_locked() -> bool:
	return lock_target != null and is_instance_valid(lock_target)


func _track_lock_target(delta: float) -> void:
	var to_target: Vector3 = lock_target.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.01:
		return
	var weight: float = 1.0 - exp(-lock_turn_speed * delta)
	_yaw = lerp_angle(_yaw, MovementMath.yaw_for_direction(to_target), weight)
	_pitch = lerpf(_pitch, deg_to_rad(lock_pitch_degrees), weight)
	_apply_rotation()


func _update_shake(delta: float) -> void:
	if _shake <= 0.0:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
		return
	_shake_time += delta * 60.0
	var power: float = _shake * _shake * shake_max_offset
	_camera.h_offset = sin(_shake_time * 1.7) * power
	_camera.v_offset = cos(_shake_time * 2.3) * power
	_shake = maxf(_shake - shake_decay * delta, 0.0)


## delta.x turns left/right, delta.y looks up/down (radians).
func _rotate_by(delta: Vector2) -> void:
	var invert: float = -1.0 if Settings.invert_y else 1.0
	_yaw = wrapf(_yaw - delta.x, -PI, PI)
	_pitch = clampf(_pitch - delta.y * invert, deg_to_rad(pitch_min_degrees), deg_to_rad(pitch_max_degrees))
	_apply_rotation()


func _apply_rotation() -> void:
	rotation = Vector3(0.0, _yaw, 0.0)
	_pivot.rotation = Vector3(_pitch, 0.0, 0.0)


func _follow_point() -> Vector3:
	return target.get_global_transform_interpolated().origin + Vector3.UP * follow_height
