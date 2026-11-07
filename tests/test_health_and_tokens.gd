extends GutTest


func _hit(amount: int) -> DamageInfo:
	var info: DamageInfo = DamageInfo.new()
	info.amount = amount
	return info


func test_damage_and_death() -> void:
	var h: HealthComponent = HealthComponent.new()
	h.max_health = 50
	add_child_autofree(h)
	watch_signals(h)
	assert_true(h.take_damage(_hit(20)))
	assert_eq(h.current, 30)
	h.take_damage(_hit(100))
	assert_true(h.is_dead())
	assert_signal_emitted(h, "died")
	assert_false(h.take_damage(_hit(1)), "no damage after death")


func test_invulnerable_reports_dodge() -> void:
	var h: HealthComponent = HealthComponent.new()
	add_child_autofree(h)
	watch_signals(h)
	h.invulnerable = true
	assert_false(h.take_damage(_hit(10)))
	assert_eq(h.current, h.max_health)
	assert_signal_emitted(h, "dodged")


func test_immortal_never_dies() -> void:
	var h: HealthComponent = HealthComponent.new()
	h.max_health = 10
	h.immortal = true
	add_child_autofree(h)
	h.take_damage(_hit(999))
	assert_eq(h.current, 1)
	assert_false(h.is_dead())


func test_heal_caps_at_max() -> void:
	var h: HealthComponent = HealthComponent.new()
	h.max_health = 100
	add_child_autofree(h)
	h.take_damage(_hit(30))
	h.heal(1000)
	assert_eq(h.current, 100)


func test_token_pool_limits_attackers() -> void:
	var pool: AttackTokenPool = AttackTokenPool.new()
	pool.max_tokens = 2
	add_child_autofree(pool)
	var a: Node = autofree(Node.new())
	var b: Node = autofree(Node.new())
	var c: Node = autofree(Node.new())
	assert_true(pool.request(a))
	assert_true(pool.request(b))
	assert_false(pool.request(c))
	assert_true(pool.request(a), "holder keeps its token")
	pool.release(a)
	assert_true(pool.request(c))


func test_lock_on_score_prefers_close_and_centered() -> void:
	var origin: Vector3 = Vector3.ZERO
	var forward: Vector3 = Vector3.FORWARD
	var ahead_near: float = LockOnTargeter.score(origin, forward, Vector3(0, 0, -5), 8.0)
	var ahead_far: float = LockOnTargeter.score(origin, forward, Vector3(0, 0, -15), 8.0)
	var side_near: float = LockOnTargeter.score(origin, forward, Vector3(5, 0, 0), 8.0)
	assert_lt(ahead_near, ahead_far)
	assert_lt(ahead_near, side_near)
