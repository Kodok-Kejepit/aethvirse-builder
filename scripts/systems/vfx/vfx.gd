class_name Vfx
extends Node
## Combat / feedback effects driven by EventBus (like AudioManager): hit sparks by element,
## crit flash rings, skill cast rings, level-up pillar, enemy death puffs. One-shot effects
## come from a small pool so fights do not allocate every hit.

const POOL: int = 16
const SPARK_LIFETIME: float = 0.45

## Off for preview stages (Codex): only explicit burst()/ring() calls.
var listen_events: bool = true

var _sparks: Array[CPUParticles3D] = []
var _rings: Array[MeshInstance3D] = []
var _next_spark: int = 0
var _next_ring: int = 0


func _ready() -> void:
	name = "Vfx"
	for i: int in POOL:
		var p: CPUParticles3D = _make_sparks()
		add_child(p)
		_sparks.append(p)
		var r: MeshInstance3D = _make_ring()
		add_child(r)
		_rings.append(r)
	if not listen_events:
		return
	EventBus.damage_number_requested.connect(_on_damage)
	EventBus.enemy_killed.connect(func(_id: StringName, at: Vector3) -> void:
		burst(at + Vector3.UP * 0.8, Color(0.75, 0.7, 0.8), 28, 3.0, 0.7))
	EventBus.skill_used.connect(_on_skill)
	EventBus.level_up.connect(func(_lv: int) -> void: _level_up())


func _on_damage(pos: Vector3, _amount: int, crit: bool, element: int, on_player: bool) -> void:
	var c: Color = Color(1.0, 0.35, 0.3) if on_player else Element.COLORS.get(element as Element.Type, Color(1, 0.95, 0.8))
	burst(pos, c, 22 if crit else 12, 5.0 if crit else 3.5, SPARK_LIFETIME)
	if crit:
		ring(pos, Color(1, 1, 1), 1.6, 0.25)


func _on_skill(skill_id: StringName) -> void:
	var player: Player = GameState.player as Player
	if player == null:
		return
	var skill: SkillData = player.stats.find_skill(skill_id) if player.stats != null else null
	var c: Color = skill.icon_color if skill != null else Color(0.5, 0.8, 1.0)
	ring(player.global_position + Vector3.UP * 0.05, c, 3.2 if skill != null and skill.is_ultimate else 2.2, 0.45, true)


func _level_up() -> void:
	var player: Node3D = GameState.player
	if player == null:
		return
	ring(player.global_position + Vector3.UP * 0.05, Color(1.0, 0.85, 0.4), 3.0, 0.8, true)
	burst(player.global_position + Vector3.UP * 1.0, Color(1.0, 0.9, 0.5), 40, 4.0, 1.2, Vector3.UP)


func burst(at: Vector3, c: Color, amount: int, speed: float, life: float, dir: Vector3 = Vector3.ZERO) -> void:
	var p: CPUParticles3D = _sparks[_next_spark]
	_next_spark = (_next_spark + 1) % _sparks.size()
	p.global_position = at
	p.amount = amount
	p.lifetime = life
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.direction = dir if dir != Vector3.ZERO else Vector3.UP
	p.spread = 25.0 if dir != Vector3.ZERO else 180.0
	p.color = c
	p.restart()
	p.emitting = true


func ring(at: Vector3, c: Color, radius: float, life: float, flat: bool = false) -> void:
	var r: MeshInstance3D = _rings[_next_ring]
	_next_ring = (_next_ring + 1) % _rings.size()
	r.global_position = at
	r.rotation_degrees = Vector3.ZERO if flat else Vector3(90, 0, 0)
	if not flat:
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam != null:
			r.look_at(cam.global_position, Vector3.UP)
			r.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	r.visible = true
	r.scale = Vector3.ONE * 0.2
	var mat: StandardMaterial3D = r.material_override as StandardMaterial3D
	mat.albedo_color = Color(c, 0.9)
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(r, ^"scale", Vector3.ONE * radius, life).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, ^"albedo_color:a", 0.0, life)
	t.chain().tween_callback(func() -> void: r.visible = false)


static func _make_sparks() -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.95
	p.local_coords = false
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	quad.material = m
	p.mesh = quad
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	return p


static func _make_ring() -> MeshInstance3D:
	var r: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 4
	r.mesh = torus
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	r.material_override = m
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.top_level = true
	r.visible = false
	return r
