class_name PlayerFrame
extends Control
## Top-left player frame in the owner's design: a round portrait of the hero (rendered from
## her own model) wrapped by a gold line-art dragon, the name bar, the HP bar, the MP strip
## and the level tab. Dragon heroes use the owner's dragon frame art; shadow heroes get a
## silver-violet frame with a crescent moon and crossed daggers. It grows richer with the
## level: dim lines (1) -> bright gold (20) -> full (40) -> glowing (60) -> sparks (80).

const TIER_LEVELS: Array[int] = [1, 20, 40, 60, 80]
const FRAME_TEX: Texture2D = preload("res://assets/ui/hud/frame_dragon.png")
const SERIF: FontFile = preload("res://assets/ui/fonts/NotoSerif-SemiBold.ttf")
## Screen size of the 1055 x 495 frame art.
const SCALE: float = 0.47
const PORTRAIT_PX: int = 256
## Frame geometry in art pixels (measured on frame_dragon.png).
const PORTRAIT_C: Vector2 = Vector2(268, 262)
const PORTRAIT_R: float = 140.0
const NAME_POLY: PackedVector2Array = [Vector2(418, 193), Vector2(1030, 193), Vector2(975, 253), Vector2(418, 253)]
const HP_POLY: PackedVector2Array = [Vector2(424, 284), Vector2(862, 284), Vector2(824, 327), Vector2(424, 327)]
const MP_POLY: PackedVector2Array = [Vector2(424, 330), Vector2(820, 330), Vector2(808, 342), Vector2(424, 342)]
const LV_POLY: PackedVector2Array = [Vector2(418, 346), Vector2(610, 346), Vector2(570, 389), Vector2(418, 389)]
const GOLD: Color = Color(0.95, 0.8, 0.5)
const SILVER: Color = Color(0.82, 0.84, 0.92)
const VIOLET: Color = Color(0.66, 0.45, 0.98)

var tier: int = 0
var _hero: HeroData = null
var _portrait: Texture2D = null
var _vp: SubViewport = null
var _frames: int = 0
var _time: float = 0.0
var _hp: Vector2 = Vector2(1, 1)
var _cam: Camera3D = null
var _model: CharacterModel = null
var _mp: Vector2 = Vector2(1, 1)


static func tier_for(level: int) -> int:
	var t: int = 0
	for i: int in TIER_LEVELS.size():
		if level >= TIER_LEVELS[i]:
			t = i
	return t


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(8, 4)
	size = Vector2(1055, 495) * SCALE
	_hero = HeroData.load_hero(GameState.hero_id)
	_hide_old_bars.call_deferred()
	EventBus.level_up.connect(func(_l: int) -> void: _refresh_tier())
	EventBus.player_stats_changed.connect(_refresh_tier)
	EventBus.player_health_changed.connect(func(current: int, maximum: int) -> void:
		_hp = Vector2(current, maxi(maximum, 1))
		queue_redraw())
	EventBus.player_mana_changed.connect(func(current: float, maximum: float) -> void:
		_mp = Vector2(current, maxf(maximum, 1.0))
		queue_redraw())
	_refresh_tier()
	if DisplayServer.get_name() != "headless":
		_render_portrait()


## The frame draws HP / MP / level itself; the old plain bars stay hidden.
func _hide_old_bars() -> void:
	var player: Player = GameState.player as Player
	if player != null and is_instance_valid(player):
		_hp = Vector2(player.health.current, maxi(player.health.max_health, 1))
		_mp = Vector2(player.mana.current, maxf(player.mana.max_mana, 1.0))
	var hud: Node = get_parent()
	for path: NodePath in [^"HealthBar", ^"ManaBar", ^"Combat/LevelLabel"]:
		var c: CanvasItem = hud.get_node_or_null(path) as CanvasItem
		if c != null:
			c.visible = false


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
	_model = model
	_cam = Camera3D.new()
	_cam.fov = 26.0
	_vp.add_child(_cam)
	_aim_camera()
	_cam.current = true
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


