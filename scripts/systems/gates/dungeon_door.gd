class_name DungeonDoor
extends StaticBody3D
## A doorway between two dungeon rooms, dressed with one of the owner's door models.
## Sealed (red glow, no prompt) while its room is fighting. Using it shudders the door,
## and the dungeon fades to the matching door in the next room.
## A Double Gate door leads nowhere in this dungeon: it wants a Gate Key.

signal used(door: DungeonDoor)

const HEIGHT_M: float = 4.6
const MAX_WIDTH_M: float = 5.8
const USE_RADIUS_M: float = 2.4
const SEAL_COLOR: Color = Color(1.0, 0.12, 0.18, 0.5)
const DOUBLE_COLOR: Color = Color(0.7, 0.3, 1.0, 0.4)
const KEY_ITEM: StringName = &"gate_key"

var room_index: int = -1
var target_room: int = -1
var target_door: int = -1
var is_double: bool = false
var _model: Node3D
var _seal: MeshInstance3D
var _interactable: Interactable
var _locked: bool = false
## Size the model ended up with (the room fills the rest of the doorway with wall).
var door_width: float = DungeonRoomShape.DOOR_HALF_M * 1.6
var door_height: float = HEIGHT_M
var door_depth: float = 0.8


func setup(model_id: StringName, double_gate: bool) -> void:
	is_double = double_gate
	_model = Node3D.new()
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
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(DungeonRoomShape.DOOR_HALF_M * 2.0, HEIGHT_M, door_depth)
	cs.shape = box
	cs.position.y = HEIGHT_M * 0.5
	add_child(cs)
	_seal = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(DungeonRoomShape.DOOR_HALF_M * 1.6, HEIGHT_M * 0.85)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = DOUBLE_COLOR if is_double else SEAL_COLOR
	mat.albedo_texture = _seal_texture()
	quad.material = mat
	_seal.mesh = quad
	_seal.position = Vector3(0.0, HEIGHT_M * 0.45, door_depth * 0.5 + 0.1)
	add_child(_seal)
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
	set_locked(false)


## Rooms seal their doors while enemies are alive.
func set_locked(locked: bool) -> void:
	_locked = locked
	_interactable.enabled = not locked
	_seal.visible = locked or is_double


func _on_use(_player: Player) -> void:
	if _locked:
		return
	if is_double and GameState.inventory != null and GameState.inventory.count_of(KEY_ITEM) <= 0:
		Codex.notify(tr(&"CODEX_MSG_DOUBLE_NEED_KEY"), &"anomaly")
		return
	if is_double and GameState.inventory != null:
		GameState.inventory.remove(KEY_ITEM)
	used.emit(self)


## Heavy shove: the door shudders and settles back (played before the fade).
func shove() -> void:
	AudioManager.play_sfx(&"hit_heavy")
	var t: Tween = create_tween()
	for i: int in 4:
		var push: float = 0.08 * (1.0 - float(i) / 4.0)
		t.tween_property(_model, ^"position:z", -push, 0.06)
		t.tween_property(_model, ^"position:z", push * 0.4, 0.06)
	t.tween_property(_model, ^"position:z", 0.0, 0.1)


## Where the player stands after coming through this door (inside the room).
func arrival_point() -> Vector3:
	return global_position + global_basis.z * (door_depth * 0.5 + 3.4) + Vector3.UP * 0.2


## Soft vertical glow: bright in the middle, fading to the edges (a ward, not a slab).
static func _seal_texture() -> GradientTexture2D:
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


func _process(_delta: float) -> void:
	if _seal != null and _seal.visible:
		var pulse: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.004)
		_seal.scale = Vector3(1.0, 1.0, 1.0) * (0.95 + 0.05 * pulse)
		_seal.transparency = 1.0 - pulse


func _fallback_slab() -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(DungeonRoomShape.DOOR_HALF_M * 1.6, HEIGHT_M, 0.4)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.22, 0.16)
	bm.material = mat
	mi.mesh = bm
	mi.position.y = HEIGHT_M * 0.5
	_model.add_child(mi)
