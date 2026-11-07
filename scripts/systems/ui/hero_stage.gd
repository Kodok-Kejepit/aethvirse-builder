class_name HeroStage
extends SubViewportContainer
## Lit 3D stage with the player's hero (character select, Codex → Status). Shows the
## class weapon (sword classes may show the Mythic Starfall), turns slowly, and can play
## a skill preview: the matching animation, the spirit dragon and coloured effects.

const MYTHIC_SWORD: StringName = &"sword_starfall"
const TURN_SPEED: float = 0.35
const PREVIEW_S: float = 1.4
## Element / effect colours of a preview come from the skill's attack, else its icon colour.
const PREVIEW_RING_RADIUS: float = 2.4

## Emitted with the Mythic item shown in hand (or null).
signal weapon_shown(item: ItemData)

var model: CharacterModel = null
var auto_turn: bool = true
var camera: Camera3D

var _world: Node3D
var _vfx: Vfx
var _preview_left: float = 0.0
var _preview_skill: SkillData = null
var _fired: bool = false
var _orb: MeshInstance3D = null


## Largest render size; the stage never asks the GPU for more (a runaway layout size
## once produced "Texture dimensions exceed device maximum" on the owner's iGPU).
const MAX_PX: int = 2048

var _vp: SubViewport


func _init() -> void:
	# Sized by hand (clamped) instead of `stretch`, so a bad layout size can never reach the GPU.
	stretch = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_fit_viewport)
	var vp: SubViewport = SubViewport.new()
	_vp = vp
	vp.size = Vector2i(16, 16)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	add_child(vp)
	_world = Node3D.new()
	vp.add_child(_world)
	_build_lights()
	_build_platform()
	camera = Camera3D.new()
	camera.fov = 34.0
	_world.add_child(camera)
	set_framing(6.4, 0.62)
	camera.current = true
	_vfx = Vfx.new()
	_vfx.listen_events = false
	_world.add_child(_vfx)


## Camera distance (m) and the height it looks at; narrow stages need more distance.
func set_framing(distance: float, look_y: float) -> void:
	camera.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, look_y + distance * 0.13, distance)).looking_at(Vector3(0.0, look_y, 0.0))


func _fit_viewport() -> void:
	var w: int = clampi(int(size.x), 16, MAX_PX) if is_finite(size.x) else 16
	var h: int = clampi(int(size.y), 16, MAX_PX) if is_finite(size.y) else 16
	_vp.size = Vector2i(w, h)


func _build_lights() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.75, 1.0)
	e.ambient_light_energy = 0.3
	e.glow_enabled = true
	e.glow_intensity = 0.3
	e.glow_hdr_threshold = 1.2
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	_world.add_child(env)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 0.75
	key.shadow_enabled = true
	_world.add_child(key)
	var rim: OmniLight3D = OmniLight3D.new()
	rim.position = Vector3(-1.5, 2.6, 1.5)
	rim.light_color = Color(0.55, 0.7, 1.0)
	rim.light_energy = 0.9
	rim.omni_range = 6.0
	_world.add_child(rim)


func _build_platform() -> void:
	var disc: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 1.3
	cyl.bottom_radius = 1.4
	cyl.height = 0.12
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.12, 0.2)
	m.emission_enabled = true
	m.emission = CodexTheme.ACCENT
	m.emission_energy_multiplier = 0.04
	cyl.material = m
	disc.mesh = cyl
	disc.position.y = -0.06
	_world.add_child(disc)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 1.32
	torus.outer_radius = 1.38
	var rm: StandardMaterial3D = StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(CodexTheme.ACCENT, 0.6)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	torus.material = rm
	ring.mesh = torus
	_world.add_child(ring)


## (Re)builds the hero with the class weapon.
func show_hero(hero_id: StringName, class_id: StringName, mythic_sword: bool) -> void:
	if model != null:
		model.queue_free()
	model = CharacterModel.new()
	_world.add_child(model)
	var weapon: CharacterRig.Weapon = CharacterRig.weapon_for_class(class_id)
	model.setup(null, weapon, OS.has_feature("mobile"), HeroData.load_hero(hero_id), 0)
	model.rotation.y = PI + 0.5
	_preview_left = 0.0
	var shown: ItemData = null
	if weapon == CharacterRig.Weapon.SWORD and mythic_sword:
		shown = _attach_mythic_sword()
	weapon_shown.emit(shown)


