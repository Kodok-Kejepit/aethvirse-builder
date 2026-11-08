class_name DungeonWard
extends StaticBody3D
## Red ward across a room's mouth: while the room fights, nothing gets in or out.

const COLOR: Color = Color(1.0, 0.12, 0.18, 0.5)
const DEPTH_M: float = 0.6

var _glow: MeshInstance3D
var _shape: CollisionShape3D


func setup(width: float, height: float) -> void:
	_shape = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(width, height, DEPTH_M)
	_shape.shape = box
	_shape.position.y = height * 0.5
	add_child(_shape)
	_glow = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(width, height)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = COLOR
	mat.albedo_texture = DungeonDoor.glow_texture()
	quad.material = mat
	_glow.mesh = quad
	_glow.position.y = height * 0.5
	add_child(_glow)
	set_active(false)


func set_active(on: bool) -> void:
	collision_layer = 1 if on else 0
	_glow.visible = on
	set_process(on)


func is_active() -> bool:
	return collision_layer != 0


func _process(_delta: float) -> void:
	_glow.transparency = 0.25 + 0.25 * sin(Time.get_ticks_msec() * 0.004)
