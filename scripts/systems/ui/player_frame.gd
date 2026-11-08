class_name PlayerFrame
extends Control
## Top-left player frame: a round portrait of the chosen hero (rendered from her own
## model), name, level, and the HP / MP bars beside it. The frame grows richer with the
## level: plain steel (1) -> silver trim (20) -> gold (40) -> hero motif (60: a dragon
## arc for dragon heroes, shadow blades otherwise) -> glowing, sparkling (80).

const TIER_LEVELS: Array[int] = [1, 20, 40, 60, 80]
const PORTRAIT_R: float = 46.0
const PORTRAIT_PX: int = 192
const STEEL: Color = Color(0.55, 0.6, 0.68)
const SILVER: Color = Color(0.86, 0.9, 0.97)
const GOLD: Color = Color(0.95, 0.78, 0.38)

var tier: int = 0
var _hero: HeroData = null
var _portrait: Texture2D = null
var _vp: SubViewport = null
var _frames: int = 0
var _time: float = 0.0
var _name: Label


static func tier_for(level: int) -> int:
	var t: int = 0
	for i: int in TIER_LEVELS.size():
		if level >= TIER_LEVELS[i]:
			t = i
	return t


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(14, 12)
	size = Vector2(560, 120)
	_hero = HeroData.load_hero(GameState.hero_id)
	_name = Label.new()
	_name.text = tr(_hero.display_name)
	_name.add_theme_font_size_override(&"font_size", 22)
	_name.add_theme_constant_override(&"outline_size", 6)
	_name.position = Vector2(PORTRAIT_R * 2.0 + 30.0, 4.0)
	add_child(_name)
	_place_bars.call_deferred()
	EventBus.level_up.connect(func(_l: int) -> void: _refresh_tier())
	EventBus.player_stats_changed.connect(_refresh_tier)
	_refresh_tier()
	if DisplayServer.get_name() != "headless":
		_render_portrait()


## Moves the existing HP / MP bars and the level label next to the portrait.
func _place_bars() -> void:
	var hud: Node = get_parent()
	var x: float = position.x + PORTRAIT_R * 2.0 + 30.0
	var hp: Control = hud.get_node_or_null(^"HealthBar") as Control
	var mp: Control = hud.get_node_or_null(^"ManaBar") as Control
	var lv: Control = hud.get_node_or_null(^"Combat/LevelLabel") as Control
	if hp != null:
		hp.position = Vector2(x, position.y + 36.0)
		hp.size = Vector2(380, 18)
	if mp != null:
		mp.position = Vector2(x, position.y + 60.0)
		mp.size = Vector2(300, 11)
	if lv != null:
		lv.position = Vector2(x + 310.0, position.y + 50.0)


func _refresh_tier() -> void:
	var level: int = GameState.progression.level if GameState.progression != null else 1
	tier = tier_for(level)
	queue_redraw()


## Head-and-shoulders shot of the hero in a small offscreen viewport (once).
func _render_portrait() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(PORTRAIT_PX, PORTRAIT_PX)
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var model: CharacterModel = CharacterModel.new()
	_vp.add_child(model)
	model.setup(null, CharacterRig.weapon_for_class(GameState.class_id), true, _hero, 0)
	model.rotation.y = PI + 0.35
	var head: Node3D = model.rig.get_joint(&"head")
	var cam: Camera3D = Camera3D.new()
	cam.fov = 26.0
	_vp.add_child(cam)
	var target: Vector3 = head.global_position + Vector3(0.0, 0.06, 0.0) if head != null else Vector3(0.0, 1.55, 0.0)
	cam.transform = Transform3D(Basis.IDENTITY, target + Vector3(0.0, 0.0, 0.62)).looking_at(target)
	cam.current = true
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25, 25, 0)
	sun.light_energy = 0.9
	_vp.add_child(sun)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_energy = 0.6
	_vp.add_child(env)


