class_name HollowGate
extends Node3D
## Entrance to the Hidden Region (MYSTERY_BIBLE §12): at the prologue Double Gate spot in
## Ashfall, only at 03:xx, and only for one who holds the three keys of this build
## (stand-ins for the 7 Sigils + 4 map pieces): the Echo King answered, the Codex Umbra read,
## the Fracture's heart reached. A white ring with a black rim.

const KEY_FLAGS: Array[StringName] = [&"echo_king_answered", &"codex_umbra_read", &"fracture_heart"]
const OPEN_HOUR: int = 3
const TARGET_REGION: StringName = &"r7_hollow_throne"

var interactable: Interactable
var _ring: MeshInstance3D
var _label: Label3D


static func keys_held() -> int:
	var n: int = 0
	for f: StringName in KEY_FLAGS:
		if GameState.has_flag(f):
			n += 1
	return n


static func is_open_now() -> bool:
	return keys_held() == KEY_FLAGS.size() and GameState.clock.hour() == OPEN_HOUR


func _ready() -> void:
	_ring = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 1.5
	torus.outer_radius = 2.0
	_ring.mesh = torus
	_ring.rotation_degrees = Vector3(90, 0, 0)
	_ring.position.y = 2.2
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.97, 0.97, 1.0)
	_ring.material_override = mat
	add_child(_ring)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 40
	_label.outline_size = 10
	_label.position.y = 4.8
	add_child(_label)
	interactable = Interactable.new()
	interactable.prompt_key = &"PROMPT_ENTER"
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 2.4
	shape.shape = sphere
	shape.position.y = 1.5
	interactable.add_child(shape)
	add_child(interactable)
	interactable.interacted.connect(_enter)
	_refresh()


func _process(delta: float) -> void:
	_ring.rotate_object_local(Vector3.UP, delta * 0.6)
	if Engine.get_process_frames() % 30 == 0:
		_refresh()


func _refresh() -> void:
	var open: bool = is_open_now()
	_ring.visible = open
	interactable.enabled = open
	# A faint crack for those who hold some keys: the place hums, but stays shut.
	_label.visible = open or keys_held() > 0
	_label.text = tr(&"HOLLOW_GATE_OPEN") if open else "· · ·"
	_label.modulate = Color(1, 1, 1, 1.0 if open else 0.35)


func _enter(_player: Player) -> void:
	var region: RegionData = RegionData.load_region(TARGET_REGION)
	if region == null:
		return
	GameState.set_flag(&"hollow_throne_entered")
	Codex.notify(tr(&"CODEX_MSG_HOLLOW_ENTER"), &"anomaly")
	WorldTravel.go(get_tree(), region, region.spawn)
