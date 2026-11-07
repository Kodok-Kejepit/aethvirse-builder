class_name ConditionData
extends Resource
## One requirement for a secret / dialog line / quest step. Evaluated against a SecretContext.

enum Type {
	FLAG,            ## key = world flag; true when set (negate for "not set")
	WEATHER,         ## values = allowed weathers
	HOUR_RANGE,      ## value = from hour, value2 = to hour (wraps midnight)
	IS_NIGHT,
	IN_AREA,         ## key = SecretArea id
	IDLE_SECONDS,    ## value = seconds without moving/attacking
	HAS_ITEM,        ## values = any of these item ids; value = min count; key = identified_by (optional)
	COUNTER_AT_LEAST,## key = counter id, value = minimum
	SECRET_FOUND,    ## key = secret id
	STAT_AT_LEAST,   ## key = str/agi/int/vit/sen, value = minimum
	LEVEL_AT_LEAST,  ## value = minimum level
}

@export var type: Type = Type.FLAG
@export var key: StringName = &""
@export var values: Array[StringName] = []
@export var value: float = 0.0
@export var value2: float = 0.0
@export var negate: bool = false


func evaluate(ctx: SecretContext) -> bool:
	var result: bool = _evaluate(ctx)
	return not result if negate else result


func _evaluate(ctx: SecretContext) -> bool:
	match type:
		Type.FLAG:
			return ctx.has_flag(key)
		Type.WEATHER:
			return ctx.weather in values
		Type.HOUR_RANGE:
			return ctx.hour_between(int(value), int(value2))
		Type.IS_NIGHT:
			return ctx.is_night
		Type.IN_AREA:
			return key in ctx.areas
		Type.IDLE_SECONDS:
			return ctx.idle_s >= value
		Type.HAS_ITEM:
			for item_id: StringName in values:
				if ctx.has_item(item_id, maxi(int(value), 1), key):
					return true
			return false
		Type.COUNTER_AT_LEAST:
			return ctx.counter(key) >= value
		Type.SECRET_FOUND:
			return ctx.is_found(key)
		Type.STAT_AT_LEAST:
			return ctx.stat(key) >= value
		Type.LEVEL_AT_LEAST:
			return ctx.level >= int(value)
	return false


static func make(t: Type, k: StringName = &"", v: float = 0.0, vals: Array[StringName] = []) -> ConditionData:
	var c: ConditionData = ConditionData.new()
	c.type = t
	c.key = k
	c.value = v
	c.values = vals
	return c


static func all_true(conditions: Array[ConditionData], ctx: SecretContext) -> bool:
	for c: ConditionData in conditions:
		if not c.evaluate(ctx):
			return false
	return true


static func any_true(conditions: Array[ConditionData], ctx: SecretContext) -> bool:
	for c: ConditionData in conditions:
		if c.evaluate(ctx):
			return true
	return false
