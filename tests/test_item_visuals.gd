extends GutTest
## Procedural item icons and rarity visuals.


func test_every_slot_has_a_glyph() -> void:
	for slot: int in ItemData.Slot.values():
		if slot == ItemData.Slot.NONE:
			continue
		var item: ItemData = ItemData.new()
		item.slot = slot as ItemData.Slot
		item.kind = ItemData.Kind.ARMOR
		assert_true(ItemIcons.GLYPHS.has(ItemIcons.glyph_for(item)), "slot %d" % slot)


func test_unidentified_shows_question_mark() -> void:
	var item: ItemData = ItemData.new()
	item.slot = ItemData.Slot.WEAPON
	assert_eq(ItemIcons.glyph_for(item, false), &"unknown")
	assert_eq(ItemIcons.glyph_for(null), &"unknown")


func test_icon_image_uses_rarity_border() -> void:
	for r: int in [ItemData.Rarity.COMMON, ItemData.Rarity.EPIC, ItemData.Rarity.MYTHIC]:
		var img: Image = ItemIcons.draw(&"sword", r)
		assert_eq(img.get_size(), Vector2i(ItemIcons.SIZE, ItemIcons.SIZE))
		var border: Color = img.get_pixel(48, 1)
		assert_almost_eq(border.r, ItemData.RARITY_COLORS[r as ItemData.Rarity].r, 0.05, "rarity %d border" % r)


func test_codex_caches_icons() -> void:
	var a: Texture2D = Codex.item_icon(&"ring", ItemData.Rarity.RARE)
	var b: Texture2D = Codex.item_icon(&"ring", ItemData.Rarity.RARE)
	assert_same(a, b)
