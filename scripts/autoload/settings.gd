extends Node
## Graphics/audio/controls/language settings and platform + quality preset detection.
## Preset logic lives in QualityPresets; this node applies it at runtime and persists the
## player's choices to user://settings.cfg (separate from save slots).

const PATH: String = "user://settings.cfg"
const AUTO: int = -1
const AUDIO_BUSES: Array[StringName] = [&"Master", &"BGM", &"SFX", &"Voice", &"UI"]
const LANGUAGES: Array[String] = ["", "en", "id"]
const FPS_CAPS: Array[int] = [0, 30, 60, 120]
const TOUCH_SCALE_RANGE: Vector2 = Vector2(0.7, 1.4)
## Sun shadow distance by shadow quality 0..3 (metres).
const SHADOW_DISTANCE_M: Array[float] = [40.0, 55.0, 80.0, 110.0]
const ULTRA_LOD_THRESHOLD: float = 0.5

var is_mobile: bool = false
var preset: QualityPresets.Preset = QualityPresets.Preset.PC_MEDIUM
var profile: PlatformProfile = null
## Force the touch controls on desktop for testing: run with `-- --mobile-ui`.
var force_mobile_ui: bool = false

# Persisted choices.
## AUTO = detected default, otherwise a QualityPresets.Preset.
var preset_choice: int = AUTO
## 0 = the preset's own frame rate.
var fps_cap: int = 0
var volumes: Dictionary[StringName, float] = {}
var mouse_sensitivity: float = 1.0
var invert_y: bool = false
## Attack / skill aim: 0 = camera (or the mouse cursor when it is free), 1 = movement direction.
var aim_mode: int = 0
var camera_distance: float = 4.5
## "" = follow the device language.
var language: String = ""
var touch_button_scale: float = 1.0
## Per-button touch layout chosen by the player: button name -> Vector3(offset x, offset y,
## size multiplier). Empty = the default layout.
var touch_layout: Dictionary[String, Vector3] = {}
const TOUCH_BUTTON_SCALE_RANGE: Vector2 = Vector2(0.6, 1.8)
var touch_opacity: float = 1.0
var show_damage_numbers: bool = true
## Basic attacks also on mouse clicks (off = keyboard keys only, e.g. J / K on a laptop).
var mouse_attack: bool = true
## Keyboard / mouse bindings per rebindable action (see Keybinds).
var keybinds: Dictionary[StringName, PackedStringArray] = {}

var _default_binds: Dictionary[StringName, PackedStringArray] = {}

var _detected: QualityPresets.Preset = QualityPresets.Preset.PC_MEDIUM
## Heavy preset on a device that cannot keep up: tell the player once per session.
const SLOW_FPS: float = 25.0
const SLOW_WARN_S: float = 12.0
var _slow_s: float = 0.0
var _warned_slow: bool = false
static var _software: int = -1


func _ready() -> void:
	# First autoload that reads user://: bring settings and saves over from the old name.
	if not OS.has_feature("mobile"):
		UserDataMigration.run()
	is_mobile = OS.has_feature("mobile")
	force_mobile_ui = "--mobile-ui" in OS.get_cmdline_user_args()
	if wants_touch_controls():
		strip_mouse_buttons_from_actions()
	var memory_info: Dictionary = OS.get_memory_info()
	var ram: int = memory_info.get("physical", 0)
	_detected = QualityPresets.detect_default(is_mobile, ram)
	for bus: StringName in AUDIO_BUSES:
		volumes[bus] = 1.0
	for action: StringName in Keybinds.ACTIONS:
		_default_binds[action] = Keybinds.current(action)
	reset_keybinds(false)
	load_from(PATH)
	apply_all()


func _process(delta: float) -> void:
	if _warned_slow or preset < QualityPresets.Preset.PC_HIGH or software_renderer() or get_tree().paused:
		return
	_slow_s = _slow_s + delta if Engine.get_frames_per_second() < SLOW_FPS else 0.0
	if _slow_s > SLOW_WARN_S:
		_warned_slow = true
		Codex.notify(tr(&"SET_TOO_HEAVY") % get_preset_name(), &"warning")


func apply_preset(target: QualityPresets.Preset) -> void:
	preset = target
	_slow_s = 0.0
	profile = QualityPresets.load_profile(target)
	Engine.max_fps = fps_cap if fps_cap > 0 else profile.target_fps
	get_viewport().scaling_3d_scale = profile.render_scale
	_apply_render_quality()
	EventBus.quality_preset_changed.emit(preset)


