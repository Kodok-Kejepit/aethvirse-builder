extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var player: Player


func before_each() -> void:
	TimeFx.reset()
	GameState.progression = null
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	player = PLAYER_SCENE.instantiate() as Player
	world.add_child(player)
	await wait_physics_frames(5)


func test_starter_kit() -> void:
	assert_eq(GameState.inventory.get_equipped_item(ItemData.Slot.WEAPON).id, &"issued_greatsword")
	assert_true(GameState.inventory.has(&"rusty_pipe"), "prologue pipe kept")
	assert_true(GameState.inventory.has(&"bread", 3))


func test_weapon_changes_attack() -> void:
	var with_greatsword: float = player.combat.stats.attack
	GameState.inventory.equip(GameState.inventory.first_stack(&"rusty_pipe"))
	await wait_physics_frames(1)
	assert_lt(player.combat.stats.attack, with_greatsword, "pipe is weaker at Lv1")


func test_accessory_bonus_applies_when_identified() -> void:
	var inv: Inventory = GameState.inventory
	inv.add(&"rusted_license")
	inv.equip(inv.first_stack(&"rusted_license"))
	await wait_physics_frames(1)
	var sen_unidentified: float = player.stats.primary.sense
	inv.identify(inv.first_stack(&"rusted_license"), &"appraiser")
	await wait_physics_frames(1)
	assert_eq(player.stats.primary.sense, sen_unidentified + 5.0)


func test_quick_potion_heals() -> void:
	var info: DamageInfo = DamageInfo.new()
	info.amount = 200
	player.health.take_damage(info)
	var before: int = player.health.current
	assert_true(player.items.use_quick_potion())
	assert_gt(player.health.current, before)
	assert_eq(GameState.inventory.count_of(&"potion_small"), 2)


func test_codex_scroll_identifies_with_codex_method() -> void:
	var inv: Inventory = GameState.inventory
	inv.add(&"rusted_license")
	watch_signals(EventBus)
	assert_true(player.items.use(inv.first_stack(&"codex_identify_scroll")))
	assert_eq(inv.first_stack(&"rusted_license").identified_by, &"codex")
	assert_signal_emitted(EventBus, "item_identified")


func test_kills_evolve_pipe() -> void:
	var inv: Inventory = GameState.inventory
	var pipe: ItemStack = inv.first_stack(&"rusty_pipe")
	inv.equip(pipe)
	pipe.kills = 299
	EventBus.enemy_killed.emit(&"gate_husk", Vector3.ZERO)
	assert_eq(pipe.item_id, &"fanged_pipe")
