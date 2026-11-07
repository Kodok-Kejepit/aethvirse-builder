class_name ComboTracker
extends RefCounted
## Hit counter + style rank D → C → B → A → S → SSS (§6). Pure, time passed in by the caller.

enum Rank { NONE, D, C, B, A, S, SSS }

const RANK_THRESHOLDS: Dictionary[Rank, int] = {
	Rank.D: 1, Rank.C: 5, Rank.B: 10, Rank.A: 20, Rank.S: 35, Rank.SSS: 60,
}
const RANK_NAMES: Dictionary[Rank, String] = {
	Rank.NONE: "", Rank.D: "D", Rank.C: "C", Rank.B: "B", Rank.A: "A", Rank.S: "S", Rank.SSS: "SSS",
}
## XP/drop bonus per rank, applied by reward systems in later milestones.
const RANK_BONUS: Dictionary[Rank, float] = {
	Rank.NONE: 1.0, Rank.D: 1.0, Rank.C: 1.05, Rank.B: 1.1, Rank.A: 1.2, Rank.S: 1.35, Rank.SSS: 1.5,
}

var timeout_s: float = 3.0
var count: int = 0
var best: int = 0
var _last_hit_time: float = -INF


func _init(combo_timeout_s: float = 3.0) -> void:
	timeout_s = combo_timeout_s


func register_hit(now: float) -> void:
	if now - _last_hit_time > timeout_s:
		count = 0
	count += 1
	best = maxi(best, count)
	_last_hit_time = now


## Taking damage breaks the combo.
func break_combo() -> void:
	count = 0
	_last_hit_time = -INF


func is_active(now: float) -> bool:
	return count > 0 and now - _last_hit_time <= timeout_s


func get_rank(now: float) -> Rank:
	if not is_active(now):
		return Rank.NONE
	return rank_for_count(count)


static func rank_for_count(hits: int) -> Rank:
	var result: Rank = Rank.NONE
	for rank: Rank in RANK_THRESHOLDS:
		if hits >= RANK_THRESHOLDS[rank]:
			result = rank
	return result
