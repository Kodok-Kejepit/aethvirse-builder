class_name EnemyData
extends Resource
## Enemy definition (data-driven). One .tres per enemy type in data/enemies/.

@export var id: StringName = &""
@export var display_name: String = ""
@export var level: int = 1
@export var max_health: int = 120
@export var stats: CombatStats
## Damage needed to stagger (resets after a short time without hits).
@export var poise: float = 25.0
@export var body_color: Color = Color(0.8, 0.25, 0.25)
## When true, HP/ATK/DEF/XP/Gold come from EnemyScaling for `level` and `tier`
## (the numbers above become fallbacks only).
@export var scale_by_level: bool = true
@export var tier: EnemyScaling.Tier = EnemyScaling.Tier.NORMAL
## Multiplies the scaled HP / ATK (per-type flavour: tanky, glass cannon...).
@export var hp_scale: float = 1.0
@export var attack_scale: float = 1.0

@export_group("Movement & awareness")
@export var walk_speed: float = 1.6
@export var chase_speed: float = 4.2
@export var aggro_radius: float = 12.0
@export var leash_radius: float = 26.0
@export var patrol_radius: float = 4.0

@export_group("Attack")
@export var attack_range: float = 2.0
@export var attack_windup_s: float = 0.7
@export var attack_active_s: float = 0.15
@export var attack_recovery_s: float = 0.6
@export var attack_cooldown_s: float = 1.2
@export var attack_multiplier: float = 1.0
@export var attack_stagger: float = 20.0
@export var attack_knockback: float = 4.0
@export var attack_lunge_speed: float = 5.0
@export var attack_hitbox_size: Vector3 = Vector3(1.8, 1.4, 1.6)
@export var attack_hitbox_offset: Vector3 = Vector3(0.0, 1.0, -1.0)
@export var telegraph_radius: float = 1.6
## Heavy hitters throw the hero through the air (owner: "kena gebuk, mental jauh"):
## upward speed added to the knockback (0 = only a shove).
@export var attack_launch: float = 0.0
## Venomous bites (PoisonEffect): chance per hit, share of max HP per second, seconds.
@export var attack_poison: float = 0.0
@export var poison_share: float = 0.02
@export var poison_s: float = 5.0

@export_group("Ranged")
## Shoots instead of swinging: keeps its distance, aims with a red sight line during the
## windup (leading a moving target), locks the aim just before firing.
@export var ranged: bool = false
@export var projectile_speed: float = 30.0
## 0 = shoots where the hero is, 1 = where the hero will be when the shot arrives.
@export var aim_lead: float = 0.9
## Backs away when the hero comes closer than this.
@export var keep_distance_m: float = 7.0
@export var projectile_color: Color = Color(1.0, 0.45, 0.15)

## World flag set when this enemy dies (secret bosses, story).
@export var death_flag: StringName = &""

@export_group("Rewards")
@export var xp_reward: int = 20
@export var gold_reward: int = 5
@export var drops_loot: bool = true
