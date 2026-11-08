class_name PlayerAura
extends OmniLight3D
## Soft light around the hero (owner: nights were too dark to see her). Fades in after
## dusk and stays on inside Gates and the metro; no shadows, one light, phone-friendly.

const RANGE_M: float = 9.0
const NIGHT_ENERGY: float = 1.1
const INSIDE_ENERGY: float = 0.8


func _ready() -> void:
	# High above her so the ground around is lit, not just her head.
	position = Vector3(0.0, 3.4, 0.0)
	light_color = Color(1.0, 0.93, 0.82)
	omni_range = RANGE_M
	omni_attenuation = 0.8
	shadow_enabled = false
	light_specular = 0.2


func _process(_delta: float) -> void:
	var inside: bool = GameState.gate_session != null or GameState.interior_return != null
	var night: float = 0.0
	if GameState.clock != null:
		night = 1.0 - clampf(sin((GameState.clock.day_fraction() - 0.25) * TAU) * 1.5 + 0.2, 0.0, 1.0)
	light_energy = maxf(NIGHT_ENERGY * night, INSIDE_ENERGY if inside else 0.0)
	visible = light_energy > 0.02
