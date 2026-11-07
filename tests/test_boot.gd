extends GutTest
## Regression: the opening must react to a tap anywhere (phone got stuck when GUI ate touches).

const BOOT: PackedScene = preload("res://scenes/main/boot.tscn")


func test_root_does_not_swallow_touches() -> void:
	var boot: Control = BOOT.instantiate() as Control
	assert_eq(boot.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for child: Node in boot.get_children():
		var control: Control = child as Control
		if control != null:
			assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE, String(child.name))
	boot.free()


func test_continue_event_types() -> void:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	assert_true(touch.is_pressed())
	var boot: Control = BOOT.instantiate() as Control
	assert_true(boot.has_method(&"_input"), "uses _input, not _unhandled_input")
	boot.free()
