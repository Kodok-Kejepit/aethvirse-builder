class_name WorldClock
extends RefCounted
## Game time. 24 real minutes = 1 game day (§7) → 1 real second = 1 game minute.

const MINUTES_PER_DAY: int = 1440
const REAL_SECONDS_PER_GAME_MINUTE: float = 1.0
const NIGHT_START_HOUR: int = 20
const NIGHT_END_HOUR: int = 5
## New games start on day 1 at 08:00.
const START_MINUTES: float = 8.0 * 60.0

## Total game minutes since day 1, 00:00.
var total_minutes: float = START_MINUTES


func advance(real_seconds: float) -> void:
	total_minutes += real_seconds / REAL_SECONDS_PER_GAME_MINUTE


## Day number, starting at 1.
func day() -> int:
	return floori(total_minutes / MINUTES_PER_DAY) + 1


func minute_of_day() -> float:
	return fposmod(total_minutes, MINUTES_PER_DAY)


func hour() -> int:
	return floori(minute_of_day() / 60.0)


func minute() -> int:
	return floori(minute_of_day()) % 60


func is_night() -> bool:
	var h: int = hour()
	return h >= NIGHT_START_HOUR or h < NIGHT_END_HOUR


## 0 at midnight, 0.5 at noon (for sun rotation).
func day_fraction() -> float:
	return minute_of_day() / MINUTES_PER_DAY


## Jumps forward to the next time the clock shows hh:mm (same day if still ahead).
func set_time_of_day(hh: int, mm: int) -> void:
	var target: float = clampi(hh, 0, 23) * 60.0 + clampi(mm, 0, 59)
	var base: float = total_minutes - minute_of_day()
	total_minutes = base + target if target >= minute_of_day() else base + MINUTES_PER_DAY + target


func is_between(from_hour: int, to_hour: int) -> bool:
	var h: int = hour()
	if from_hour <= to_hour:
		return h >= from_hour and h < to_hour
	return h >= from_hour or h < to_hour


func format() -> String:
	return "%02d:%02d" % [hour(), minute()]
