class_name ItemTile
extends Button
## One inventory square: item icon on its rarity plate, stack count, +upgrade, equipped mark.
## Empty tiles show the slot name faintly (equipment panel).

var stack: ItemStack = null
var empty_text: String = ""
var equipped: bool = false
var selected: bool = false


static func make(item_stack: ItemStack, tile_px: int) -> ItemTile:
	var t: ItemTile = ItemTile.new()
	t.stack = item_stack
	t.custom_minimum_size = Vector2(tile_px, tile_px)
	t.flat = true
	t.focus_mode = Control.FOCUS_ALL
	if item_stack != null:
		t.tooltip_text = GameState.inventory.display_name(item_stack) if GameState.inventory != null else ""
	return t


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	if stack == null:
		draw_rect(r, Color(0.05, 0.1, 0.18, 0.75))
		draw_rect(r, Color(CodexTheme.ACCENT, 0.35), false, 2.0)
		if empty_text != "":
			var font: Font = get_theme_default_font()
			var fs: int = CodexTheme.px(12)
			draw_multiline_string(font, Vector2(3, size.y * 0.45), empty_text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 6, fs, 2, Color(CodexTheme.TEXT, 0.5))
		return
	draw_texture_rect(Codex.icon_for_stack(stack), r, false)
	var font2: Font = get_theme_default_font()
	var fsz: int = CodexTheme.px(16)
	if stack.count > 1:
		draw_string_outline(font2, Vector2(4, size.y - 6), "×%d" % stack.count, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8, fsz, 4, Color.BLACK)
		draw_string(font2, Vector2(4, size.y - 6), "×%d" % stack.count, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8, fsz, Color.WHITE)
	if stack.upgrade > 0:
		draw_string_outline(font2, Vector2(6, fsz + 4), "+%d" % stack.upgrade, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, 4, Color.BLACK)
		draw_string(font2, Vector2(6, fsz + 4), "+%d" % stack.upgrade, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color(1, 0.9, 0.5))
	if equipped:
		draw_circle(Vector2(size.x - 10, 10), 6, CodexTheme.ACCENT)
	if selected or has_focus():
		draw_rect(r.grow(-1), Color.WHITE, false, 3.0)
