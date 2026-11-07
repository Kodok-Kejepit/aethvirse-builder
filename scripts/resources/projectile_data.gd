class_name ProjectileData
extends Resource
## Ranged hit: arrows, bolts, orbs, traps (speed 0 = stays where placed until triggered).

@export var speed: float = 28.0
@export var range_m: float = 30.0
@export var radius: float = 0.3
## Enemies it can pass through after the first hit (0 = stops at the first).
@export var pierce: int = 0
## > 0: explodes on impact / end, hitting everything in this radius.
@export var explode_radius: float = 0.0
## Several projectiles fanned out over spread_degrees.
@export var count: int = 1
@export var spread_degrees: float = 0.0
## Turns toward the lock-on target.
@export var homing: bool = false
@export var homing_turn_speed: float = 6.0
## For traps (speed 0): how long they wait.
@export var lifetime_s: float = 0.0
@export var color: Color = Color(0.7, 0.9, 1.0)


func get_lifetime() -> float:
	if lifetime_s > 0.0:
		return lifetime_s
	return range_m / maxf(speed, 0.01)
