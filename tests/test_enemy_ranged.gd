extends GutTest
## Ranged enemies lead a moving hero and shoot at the hero's hurtbox layer; heavy hitters
## throw the hero (launch).

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const ARCHER: EnemyData = preload("res://data/enemies/cinder_archer.tres")
const BRUTE: EnemyData = preload("res://data/enemies/moss_brute.tres")


func _enemy(data: EnemyData) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate() as Enemy
	e.data = data
	add_child_autofree(e)
	return e


func test_archer_is_ranged() -> void:
	assert_true(ARCHER.ranged)
	assert_gt(ARCHER.attack_range, ARCHER.keep_distance_m)


func test_aim_leads_a_running_target() -> void:
	var target: CharacterBody3D = CharacterBody3D.new()
	add_child_autofree(target)
	target.global_position = Vector3(0, 0, -20)
	target.velocity = Vector3(5, 0, 0)
	var still: Vector3 = EnemyRanged.aim_point(Vector3.ZERO, target, 30.0, 0.0)
	var led: Vector3 = EnemyRanged.aim_point(Vector3.ZERO, target, 30.0, 1.0)
	assert_almost_eq(still.x, 0.0, 0.01)
	assert_gt(led.x, 2.0, "aims ahead of a hero running sideways")


func test_shot_targets_the_hero_layer() -> void:
	var e: Enemy = _enemy(ARCHER)
	EnemyRanged.fire(e, e.global_position + Vector3(0, 1, -10))
	var shots: Array[Projectile] = []
	for n: Node in e.get_parent().get_children():
		if n is Projectile:
			shots.append(n as Projectile)
	assert_eq(shots.size(), 1)
	var p: Projectile = shots[0]
	assert_eq(p.hit_mask, Projectile.PLAYER_HURTBOX_MASK)
	assert_eq(p.collision_mask & Projectile.ENEMY_HURTBOX_MASK, 0, "never hits other monsters")
	p.free()


func test_brute_blows_throw_the_hero() -> void:
	var e: Enemy = _enemy(BRUTE)
	var hurt: HurtboxComponent = HurtboxComponent.new()
	add_child_autofree(hurt)
	hurt.global_position = e.global_position + Vector3(3, 0, 0)
	var info: DamageInfo = e.build_damage_for(hurt)
	assert_gt(info.launch, 5.0)
	assert_gt(info.knockback.length(), 10.0)
