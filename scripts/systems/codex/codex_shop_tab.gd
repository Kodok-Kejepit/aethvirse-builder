class_name CodexShopTab
extends VBoxContainer
## Codex → Shop: the System's daily offers (CodexShop). Expensive rare to mythic gear.


func _init() -> void:
	add_theme_constant_override(&"separation", CodexTheme.px(8))


func refresh() -> void:
	for child: Node in get_children():
		child.queue_free()
	if GameState.inventory == null or GameState.progression == null:
		return
	var title: Label = _label(tr(&"SHOP_TITLE"), 28, CodexTheme.TRIM)
	title.add_theme_font_override(&"font", CodexTheme.SERIF)
	add_child(title)
	add_child(_label(tr(&"SHOP_NOTE"), 18, Color(CodexTheme.TEXT, 0.7)))
	add_child(_label(tr(&"SHOP_GOLD") % GameState.gold, 22, Color(1.0, 0.85, 0.4)))
	var list: Array[Dictionary] = CodexShop.offers()
	for i: int in list.size():
		add_child(_row(i, list[i]))


func _row(index: int, offer: Dictionary) -> HBoxContainer:
	var inv: Inventory = GameState.inventory
	var stack: ItemStack = offer["stack"]
	var item: ItemData = inv.db.get_item(stack.item_id)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", CodexTheme.px(12))
	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var color: Color = ItemData.RARITY_COLORS[ItemStats.rarity_of(stack, item)]
	info.add_child(_label(inv.display_name(stack), 22, color))
	var stats: String = CodexInventoryTab._stat_line(stack, item)
	if stats != "":
		info.add_child(_label(stats, 16, Color(CodexTheme.TEXT, 0.75)))
	row.add_child(info)
	var cost: int = offer["price"]
	var price: Label = _label("%d G" % cost, 20, Color(1.0, 0.85, 0.4))
	price.autowrap_mode = TextServer.AUTOWRAP_OFF
	price.custom_minimum_size = Vector2(CodexTheme.px(130), 0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price)
	var b: Button = Button.new()
	var sold: bool = offer["sold"]
	b.text = tr(&"SHOP_SOLD") if sold else tr(&"SHOP_BUY")
	b.disabled = sold or GameState.gold < cost
	b.custom_minimum_size = CodexTheme.button_size(140, 44)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		if CodexShop.buy(index):
			Codex.notify(tr(&"SHOP_BOUGHT") % inv.display_name(stack), &"reward")
			AudioManager.play_ui(&"ding")
		refresh())
	row.add_child(b)
	return row


func _label(text: String, size_px: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override(&"font_size", CodexTheme.px(size_px))
	l.add_theme_color_override(&"font_color", color)
	return l
