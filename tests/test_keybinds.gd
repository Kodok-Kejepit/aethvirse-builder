extends GutTest
## Rebindable keys: codes, conflicts, InputMap updates, mouse-attack option, persistence.

var _saved: Dictionary[StringName, PackedStringArray] = {}
var _mouse: bool = true


func before_each() -> void:
	_saved = Settings.keybinds.duplicate(true)
	_mouse = Settings.mouse_attack


func after_each() -> void:
	Settings.keybinds = _saved
	Settings.mouse_attack = _mouse
	Settings.apply_keybinds()


func test_codes_round_trip() -> void:
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_J
	assert_eq(Keybinds.encode(key), "k:%d" % KEY_J)
	assert_eq((Keybinds.decode("k:%d" % KEY_J) as InputEventKey).physical_keycode, KEY_J)
	assert_eq((Keybinds.decode("m:2") as InputEventMouseButton).button_index, MOUSE_BUTTON_RIGHT)
	assert_eq(Keybinds.label("m:1"), "Mouse L")


func test_defaults_split_sprint_and_dash_and_offer_keyboard_attacks() -> void:
	var sprint: PackedStringArray = Settings.default_binds(&"sprint")
	var dodge: PackedStringArray = Settings.default_binds(&"dodge")
	assert_false(sprint.is_empty())
	assert_false(dodge.is_empty())
	for code: String in sprint:
		assert_false(code in dodge, "sprint and dash never share a key")
	assert_true("k:%d" % KEY_J in Settings.default_binds(&"attack_light"), "J = basic attack without a mouse")


func test_assign_moves_a_key_away_from_its_old_action() -> void:
	var binds: Dictionary = {&"jump": PackedStringArray(["k:%d" % KEY_SPACE]), &"dodge": PackedStringArray(["k:%d" % KEY_CTRL])}
	Keybinds.assign(binds, &"dodge", 0, "k:%d" % KEY_SPACE)
	var dodge: PackedStringArray = binds[&"dodge"]
	var jump: PackedStringArray = binds[&"jump"]
	assert_eq(dodge, PackedStringArray(["k:%d" % KEY_SPACE]))
	assert_true(jump.is_empty(), "space left jump")
	Keybinds.assign(binds, &"dodge", 0, "")
	var cleared: PackedStringArray = binds[&"dodge"]
	assert_true(cleared.is_empty(), "cleared")


func test_rebinding_updates_the_input_map() -> void:
	Keybinds.assign(Settings.keybinds, &"jump", 0, "k:%d" % KEY_H)
	Settings.apply_keybinds()
	assert_true("k:%d" % KEY_H in Keybinds.current(&"jump"))
	var pad: bool = false
	for e: InputEvent in InputMap.action_get_events(&"jump"):
		pad = pad or e is InputEventJoypadButton
	assert_true(pad, "gamepad binding kept")


func test_mouse_attack_off_removes_clicks_only_from_attacks() -> void:
	Settings.mouse_attack = false
	Settings.apply_keybinds()
	for code: String in Keybinds.current(&"attack_light"):
		assert_false(code.begins_with("m:"))
	assert_true("k:%d" % KEY_J in Keybinds.current(&"attack_light"))
	Settings.mouse_attack = true
	Settings.apply_keybinds()
	assert_true("m:%d" % MOUSE_BUTTON_LEFT in Keybinds.current(&"attack_light"))


func test_settings_file_keeps_custom_keys() -> void:
	var path: String = "user://test_keybinds.cfg"
	Keybinds.assign(Settings.keybinds, &"dodge", 0, "k:%d" % KEY_L)
	Settings.mouse_attack = false
	Settings.save_to(path)
	Settings.reset_keybinds()
	Settings.mouse_attack = true
	Settings.load_from(path)
	assert_eq(Settings.keybinds[&"dodge"][0], "k:%d" % KEY_L)
	assert_false(Settings.mouse_attack)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
