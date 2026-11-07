class_name GuildRank
extends RefCounted
## Hunter guild rank E → S from guild points (Gates, quests, bounties). Gates may require a rank.

enum Rank { E, D, C, B, A, S }

const THRESHOLDS: Array[int] = [0, 100, 300, 700, 1500, 3000]
const NAMES: Array[String] = ["E", "D", "C", "B", "A", "S"]


static func rank_for(points: int) -> Rank:
	var r: int = 0
	for i: int in THRESHOLDS.size():
		if points >= THRESHOLDS[i]:
			r = i
	return r as Rank


static func current() -> Rank:
	return rank_for(GameState.guild_points)


static func add_points(amount: int) -> void:
	var before: Rank = current()
	GameState.guild_points += amount
	var after: Rank = current()
	if after != before:
		Codex.notify(TranslationServer.translate(&"CODEX_MSG_GUILD_RANK") % NAMES[after], &"level_up")
		EventBus.guild_rank_changed.emit(after)