func _process(delta: float) -> void:
	_time += delta
	if _vp != null:
		_frames += 1
		if _frames == 6:
			# Freeze the shot: keep the image, drop the viewport.
			_portrait = ImageTexture.create_from_image(_vp.get_texture().get_image())
			_vp.queue_free()
			_vp = null
			queue_redraw()
	if tier >= 4:
		queue_redraw()


func _draw() -> void:
	var c: Vector2 = Vector2(PORTRAIT_R + 8.0, PORTRAIT_R + 8.0)
	var trim: Color = [STEEL, SILVER, GOLD, GOLD, GOLD][tier]
	var accent: Color = Color(0.72, 0.62, 1.0) if _hero != null and _hero.has_dragon else Color(0.62, 0.42, 0.9)
	# Plate behind the bars.
	var plate: PackedVector2Array = [Vector2(c.x + 20, 26), Vector2(c.x + 470, 26), Vector2(c.x + 450, 80), Vector2(c.x + 20, 80)]
	draw_colored_polygon(plate, Color(0.03, 0.05, 0.1, 0.55))
	draw_polyline(plate + PackedVector2Array([plate[0]]), Color(trim, 0.6), 1.5, true)
	if tier >= 2:
		draw_line(Vector2(c.x + 24, 84), Vector2(c.x + 300, 84), Color(GOLD, 0.7), 2.0, true)
	# Hero motif behind the portrait (60+).
	if tier >= 3:
		if _hero != null and _hero.has_dragon:
			for i: int in 3:
				var r: float = PORTRAIT_R + 10.0 + float(i) * 5.0
				draw_arc(c, r, -PI * 0.95 + _time * 0.15 * float(tier - 2), PI * 0.35, 48, Color(accent, 0.85 - float(i) * 0.2), 6.0 - float(i) * 1.5, true)
			draw_circle(c + Vector2(PORTRAIT_R + 14.0, -PORTRAIT_R * 0.55), 5.0, Color(1.0, 0.95, 0.8))
		else:
			for i: int in 4:
				var a: float = -PI * 0.8 + float(i) * 0.45
				var dir: Vector2 = Vector2(cos(a), sin(a))
				draw_line(c + dir * (PORTRAIT_R + 4.0), c + dir * (PORTRAIT_R + 26.0), Color(accent, 0.8), 3.0, true)
	# Portrait disc.
	draw_circle(c, PORTRAIT_R + 4.0, Color(0.02, 0.03, 0.06, 0.9))
	if _portrait != null:
		draw_set_transform(c - Vector2(PORTRAIT_R, PORTRAIT_R), 0.0, Vector2.ONE)
		var pts: PackedVector2Array = []
		var uvs: PackedVector2Array = []
		for i: int in 48:
			var a2: float = TAU * float(i) / 48.0
			var p: Vector2 = Vector2(cos(a2), sin(a2))
			pts.append(Vector2(PORTRAIT_R, PORTRAIT_R) + p * PORTRAIT_R)
			uvs.append(Vector2(0.5, 0.5) + p * 0.5)
		draw_colored_polygon(pts, Color.WHITE, uvs, _portrait)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Rings: thicker and brighter with each tier.
	draw_arc(c, PORTRAIT_R + 2.0, 0.0, TAU, 64, trim, 2.0 + float(tier), true)
	if tier >= 1:
		draw_arc(c, PORTRAIT_R + 7.0, 0.0, TAU, 64, Color(trim, 0.45), 1.5, true)
	if tier >= 4:
		var pulse: float = 0.5 + 0.5 * sin(_time * 2.5)
		draw_arc(c, PORTRAIT_R + 11.0, 0.0, TAU, 64, Color(accent, 0.25 + 0.35 * pulse), 3.0, true)
		for i: int in 6:
			var a3: float = _time * 0.8 + TAU * float(i) / 6.0
			draw_circle(c + Vector2(cos(a3), sin(a3)) * (PORTRAIT_R + 11.0), 2.2, Color(GOLD, 0.9))
