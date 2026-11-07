class_name CodexInventoryTab
extends VBoxContainer
## Codex → Inventory: equipment slots, bag (use / equip / sell / salvage / upgrade), crafting.

const RECIPE_DIR: String = "res://data/recipes/"
const RULES: LootRules = preload("res://data/balancing/loot_rules.tres")
const SHOWN_SLOTS: Dictionary[int, StringName] = {
	ItemData.Slot.WEAPON: &"SLOT_WEAPON", ItemData.Slot.OFF_HAND: &"SLOT_OFF_HAND",
	ItemData.Slot.HELM: &"SLOT_HELM", ItemData.Slot.ARMOR: &"SLOT_ARMOR",
	ItemData.Slot.GLOVES: &"SLOT_GLOVES", ItemData.Slot.BOOTS: &"SLOT_BOOTS",
	ItemData.Slot.RING: &"SLOT_RING", ItemData.Slot.RING_2: &"SLOT_RING",
	ItemData.Slot.NECKLACE: &"SLOT_NECKLACE", ItemData.Slot.RUNE_CORE: &"SLOT_RUNE_CORE",
	ItemData.Slot.COSTUME: &"SLOT_COSTUME",
}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	add_theme_constant_override(&"separation", 8)
	_rng.randomize()


## Currently inspected stack (bag or equipment) and the slot it is worn in (-1 = bag).
var _selected: ItemStack = null
var _selected_slot: int = -1


func refresh() -> void:
	for child: Node in get_children():
		child.queue_free()
	var inv: Inventory = GameState.inventory
	var player: Player = GameState.player as Player
	if inv == null or player == null:
		return
	if _selected != null and not inv.stacks.has(_selected) and inv.get_equipped(_selected_slot) != _selected:
		_selected = null
	if _selected == null and not inv.stacks.is_empty():
		_selected = _sorted(inv)[0]
		_selected_slot = -1
	_add_title(tr(&"INV_GOLD") % GameState.gold)
	var main: HBoxContainer = HBoxContainer.new()
	main.add_theme_constant_override(&"separation", CodexTheme.px(18))
	add_child(main)
	main.add_child(_equipment_panel(inv))
	main.add_child(_bag_panel(inv))
	main.add_child(_detail_panel(inv, player))
	_add_title(tr(&"INV_CRAFTING"))
	for file: String in DirAccess.get_files_at(RECIPE_DIR):
		var path: String = RECIPE_DIR + file.trim_suffix(".remap")
		if path.ends_with(".tres"):
			_recipe_row(inv, load(path) as RecipeData)


func _tile_px() -> int:
	return CodexTheme.px(76)


func _equipment_panel(inv: Inventory) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	var title: Label = Label.new()
	title.text = tr(&"INV_EQUIPPED")
	title.add_theme_color_override(&"font_color", CodexTheme.ACCENT)
	box.add_child(title)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	box.add_child(grid)
	for slot: int in SHOWN_SLOTS:
		var stack: ItemStack = inv.get_equipped(slot)
		var tile: ItemTile = ItemTile.make(stack, _tile_px())
		tile.empty_text = tr(SHOWN_SLOTS[slot])
		tile.equipped = stack != null
		tile.selected = stack != null and stack == _selected
		tile.tooltip_text = tr(SHOWN_SLOTS[slot]) + ("" if stack == null else ": " + inv.display_name(stack))
		tile.pressed.connect(_select.bind(stack, slot))
		grid.add_child(tile)
	return box


func _bag_panel(inv: Inventory) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title: Label = Label.new()
	title.text = tr(&"INV_BAG") % [inv.stacks.size(), Inventory.CAPACITY]
	title.add_theme_color_override(&"font_color", CodexTheme.ACCENT)
	box.add_child(title)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override(&"h_separation", 6)
	grid.add_theme_constant_override(&"v_separation", 6)
	box.add_child(grid)
	for stack: ItemStack in _sorted(inv):
		var tile: ItemTile = ItemTile.make(stack, _tile_px())
		tile.selected = stack == _selected
		tile.pressed.connect(_select.bind(stack, -1))
		grid.add_child(tile)
	for i: int in maxi(0, Inventory.CAPACITY - inv.stacks.size()):
		if i >= grid.columns * 2:
			break
		var empty: ItemTile = ItemTile.make(null, _tile_px())
		empty.disabled = true
		grid.add_child(empty)
	return box


