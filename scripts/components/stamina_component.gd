class_name StaminaComponent
extends Node
## Stamina pool with delayed regeneration and an exhausted state after depletion.

signal changed(current: float, maximum: float)
signal depleted

@export var max_stamina: float = 100.0
@export var regen_per_second: float = 28.0
@export var regen_delay_s: float = 0.8
## After hitting 0, stamina must refill to this ratio before it can be spent again.
@export_range(0.0, 1.0, 0.05) var exhausted_recover_ratio: float = 0.3

var current: float = 0.0
var exhausted: bool = false
var _regen_cooldown: float = 0.0


func _ready() -> void:
	reset()


func reset() -> void:
	current = max_stamina
	exhausted = false
	_regen_cooldown = 0.0
	changed.emit(current, max_stamina)


func can_spend() -> bool:
	return not exhausted and current > 0.0


## Spends a fixed amount (e.g. a dodge). Allowed while any stamina is left; clamps at 0.
func try_spend(amount: float) -> bool:
	if not can_spend():
		return false
	_consume(amount)
	return true


## Continuous drain (e.g. sprint). Returns false once stamina can no longer be spent.
func drain(amount_per_second: float, delta: float) -> bool:
	if not can_spend():
		return false
	_consume(amount_per_second * delta)
	return can_spend()


func tick(delta: float) -> void:
	if _regen_cooldown > 0.0:
		_regen_cooldown = maxf(_regen_cooldown - delta, 0.0)
		return
	if current >= max_stamina:
		return
	current = minf(current + regen_per_second * delta, max_stamina)
	if exhausted and current >= max_stamina * exhausted_recover_ratio:
		exhausted = false
	changed.emit(current, max_stamina)


func get_ratio() -> float:
	return current / max_stamina if max_stamina > 0.0 else 0.0


func _consume(amount: float) -> void:
	current = maxf(current - amount, 0.0)
	_regen_cooldown = regen_delay_s
	if current <= 0.0:
		exhausted = true
		depleted.emit()
	changed.emit(current, max_stamina)


func _physics_process(delta: float) -> void:
	tick(delta)
