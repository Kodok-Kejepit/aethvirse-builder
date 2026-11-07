class_name SecretState
extends RefCounted
## Saved mystery progress: found/failed secrets, counters + daily streaks, journal hints,
## lore fragments, titles, the player's own journal notes.

var found: Dictionary[StringName, bool] = {}
var failed: Dictionary[StringName, bool] = {}
var counters: Dictionary[StringName, int] = {}
## counter id -> last game day it was recorded (for daily streaks).
var counter_days: Dictionary[StringName, int] = {}
## secret id -> discovered hint keys.
var hints: Dictionary[StringName, Array] = {}
var lore: Array[StringName] = []
var titles: Array[StringName] = []
var notes: String = ""


func increment(id: StringName, amount: int = 1) -> int:
	counters[id] = counters.get(id, 0) + amount
	return counters[id]


## Daily streak: +1 if last recorded yesterday, unchanged if already today, else restarts at 1.
func record_daily(id: StringName, today: int) -> int:
	var last: int = counter_days.get(id, -100)
	if last == today:
		return counters.get(id, 0)
	counters[id] = counters.get(id, 0) + 1 if last == today - 1 else 1
	counter_days[id] = today
	return counters[id]


func add_hint(secret_id: StringName, hint_key: StringName) -> bool:
	var list: Array = hints.get(secret_id, [])
	if hint_key in list:
		return false
	list.append(hint_key)
	hints[secret_id] = list
	return true


func to_dict() -> Dictionary:
	return {
		"found": _keys(found), "failed": _keys(failed),
		"counters": _str_dict(counters), "counter_days": _str_dict(counter_days),
		"hints": _str_dict(hints), "lore": _names(lore), "titles": _names(titles), "notes": notes,
	}


func load_dict(d: Dictionary) -> void:
	found.clear()
	failed.clear()
	counters.clear()
	counter_days.clear()
	hints.clear()
	lore.clear()
	titles.clear()
	var f: Array = d.get("found", [])
	for id: String in f:
		found[StringName(id)] = true
	var fl: Array = d.get("failed", [])
	for id: String in fl:
		failed[StringName(id)] = true
	var c: Dictionary = d.get("counters", {})
	for k: String in c:
		var v: int = c[k]
		counters[StringName(k)] = v
	var cd: Dictionary = d.get("counter_days", {})
	for k: String in cd:
		var v: int = cd[k]
		counter_days[StringName(k)] = v
	var h: Dictionary = d.get("hints", {})
	for k: String in h:
		var list: Array = []
		var raw: Array = h[k]
		for hint: String in raw:
			list.append(StringName(hint))
		hints[StringName(k)] = list
	var l: Array = d.get("lore", [])
	for id: String in l:
		lore.append(StringName(id))
	var t: Array = d.get("titles", [])
	for id: String in t:
		titles.append(StringName(id))
	var n: String = d.get("notes", "")
	notes = n


static func _keys(d: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k: StringName in d:
		out.append(String(k))
	return out


static func _names(list: Array[StringName]) -> Array[String]:
	var out: Array[String] = []
	for k: StringName in list:
		out.append(String(k))
	return out


static func _str_dict(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: StringName in d:
		var v: Variant = d[k]
		if v is Array:
			var arr: Array[String] = []
			var src: Array = v
			for item: StringName in src:
				arr.append(String(item))
			out[String(k)] = arr
		else:
			out[String(k)] = v
	return out
