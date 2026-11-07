extends Node3D
## Character showcase (F6 playtest + screenshots): every pose of the heroine side by side,
## or one pose close up. User args: --sheet (default), --focus=<pose>, --weapon=<0-3>,
## --yaw=<deg> (model turn), --dragon / --dragon-ult (summon on start), --turntable,
## --hero=<id>, --lite (phone meshes).

const COLUMNS: int = 5
const SPACING: Vector2 = Vector2(1.9, 2.9)

var _models: Array[CharacterModel] = []
var _turntable: bool = false
var _camera: Camera3D
var _hero: HeroData
var _lite: bool = false


func _ready() -> void:
	var focus: StringName = &""
	var weapon: int = CharacterRig.Weapon.SWORD
	var yaw: float = 20.0
	var dragon: int = 0
	var hero_id: StringName = HeroData.DEFAULT_ID
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--focus="):
			focus = StringName(arg.trim_prefix("--focus="))
		elif arg.begins_with("--weapon="):
			weapon = arg.trim_prefix("--weapon=").to_int()
		elif arg.begins_with("--yaw="):
			yaw = arg.trim_prefix("--yaw=").to_float()
		elif arg == "--dragon":
			dragon = 1
		elif arg == "--dragon-ult":
			dragon = 2
		elif arg.begins_with("--hero="):
			hero_id = StringName(arg.trim_prefix("--hero="))
		elif arg == "--lite":
			_lite = true
		elif arg == "--turntable":
			_turntable = true
	_build_stage()
	if focus != &"":
		_hero = HeroData.load_hero(hero_id)
		_spawn(focus, Vector3.ZERO, weapon, yaw, false)
		_camera.position = Vector3(0.0, 1.35, 3.6) if dragon == 0 else Vector3(0.0, 2.2, 7.5)
		_camera.look_at(Vector3(0.0, 1.0 if dragon == 0 else 1.6, 0.0))
	else:
		_hero = HeroData.load_hero(hero_id)
		var names: Array[StringName] = CharacterPoses.NAMES
		var rows: int = ceili(float(names.size()) / float(COLUMNS))
		for i: int in names.size():
			var col: int = i % COLUMNS
			var row: int = floori(float(i) / float(COLUMNS))
			var pos: Vector3 = Vector3((float(col) - float(COLUMNS - 1) * 0.5) * SPACING.x, 0.0, -float(row) * 0.01)
			pos.y = float(rows - 1 - row) * SPACING.y
			_spawn(names[i], pos, weapon, yaw, true)
		_camera.position = Vector3(0.0, float(rows - 1) * SPACING.y * 0.5 + 1.0, 15.5)
		_camera.look_at(Vector3(0.0, float(rows - 1) * SPACING.y * 0.5 + 1.0, 0.0))
	if dragon > 0 and not _models.is_empty():
		_models[0].summon_dragon(dragon == 2)


func _process(delta: float) -> void:
	if _turntable:
		for m: CharacterModel in _models:
			m.rotation.y += delta * 0.8


func _spawn(pose: StringName, at: Vector3, weapon: int, yaw: float, caption: bool) -> void:
	var model: CharacterModel = CharacterModel.new()
	add_child(model)
	model.position = at
	model.rotation_degrees.y = 180.0 + yaw
	model.setup(null, weapon as CharacterRig.Weapon, _lite, _hero)
	model.forced_pose = pose
	_models.append(model)
	if caption:
		var label: Label3D = Label3D.new()
		label.text = String(pose).to_upper()
		label.font_size = 48
		label.outline_size = 10
		label.position = at + Vector3(0.0, -0.25, 0.4)
		add_child(label)


func _build_stage() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.18, 0.28)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.82, 0.95)
	e.ambient_light_energy = 0.35
	e.glow_enabled = true
	e.glow_intensity = 0.25
	e.glow_hdr_threshold = 1.2
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, 25.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 45.0
	add_child(_camera)
	_camera.current = true
