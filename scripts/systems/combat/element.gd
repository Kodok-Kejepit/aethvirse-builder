class_name Element
extends RefCounted
## The 9 elements and their damage multipliers (master prompt §6.1).
## Natural cycle: Fire > Ice > Wind > Earth > Lightning > Fire. Shadow <-> Light 1.5x both ways.
## Same element resists (0.75x) except Physical. Void deals 1.25x to all, 0.5x to Void.

enum Type { PHYSICAL, FIRE, ICE, WIND, EARTH, LIGHTNING, SHADOW, LIGHT, VOID }

const STRONG: float = 1.5
const WEAK: float = 0.75
const RESIST_SAME: float = 0.75
const NEUTRAL: float = 1.0
const VOID_VS_ALL: float = 1.25
const VOID_VS_VOID: float = 0.5

## Each natural element beats the next one in this cycle.
const NATURAL_CYCLE: Array[Type] = [Type.FIRE, Type.ICE, Type.WIND, Type.EARTH, Type.LIGHTNING]

const NAMES: Dictionary[Type, String] = {
	Type.PHYSICAL: "Physical", Type.FIRE: "Fire", Type.ICE: "Ice", Type.WIND: "Wind",
	Type.EARTH: "Earth", Type.LIGHTNING: "Lightning", Type.SHADOW: "Shadow",
	Type.LIGHT: "Light", Type.VOID: "Void",
}

const COLORS: Dictionary[Type, Color] = {
	Type.PHYSICAL: Color(0.92, 0.92, 0.95), Type.FIRE: Color(1.0, 0.55, 0.15),
	Type.ICE: Color(0.55, 0.85, 1.0), Type.WIND: Color(0.6, 1.0, 0.7),
	Type.EARTH: Color(0.75, 0.55, 0.3), Type.LIGHTNING: Color(1.0, 0.92, 0.25),
	Type.SHADOW: Color(0.65, 0.35, 0.95), Type.LIGHT: Color(1.0, 0.85, 0.45),
	Type.VOID: Color(0.15, 0.15, 0.15),
}


static func is_natural(element: Type) -> bool:
	return element in NATURAL_CYCLE


## Multiplier for an attack of `attack` element against a target with `defense` affinity.
static func multiplier(attack: Type, defense: Type) -> float:
	if attack == Type.VOID:
		return VOID_VS_VOID if defense == Type.VOID else VOID_VS_ALL
	if attack == Type.PHYSICAL or defense == Type.PHYSICAL or defense == Type.VOID:
		return NEUTRAL
	if attack == defense:
		return RESIST_SAME
	if (attack == Type.SHADOW and defense == Type.LIGHT) or (attack == Type.LIGHT and defense == Type.SHADOW):
		return STRONG
	if is_natural(attack) and is_natural(defense):
		var a: int = NATURAL_CYCLE.find(attack)
		var d: int = NATURAL_CYCLE.find(defense)
		var size: int = NATURAL_CYCLE.size()
		if (a + 1) % size == d:
			return STRONG
		if (d + 1) % size == a:
			return WEAK
	return NEUTRAL
