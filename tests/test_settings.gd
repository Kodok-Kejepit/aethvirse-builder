extends GutTest
## Settings persistence (user://settings.cfg) and clamping of bad values.

const TEST_PATH: String = "user://test_settings.cfg"

var _saved: Dictionary = {}


func before_each() -> void:
	_saved = {"sens": Settings.mouse_sensitivity, "inv": Settings.invert_y, "lang": Settings.language,
		"fps": Settings.fps_cap, "preset": Settings.preset_choice, "touch": Settings.touch_button_scale,
		"dmg": Settings.show_damage_numbers, "vol": Settings.volumes.duplicate()}


func after_each() -> void:
	Settings.mouse_sensitivity = _saved["sens"]
	Settings.invert_y = _saved["inv"]
	Settings.language = _saved["lang"]
	Settings.fps_cap = _saved["fps"]
	Settings.preset_choice = _saved["preset"]
	Settings.touch_button_scale = _saved["touch"]
	Settings.show_damage_numbers = _saved["dmg"]
	var vol: Dictionary = _saved["vol"]
	Settings.volumes.assign(vol)
	Settings.apply_all()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func test_roundtrip() -> void:
	Settings.mouse_sensitivity = 1.7
	Settings.invert_y = true
	Settings.language = "id"
	Settings.fps_cap = 30
	Settings.preset_choice = QualityPresets.Preset.PC_HIGH
	Settings.volumes[&"BGM"] = 0.25
	Settings.show_damage_numbers = false
	assert_eq(Settings.save_to(TEST_PATH), OK)
	Settings.mouse_sensitivity = 1.0
	Settings.invert_y = false
	Settings.language = ""
	Settings.fps_cap = 0
	Settings.preset_choice = Settings.AUTO
	Settings.volumes[&"BGM"] = 1.0
	Settings.show_damage_numbers = true
	Settings.load_from(TEST_PATH)
	assert_almost_eq(Settings.mouse_sensitivity, 1.7, 0.001)
	assert_true(Settings.invert_y)
	assert_eq(Settings.language, "id")
	assert_eq(Settings.fps_cap, 30)
	assert_eq(Settings.preset_choice, QualityPresets.Preset.PC_HIGH)
	assert_almost_eq(Settings.volumes[&"BGM"], 0.25, 0.001)
	assert_false(Settings.show_damage_numbers)


func test_bad_values_are_clamped() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("graphics", "preset", 99)
	cfg.set_value("graphics", "fps_cap", 7)
	cfg.set_value("audio", "Master", 5.0)
	cfg.set_value("controls", "sensitivity", 100.0)
	cfg.set_value("controls", "touch_scale", 0.0)
	cfg.set_value("game", "language", "xx")
	cfg.save(TEST_PATH)
	Settings.load_from(TEST_PATH)
	assert_eq(Settings.preset_choice, Settings.AUTO)
	assert_eq(Settings.fps_cap, 0)
	assert_almost_eq(Settings.volumes[&"Master"], 1.0, 0.001)
	assert_almost_eq(Settings.mouse_sensitivity, 3.0, 0.001)
	assert_almost_eq(Settings.touch_button_scale, Settings.TOUCH_SCALE_RANGE.x, 0.001)
	assert_eq(Settings.language, "")


func test_missing_file_keeps_defaults() -> void:
	Settings.mouse_sensitivity = 1.3
	Settings.load_from("user://does_not_exist.cfg")
	assert_almost_eq(Settings.mouse_sensitivity, 1.3, 0.001)


func test_fps_cap_overrides_preset() -> void:
	Settings.fps_cap = 30
	Settings.apply_all()
	assert_eq(Engine.max_fps, 30)


func test_panel_builds_and_saves_on_close() -> void:
	var panel: SettingsPanel = SettingsPanel.new()
	add_child_autofree(panel)
	panel.open()
	assert_true(panel.is_open(), "settings open without a player (main menu)")
	assert_gt(panel._list.get_child_count(), 8)
	panel.close()
	assert_false(get_tree().paused)
