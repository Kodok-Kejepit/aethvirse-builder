class_name PlayerMovementData
extends Resource
## Movement tuning for the player. Edit data/player/default_movement.tres to tune feel.

@export_group("Ground")
@export var walk_speed: float = 2.2
@export var run_speed: float = 5.5
@export var sprint_speed: float = 8.5
## Analog stick magnitude below this walks, above it runs (keyboard always runs).
@export_range(0.0, 1.0, 0.05) var walk_threshold: float = 0.55
@export var acceleration: float = 45.0
@export var deceleration: float = 55.0
@export var turn_speed: float = 14.0

@export_group("Air")
@export var jump_height: float = 1.4
@export var fall_gravity_multiplier: float = 1.8
## Releasing jump while rising multiplies vertical speed by this (variable jump height).
@export_range(0.0, 1.0, 0.05) var jump_cut_multiplier: float = 0.5
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.35
@export var max_fall_speed: float = 40.0
@export var coyote_time_s: float = 0.12

@export_group("Dodge")
@export var dodge_speed: float = 13.0
@export var dodge_end_speed: float = 4.0
@export var dodge_duration_s: float = 0.38
@export var dodge_iframe_s: float = 0.3
## Fraction of the dodge after which jump / a new dodge may cancel it.
@export_range(0.0, 1.0, 0.05) var dodge_cancel_ratio: float = 0.6
@export var dodge_stamina_cost: float = 20.0

@export_group("Stamina & input")
@export var sprint_stamina_per_second: float = 18.0
@export var input_buffer_s: float = 0.2
