class_name StatBlock
extends Resource
## The five primary stats (§8). Floats so class growth can be fractional; shown rounded.

enum Stat { STR, AGI, INT, VIT, SEN }

const NAMES: Dictionary[Stat, String] = {
	Stat.STR: "STR", Stat.AGI: "AGI", Stat.INT: "INT", Stat.VIT: "VIT", Stat.SEN: "SEN",
}

@export var strength: float = 0.0
@export var agility: float = 0.0
@export var intelligence: float = 0.0
@export var vitality: float = 0.0
@export var sense: float = 0.0


static func make(s: float, a: float, i: float, v: float, se: float) -> StatBlock:
	var block: StatBlock = StatBlock.new()
	block.strength = s
	block.agility = a
	block.intelligence = i
	block.vitality = v
	block.sense = se
	return block


func get_stat(stat: Stat) -> float:
	match stat:
		Stat.STR:
			return strength
		Stat.AGI:
			return agility
		Stat.INT:
			return intelligence
		Stat.VIT:
			return vitality
		_:
			return sense


func set_stat(stat: Stat, value: float) -> void:
	match stat:
		Stat.STR:
			strength = value
		Stat.AGI:
			agility = value
		Stat.INT:
			intelligence = value
		Stat.VIT:
			vitality = value
		_:
			sense = value


## this + other × factor (new block).
func plus(other: StatBlock, factor: float = 1.0) -> StatBlock:
	return StatBlock.make(strength + other.strength * factor, agility + other.agility * factor,
		intelligence + other.intelligence * factor, vitality + other.vitality * factor,
		sense + other.sense * factor)


func rounded() -> StatBlock:
	return StatBlock.make(roundf(strength), roundf(agility), roundf(intelligence), roundf(vitality), roundf(sense))


func to_dict() -> Dictionary:
	return {"str": strength, "agi": agility, "int": intelligence, "vit": vitality, "sen": sense}


static func from_dict(d: Dictionary) -> StatBlock:
	var s: float = d.get("str", 0.0)
	var a: float = d.get("agi", 0.0)
	var i: float = d.get("int", 0.0)
	var v: float = d.get("vit", 0.0)
	var se: float = d.get("sen", 0.0)
	return StatBlock.make(s, a, i, v, se)