func apply_all() -> void:
	apply_preset(_detected if preset_choice == AUTO else preset_choice as QualityPresets.Preset)
	for bus: StringName in volumes:
		var index: int = AudioServer.get_bus_index(bus)
		if index >= 0:
			AudioServer.set_bus_volume_db(index, linear_to_db(volumes[bus]))
	TranslationServer.set_locale(language if language != "" else OS.get_locale_language())
	apply_keybinds()
	EventBus.settings_changed.emit()


## Pushes `keybinds` (and the mouse-attack choice) into the InputMap.
func apply_keybinds() -> void:
	var touch: bool = wants_touch_controls()
	for action: StringName in keybinds:
		var mouse_ok: bool = not touch and (mouse_attack or action not in Keybinds.MOUSE_ATTACK_ACTIONS)
		Keybinds.apply(action, keybinds[action], mouse_ok)


func default_binds(action: StringName) -> PackedStringArray:
	return _default_binds.get(action, PackedStringArray())


func reset_keybinds(apply: bool = true) -> void:
	keybinds.clear()
	for action: StringName in _default_binds:
		keybinds[action] = _default_binds[action].duplicate()
	if apply:
		apply_keybinds()


func get_preset_name() -> String:
	return profile.display_name if profile != null else "?"


func detected_preset() -> QualityPresets.Preset:
	return _detected


func wants_touch_controls() -> bool:
	return is_mobile or force_mobile_ui


## On touch screens every touch is also reported as a left mouse click; with mouse buttons
## bound to attacks, touching the joystick would attack. Gameplay actions drop mouse buttons there.
func strip_mouse_buttons_from_actions() -> void:
	for action: StringName in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventMouseButton:
				InputMap.action_erase_event(action, event)


