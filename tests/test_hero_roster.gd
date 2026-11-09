extends GutTest
## One hero per class (owner): Dragon Sovereign = Paladin, Senjakala = Assassin with the
## Meshy dagger rig, Nocturne = Marksman; each hero has its own Codex palette.

var _saved_hero: StringName
var _saved_class: StringName


func before_each() -> void:
	_saved_hero = GameState.hero_id
	_saved_class = GameState.class_id


func after_each() -> void:
	GameState.hero_id = _saved_hero
	GameState.class_id = _saved_class
	CodexTheme.sync_hero()


func test_each_class_has_its_hero() -> void:
	assert_eq(HeroData.hero_for_class(&"vanguard"), &"dragon_maiden")
	assert_eq(HeroData.hero_for_class(&"phantom"), &"senjakala")
	assert_eq(HeroData.hero_for_class(&"ranger"), &"starblade")
	assert_eq(HeroData.hero_for_class(&"arcanist"), &"", "mage still waits for the owner's hero")


func test_senjakala_rig_has_the_dagger_clips() -> void:
	var hero: HeroData = HeroData.load_hero(&"senjakala")
	assert_true(hero.has_rig())
	var model: CharacterModel = CharacterModel.new()
	add_child_autofree(model)
	model.setup(null, CharacterRig.Weapon.DAGGERS, true, hero, 0)
	var body: AnimatedBody = model.animated
	assert_not_null(body)
	for clip: StringName in [&"DaggerCombo", &"DaggerCombo2", &"DaggerThrust", &"BladeSpin", &"IdleAlt", &"Walking", &"Running", &"Jump", &"Dodge", &"KnockDown", &"Dead"]:
		assert_true(body.animation.has_animation(clip), "clip %s" % clip)
	assert_gt(body.springs.get_setting_count(), 4, "the cloak sways on spring chains")


func test_dagger_rig_swings_with_dagger_strikes() -> void:
	var model: CharacterModel = CharacterModel.new()
	add_child_autofree(model)
	model.setup(null, CharacterRig.Weapon.DAGGERS, true, HeroData.load_hero(&"senjakala"), 0)
	var body: AnimatedBody = model.animated
	for swing: int in AnimatedBody.DAGGER_SWINGS.size():
		body.drive(&"attack", swing, 0.5, 0.0, 0.016)
		var move: Array = AnimatedBody.DAGGER_SWINGS[swing]
		var clip: StringName = move[0]
		var t1: float = move[2]
		assert_eq(body.animation.current_animation, clip)
		assert_lt(t1, body.animation.get_animation(clip).length, "segment inside the clip")
	body.drive(&"ultimate", AnimatedBody.SWING_ULTIMATE, 0.5, 0.0, 0.016)
	assert_eq(body.animation.current_animation, &"BladeSpin")


func test_sword_rig_keeps_its_own_swings() -> void:
	var model: CharacterModel = CharacterModel.new()
	add_child_autofree(model)
	model.setup(null, CharacterRig.Weapon.SWORD, true, HeroData.load_hero(&"dragon_maiden"), 0)
	model.animated.drive(&"attack", 0, 0.5, 0.0, 0.016)
	var first: Array = AnimatedBody.SWINGS[0]
	var clip: StringName = first[0]
	assert_eq(model.animated.animation.current_animation, clip)


func test_codex_palette_follows_the_hero() -> void:
	var seen: Array[Color] = []
	for hid: StringName in HeroData.IDS:
		GameState.hero_id = hid
		CodexTheme.sync_hero()
		assert_false(seen.has(CodexTheme.ACCENT), "%s has its own Codex colours" % hid)
		seen.append(CodexTheme.ACCENT)


func test_old_save_with_moved_hero_gets_the_class_hero() -> void:
	GameState.class_id = &"phantom"
	GameState.hero_id = &"starblade"
	GameState._match_hero_to_class()
	assert_eq(GameState.hero_id, &"senjakala")
	GameState.class_id = &"ranger"
	GameState._match_hero_to_class()
	assert_eq(GameState.hero_id, &"starblade")
