class_name Projectile
extends Area3D
## A moving (or waiting) hit volume. Damage comes from the owner's damage_builder,
## like HitboxComponent, so crits/elements/combos work the same.

const WORLD_MASK: int = 1
const ENEMY_HURTBOX_MASK: int = 16

var data: ProjectileData
var direction: Vector3 = Vector3.FORWARD
var damage_builder: Callable
var source: Node3D
var homing_target: Node3D = null

var _age: float = 0.0
var _pierce_left: int = 0
var _already_hit: Array[HurtboxComponent] = []
var _done: bool = false


static func fire(parent: Node, from: Vector3, dir: Vector3, projectile: ProjectileData, builder: Callable,
		owner_body: Node3D, target: Node3D = null) -> Array[Projectile]:
	var out: Array[Projectile] = []
	var count: int = maxi(projectile.count, 1)
	for i: int in count:
		var angle: float = 0.0
		if count > 1:
			angle = deg_to_rad(lerpf(-projectile.spread_degrees * 0.5, projectile.spread_degrees * 0.5, float(i) / float(count - 1)))
		var p: Projectile = Projectile.new()
		p.data = projectile
		p.direction = dir.rotated(Vector3.UP, angle).normalized()
		p.damage_builder = builder
		p.source = owner_body
		p.homing_target = target if projectile.homing else null
		p.position = from
		parent.add_child(p)
		out.append(p)
	return out


func _ready() -> void:
	collision_layer = 0
	collision_mask = ENEMY_HURTBOX_MASK | WORLD_MASK
	monitoring = true
	monitorable = false
	_pierce_left = data.pierce
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = data.radius
	shape.shape = sphere
	add_child(shape)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = data.radius
	sm.height = data.radius * 2.0
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = data.color
	sm.material = material
	mesh.mesh = sm
	add_child(mesh)
	body_entered.connect(func(_body: Node3D) -> void:
		if data.speed > 0.0:
			_finish())


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	if homing_target != null and is_instance_valid(homing_target):
		var to: Vector3 = (homing_target.global_position + Vector3.UP - global_position).normalized()
		direction = direction.slerp(to, clampf(data.homing_turn_speed * delta, 0.0, 1.0)).normalized()
	global_position += direction * data.speed * delta
	for area: Area3D in get_overlapping_areas():
		var target: HurtboxComponent = area as HurtboxComponent
		if target == null or target in _already_hit or target.body == source:
			continue
		if data.explode_radius > 0.0:
			_finish()
			return
		_hit(target)
		if _pierce_left < 0:
			_finish()
			return
	if _age >= data.get_lifetime():
		_finish()


func _hit(target: HurtboxComponent) -> void:
	_already_hit.append(target)
	_pierce_left -= 1
	if not damage_builder.is_valid():
		return
	var info: DamageInfo = damage_builder.call(target)
	info.source = source
	info.hit_position = target.global_position
	var applied: bool = target.receive(info)
	EventBus.projectile_hit.emit(target, info, applied)


func _finish() -> void:
	if _done:
		return
	_done = true
	if data.explode_radius > 0.0:
		for node: Node in get_tree().get_nodes_in_group(LockOnTargeter.GROUP):
			var body: Node3D = node as Node3D
			if body == null or body.global_position.distance_to(global_position) > data.explode_radius:
				continue
			var hurtbox: HurtboxComponent = body.get_node_or_null(^"Hurtbox") as HurtboxComponent
			if hurtbox == null:
				hurtbox = body.find_child("Hurtbox", true, false) as HurtboxComponent
			if hurtbox != null and not hurtbox in _already_hit:
				_hit(hurtbox)
	queue_free()
