class_name WeaponTrail
extends MeshInstance3D
## Ribbon between the hand and the weapon tip, drawn while an attack is active and fading
## along its length (slash trail). Lives in world space (top_level) so it streaks.

const MAX_POINTS: int = 14
const FADE_S: float = 0.18

var hand: Node3D
var tip: Node3D
var color: Color = Color(0.6, 0.85, 1.0)
var active: bool = false

var _points: Array[PackedVector3Array] = []
var _ages: PackedFloat32Array = PackedFloat32Array()
var _im: ImmediateMesh
var _mat: StandardMaterial3D


func setup(hand_node: Node3D, tip_node: Node3D) -> void:
	hand = hand_node
	tip = tip_node
	top_level = true
	_im = ImmediateMesh.new()
	mesh = _im
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.vertex_color_use_as_albedo = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	global_transform = Transform3D.IDENTITY


func _process(delta: float) -> void:
	if hand == null or tip == null or not is_instance_valid(tip):
		return
	for i: int in _ages.size():
		_ages[i] += delta
	if active:
		var base: Vector3 = hand.global_position.lerp(tip.global_position, 0.25)
		_points.push_front(PackedVector3Array([base, tip.global_position]))
		_ages.insert(0, 0.0)
	while not _ages.is_empty() and (_ages[_ages.size() - 1] > FADE_S or _points.size() > MAX_POINTS):
		_points.pop_back()
		_ages.remove_at(_ages.size() - 1)
	_rebuild()


func _rebuild() -> void:
	_im.clear_surfaces()
	if _points.size() < 2:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat)
	for i: int in _points.size():
		var k: float = 1.0 - float(i) / float(_points.size() - 1)
		var a: float = k * (1.0 - _ages[i] / FADE_S) * 0.5
		_im.surface_set_color(Color(color, a * 0.5))
		_im.surface_add_vertex(_points[i][0])
		_im.surface_set_color(Color(color.lightened(0.15), a))
		_im.surface_add_vertex(_points[i][1])
	_im.surface_end()
