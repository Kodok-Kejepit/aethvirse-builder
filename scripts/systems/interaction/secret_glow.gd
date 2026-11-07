class_name SecretGlow
extends Node
## Makes a secret mesh shimmer when the player is near and has enough SEN (§9 Sense).
## Higher SEN = visible from further away.

@export var target_mesh: MeshInstance3D
@export var min_sense: float = 8.0
@export var base_radius_m: float = 6.0
@export var radius_per_sense_m: float = 0.5
@export var glow_color: Color = Color(0.5, 0.85, 1.0)
## Optional: stop glowing when this flag is set (secret found).
@export var hide_when_flag: StringName = &""

var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(glow_color, 0.0)
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if target_mesh != null:
		target_mesh.material_overlay = _material


func _process(_delta: float) -> void:
	_material.albedo_color.a = intensity()


## 0..1 shimmer strength for the current player (0 if SEN too low or out of range).
func intensity() -> float:
	var player: Player = GameState.player as Player
	if player == null or not is_instance_valid(player) or target_mesh == null or not target_mesh.visible:
		return 0.0
	if hide_when_flag != &"" and GameState.has_flag(hide_when_flag):
		return 0.0
	var sense: float = player.stats.primary.sense if player.stats.primary != null else 0.0
	return glow_strength(sense, player.global_position.distance_to(target_mesh.global_position),
		min_sense, base_radius_m, radius_per_sense_m) * (0.25 + 0.15 * sin(Time.get_ticks_msec() / 300.0))


static func glow_strength(sense: float, distance: float, min_sen: float, base_radius: float, per_sense: float) -> float:
	if sense < min_sen:
		return 0.0
	var radius: float = base_radius + (sense - min_sen) * per_sense
	return clampf(1.0 - distance / radius, 0.0, 1.0)
