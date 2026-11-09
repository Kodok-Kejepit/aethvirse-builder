class_name HurtboxComponent
extends Area3D
## Receives hits. Defense numbers come from `stats`; damage goes to `health`.

signal hit_received(info: DamageInfo)

@export var health: HealthComponent
@export var stats: CombatStats
## Node that owns this hurtbox (player / enemy root). Used to ignore self-hits.
@export var body: Node3D


func _ready() -> void:
	monitoring = false
	monitorable = true


func receive(info: DamageInfo) -> bool:
	var applied: bool = health.take_damage(info) if health != null else false
	if applied and info.poison_chance > 0.0:
		PoisonEffect.try_apply(self, info.poison_chance, info.poison_share, info.poison_s)
	hit_received.emit(info)
	return applied
