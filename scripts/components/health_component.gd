class_name HealthComponent
extends Node
## Hit points. `invulnerable` hits are reported as `dodged` instead of applied.

signal damaged(info: DamageInfo)
signal healed(amount: int)
signal died
signal dodged(info: DamageInfo)
signal changed(current: int, maximum: int)

@export var max_health: int = 100
## Never drops below 1 and refills after a pause (training dummies).
@export var immortal: bool = false
@export var immortal_refill_delay_s: float = 3.0

var current: int = 0
var invulnerable: bool = false
var _since_last_hit: float = 0.0


func _ready() -> void:
	current = max_health
	set_physics_process(immortal)


func is_dead() -> bool:
	return current <= 0


## Returns true if the damage was applied.
func take_damage(info: DamageInfo) -> bool:
	if is_dead():
		return false
	if invulnerable:
		dodged.emit(info)
		return false
	var floor_hp: int = 1 if immortal else 0
	current = maxi(current - info.amount, floor_hp)
	_since_last_hit = 0.0
	damaged.emit(info)
	changed.emit(current, max_health)
	if current <= 0:
		died.emit()
	return true


func heal(amount: int) -> void:
	if is_dead() or amount <= 0:
		return
	var before: int = current
	current = mini(current + amount, max_health)
	if current != before:
		healed.emit(current - before)
		changed.emit(current, max_health)


func revive_full() -> void:
	current = max_health
	changed.emit(current, max_health)


func set_max_health(value: int, refill: bool) -> void:
	max_health = maxi(value, 1)
	current = max_health if refill else mini(current, max_health)
	changed.emit(current, max_health)


func get_ratio() -> float:
	return float(current) / float(max_health) if max_health > 0 else 0.0


func _physics_process(delta: float) -> void:
	_since_last_hit += delta
	if _since_last_hit >= immortal_refill_delay_s and current < max_health:
		revive_full()
