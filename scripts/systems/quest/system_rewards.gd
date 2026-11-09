class_name SystemRewards
extends RefCounted
## The Codex's own appreciation (owner): every finished mission and every resolved Mystery
## Journal entry pays extra XP and gold scaled to the hero's level, so a full journal page
## carries the hero past the next region's level. A finished page lifts the hero to at
## least the next region's minimum level + PAGE_LEVEL_MARGIN.

## Share of the XP still needed for the next level.
const QUEST_SHARE: float = 0.35
const DAILY_SHARE: float = 0.12
const ENTRY_SHARE: float = 0.8
const QUEST_GOLD_PER_LEVEL: int = 40
const ENTRY_GOLD_PER_LEVEL: int = 120
const PAGE_GOLD: int = 6000
const PAGE_LEVEL_MARGIN: int = 1


static func on_quest(q: QuestData) -> void:
	var prog: Progression = GameState.progression
	if prog == null:
		return
	var share: float = DAILY_SHARE if q.kind == QuestData.Kind.DAILY else QUEST_SHARE
	_pay(roundi(prog.xp_to_next() * share), QUEST_GOLD_PER_LEVEL * prog.level)


static func on_entry() -> void:
	var prog: Progression = GameState.progression
	if prog == null:
		return
	_pay(roundi(prog.xp_to_next() * ENTRY_SHARE), ENTRY_GOLD_PER_LEVEL * prog.level)


## XP that takes the hero from now to `target` level (0 when already there).
static func xp_to_reach(prog: Progression, target: int) -> int:
	if prog.level >= target:
		return 0
	var total: int = prog.xp_to_next() - prog.xp
	for lvl: int in range(prog.level + 1, target):
		total += Progression.xp_needed(lvl, prog.tuning)
	return total


static func on_page(next_region: StringName) -> void:
	var prog: Progression = GameState.progression
	if prog == null:
		return
	var target: int = prog.level
	var region: RegionData = RegionData.load_region(next_region) if next_region != &"" else null
	if region != null:
		target = maxi(target, region.level_min + PAGE_LEVEL_MARGIN)
	_pay(xp_to_reach(prog, target), PAGE_GOLD)


static func _pay(xp: int, gold: int) -> void:
	if xp > 0:
		EventBus.xp_gained.emit(xp)
	if gold > 0:
		EventBus.gold_gained.emit(gold)
	Codex.notify(TranslationServer.translate(&"CODEX_MSG_SYSTEM_REWARD") % [xp, gold], &"reward")
