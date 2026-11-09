class_name CodexShop
extends RefCounted
## The System's own shop (owner): rare, legendary and mythic gear for the hero's level,
## expensive on purpose. Stock changes every game day (same stock all day for the same
## hero); each offer can be bought once a day.

## Rarity of each daily slot.
const SLOTS: Array[ItemData.Rarity] = [
	ItemData.Rarity.RARE, ItemData.Rarity.RARE, ItemData.Rarity.RARE,
	ItemData.Rarity.EPIC, ItemData.Rarity.EPIC,
	ItemData.Rarity.LEGENDARY, ItemData.Rarity.LEGENDARY,
	ItemData.Rarity.MYTHIC,
]
## Gold per item level by rarity (index = rarity).
const PRICE_PER_LEVEL: Array[int] = [8, 15, 70, 200, 650, 2200]
const MIN_LEVEL: int = 5


static func day() -> int:
	return GameState.clock.day() if GameState.clock != null else 0


static func level() -> int:
	return maxi(GameState.progression.level if GameState.progression != null else 1, MIN_LEVEL)


static func price(rarity: int, item_level: int) -> int:
	return PRICE_PER_LEVEL[clampi(rarity, 0, PRICE_PER_LEVEL.size() - 1)] * maxi(item_level, 1)


## Today's offers: [{stack: ItemStack, price: int, sold: bool}], same for the whole day.
static func offers() -> Array[Dictionary]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%d:%s:%d" % [day(), GameState.hero_id, level()])
	var gen: EquipmentGenerator = EquipmentGenerator.new(GameState.items, rng)
	var out: Array[Dictionary] = []
	for i: int in SLOTS.size():
		var stack: ItemStack = gen.generate(level(), SLOTS[i])
		out.append({"stack": stack, "price": price(SLOTS[i], level()), "sold": GameState.has_flag(_sold_flag(i))})
	return out


static func _sold_flag(index: int) -> StringName:
	return StringName("codex_shop_%d_%d" % [day(), index])


## Buys today's offer `index`. Returns false when sold out or too poor.
static func buy(index: int) -> bool:
	var list: Array[Dictionary] = offers()
	if index < 0 or index >= list.size():
		return false
	var offer: Dictionary = list[index]
	var cost: int = offer["price"]
	if offer["sold"] or GameState.gold < cost:
		return false
	GameState.gold -= cost
	var stack: ItemStack = offer["stack"]
	GameState.inventory.add_stack(stack)
	GameState.set_flag(_sold_flag(index))
	return true
