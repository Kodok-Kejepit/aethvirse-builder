class_name PoisonEffect
extends Node
## Venom on a body (hero or enemy): loses a share of max HP every tick for a while,
## green numbers, never kills on its own (stops at 1 HP). A new dose refreshes the
## duration instead of stacking.

const TICK_S: float = 1.0
const MIN_TICK_DAMAGE: int = 1

var health: HealthComponent = null
## Share of max HP lost per second.
var share_per_s: float = 0.02
var remaining_s: float = 5.0
var _tick: float = 0.0


## Rolls `chance` and poisons the hurtbox's owner. Returns true when it took.
static func try_apply(hurtbox: HurtboxComponent, chance: float, share: float, seconds: float, rng: RandomNumberGenerator = null) -> bool:
	if hurtbox == null or hurtbox.health == null or hurtbox.health.is_dead() or chance <= 0.0:
		return false
	var roll: float = rng.randf() if rng != null else randf()
	if roll >= chance:
		return false
	var owner_node: Node = hurtbox.body if hurtbox.body != null else hurtbox.get_parent()
	var existing: PoisonEffect = owner_node.get_node_or_null(^"Poison") as PoisonEffect
	if existing != null:
		existing.remaining_s = maxf(existing.remaining_s, seconds)
		existing.share_per_s = maxf(existing.share_per_s, share)
		return true
	var p: PoisonEffect = PoisonEffect.new()
	p.name = "Poison"
	p.health = hurtbox.health
	p.share_per_s = share
	p.remaining_s = seconds
	owner_node.add_child(p)
	return true


func _physics_process(delta: float) -> void:
	if health == null or health.is_dead():
		queue_free()
		return
	remaining_s -= delta
	_tick += delta
	if _tick >= TICK_S:
		_tick -= TICK_S
		var amount: int = maxi(roundi(health.max_health * share_per_s * TICK_S), MIN_TICK_DAMAGE)
		amount = mini(amount, health.current - 1)
		if amount > 0:
			var info: DamageInfo = DamageInfo.new()
			info.amount = amount
			info.ignore_defense = true
			health.take_damage(info)
			var body: Node3D = get_parent() as Node3D
			if body != null:
				EventBus.damage_number_requested.emit(body.global_position + Vector3.UP * 2.2, amount, false, Element.Type.WIND, body is Player)
	if remaining_s <= 0.0:
		queue_free()
