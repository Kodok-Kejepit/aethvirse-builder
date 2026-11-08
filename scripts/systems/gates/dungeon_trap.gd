class_name DungeonTrap
extends Node3D
## Fire vent in a challenge room: a red ring glows up as a warning, then flame bursts out
## and burns whoever stands on it (a share of max HP). Runs only while `armed`.

const RADIUS_M: float = 1.9
const CYCLE_S: float = 3.6
const WARN_S: float = 1.2
const BURST_S: float = 0.6
const DAMAGE_SHARE: float = 0.08

var armed: bool = false
var _t: float = 0.0
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _flame: CPUParticles3D
var _hit_this_burst: bool = false


func _ready() -> void:
	_t = randf() * CYCLE_S
	_ring = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = RADIUS_M
	disc.bottom_radius = RADIUS_M
	disc.height = 0.02
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring_mat.albedo_texture = DungeonDoor.glow_texture()
	disc.material = _ring_mat
	_ring.mesh = disc
	_ring.position.y = 0.05
	add_child(_ring)
	_flame = CPUParticles3D.new()
	_flame.amount = 60
	_flame.lifetime = 0.7
	_flame.emitting = false
	_flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_flame.emission_sphere_radius = RADIUS_M * 0.6
	_flame.direction = Vector3.UP
	_flame.spread = 14.0
	_flame.gravity = Vector3(0, 2.0, 0)
	_flame.initial_velocity_min = 3.0
	_flame.initial_velocity_max = 5.5
	_flame.scale_amount_min = 1.5
	_flame.scale_amount_max = 3.0
	_flame.color = Color(1.0, 0.5, 0.15)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.25, 0.25)
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.vertex_color_use_as_albedo = true
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = fm
	_flame.mesh = quad
	add_child(_flame)
	_ring.visible = false


func _process(delta: float) -> void:
	_ring.visible = armed
	if not armed:
		_flame.emitting = false
		return
	_t = fmod(_t + delta, CYCLE_S)
	var warn_start: float = CYCLE_S - WARN_S - BURST_S
	if _t < warn_start:
		_ring_mat.albedo_color = Color(1.0, 0.2, 0.1, 0.15)
		_hit_this_burst = false
	elif _t < CYCLE_S - BURST_S:
		var k: float = (_t - warn_start) / WARN_S
		_ring_mat.albedo_color = Color(1.0, 0.25, 0.1, 0.2 + 0.6 * k)
	else:
		_ring_mat.albedo_color = Color(1.0, 0.55, 0.2, 0.9)
		_flame.emitting = true
		_burn()
		return
	_flame.emitting = false


func _burn() -> void:
	if _hit_this_burst:
		return
	var player: Player = GameState.player as Player
	if player == null or not is_instance_valid(player):
		return
	var flat: Vector3 = player.global_position - global_position
	flat.y = 0.0
	if flat.length() > RADIUS_M or player.global_position.y - global_position.y > 2.0:
		return
	_hit_this_burst = true
	var info: DamageInfo = DamageInfo.new()
	info.amount = maxi(1, roundi(player.health.max_health * DAMAGE_SHARE))
	info.element = Element.Type.FIRE
	info.hit_position = player.global_position
	player.health.take_damage(info)
