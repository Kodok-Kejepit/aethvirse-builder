class_name AttackData
extends Resource
## One attack in a combo graph. Timings are seconds from the start of the attack.

enum Swing { HORIZONTAL, VERTICAL, SPIN, THRUST }

@export var id: StringName = &""
@export var display_name: String = ""
@export var damage_multiplier: float = 1.0
@export var is_heavy: bool = false
@export var element: Element.Type = Element.Type.PHYSICAL

@export_group("Timing")
@export var startup_s: float = 0.1
@export var active_s: float = 0.12
@export var recovery_s: float = 0.25
## After this time the next combo input is accepted (and buffered input fires).
@export var combo_window_s: float = 0.22
## After this time a dodge can cancel the attack.
@export var dodge_cancel_s: float = 0.2

@export_group("Hit")
@export var hitbox_size: Vector3 = Vector3(2.2, 1.4, 1.8)
@export var hitbox_offset: Vector3 = Vector3(0.0, 1.0, -1.1)
@export var knockback: float = 2.0
@export var stagger: float = 10.0
@export var hit_stop_s: float = 0.05
@export var lunge_speed: float = 3.0
@export var swing: Swing = Swing.HORIZONTAL

## Ranged attack: spawns this at the start of the active window instead of using the melee hitbox.
@export var projectile: ProjectileData

@export_group("Combo graph")
@export var next_light: AttackData
@export var next_heavy: AttackData


func get_total_s() -> float:
	return startup_s + active_s + recovery_s