func save_to(path: String = PATH) -> Error:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("graphics", "preset", preset_choice)
	cfg.set_value("graphics", "fps_cap", fps_cap)
	for bus: StringName in volumes:
		cfg.set_value("audio", String(bus), volumes[bus])
	cfg.set_value("controls", "sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("controls", "aim_mode", aim_mode)
	cfg.set_value("controls", "camera_distance", camera_distance)
	cfg.set_value("controls", "touch_scale", touch_button_scale)
	cfg.set_value("controls", "touch_opacity", touch_opacity)
	cfg.set_value("controls", "touch_layout", touch_layout)
	cfg.set_value("game", "language", language)
	cfg.set_value("game", "damage_numbers", show_damage_numbers)
	cfg.set_value("controls", "mouse_attack", mouse_attack)
	for action: StringName in keybinds:
		if keybinds[action] != default_binds(action):
			cfg.set_value("keybinds", String(action), ",".join(keybinds[action]))
	return cfg.save(path)


## Missing or corrupt files keep the defaults; values are clamped to valid ranges.
func load_from(path: String = PATH) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(path) != OK:
		return
	var p: int = cfg.get_value("graphics", "preset", AUTO)
	preset_choice = p if p == AUTO or QualityPresets.PROFILE_PATHS.has(p) else AUTO
	var cap: int = cfg.get_value("graphics", "fps_cap", 0)
	fps_cap = cap if cap in FPS_CAPS else 0
	for bus: StringName in AUDIO_BUSES:
		var v: float = cfg.get_value("audio", String(bus), 1.0)
		volumes[bus] = clampf(v, 0.0, 1.0)
	var sens: float = cfg.get_value("controls", "sensitivity", 1.0)
	mouse_sensitivity = clampf(sens, 0.2, 3.0)
	invert_y = cfg.get_value("controls", "invert_y", false)
	var aim: int = cfg.get_value("controls", "aim_mode", 0)
	aim_mode = clampi(aim, 0, 1)
	var dist: float = cfg.get_value("controls", "camera_distance", 4.5)
	camera_distance = clampf(dist, 2.5, 8.0)
	var ts: float = cfg.get_value("controls", "touch_scale", 1.0)
	touch_button_scale = clampf(ts, TOUCH_SCALE_RANGE.x, TOUCH_SCALE_RANGE.y)
	var op: float = cfg.get_value("controls", "touch_opacity", 1.0)
	touch_opacity = clampf(op, 0.3, 1.0)
	touch_layout.clear()
	var layout: Variant = cfg.get_value("controls", "touch_layout", {})
	if layout is Dictionary:
		var raw: Dictionary = layout
		for key: Variant in raw:
			var v: Variant = raw[key]
			if key is String and v is Vector3:
				var spec: Vector3 = v
				spec.z = clampf(spec.z, TOUCH_BUTTON_SCALE_RANGE.x, TOUCH_BUTTON_SCALE_RANGE.y)
				touch_layout[key] = spec
	var lang: String = cfg.get_value("game", "language", "")
	language = lang if lang in LANGUAGES else ""
	show_damage_numbers = cfg.get_value("game", "damage_numbers", true)
	mouse_attack = cfg.get_value("controls", "mouse_attack", true)
	for action: StringName in Keybinds.ACTIONS:
		if not cfg.has_section_key("keybinds", String(action)):
			continue
		var saved: String = cfg.get_value("keybinds", String(action), "")
		var codes: PackedStringArray = []
		for code: String in saved.split(",", false):
			if Keybinds.decode(code) != null:
				codes.append(code)
		keybinds[action] = codes


## Anti-aliasing and shadow filtering by preset: High / Ultra (shadow quality 3) get MSAA
## 4x and soft 4K shadows; Medium MSAA 2x; Low and phones stay light (FPS first).
func _apply_render_quality() -> void:
	var q: int = mini(profile.shadow_quality, 1) if software_renderer() else profile.shadow_quality
	var vp: Viewport = get_viewport()
	vp.msaa_3d = Viewport.MSAA_4X if q >= 3 else (Viewport.MSAA_2X if q == 2 and not is_mobile else Viewport.MSAA_DISABLED)
	RenderingServer.directional_shadow_atlas_set_size(4096 if q >= 3 else 2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_HIGH if q >= 3 else (RenderingServer.SHADOW_QUALITY_SOFT_LOW if q == 2 else RenderingServer.SHADOW_QUALITY_HARD))


## Heavy PC effects from the profile (PC Ultra: volumetric fog, screen-space reflections,
## real-time global illumination; High+: ambient occlusion). Phones and software
## rendering get none of them. Call on every scene's Environment.
func apply_effects(env: Environment) -> void:
	if env == null or profile == null or is_mobile or software_renderer():
		return
	if profile.shadow_quality >= 3:
		env.ssao_enabled = true
	if profile.volumetric_fog:
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.012
		env.volumetric_fog_albedo = env.fog_light_color.lightened(0.4)
		env.volumetric_fog_anisotropy = 0.45
		env.volumetric_fog_length = 96.0
	if profile.ssr:
		env.ssr_enabled = true
		env.ssr_max_steps = 48
		env.ssr_fade_out = 2.0
	# Real-time GI (SDFGI + SSIL) only on a dedicated GPU: on a laptop's built-in GPU it
	# alone drops Ultra to a slideshow (owner's Intel UHD).
	var gi: bool = profile.global_illumination and not integrated_gpu()
	if gi:
		env.sdfgi_enabled = true
		env.sdfgi_use_occlusion = true
		env.ssil_enabled = true
	var vp: Viewport = get_viewport()
	vp.use_taa = gi
	# Ultra keeps more detail at a distance, but distance LODs stay on everywhere.
	vp.mesh_lod_threshold = ULTRA_LOD_THRESHOLD if profile.global_illumination else 1.0


## Sun / moon shadows by preset: the shadow pass redraws everything in range, so lower
## presets cover less distance with fewer cascades. Call on every scene's sun.
func apply_sun(sun: DirectionalLight3D) -> void:
	if sun == null or profile == null:
		return
	var q: int = mini(profile.shadow_quality, 1) if software_renderer() else profile.shadow_quality
	sun.shadow_enabled = q > 0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if q >= 3 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = SHADOW_DISTANCE_M[clampi(q, 0, SHADOW_DISTANCE_M.size() - 1)]


## Laptop / phone GPU sharing system memory (Intel UHD / Iris, AMD APU graphics).
static func integrated_gpu() -> bool:
	return RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU


## Screen-space ambient occlusion only on PC High / Ultra.
func wants_ssao() -> bool:
	return profile != null and profile.shadow_quality >= 3 and not is_mobile and not software_renderer()


## CPU rendering (llvmpipe: headless captures / VMs): heavy effects would crawl.
static func software_renderer() -> bool:
	if _software < 0:
		_software = 1 if RenderingServer.get_video_adapter_name().to_lower().contains("llvmpipe") else 0
	return _software == 1
