extends GutTest
## Data validation for every class in data/classes (catches broken .tres edits).

const CLASS_DIR: String = "res://data/classes/"


func _classes() -> Array[ClassData]:
	var result: Array[ClassData] = []
	for file: String in DirAccess.get_files_at(CLASS_DIR):
		if file.ends_with(".tres"):
			result.append(load(CLASS_DIR + file) as ClassData)
	return result


func test_classes_exist() -> void:
	assert_gt(_classes().size(), 0)


func test_class_data_is_complete() -> void:
	for c: ClassData in _classes():
		assert_not_null(c.base_stats, "%s base" % c.id)
		assert_not_null(c.growth, "%s growth" % c.id)
		assert_not_null(c.combo, "%s combo" % c.id)
		var split: StatBlock = c.recommended_split
		var total: float = split.strength + split.agility + split.intelligence + split.vitality + split.sense
		assert_almost_eq(total, 1.0, 0.001, "%s split sums to 1" % c.id)


func test_skills_are_valid() -> void:
	for c: ClassData in _classes():
		var ids: Array[StringName] = []
		var ultimates: int = 0
		for skill: SkillData in c.skills:
			assert_false(skill.id in ids, "%s duplicate skill id %s" % [c.id, skill.id])
			ids.append(skill.id)
			if skill.is_ultimate:
				ultimates += 1
			if skill.kind != SkillData.Kind.BUFF and not skill.is_passive():
				assert_not_null(skill.attack, "%s needs attack data" % skill.id)
			assert_gt(skill.cooldown_s, 0.0, skill.id)
			assert_between(skill.unlock_level, 1, 100, skill.id)
		assert_eq(ultimates, 1, "%s has exactly one ultimate" % c.id)
		for combo: SkillComboData in c.skill_combos:
			assert_true(combo.first in ids and combo.second in ids, "%s combo refers to real skills" % combo.id)


func test_skill_combo_window() -> void:
	var combo: SkillComboData = SkillComboData.new()
	combo.first = &"a"
	combo.second = &"b"
	combo.window_s = 2.0
	assert_true(combo.matches(&"a", 1.0, &"b"))
	assert_false(combo.matches(&"a", 3.0, &"b"), "too late")
	assert_false(combo.matches(&"b", 1.0, &"a"), "wrong order")


func test_skill_level_scaling() -> void:
	var s: SkillData = SkillData.new()
	s.damage_multiplier = 2.0
	s.multiplier_per_level = 0.1
	assert_almost_eq(s.multiplier_at(1), 2.0, 0.0001)
	assert_almost_eq(s.multiplier_at(10), 2.9, 0.0001)
