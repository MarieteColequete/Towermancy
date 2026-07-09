class_name Bullet
extends Node2D

#> STATS
# Speed is unique to this projectile scene and is not inherited.
# Damage and other combat stats are pulled from the Tower via setup().

@export var speed: float = 20000.0

var damage: float = 0.0
var lifetime_timer: Timer


#> LIFECYCLE

func _ready() -> void:
	var hitbox: Area2D = get_node_or_null("Hitbox")
	assert(hitbox != null, "[Bullet] No Hitbox child found.")
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	_setup_lifetime_timer()
	on_spawn()

func _physics_process(delta: float) -> void:
	# Moves along its own facing direction, set externally via global_rotation
	position += Vector2.RIGHT.rotated(rotation) * speed * delta


#> SETUP
# Called by TowerWeapon right after instantiating the projectile.
# Lets the projectile pull its stats from the Tower instead of hardcoding them.

func setup(tower: Tower) -> void:
	assert(tower != null, "[Bullet] setup() called with a null tower.")
	damage = tower.get_damage()
	_apply_spread(tower.get_spread())
	_start_lifetime(tower.get_optics())

func _apply_spread(spread_degrees: float) -> void:
	# spread is the +- angle (in degrees) the projectile can deviate from
	# the tower's aim. 0 = perfect accuracy, 360+ = aim is meaningless.
	var half_spread: float = spread_degrees * 0.5
	var deviation_degrees: float = randf_range(-half_spread, half_spread)
	rotation += deg_to_rad(deviation_degrees)

func _setup_lifetime_timer() -> void:
	lifetime_timer = Timer.new()
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_timeout)
	add_child(lifetime_timer)

func _start_lifetime(optics: float) -> void:
	# Gives the projectile 50% more travel distance than the tower's range,
	# so it can still hit targets acquired near the edge of that range.
	assert(speed > 0, "[Bullet] speed must be greater than 0.")
	var lifetime_distance: float = optics * 1.5
	lifetime_timer.wait_time = lifetime_distance / speed
	lifetime_timer.start()


#> COLLISION

func _on_hitbox_area_entered(area: Area2D) -> void:
	var enemy: Node = area.get_owner()
	assert(enemy != null and enemy.has_method("take_damage"), "[Bullet] Hitbox collided with a non-enemy area.")
	var damage_dealt: int = enemy.take_damage(int(damage))
	on_hit(enemy, damage_dealt)
	queue_free()


#> LIFETIME EXPIRATION

func _on_lifetime_timeout() -> void:
	on_lifetime_expired()
	queue_free()


#> VIRTUAL HOOKS
# Override these in subclasses to add custom on-spawn / on-hit / on-lifetime-
# expired behavior without touching the base collision and movement logic.

func on_spawn() -> void:
	pass

func on_hit(_enemy: Node, _damage_dealt: int) -> void:
	pass

func on_lifetime_expired() -> void:
	pass
