class_name DialogRunner
extends RefCounted
## Pure dialog logic: pick entry, resolve lines, filter choices, apply effects.

var tracker: SecretTracker


func _init(secret_tracker: SecretTracker) -> void:
	tracker = secret_tracker


func pick_entry(npc: NpcData, ctx: SecretContext) -> DialogEntry:
	for entry: DialogEntry in npc.entries:
		if ConditionData.all_true(entry.conditions, ctx):
			return entry
	return null


static func lines_for(entry: DialogEntry, day: int) -> Array[StringName]:
	var out: Array[StringName] = []
	if not entry.daily_variants.is_empty():
		out.append(entry.daily_variants[posmod(day, entry.daily_variants.size())])
	out.append_array(entry.lines)
	return out


static func available_choices(entry: DialogEntry, ctx: SecretContext, gold: int) -> Array[DialogChoice]:
	var out: Array[DialogChoice] = []
	for choice: DialogChoice in entry.choices:
		if gold >= choice.gold_cost and ConditionData.all_true(choice.conditions, ctx):
			out.append(choice)
	return out


func choose(choice: DialogChoice) -> void:
	if choice.gold_cost > 0:
		GameState.gold = maxi(GameState.gold - choice.gold_cost, 0)
	apply(choice.effects)


func apply(effects: Array[DialogEffect]) -> void:
	for e: DialogEffect in effects:
		match e.type:
			DialogEffect.Type.GIVE_ITEM:
				GameState.inventory.add(e.key, e.amount)
			DialogEffect.Type.TAKE_ITEM:
				GameState.inventory.remove(e.key, e.amount)
			DialogEffect.Type.GIVE_GOLD:
				EventBus.gold_gained.emit(e.amount)
			DialogEffect.Type.TAKE_GOLD:
				GameState.gold = maxi(GameState.gold - e.amount, 0)
			DialogEffect.Type.SET_FLAG:
				GameState.set_flag(e.key)
			DialogEffect.Type.COMPLETE_SECRET:
				if tracker != null:
					tracker.complete(e.key)
			DialogEffect.Type.HINT:
				if tracker != null:
					tracker.discover_hint(e.key, e.text)
			DialogEffect.Type.RECORD_DAILY:
				GameState.secrets.record_daily(e.key, GameState.clock.day())
			DialogEffect.Type.IDENTIFY:
				var stack: ItemStack = GameState.inventory.first_stack(e.key)
				if stack != null and not stack.identified:
					GameState.inventory.identify(stack, e.text)
					EventBus.item_identified.emit(e.key, e.text)
