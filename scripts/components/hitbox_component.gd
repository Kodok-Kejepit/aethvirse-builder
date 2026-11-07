class_name HitboxComponent
extends Area3D
## Deals hits to overlapping hurtboxes while active; each hurtbox is hit once per activation.
## The owner supplies `damage_builder` (Callable(target: HurtboxComponent) -> DamageInfo).

signal hit_landed(target: HurtboxComponent, info: DamageInfo, applied: bool)

@export var body: Node3D
@export var debug_mesh: MeshInstance3D

var damage_builder: Callable
var _active: bool = false
var _already_hit: Array[HurtboxComponent] = []


func _ready() -> void:
	monitoring = true
	monitorable = false
	_set_debug_visible(false)


func activate() -> void:
	_active = true
	_already_hit.clear()
	_set_debug_visible(true)


func deactivate() -> void:
	_active = false
	_set_debug_visible(false)


func is_active() -> bool:
	return _active


func _physics_process(_delta: float) -> void:
	if not _active or not damage_builder.is_valid():
		return
	for area: Area3D in get_overlapping_areas():
		var target: HurtboxComponent = area as HurtboxComponent
		if target == null or target in _already_hit or target.body == body:
			continue
		_already_hit.append(target)
		var info: DamageInfo = damage_builder.call(target)
		info.source = body
		info.hit_position = target.global_position
		var applied: bool = target.receive(info)
		hit_landed.emit(target, info, applied)


## Hitbox boxes only show while the F3 debug overlay is open.
func _set_debug_visible(value: bool) -> void:
	if debug_mesh == null:
		return
	var overlay: CanvasLayer = get_tree().root.get_node_or_null(^"DebugOverlay") as CanvasLayer
	debug_mesh.visible = value and overlay != null and overlay.visible
