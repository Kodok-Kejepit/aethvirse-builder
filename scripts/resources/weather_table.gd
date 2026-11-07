class_name WeatherTable
extends Resource
## Per-region weather weights and how long each weather lasts (game minutes).

@export var weights: Dictionary[StringName, float] = {&"clear": 60.0, &"rain": 25.0, &"fog": 10.0, &"storm": 5.0}
@export var min_duration_minutes: float = 120.0
@export var max_duration_minutes: float = 360.0


func pick(rng: RandomNumberGenerator, exclude: StringName = &"") -> StringName:
	var total: float = 0.0
	for id: StringName in weights:
		if id != exclude:
			total += weights[id]
	if total <= 0.0:
		return &"clear"
	var roll: float = rng.randf() * total
	for id: StringName in weights:
		if id == exclude:
			continue
		roll -= weights[id]
		if roll <= 0.0:
			return id
	return weights.keys()[0]
