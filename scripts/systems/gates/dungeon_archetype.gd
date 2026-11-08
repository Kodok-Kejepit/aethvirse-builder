class_name DungeonArchetype
extends RefCounted
## What kind of place a Gate opens into today (owner: several map types per rank, picked
## at random so Gates feel alive). Each archetype sets the room style mix, room size and
## roof scale, how much tunnels wind, how wet / mossy it is, the light tint, and which
## room challenges it likes.

const ALL: Dictionary[StringName, Dictionary] = {
	&"warrens": {"name": &"DUNGEON_WARRENS", "styles": {&"cave": 3, &"ruin": 1}, "radius": 0.85, "roof": 0.85,
		"wiggle": 1.4, "wet": 0.45, "moss": 0.35, "tint": Color(0.95, 0.72, 0.5), "fog": Color(0.1, 0.08, 0.06)},
	&"halls": {"name": &"DUNGEON_HALLS", "styles": {&"hall": 3, &"ruin": 1}, "radius": 1.15, "roof": 1.2,
		"wiggle": 0.6, "wet": 0.15, "moss": 0.2, "tint": Color(1.0, 0.82, 0.6), "fog": Color(0.08, 0.07, 0.1)},
	&"ruins": {"name": &"DUNGEON_RUINS", "styles": {&"ruin": 3, &"cave": 1}, "radius": 1.0, "roof": 1.0,
		"wiggle": 1.0, "wet": 0.25, "moss": 0.4, "tint": Color(0.9, 0.85, 0.7), "fog": Color(0.09, 0.09, 0.08)},
	&"grotto": {"name": &"DUNGEON_GROTTO", "styles": {&"cave": 2, &"hall": 1}, "radius": 1.05, "roof": 1.3,
		"wiggle": 1.2, "wet": 0.35, "moss": 0.15, "tint": Color(0.55, 0.8, 1.0), "fog": Color(0.04, 0.08, 0.14)},
	&"crypt": {"name": &"DUNGEON_CRYPT", "styles": {&"hall": 2, &"ruin": 2}, "radius": 0.9, "roof": 0.75,
		"wiggle": 0.8, "wet": 0.2, "moss": 0.25, "tint": Color(0.75, 0.6, 1.0), "fog": Color(0.06, 0.04, 0.1)},
	&"rootdeep": {"name": &"DUNGEON_ROOTDEEP", "styles": {&"cave": 3}, "radius": 1.0, "roof": 1.1,
		"wiggle": 1.3, "wet": 0.3, "moss": 0.65, "tint": Color(0.7, 1.0, 0.6), "fog": Color(0.05, 0.1, 0.05)},
}
## Rank (E..S) -> archetypes a Gate of that rank can open into.
const BY_RANK: Array[Array] = [
	[&"warrens", &"ruins", &"rootdeep"],
	[&"rootdeep", &"crypt", &"warrens"],
	[&"grotto", &"halls", &"crypt"],
	[&"halls", &"grotto", &"rootdeep"],
	[&"crypt", &"halls", &"grotto"],
	[&"grotto", &"crypt", &"halls"],
]
## Room challenges (owner: more than just monsters). A share of fight rooms gets one.
const CHALLENGES: Array[StringName] = [&"waves", &"timed", &"traps", &"dark", &"elite"]
const CHALLENGE_CHANCE: float = 0.5


## Today's archetype for a Gate rank (deterministic per seed).
static func pick(rank: int, seed_value: int) -> StringName:
	var options: Array = BY_RANK[clampi(rank, 0, BY_RANK.size() - 1)]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var id: StringName = options[rng.randi() % options.size()]
	return id


static func spec(id: StringName) -> Dictionary:
	return ALL.get(id, ALL[&"ruins"])


## Weighted room style for this archetype.
static func roll_style(id: StringName, rng: RandomNumberGenerator) -> StringName:
	var weights: Dictionary = spec(id)["styles"]
	var total: int = 0
	for w: int in weights.values():
		total += w
	var roll: int = rng.randi() % maxi(total, 1)
	for style: StringName in weights:
		var w2: int = weights[style]
		if roll < w2:
			return style
		roll -= w2
	return &"cave"
