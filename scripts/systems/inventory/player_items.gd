class_name PlayerItems
extends Node
## Player-side item behaviour: using items, quick potion, equipment effects
## (stat bonuses via StatsComponent, lifesteal, curses), evolving weapons.

const QUICK_POTION_ACTION: StringName = &"use_potion"
const OUT_OF_COMBAT_S: float = 5.0
## New game kit (the rusty pipe is the prologue weapon — keep it!). Weapon depends on class.
const STARTER_WEAPON: Dictionary[StringName, StringName] = {
	&"vanguard": &"issued_greatsword", &"phantom": &"issued_daggers",
	&"arcanist": &"issued_staff", &"ranger": &"issued_bow",
}
const STARTER_BAG: Dictionary[StringName, int] = {
	&"rusty_pipe": 1, &"bread": 3, &"potion_small": 3, &"codex_identify_scroll": 1,
}

@export var player: Player

var _since_combat: float = 999.0
var _curse_timer: float = 0.0
var _potion_was_down: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	# Player's @onready references are set after children are ready.
	_connect.call_deferred()


func _connect() -> void:
	EventBus.enemy_killed.connect(_on_enemy_killed)
	player.combat.hitbox.hit_landed.connect(_on_hit_landed)
	player.health.damaged.connect(func(_info: DamageInfo) -> void: _since_combat = 0.0)
	GameState.inventory.changed.connect(func() -> void: player.stats.recompute(false))


static func give_starter_kit(inventory: Inventory, class_id: StringName = &"vanguard") -> void:
	for id: StringName in STARTER_BAG:
		inventory.add(id, STARTER_BAG[id])
	var weapon: StringName = STARTER_WEAPON.get(class_id, &"issued_greatsword")
	inventory.add(weapon, 1)
	inventory.equip(inventory.first_stack(weapon))


func _physics_process(delta: float) -> void:
	_since_combat += delta
	var down: bool = Input.is_action_pressed(QUICK_POTION_ACTION)
	if down and not _potion_was_down:
		use_quick_potion()
	_potion_was_down = down
	_tick_curse(delta)


func use(stack: ItemStack) -> bool:
	var inv: Inventory = GameState.inventory
	var item: ItemData = inv.db.get_item(stack.item_id)
	if item == null or not item.is_usable():
		return false
	if item.kind == ItemData.Kind.CONSUMABLE and GameState.gate_session != null and GameState.gate_session.has_rule(&"no_potions"):
		Codex.notify(tr(&"GATE_RULE_NO_POTIONS"), &"anomaly")
		return false
	if item.opens_mystery_box:
		var result: Dictionary = ItemActions.open_mystery_box(GameState.inventory, stack, GameState.progression.level, _rng)
		var steps: Array[int] = result["steps"]
		var names: PackedStringArray = []
		for tier: int in steps:
			names.append(tr(StringName("RARITY_%d" % tier)))
		var got: ItemStack = result["item"]
		Codex.notify(tr(&"CODEX_MSG_BOX") % [" → ".join(names), GameState.inventory.display_name(got)],
			&"anomaly" if steps[steps.size() - 1] == ItemData.Rarity.UNKNOWN else &"reward")
		var got_key: bool = result.get("key", false)
		if got_key:
			Codex.notify(tr(&"CODEX_MSG_GOT_GATE_KEY"), &"anomaly")
		return true
	if item.identifies_items:
		var target: ItemStack = _first_unidentified()
		if target == null:
			Codex.notify(tr(&"CODEX_MSG_NOTHING_TO_IDENTIFY"), &"warning")
			return false
		inv.identify(target, &"codex")
		inv.remove(stack.item_id)
		Codex.notify(tr(&"CODEX_MSG_IDENTIFIED") % inv.display_name(target), &"info")
		EventBus.item_identified.emit(target.item_id, &"codex")
		return true
	if item.heal_amount > 0:
		player.health.heal(item.heal_amount)
	if item.mana_amount > 0:
		player.mana.current = minf(player.mana.current + item.mana_amount, player.mana.max_mana)
	inv.remove(stack.item_id)
	EventBus.item_used.emit(stack.item_id)
	return true


func use_quick_potion() -> bool:
	for stack: ItemStack in GameState.inventory.stacks:
		var item: ItemData = GameState.inventory.db.get_item(stack.item_id)
		if item != null and item.kind == ItemData.Kind.CONSUMABLE and item.heal_amount > 0:
			return use(stack)
	return false


## Sum of a bonus key over all equipped (identified) items.
static func equipment_bonus(inv: Inventory, key: StringName) -> float:
	var total: float = 0.0
	for stack: ItemStack in inv.equipped.values():
		var item: ItemData = inv.db.get_item(stack.item_id)
		if item != null and stack.identified:
			total += ItemStats.bonus(stack, item, key)
	return total


static func weapon_attack(inv: Inventory, level: int) -> float:
	var stack: ItemStack = inv.get_equipped(ItemData.Slot.WEAPON)
	var weapon: ItemData = inv.get_equipped_item(ItemData.Slot.WEAPON)
	return ItemStats.attack(stack, weapon, level) if weapon != null else 0.0


static func equipment_defense(inv: Inventory) -> float:
	var total: float = 0.0
	for stack: ItemStack in inv.equipped.values():
		var item: ItemData = inv.db.get_item(stack.item_id)
		if item != null:
			total += ItemStats.defense(stack, item)
	return total


func _first_unidentified() -> ItemStack:
	for stack: ItemStack in GameState.inventory.stacks:
		if not stack.identified:
			return stack
	return null


func _on_hit_landed(_target: HurtboxComponent, info: DamageInfo, applied: bool) -> void:
	if not applied:
		return
	_since_combat = 0.0
	var lifesteal: float = equipment_bonus(GameState.inventory, &"lifesteal")
	if lifesteal > 0.0:
		player.health.heal(maxi(1, roundi(info.amount * lifesteal)))


func _tick_curse(delta: float) -> void:
	var weapon_stack: ItemStack = GameState.inventory.get_equipped(ItemData.Slot.WEAPON)
	var weapon: ItemData = GameState.inventory.get_equipped_item(ItemData.Slot.WEAPON)
	if weapon == null or weapon_stack == null or not weapon.cursed or _since_combat < OUT_OF_COMBAT_S:
		_curse_timer = 0.0
		return
	_curse_timer += delta
	if _curse_timer < weapon.curse_interval_s:
		return
	_curse_timer = 0.0
	var loss: int = maxi(1, roundi(player.health.max_health * weapon.curse_hp_fraction))
	if player.health.current - loss >= 1:
		var info: DamageInfo = DamageInfo.new()
		info.amount = loss
		player.health.take_damage(info)
		_since_combat = OUT_OF_COMBAT_S


func _on_enemy_killed(_enemy_id: StringName, _position: Vector3) -> void:
	var inv: Inventory = GameState.inventory
	var stack: ItemStack = inv.get_equipped(ItemData.Slot.WEAPON)
	var item: ItemData = inv.get_equipped_item(ItemData.Slot.WEAPON)
	if stack == null or item == null or item.evolve_kills <= 0 or item.evolves_into == &"":
		return
	stack.kills += 1
	if stack.kills >= item.evolve_kills:
		var before: String = item.display_name
		inv.transform(stack, item.evolves_into)
		Codex.notify(tr(&"CODEX_MSG_EVOLVED") % [before, inv.display_name(stack)], &"secret")
		EventBus.item_evolved.emit(item.id, item.evolves_into)
