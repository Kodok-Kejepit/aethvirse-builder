class_name ManaComponent
extends Node
## MP pool with constant regeneration.

signal changed(current: float, maximum: float)

@export var max_mana: float = 100.0
@export var regen_per_second: float = 2.0

var current: float = 0.0


func _ready() -> void:
	current = max_mana
	changed.emit(current, max_mana)


func set_max(value: float, fill: bool) -> void:
	max_mana = maxf(value, 1.0)
	current = max_mana if fill else minf(current, max_mana)
	changed.emit(current, max_mana)


func can_pay(cost: float) -> bool:
	return current >= cost


func try_pay(cost: float) -> bool:
	if not can_pay(cost):
		return false
	current -= cost
	changed.emit(current, max_mana)
	return true


func refill() -> void:
	current = max_mana
	changed.emit(current, max_mana)


func tick(delta: float) -> void:
	if current >= max_mana:
		return
	current = minf(current + regen_per_second * delta, max_mana)
	changed.emit(current, max_mana)


func _physics_process(delta: float) -> void:
	tick(delta)
