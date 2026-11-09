class_name DungeonArchetype
extends RefCounted
## What kind of place a Gate opens into today (owner: several map types per rank, picked
## at random so Gates feel alive). Each archetype sets the room style mix, room size and
## roof scale, how much tunnels wind, how wet / mossy it is, the light tint, the map shapes
## it is built in, and (newer kinds) glowing cracks, frost or sand on the surfaces.
## Each region adds its own kind to every rank's list (a Gate in the Dunes often opens
## into a sand-choked tomb, one in Frostveil into a frozen hollow).

const ALL: Dictionary[StringName, Dictionary] = {
	&"warrens": {"name": &"DUNGEON_WARRENS", "styles": {&"cave": 3, &"ruin": 1}, "radius": 0.85, "roof": 0.85,
		"wiggle": 1.4, "wet": 0.45, "moss": 0.35, "tint": Color(0.95, 0.72, 0.5), "fog": Color(0.1, 0.08, 0.06),
		"layouts": [&"winding", &"loop", &"spiral"]},
	&"halls": {"name": &"DUNGEON_HALLS", "styles": {&"hall": 3, &"ruin": 1}, "radius": 1.15, "roof": 1.2,
		"wiggle": 0.6, "wet": 0.15, "moss": 0.2, "tint": Color(1.0, 0.82, 0.6), "fog": Color(0.08, 0.07, 0.1),
		"layouts": [&"hub", &"fork", &"winding"]},
	&"ruins": {"name": &"DUNGEON_RUINS", "styles": {&"ruin": 3, &"cave": 1}, "radius": 1.0, "roof": 1.0,
		"wiggle": 1.0, "wet": 0.25, "moss": 0.4, "tint": Color(0.9, 0.85, 0.7), "fog": Color(0.09, 0.09, 0.08),
		"layouts": [&"winding", &"fork", &"loop"]},
	&"grotto": {"name": &"DUNGEON_GROTTO", "styles": {&"cave": 2, &"hall": 1}, "radius": 1.05, "roof": 1.3,
		"wiggle": 1.2, "wet": 0.35, "moss": 0.15, "tint": Color(0.55, 0.8, 1.0), "fog": Color(0.04, 0.08, 0.14),
		"layouts": [&"loop", &"spiral", &"winding"]},
	&"crypt": {"name": &"DUNGEON_CRYPT", "styles": {&"hall": 2, &"ruin": 2}, "radius": 0.9, "roof": 0.75,
		"wiggle": 0.8, "wet": 0.2, "moss": 0.25, "tint": Color(0.75, 0.6, 1.0), "fog": Color(0.06, 0.04, 0.1),
		"layouts": [&"spiral", &"hub", &"fork"]},
	&"rootdeep": {"name": &"DUNGEON_ROOTDEEP", "styles": {&"cave": 3}, "radius": 1.0, "roof": 1.1,
		"wiggle": 1.3, "wet": 0.3, "moss": 0.65, "tint": Color(0.7, 1.0, 0.6), "fog": Color(0.05, 0.1, 0.05),
		"layouts": [&"winding", &"loop"]},
	# Region kinds (2026-11-10): glow = emissive cracks [colour, strength], frost / sand = how
	# much of the floor and walls is iced over / drifted with sand.
	&"ember": {"name": &"DUNGEON_EMBER", "styles": {&"hall": 2, &"cave": 2}, "radius": 1.05, "roof": 1.05,
		"wiggle": 0.9, "wet": 0.0, "moss": 0.0, "tint": Color(1.0, 0.6, 0.38), "fog": Color(0.14, 0.05, 0.03),
		"glow": [Color(1.0, 0.38, 0.08), 1.6], "layouts": [&"hub", &"winding", &"fork"]},
	&"sandtomb": {"name": &"DUNGEON_SANDTOMB", "styles": {&"hall": 2, &"ruin": 2}, "radius": 1.0, "roof": 1.15,
		"wiggle": 0.7, "wet": 0.0, "moss": 0.05, "tint": Color(1.0, 0.85, 0.62), "fog": Color(0.13, 0.1, 0.06),
		"sand": 0.55, "layouts": [&"fork", &"hub", &"spiral"]},
	&"frost": {"name": &"DUNGEON_FROST", "styles": {&"cave": 3, &"hall": 1}, "radius": 1.05, "roof": 1.25,
		"wiggle": 1.1, "wet": 0.5, "moss": 0.0, "tint": Color(0.75, 0.9, 1.0), "fog": Color(0.07, 0.1, 0.14),
		"frost": 0.6, "glow": [Color(0.45, 0.85, 1.0), 0.5], "layouts": [&"spiral", &"loop", &"winding"]},
	&"sunken": {"name": &"DUNGEON_SUNKEN", "styles": {&"hall": 2, &"ruin": 1, &"cave": 1}, "radius": 1.1, "roof": 1.1,
		"wiggle": 1.0, "wet": 0.9, "moss": 0.45, "tint": Color(0.6, 0.9, 0.85), "fog": Color(0.03, 0.08, 0.09),
		"layouts": [&"loop", &"fork", &"hub"]},
	&"void": {"name": &"DUNGEON_VOID", "styles": {&"ruin": 2, &"hall": 1}, "radius": 1.1, "roof": 1.35,
		"wiggle": 1.2, "wet": 0.1, "moss": 0.0, "tint": Color(0.8, 0.65, 1.0), "fog": Color(0.07, 0.03, 0.12),
		"glow": [Color(0.7, 0.4, 1.0), 1.2], "layouts": [&"spiral", &"hub", &"loop"]},
}
## Region -> its own kind of place, added to every rank's list in that region.
const BY_REGION: Dictionary[StringName, StringName] = {
	&"r1": &"ember", &"r2": &"rootdeep", &"r3": &"sandtomb", &"r4": &"frost", &"r5": &"sunken", &"r6": &"void", &"r7": &"void",
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


## Today's archetype for a Gate rank (deterministic per seed). `region` ("r3", or a Gate id
## like "gate_r3_c_mirage") adds that region's own kind twice, so it comes up often.
static func pick(rank: int, seed_value: int, region: String = "") -> StringName:
	var options: Array = BY_RANK[clampi(rank, 0, BY_RANK.size() - 1)].duplicate()
	var own: StringName = BY_REGION.get(StringName(region_of(region)), &"")
	if own != &"":
		options.append(own)
		options.append(own)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var id: StringName = options[rng.randi() % options.size()]
	return id


## "r3" from "r3", "r3_dunes" or "gate_r3_c_mirage"; "" if none.
static func region_of(text: String) -> String:
	var m: RegExMatch = RegEx.create_from_string("(?:^|_)(r[0-9])(?:_|$)").search(text)
	return m.get_string(1) if m != null else ""


## Map shape for a kind of place (own dice, so the rooms of a winding run do not change).
static func roll_layout(id: StringName, seed_value: int) -> StringName:
	var shapes: Array = spec(id).get("layouts", [&"winding"])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13
	var shape: StringName = shapes[rng.randi() % shapes.size()]
	return shape


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
