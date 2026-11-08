extends GutTest
## Touch buttons the player arranged: saved and loaded with Settings, applied on screen.

const TEST_PATH: String = "user://test_touch_layout.cfg"
const CONTROLS: String = "res://scenes/ui/mobile_controls/mobile_controls.tscn"


func after_each() -> void:
	Settings.touch_layout.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func test_layout_survives_save_and_load() -> void:
	Settings.touch_layout = {"AttackButton": Vector3(-40, 25, 1.3)}
	assert_eq(Settings.save_to(TEST_PATH), OK)
	Settings.touch_layout.clear()
	Settings.load_from(TEST_PATH)
	assert_true(Settings.touch_layout.has("AttackButton"))
	assert_almost_eq(Settings.touch_layout["AttackButton"], Vector3(-40, 25, 1.3), Vector3.ONE * 0.001)


func test_wild_sizes_are_clamped_on_load() -> void:
	Settings.touch_layout = {"JumpButton": Vector3(0, 0, 9.0)}
	Settings.save_to(TEST_PATH)
	Settings.load_from(TEST_PATH)
	assert_eq(Settings.touch_layout["JumpButton"].z, Settings.TOUCH_BUTTON_SCALE_RANGE.y)


func test_arranged_button_moves_and_resizes() -> void:
	var controls: CanvasLayer = (load(CONTROLS) as PackedScene).instantiate() as CanvasLayer
	add_child_autofree(controls)
	await wait_process_frames(2)
	var attack: Control = controls.get_node("%AttackButton") as Control
	var home: Vector2 = attack.position
	Settings.touch_layout = {"AttackButton": Vector3(-60, -30, 1.5)}
	controls.call(&"apply_layout")
	assert_almost_eq(attack.position, home + Vector2(-60, -30), Vector2.ONE * 0.01)
	assert_almost_eq(attack.scale.x, Settings.touch_button_scale * 1.5, 0.001)
	Settings.touch_layout.clear()
	controls.call(&"apply_layout")
	assert_almost_eq(attack.position, home, Vector2.ONE * 0.01, "reset puts it back")
