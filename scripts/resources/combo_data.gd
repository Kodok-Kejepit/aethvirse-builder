class_name ComboData
extends Resource
## Entry points of a weapon's combo graph (see AttackData.next_light / next_heavy).

@export var light_start: AttackData
@export var heavy_start: AttackData
## Time after an attack ends during which the chain continues.
@export var chain_grace_s: float = 0.35


## Next attack given the attack that just ran (null = from neutral) and the pressed button.
func resolve_next(previous: AttackData, heavy: bool) -> AttackData:
	if previous != null:
		var chained: AttackData = previous.next_heavy if heavy else previous.next_light
		if chained != null:
			return chained
	return heavy_start if heavy else light_start
