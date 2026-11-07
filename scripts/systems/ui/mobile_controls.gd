extends CanvasLayer
## Routes multitouch: buttons first, left half = floating joystick, right half = camera look.

## Fraction of the screen width (from the left) that starts the joystick.
const JOYSTICK_ZONE: float = 0.45

@onready var _joystick: FloatingJoystick = %Joystick
@onready var _buttons: Array[TouchActionButton] = [%AttackButton, %HeavyButton, %JumpButton, %DodgeButton, %LockButton,
	%Skill1Button, %Skill2Button, %Skill3Button, %Skill4Button, %UltimateButton, %StatusButton, %InventoryButton, %SettingsButton, %PauseButton, %InteractButton]

var _joystick_index: int = -1
var _look_index: int = -1


func _ready() -> void:
	visible = Settings.wants_touch_controls()
	set_process_input(visible)
	EventBus.settings_changed.connect(apply_layout)
	apply_layout.call_deferred()


## Button size and opacity from Settings (Pengaturan → Kontrol sentuh).
func apply_layout() -> void:
	for button: TouchActionButton in _buttons:
		button.pivot_offset = button.size * 0.5
		button.scale = Vector2.ONE * Settings.touch_button_scale
		button.modulate.a = Settings.touch_opacity
	_joystick.modulate.a = Settings.touch_opacity


func _input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_on_touch_down(touch.index, touch.position)
		else:
			_on_touch_up(touch.index)
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag == null:
		return
	if drag.index == _joystick_index:
		_joystick.move_to(drag.position)
	elif drag.index == _look_index:
		EventBus.camera_look_input.emit(drag.relative)


func _on_touch_down(index: int, point: Vector2) -> void:
	for button: TouchActionButton in _buttons:
		if button.try_press(index, point):
			return
	var width: float = get_viewport().get_visible_rect().size.x
	if point.x < width * JOYSTICK_ZONE and _joystick_index == -1:
		_joystick_index = index
		_joystick.begin(point)
	elif _look_index == -1:
		_look_index = index


func _on_touch_up(index: int) -> void:
	for button: TouchActionButton in _buttons:
		button.release(index)
	if index == _joystick_index:
		_joystick_index = -1
		_joystick.end()
	if index == _look_index:
		_look_index = -1