## Best first: rarity, then equipment, then name.
static func _sorted(inv: Inventory) -> Array[ItemStack]:
	var out: Array[ItemStack] = inv.stacks.duplicate()
	out.sort_custom(func(a: ItemStack, b: ItemStack) -> bool:
		var ia: ItemData = inv.db.get_item(a.item_id)
		var ib: ItemData = inv.db.get_item(b.item_id)
		var ra: int = ItemStats.rarity_of(a, ia) if ia != null else 0
		var rb: int = ItemStats.rarity_of(b, ib) if ib != null else 0
		if ra != rb:
			return ra > rb
		var ea: bool = ia != null and ia.is_equipment()
		var eb: bool = ib != null and ib.is_equipment()
		if ea != eb:
			return ea
		return String(a.item_id) < String(b.item_id))
	return out


func _select(stack: ItemStack, slot: int) -> void:
	_selected = stack
	_selected_slot = slot
	refresh()


func _detail_panel(inv: Inventory, player: Player) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(CodexTheme.px(400), 0)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	panel.add_child(box)
	if _selected == null:
		var hint: Label = Label.new()
		hint.text = tr(&"INV_SELECT_HINT")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.modulate = Color(1, 1, 1, 0.6)
		box.add_child(hint)
		return panel
	var stack: ItemStack = _selected
	var item: ItemData = inv.db.get_item(stack.item_id)
	var head: HBoxContainer = HBoxContainer.new()
	box.add_child(head)
	var icon: TextureRect = TextureRect.new()
	icon.texture = Codex.icon_for_stack(stack)
	icon.custom_minimum_size = Vector2(CodexTheme.px(96), CodexTheme.px(96))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.add_child(icon)
	var names: VBoxContainer = VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	var title: Label = Label.new()
	title.text = inv.display_name(stack) + ("  +%d" % stack.upgrade if stack.upgrade > 0 else "")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override(&"font_color", _color(inv, stack))
	title.add_theme_font_size_override(&"font_size", CodexTheme.px(26))
	names.add_child(title)
	var rarity: Label = Label.new()
	var r: int = ItemStats.rarity_of(stack, item) if item != null and stack.identified else ItemData.Rarity.UNKNOWN
	rarity.text = tr(StringName("RARITY_%d" % r)) + ("  ·  ×%d" % stack.count if stack.count > 1 else "")
	rarity.add_theme_color_override(&"font_color", _color(inv, stack))
	names.add_child(rarity)
	if item != null:
		var stats: String = _stat_line(stack, item)
		if stats != "":
			var st: Label = Label.new()
			st.text = stats.replace("  ·  ", "\n")
			box.add_child(st)
		var desc: Label = Label.new()
		desc.text = item.description if stack.identified else item.unidentified_description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.modulate = Color(1, 1, 1, 0.75)
		box.add_child(desc)
	var actions: HFlowContainer = HFlowContainer.new()
	box.add_child(actions)
	for b: Button in _actions(inv, player, stack, item):
		actions.add_child(b)
	return panel


func _actions(inv: Inventory, player: Player, stack: ItemStack, item: ItemData) -> Array[Button]:
	var out: Array[Button] = []
	if item == null:
		return out
	if _selected_slot >= 0:
		out.append(_button(tr(&"INV_UNEQUIP"), func() -> void:
			if not inv.unequip(_selected_slot):
				Codex.notify(tr(&"INV_CURSED"), &"warning")
			_selected = null
			refresh()))
		out.append(_upgrade_button(inv, stack))
		return out
	if item.is_equipment():
		out.append(_button(tr(&"INV_EQUIP"), func() -> void:
			inv.equip(stack)
			_selected = null
			refresh()))
		out.append(_upgrade_button(inv, stack))
		if item.can_sell:
			out.append(_button(tr(&"INV_SALVAGE"), func() -> void:
				ItemActions.salvage(inv, stack)
				_selected = null
				refresh()))
	elif item.is_usable():
		out.append(_button(tr(&"INV_USE"), func() -> void:
			player.items.use(stack)
			refresh()))
	var price: int = ItemActions.sell_price(inv, stack)
	if price > 0:
		out.append(_button("%s %dG" % [tr(&"INV_SELL"), price], func() -> void:
			ItemActions.sell(inv, stack)
			_selected = null
			refresh()))
	return out