## Frames the head: the rig's head bone once the pose is applied (each hero model has
## its own proportions), else the old head joint / a default height.
func _aim_camera() -> void:
	var target: Vector3 = Vector3(0.0, 1.55, 0.0)
	var head: Node3D = _model.rig.get_joint(&"head") if _model.rig != null else null
	if head != null:
		target = head.global_position
	for n: Node in _model.find_children("*", "Skeleton3D", true, false):
		var sk: Skeleton3D = n as Skeleton3D
		var idx: int = sk.find_bone("mixamorig_Head")
		if idx >= 0:
			target = sk.global_transform * sk.get_bone_global_pose(idx).origin
			# Meshy rigs mark the face with a "headfront" bone: aim between the two.
			var front: int = sk.find_bone("headfront")
			if front >= 0:
				target = target.lerp(sk.global_transform * sk.get_bone_global_pose(front).origin, 0.6)
	target += Vector3(0.0, 0.06, 0.0)
	# Models face their local -Z.
	var facing: Vector3 = -_model.global_basis.z
	_cam.global_transform = Transform3D(Basis.IDENTITY, target + facing * 0.7).looking_at(target)


func _process(delta: float) -> void:
	_time += delta
	if _vp != null:
		_frames += 1
		if _frames == 3:
			_aim_camera()
		if _frames == 8:
			# Freeze the shot: keep the image, drop the viewport.
			_portrait = ImageTexture.create_from_image(_vp.get_texture().get_image())
			_vp.queue_free()
			_vp = null
			queue_redraw()
	if tier >= 3:
		queue_redraw()


func _dragon() -> bool:
	return _hero == null or _hero.has_dragon


func _p(art: Vector2) -> Vector2:
	return art * SCALE


func _poly(art: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = []
	for v: Vector2 in art:
		out.append(_p(v))
	return out


## Fills `art` from the left up to `share` (0..1) of its width.
func _fill(art: PackedVector2Array, share: float, left: Color, right: Color) -> void:
	if share <= 0.001:
		return
	var x0: float = art[0].x
	var x1: float = maxf(art[1].x, art[2].x)
	var cut: float = lerpf(x0, x1, clampf(share, 0.0, 1.0))
	var pts: PackedVector2Array = []
	var cols: PackedColorArray = []
	for v: Vector2 in art:
		var p: Vector2 = Vector2(minf(v.x, cut), v.y)
		pts.append(_p(p))
		cols.append(left.lerp(right, (p.x - x0) / maxf(x1 - x0, 1.0)))
	draw_polygon(pts, cols)


func _draw() -> void:
	var trim: Color = GOLD if _dragon() else SILVER
	var accent: Color = Color(0.55, 0.95, 0.75) if _dragon() else VIOLET
	var line_alpha: float = [0.85, 0.92, 1.0, 1.0, 1.0][tier]
	# Bar backgrounds.
	draw_colored_polygon(_poly(NAME_POLY), Color(0.02, 0.1, 0.08, 0.72) if _dragon() else Color(0.06, 0.03, 0.1, 0.72))
	draw_colored_polygon(_poly(HP_POLY), Color(0.05, 0.02, 0.03, 0.75))
	draw_colored_polygon(_poly(MP_POLY), Color(0.02, 0.03, 0.07, 0.75))
	draw_colored_polygon(_poly(LV_POLY), Color(0.03, 0.04, 0.08, 0.75))
	_fill(HP_POLY, _hp.x / _hp.y, Color(0.62, 0.08, 0.12), Color(0.95, 0.32, 0.32))
	_fill(MP_POLY, _mp.x / _mp.y, Color(0.12, 0.3, 0.85), Color(0.45, 0.75, 1.0))
	# Portrait disc (shadow heroes: crossed daggers behind it).
	var c: Vector2 = _p(PORTRAIT_C)
	var r: float = PORTRAIT_R * SCALE
	if not _dragon():
		_daggers(c, r, trim, accent, line_alpha)
	draw_circle(c, r, Color(0.02, 0.03, 0.06, 0.9))
	if _portrait != null:
		var pts: PackedVector2Array = []
		var uvs: PackedVector2Array = []
		for i: int in 48:
			var a: float = TAU * float(i) / 48.0
			var d: Vector2 = Vector2(cos(a), sin(a))
			pts.append(c + d * r)
			uvs.append(Vector2(0.5, 0.5) + d * 0.5)
		draw_colored_polygon(pts, Color.WHITE, uvs, _portrait)
	# The frame art (dragon heroes) or the drawn shadow frame.
	if _dragon():
		if tier >= 3:
			var pulse: float = 0.5 + 0.5 * sin(_time * 2.2)
			draw_texture_rect(FRAME_TEX, Rect2(Vector2(-2, -2), size + Vector2(4, 4)), false, Color(accent, 0.18 + 0.2 * pulse))
		draw_texture_rect(FRAME_TEX, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, line_alpha))
	else:
		_shadow_frame(trim, line_alpha)
	if tier >= 4:
		for i: int in 8:
			var a2: float = _time * 0.7 + TAU * float(i) / 8.0
			draw_circle(c + Vector2(cos(a2), sin(a2)) * (r + 10.0), 1.8, Color(trim, 0.9))
	_texts(trim)


