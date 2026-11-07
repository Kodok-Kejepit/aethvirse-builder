extends Label
## HUD: "Day N  HH:MM  · weather".

const WEATHER_KEYS: Dictionary[StringName, StringName] = {
	&"clear": &"WEATHER_CLEAR", &"rain": &"WEATHER_RAIN", &"fog": &"WEATHER_FOG", &"storm": &"WEATHER_STORM",
}

var _last_minute: int = -1


func _process(_delta: float) -> void:
	var clock: WorldClock = GameState.clock
	var stamp: int = floori(clock.total_minutes)
	if stamp == _last_minute:
		return
	_last_minute = stamp
	var weather_key: StringName = WEATHER_KEYS.get(GameState.weather.current, &"WEATHER_CLEAR")
	text = "%s %d   %s   %s" % [tr(&"HUD_DAY"), clock.day(), clock.format(), tr(weather_key)]
