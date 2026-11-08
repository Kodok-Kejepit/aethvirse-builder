class_name EnemyRanged
extends RefCounted
## Ranged enemies (EnemyData.ranged): sight line, leading aim and the shot itself.
## The sight line follows the hero through the windup, then freezes for AIM_LOCK_S before
## the shot — that is the moment to dash aside.

const AIM_LOCK_S: float = 0.25
const MUZZLE_HEIGHT: float = 1.35
const CHEST_HEIGHT: float = 1.1
const SHOT_RADIUS: float = 0.16
const LINE_WIDTH: float = 0.035
const WORLD_MASK: int = 1


## Where to aim: the hero's chest, led by their velocity over the shot's flight time.
static func aim_point(from: Vector3, target: Node3D, speed: float, lead: float) -> Vector3:
	var point: Vector3 = target.global_position + Vector3.UP * CHEST_HEIGHT
	var body: CharacterBody3D = target as CharacterBody3D
	if body == null or speed <= 0.0:
		return point
	var flight: float = from.distance_to(point) / speed
	var v: Vector3 = body.velocity
	v.y = 0.0
	return point + v * flight * lead


static func muzzle(enemy: Enemy) -> Vector3:
	return enemy.global_position + Vector3.UP * MUZZLE_HEIGHT + enemy.get_facing() * 0.5


## True when nothing solid stands between the enemy and the point.
static func clear_shot(enemy: Enemy, point: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = enemy.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(muzzle(enemy), point, WORLD_MASK, [enemy.get_rid()])
	return space.intersect_ray(query).is_empty()


static func fire(enemy: Enemy, point: Vector3) -> void:
	var d: EnemyData = enemy.data
	var shot: ProjectileData = ProjectileData.new()
	shot.speed = d.projectile_speed
	shot.range_m = d.attack_range * 1.6
	shot.radius = SHOT_RADIUS
	shot.color = d.projectile_color
	var from: Vector3 = muzzle(enemy)
	Projectile.fire(enemy.get_parent(), from, (point - from).normalized(), shot, enemy.build_damage_for,
		enemy, null, Projectile.PLAYER_HURTBOX_MASK)


## Thin glowing line from the muzzle to the aim point; brighter as the shot nears.
static func update_line(line: MeshInstance3D, from: Vector3, to: Vector3, progress: float, locked: bool) -> void:
	var length: float = from.distance_to(to)
	if length < 0.1:
		line.visible = false
		return
	line.visible = true
	var box: BoxMesh = line.mesh as BoxMesh
	box.size = Vector3(LINE_WIDTH, LINE_WIDTH, length)
	line.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from.lerp(to, 0.5))
	var mat: StandardMaterial3D = line.material_override as StandardMaterial3D
	mat.albedo_color = Color(1.0, 0.15 if locked else 0.35, 0.1, 0.25 + 0.6 * progress)


static func make_line() -> MeshInstance3D:
	var line: MeshInstance3D = MeshInstance3D.new()
	line.mesh = BoxMesh.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.25, 0.1)
	mat.emission_energy_multiplier = 2.0
	line.material_override = mat
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line.top_level = true
	line.visible = false
	return line
