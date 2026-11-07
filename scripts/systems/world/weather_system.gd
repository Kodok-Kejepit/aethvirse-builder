class_name WeatherSystem
extends RefCounted
## Current weather and when it changes (in game minutes). Region decides the table.

const CLEAR: StringName = &"clear"
const RAIN: StringName = &"rain"
const FOG: StringName = &"fog"
const STORM: StringName = &"storm"
const WET: Array[StringName] = [RAIN, STORM]

var current: StringName = CLEAR
var table: WeatherTable = WeatherTable.new()
## Game-minute timestamp when the weather changes next.
var change_at: float = 0.0
## When true (cheat), weather never changes by itself.
var locked: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


## Returns true if the weather changed.
func update(now_minutes: float) -> bool:
	if locked or now_minutes < change_at:
		return false
	var next: StringName = table.pick(rng, current)
	change_at = now_minutes + rng.randf_range(table.min_duration_minutes, table.max_duration_minutes)
	if next == current:
		return false
	current = next
	return true


func force(weather: StringName, now_minutes: float, lock: bool) -> void:
	current = weather
	locked = lock
	change_at = now_minutes + table.max_duration_minutes


func is_wet() -> bool:
	return current in WET
