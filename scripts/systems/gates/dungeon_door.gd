class_name DungeonDoor
extends StaticBody3D
## A door across a dungeon tunnel, dressed with one of the owner's door models and framed
## with stone up to the tunnel roof. Pushing it (interact) shudders it and lowers it into
## the floor. A Double Gate door wants a Gate Key instead and leads into the hidden Gate.

signal used(door: DungeonDoor)

const HALF_WIDTH_M: float = 3.0
const HEIGHT_M: float = 4.6
const MAX_WIDTH_M: float = 5.8
const USE_RADIUS_M: float = 2.4
const OPEN_S: float = 1.4
const DOUBLE_COLOR: Color = Color(0.7, 0.3, 1.0, 0.4)
const KEY_ITEM: StringName = &"gate_key"

var is_double: bool = false
var is_open: bool = false
## Size the model ended up with (the frame fills the rest of the tunnel).
var door_width: float = HALF_WIDTH_M * 1.6
var door_height: float = HEIGHT_M
var door_depth: float = 0.8
var _model: Node3D
var _seal: MeshInstance3D = null
var _shape: CollisionShape3D
var _interactable: Interactable


## +Z of the door faces the side the player comes from.
func setup(model_id: StringName, double_gate: bool) -> void:
	is_double = double_gate
	_model = Node3D.new()
	# The imported door models face -Z; turn them to the player's side.
	_model.rotation.y = PI
	add_child(_model)
	var height: float = HEIGHT_M
	var d: PropData = PropData.find(model_id)
	if d != null and d.size.x > MAX_WIDTH_M * d.size.y / HEIGHT_M:
		height = HEIGHT_M * MAX_WIDTH_M / (d.size.x * HEIGHT_M / d.size.y)
	if PropInstance.attach_model(_model, model_id, height):
		door_width = d.size.x * height / d.size.y
		door_height = height
		door_depth = maxf(d.size.z * height / d.size.y, 0.8)
	else:
		_fallback_slab()
	_shape = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(HALF_WIDTH_M * 2.0, HEIGHT_M, door_depth)
	_shape.shape = box
	_shape.position.y = HEIGHT_M * 0.5
	add_child(_shape)
	if is_double:
		_add_seal()
	_interactable = Interactable.new()
	_interactable.prompt_key = &"PROMPT_DOUBLE_DOOR" if is_double else &"PROMPT_OPEN_DOOR"
	var use: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = USE_RADIUS_M
	use.shape = sphere
	use.position = Vector3(0.0, 1.0, door_depth * 0.5 + 1.2)
	_interactable.add_child(use)
	add_child(_interactable)
	_interactable.interacted.connect(_on_use)


## Stone around the model: side jambs and a lintel up to `roof_y` (static, stays put).
func build_frame(material: Material, roof_y: float) -> void:
	var side: float = HALF_WIDTH_M - door_width * 0.5
	if side > 0.1:
		for sx: float in [-1.0, 1.0]:
			_frame_box(Vector3(side + 0.4, roof_y + 0.5, door_depth + 0.6), Vector3(sx * (door_width * 0.5 + side * 0.5 + 0.2), (roof_y + 0.5) * 0.5, 0.0), material)
	if roof_y > door_height:
		var lintel: float = roof_y + 0.5 - door_height
		_frame_box(Vector3(HALF_WIDTH_M * 2.0 + 0.8, lintel, door_depth + 0.6), Vector3(0.0, door_height + lintel * 0.5, 0.0), material)


func _frame_box(box_size: Vector3, pos: Vector3, material: Material) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = pos
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = box_size
	cs.shape = shape
	body.add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = box_size
	mi.mesh = bm
	mi.material_override = material
	body.add_child(mi)
	add_child(body)


func _on_use(_player: Player) -> void:
	if is_open:
		return
	if is_double:
		if GameState.inventory == null or GameState.inventory.count_of(KEY_ITEM) <= 0:
			Codex.notify(tr(&"CODEX_MSG_DOUBLE_NEED_KEY"), &"anomaly")
			return
		GameState.inventory.remove(KEY_ITEM)
	used.emit(self)


## Shudder, then sink into the floor; the way is free once it is down.
func open() -> void:
	if is_open:
		return
	is_open = true
	_interactable.enabled = false
	AudioManager.play_sfx(&"hit_heavy")
	var t: Tween = create_tween()
	for i: int in 3:
		var push: float = 0.06 * (1.0 - float(i) / 3.0)
		t.tween_property(_model, ^"position:x", push, 0.05)
		t.tween_property(_model, ^"position:x", -push, 0.05)
	t.tween_property(_model, ^"position:x", 0.0, 0.05)
	t.tween_property(_model, ^"position:y", -door_height - 0.2, OPEN_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		_shape.set_deferred(&"disabled", true)
		_model.visible = false)


func _add_seal() -> void:
	_seal = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(HALF_WIDTH_M * 1.6, HEIGHT_M * 0.85)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = DOUBLE_COLOR
	mat.albedo_texture = glow_texture()
	quad.material = mat
	_seal.mesh = quad
	_seal.position = Vector3(0.0, HEIGHT_M * 0.45, door_depth * 0.5 + 0.1)
	add_child(_seal)


## Soft radial glow (wards, seals): bright in the middle, fading to the edges.
static func glow_texture() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	return tex


func _fallback_slab() -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(HALF_WIDTH_M * 1.6, HEIGHT_M, 0.4)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.22, 0.16)
	bm.material = mat
	mi.mesh = bm
	mi.position.y = HEIGHT_M * 0.5
	_model.add_child(mi)
