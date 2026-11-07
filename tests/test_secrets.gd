extends GutTest
## Mandatory secret data checks (MYSTERY_BIBLE §4 / master prompt §9.5) + condition logic.

var db: SecretDatabase = SecretDatabase.new()


func _translated(key: StringName) -> bool:
	TranslationServer.set_locale("en")
	return tr(key) != String(key)


func test_secrets_loaded() -> void:
	assert_gt(db.secrets.size(), 8, "at least the 9 M5 entries")


func test_every_secret_has_two_hints_and_a_reward() -> void:
	for secret: SecretData in db.secrets.values():
		assert_gte(secret.hints.size(), 2, "%s needs >= 2 hints" % secret.id)
		assert_true(not secret.rewards.is_empty() or not secret.unlocks.is_empty(), "%s gives something" % secret.id)
		assert_false(secret.conditions.is_empty(), "%s has conditions" % secret.id)


func test_text_is_translated() -> void:
	for secret: SecretData in db.secrets.values():
		assert_true(_translated(secret.display_name), "%s name" % secret.id)
		for hint: StringName in secret.hints:
			assert_true(_translated(hint), "%s hint %s" % [secret.id, hint])
		for reward: RewardData in secret.rewards:
			if reward.text != &"":
				assert_true(_translated(reward.text), "%s reward text" % secret.id)
	for lore: LoreData in db.lore.values():
		assert_true(_translated(lore.title) and _translated(lore.text), String(lore.id))


func test_unlocks_and_references_exist() -> void:
	var items: ItemDatabase = ItemDatabase.new()
	for secret: SecretData in db.secrets.values():
		for id: StringName in secret.unlocks:
			assert_true(db.secrets.has(id), "%s unlocks missing %s" % [secret.id, id])
		for c: ConditionData in secret.conditions:
			if c.type == ConditionData.Type.SECRET_FOUND:
				assert_true(db.secrets.has(c.key), "%s depends on missing %s" % [secret.id, c.key])
			if c.type == ConditionData.Type.HAS_ITEM:
				for item_id: StringName in c.values:
					assert_true(items.has(item_id), "%s needs unknown item %s" % [secret.id, item_id])
		for r: RewardData in secret.rewards:
			match r.type:
				RewardData.Type.ITEM:
					assert_true(items.has(r.key), "%s rewards unknown item %s" % [secret.id, r.key])
				RewardData.Type.LORE:
					assert_true(db.lore.has(r.key), "%s rewards unknown lore %s" % [secret.id, r.key])
				RewardData.Type.LOOT_TABLE:
					assert_true(ResourceLoader.exists("res://data/loot_tables/%s.tres" % r.key), String(r.key))
				RewardData.Type.TITLE:
					assert_true(_translated(StringName("TITLE_" + String(r.key).to_upper())), "title %s" % r.key)


func test_no_dependency_cycles() -> void:
	# Edges: secret -> secrets it requires (SECRET_FOUND) and unlocks (unlock -> unlocker).
	var deps: Dictionary[StringName, Array] = {}
	for secret: SecretData in db.secrets.values():
		var list: Array = []
		for c: ConditionData in secret.conditions:
			if c.type == ConditionData.Type.SECRET_FOUND:
				list.append(c.key)
		deps[secret.id] = list
	for start: StringName in deps:
		var stack: Array = [start]
		var seen: Dictionary = {}
		var cyclic: bool = false
		while not stack.is_empty():
			var node: StringName = stack.pop_back()
			for next: StringName in deps.get(node, []):
				if next == start:
					cyclic = true
				elif not seen.has(next):
					seen[next] = true
					stack.append(next)
		assert_false(cyclic, "cycle through %s" % start)


func test_regions_have_totals() -> void:
	var r1: RegionData = db.regions.get(&"r1_ashfall", null)
	assert_not_null(r1)
	assert_eq(r1.secret_total, 13)
	assert_eq(r1.mission_total, 3)


func test_conditions() -> void:
	var ctx: SecretContext = SecretContext.new()
	ctx.weather = &"rain"
	ctx.areas = [&"pump"]
	ctx.idle_s = 11.0
	ctx.hour = 23
	ctx.is_night = true
	ctx.counters = {&"fed": 3}
	assert_true(ConditionData.make(ConditionData.Type.WEATHER, &"", 0.0, [&"rain", &"storm"]).evaluate(ctx))
	assert_true(ConditionData.make(ConditionData.Type.IN_AREA, &"pump").evaluate(ctx))
	assert_false(ConditionData.make(ConditionData.Type.IN_AREA, &"roof").evaluate(ctx))
	assert_true(ConditionData.make(ConditionData.Type.IDLE_SECONDS, &"", 10.0).evaluate(ctx))
	assert_true(ConditionData.make(ConditionData.Type.COUNTER_AT_LEAST, &"fed", 3.0).evaluate(ctx))
	assert_true(ConditionData.make(ConditionData.Type.IS_NIGHT).evaluate(ctx))
	var c: ConditionData = ConditionData.make(ConditionData.Type.HOUR_RANGE, &"", 22.0)
	c.value2 = 2.0
	assert_true(c.evaluate(ctx), "22:00–02:00 wraps midnight")
	var negated: ConditionData = ConditionData.make(ConditionData.Type.FLAG, &"marrow_attacked")
	negated.negate = true
	assert_true(negated.evaluate(ctx))


func test_has_item_identified_by() -> void:
	var inv: Inventory = Inventory.new(ItemDatabase.new())
	inv.add(&"rusted_license")
	var ctx: SecretContext = SecretContext.new()
	ctx.inventory = inv
	var honest: ConditionData = ConditionData.make(ConditionData.Type.HAS_ITEM, &"appraiser", 0.0, [&"rusted_license"])
	assert_false(honest.evaluate(ctx), "not identified yet")
	inv.identify(inv.first_stack(&"rusted_license"), &"appraiser")
	assert_true(honest.evaluate(ctx))


func test_daily_streak() -> void:
	var s: SecretState = SecretState.new()
	assert_eq(s.record_daily(&"fed", 1), 1)
	assert_eq(s.record_daily(&"fed", 1), 1, "same day does not count twice")
	assert_eq(s.record_daily(&"fed", 2), 2)
	assert_eq(s.record_daily(&"fed", 3), 3)
	assert_eq(s.record_daily(&"fed", 5), 1, "skipped a day → restart")


func test_secret_state_roundtrip() -> void:
	var s: SecretState = SecretState.new()
	s.found[&"SEC-R1-01"] = true
	s.record_daily(&"fed", 4)
	s.add_hint(&"SEC-R1-02", &"HINT_SEC_R1_02_1")
	s.lore.append(&"LORE-R1-01")
	s.titles.append(&"listener")
	s.notes = "pump room + rain?"
	var copy: SecretState = SecretState.new()
	var data: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	copy.load_dict(data)
	assert_true(copy.found.has(&"SEC-R1-01"))
	assert_eq(copy.counters[&"fed"], 1)
	assert_eq(copy.counter_days[&"fed"], 4)
	assert_true(&"HINT_SEC_R1_02_1" in copy.hints[&"SEC-R1-02"])
	assert_eq(copy.lore[0], &"LORE-R1-01")
	assert_eq(copy.notes, "pump room + rain?")
