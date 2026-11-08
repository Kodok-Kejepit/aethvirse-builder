class_name DamageInfo
extends RefCounted
## One resolved hit, passed from hitbox to hurtbox to health.

var amount: int = 0
var is_crit: bool = false
var is_heavy: bool = false
var element: Element.Type = Element.Type.PHYSICAL
var knockback: Vector3 = Vector3.ZERO
## Upward speed on the target (heavy blows send the hero flying).
var launch: float = 0.0
## Poise damage; enough of it staggers the target.
var stagger: float = 0.0
var hit_stop_s: float = 0.0
var hit_position: Vector3 = Vector3.ZERO
var source: Node = null
## True damage ignores DEF (e.g. Eclipse reaction, later milestones).
var ignore_defense: bool = false