func _texts(trim: Color) -> void:
	var name_text: String = tr(_hero.display_name) if _hero != null else ""
	var name_rect: Rect2 = Rect2(_p(Vector2(430, 196)), _p(Vector2(560, 56)))
	draw_string(SERIF, Vector2(name_rect.position.x, name_rect.end.y - 6.0), name_text.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, name_rect.size.x, 20, trim)
	var hp_text: String = "%d / %d" % [roundi(_hp.x), roundi(_hp.y)]
	draw_string(ThemeDB.fallback_font, _p(Vector2(440, 318)), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.95, 0.92))
	var level: int = GameState.progression.level if GameState.progression != null else 1
	draw_string(SERIF, _p(Vector2(436, 381)), "Lv %d" % level, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, trim)


## Two crossed daggers behind the portrait, blades out past the ring.
func _daggers(c: Vector2, r: float, trim: Color, accent: Color, alpha: float) -> void:
	for s: float in [-1.0, 1.0]:
		var dir: Vector2 = Vector2(s * 0.75, -0.66).normalized()
		var hilt: Vector2 = c - dir * (r * 1.25)
		var tip: Vector2 = c + dir * (r + 52.0)
		var side: Vector2 = dir.orthogonal() * 7.0
		draw_colored_polygon(PackedVector2Array([hilt + side, tip, hilt - side]), Color(trim.lightened(0.2), alpha))
		draw_line(c + dir * (r + 2.0), tip, Color(accent, alpha), 2.0, true)
		draw_line(hilt + side * 2.4, hilt - side * 2.4, Color(accent, alpha), 3.5, true)


## Silver-violet frame for shadow heroes: double rings, the bars' outlines, a crescent moon
## over the portrait and two crossed daggers behind it.
func _shadow_frame(trim: Color, alpha: float) -> void:
	var col: Color = Color(trim, alpha)
	var c: Vector2 = _p(PORTRAIT_C)
	var r: float = PORTRAIT_R * SCALE
	for k: int in 2:
		draw_arc(c, r + 3.0 + float(k) * 5.0, 0.0, TAU, 64, col, 1.6, true)
	for poly: PackedVector2Array in [NAME_POLY, HP_POLY, MP_POLY, LV_POLY]:
		var p: PackedVector2Array = _poly(poly)
		p.append(p[0])
		draw_polyline(p, col, 1.4, true)
	# Crescent moon at the top-left of the ring.
	var moon: Vector2 = c + Vector2(-r * 0.78, -r * 0.82)
	draw_arc(moon, 7.0, PI * 0.35, PI * 1.55, 24, Color(trim, alpha), 4.0, true)
