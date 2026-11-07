class_name FloatingJoystick
extends Control
## Floating joystick: appears where the touch starts and feeds the move_* input actions,
## so gameplay code reads touch exactly like a gamepad stick.

const ACTION_LEFT: StringName = &"move_left"
const ACTION_RIGHT: StringName = &"move_right"
const ACTION_UP: StringName = &"move_forward"
const ACTION_DOWN: StringName = &"move_back"

@export var radius: float = 130.0
@export var knob_radius: float = 55.0
@export var base_color: Color = Color(0.35, 0.7, 1.0, 0.18)
@export var ring_color: Color = Color(0.45, 0.8, 1.0, 0.55)
@export var knob_color: Color = Color(0.6, 0.88, 1.0, 0.75)
## Where the idle joystick hint is drawn, relative to this control's size.
@export var idle_anchor: Vector2 = Vector2(0.18, 0.72)

var active: bool = false
var _origin: Vector2 = Vector2.ZERO
var _value: Vector2 = Vector2.ZERO


## Normalized stick value for a touch point (length clamped to 1).
static func compute_value(origin: Vector2, point: Vector2, stick_radius: float) -> Vector2:
	if stick_radius <= 0.0:
		return Vector2.ZERO
	return ((point - origin) / stick_radius).limit_length(1.0)


func begin(point: Vector2) -> void:
	active = true
	_origin = point
	_set_value(Vector2.ZERO)


func move_to(point: Vector2) -> void:
	if active:
		_set_value(compute_value(_origin, point, radius))


func end() -> void:
	active = false
	_set_value(Vector2.ZERO)


func _set_value(value: Vector2) -> void:
	_value = value
	_press_axis(ACTION_LEFT, ACTION_RIGHT, value.x)
	_press_axis(ACTION_UP, ACTION_DOWN, value.y)
	queue_redraw()


func _press_axis(negative: StringName, positive: StringName, amount: float) -> void:
	if amount < 0.0:
		Input.action_press(negative, -amount)
		Input.action_release(positive)
	elif amount > 0.0:
		Input.action_press(positive, amount)
		Input.action_release(negative)
	else:
		Input.action_release(negative)
		Input.action_release(positive)


func _draw() -> void:
	var center: Vector2 = _origin if active else size * idle_anchor
	var alpha: float = 1.0 if active else 0.5
	draw_circle(center, radius, Color(base_color, base_color.a * alpha))
	draw_arc(center, radius, 0.0, TAU, 64, Color(ring_color, ring_color.a * alpha), 3.0, true)
	draw_circle(center + _value * radius, knob_radius, Color(knob_color, knob_color.a * alpha))