func _attach_mythic_sword() -> ItemData:
	var item: ItemData = GameState.items.get_item(MYTHIC_SWORD) if GameState.items != null else null
	var rig: CharacterRig = model.rig
	if item == null or rig.weapon_tip == null or PropData.find(item.visual_prop) == null:
		return null
	var holder: Node3D = Node3D.new()
	holder.position = item.visual_offset
	holder.rotation_degrees = item.visual_rotation_deg
	rig.get_joint(&"hand_r").add_child(holder)
	var d: PropData = PropData.find(item.visual_prop)
	if not PropInstance.attach_model(holder, item.visual_prop, d.size.y):
		return null
	(rig.weapon_tip.get_parent() as Node3D).visible = false
	return item


func is_previewing() -> bool:
	return _preview_left > 0.0


## Plays what a skill looks like: pose by kind, dragon on skills, element effects.
func preview_skill(skill: SkillData) -> void:
	if model == null or skill == null:
		return
	_preview_skill = skill
	_preview_left = PREVIEW_S
	_fired = false
	model.rotation.y = PI + 0.6
	model.forced_pose = _pose_for(skill)
	model.forced_progress = 0.0
	var c: Color = _colour(skill)
	_vfx.ring(Vector3(0.0, 0.05, 0.0), c, PREVIEW_RING_RADIUS if not skill.is_ultimate else 3.4, 0.6, true)
	if model.has_dragon() and not skill.is_passive():
		model.summon_dragon(skill.is_ultimate)


static func _pose_for(skill: SkillData) -> StringName:
	match skill.kind:
		SkillData.Kind.BUFF, SkillData.Kind.PASSIVE:
			return &"summon"
		SkillData.Kind.SUMMON, SkillData.Kind.SHADOW_CALL, SkillData.Kind.SHADOW_EXTRACT:
			return &"cast"
	return &"cast" if skill.is_ultimate or skill.kind == SkillData.Kind.AOE else &"slash"


static func _colour(skill: SkillData) -> Color:
	if skill.attack != null and skill.attack.element != Element.Type.PHYSICAL:
		return Element.COLORS.get(skill.attack.element, skill.icon_color)
	return skill.icon_color


func _process(delta: float) -> void:
	if model == null:
		return
	if _preview_left > 0.0:
		_tick_preview(delta)
	elif auto_turn:
		model.rotation.y += delta * TURN_SPEED


func _tick_preview(delta: float) -> void:
	_preview_left = maxf(_preview_left - delta, 0.0)
	var t: float = 1.0 - _preview_left / PREVIEW_S
	model.forced_progress = t
	var skill: SkillData = _preview_skill
	var c: Color = _colour(skill)
	var forward: Vector3 = -model.global_basis.z
	if not _fired and t > 0.45:
		_fired = true
		_impact(skill, c, forward)
	if skill.kind == SkillData.Kind.DASH:
		model.position = forward * sin(t * PI) * 1.2
	if _orb != null:
		_orb.position += forward * delta * 6.0
	if _preview_left <= 0.0:
		model.position = Vector3.ZERO
		model.forced_pose = &"idle"
		model.forced_progress = -1.0
		if _orb != null:
			_orb.queue_free()
			_orb = null


func _impact(skill: SkillData, c: Color, forward: Vector3) -> void:
	var front: Vector3 = Vector3.UP * 1.0 + forward * 1.2
	match skill.kind:
		SkillData.Kind.AOE:
			_vfx.ring(Vector3(0.0, 0.08, 0.0), c, 3.2, 0.7, true)
			_vfx.burst(Vector3.UP * 0.3, c, 60, 6.0, 0.9)
		SkillData.Kind.BUFF, SkillData.Kind.PASSIVE:
			_vfx.burst(Vector3.UP * 0.4, c, 50, 3.5, 1.2, Vector3.UP)
			_vfx.ring(Vector3.UP * 1.0, c, 1.6, 0.6)
		SkillData.Kind.PROJECTILE:
			_spawn_orb(front, c)
		_:
			_vfx.burst(front, c, 40, 5.5, 0.6, forward)
			_vfx.ring(front, Color.WHITE, 1.4, 0.3)


func _spawn_orb(at: Vector3, c: Color) -> void:
	_orb = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 3.0
	sphere.material = m
	_orb.mesh = sphere
	_orb.position = at
	_world.add_child(_orb)
	_vfx.burst(at, c, 24, 3.0, 0.4)
