class_name TideWater
extends Node3D
## Sunken Archive tide: the water plane rises and falls every 12 game hours.
## Low tide (hours 12–18) uncovers the lower library.

@export var low_y: float = -1.5
@export var high_y: float = 2.2
@export var size: Vector2 = Vector2(120, 120)

const PERIOD_H: float = 12.0
## Low point at 15:00 / 03:00.
const LOW_HOUR: float = 15.0

var _mesh: MeshInstance3D


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var plane: BoxMesh = BoxMesh.new()
	plane.size = Vector3(size.x, 0.2, size.y)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.35, 0.5, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plane.material = mat
	_mesh.mesh = plane
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


static func level_at(hour_f: float, low: float, high: float) -> float:
	var k: float = 0.5 - 0.5 * cos((hour_f - LOW_HOUR) / PERIOD_H * TAU)
	return lerpf(low, high, k)


func _process(_delta: float) -> void:
	var minutes: float = fmod(GameState.clock.total_minutes, 1440.0)
	_mesh.position.y = level_at(minutes / 60.0, low_y, high_y)
