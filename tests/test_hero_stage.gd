extends GutTest
## Hero preview stage (character select, Codex → Status): builds the hero and plays
## skill previews back to idle.

var _stage: HeroStage


func before_each() -> void:
	_stage = HeroStage.new()
	_stage.size = Vector2(400, 560)
	add_child_autofree(_stage)
	_stage.show_hero(&"dragon_maiden", &"vanguard", false)


func test_shows_the_hero() -> void:
	assert_not_null(_stage.model)
	assert_not_null(_stage.model.rig.weapon_tip, "class weapon in hand")


func test_skill_preview_plays_then_returns_to_idle() -> void:
	var skill: SkillData = load("res://data/skills/vanguard/earthsplitter.tres") as SkillData
	if skill == null:
		skill = SkillData.new()
		skill.kind = SkillData.Kind.AOE
	_stage.preview_skill(skill)
	assert_true(_stage.is_previewing())
	assert_ne(_stage.model.forced_pose, &"idle")
	await wait_seconds(HeroStage.PREVIEW_S + 0.3)
	assert_false(_stage.is_previewing())
	assert_eq(_stage.model.forced_pose, &"idle")
	assert_lt(_stage.model.forced_progress, 0.0)


func test_every_skill_kind_has_a_pose() -> void:
	for kind: int in SkillData.Kind.values():
		var s: SkillData = SkillData.new()
		s.kind = kind as SkillData.Kind
		_stage.preview_skill(s)
		assert_true(_stage.model.forced_pose in CharacterPoses.NAMES, "kind %d" % kind)


func test_render_size_is_clamped() -> void:
	_stage.size = Vector2(40000, 30000)
	var vp: SubViewport = _stage.get_child(0) as SubViewport
	assert_lte(vp.size.x, HeroStage.MAX_PX)
	assert_lte(vp.size.y, HeroStage.MAX_PX)