func _upgrade_button(inv: Inventory, stack: ItemStack) -> Button:
	var item: ItemData = inv.db.get_item(stack.item_id)
	var target: int = stack.upgrade + 1
	var label: String = "+%d (%dG, %d%%)" % [target, RULES.upgrade_cost(target), roundi(RULES.upgrade_chance(target) * 100.0)]
	var button: Button = _button(label, func() -> void:
		var result: ItemActions.UpgradeResult = ItemActions.upgrade(stack, item, _rng)
		Codex.notify(tr(StringName("UPGRADE_RESULT_%d" % result)) % inv.display_name(stack),
			&"reward" if result == ItemActions.UpgradeResult.SUCCESS else &"warning")
		inv.changed.emit()
		refresh())
	button.disabled = stack.upgrade >= RULES.upgrade_max or GameState.gold < RULES.upgrade_cost(target)
	return button


func _recipe_row(inv: Inventory, recipe: RecipeData) -> void:
	var parts: PackedStringArray = []
	for id: StringName in recipe.inputs:
		var input: ItemData = inv.db.get_item(id)
		parts.append("%s ×%d" % [input.display_name if input != null else String(id), recipe.inputs[id]])
	if recipe.gold_cost > 0:
		parts.append("%dG" % recipe.gold_cost)
	var output: ItemData = inv.db.get_item(recipe.output)
	var text: String = "%s  ←  %s" % [output.display_name if output != null else String(recipe.output), " + ".join(parts)]
	var button: Button = _button(tr(&"INV_CRAFT"), func() -> void:
		ItemActions.craft(inv, recipe)
		refresh())
	button.disabled = not ItemActions.can_craft(inv, recipe)
	_add_row(text, CodexTheme.TEXT, [button])


func _describe(inv: Inventory, stack: ItemStack) -> String:
	var item: ItemData = inv.db.get_item(stack.item_id)
	var name_text: String = inv.display_name(stack)
	var count_text: String = "  ×%d" % stack.count if stack.count > 1 else ""
	var desc: String = item.description if stack.identified else item.unidentified_description
	var stats: String = _stat_line(stack, item)
	return "%s%s\n    %s%s" % [name_text, count_text, desc, "\n    " + stats if stats != "" else ""]


static func _stat_line(stack: ItemStack, item: ItemData) -> String:
	if not item.is_equipment() or not stack.identified:
		return ""
	var level: int = GameState.progression.level if GameState.progression != null else 1
	var parts: PackedStringArray = []
	if item.slot == ItemData.Slot.WEAPON:
		parts.append("ATK %.0f" % ItemStats.attack(stack, item, level))
	var def: float = ItemStats.defense(stack, item)
	if def > 0.0:
		parts.append("DEF %.0f" % def)
	for key: StringName in [&"str", &"agi", &"int", &"vit", &"sen"]:
		var v: float = ItemStats.bonus(stack, item, key)
		if v > 0.0:
			parts.append("%s +%.0f" % [String(key).to_upper(), v])
	for key: StringName in [&"crit", &"lifesteal"]:
		var p: float = ItemStats.bonus(stack, item, key)
		if p > 0.0:
			parts.append("%s +%.1f%%" % [String(key).to_upper(), p * 100.0])
	if stack.item_level > 0:
		parts.append("iLv %d" % stack.item_level)
	return "  ·  ".join(parts)


func _color(inv: Inventory, stack: ItemStack) -> Color:
	if stack == null:
		return Color(1, 1, 1, 0.5)
	var item: ItemData = inv.db.get_item(stack.item_id)
	if item == null or not stack.identified:
		return ItemData.RARITY_COLORS[ItemData.Rarity.UNKNOWN]
	return ItemData.RARITY_COLORS[ItemStats.rarity_of(stack, item)]


func _add_title(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", CodexTheme.px(26))
	label.add_theme_color_override(&"font_color", CodexTheme.ACCENT)
	add_child(label)


func _add_row(text: String, color: Color, buttons: Array[Button]) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override(&"font_color", color)
	row.add_child(label)
	for button: Button in buttons:
		row.add_child(button)
	add_child(row)


static func _button(text: String, on_press: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = CodexTheme.button_size(120, 52)
	button.pressed.connect(on_press)
	return button
