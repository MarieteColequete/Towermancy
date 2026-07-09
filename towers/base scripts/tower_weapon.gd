class_name TowerWeapon
extends Node2D

@export var _projectile: PackedScene
@export var _projectile_spawn: Marker2D
@export var _tower: Tower
@export var _visuals: TowerVisuals

var _attack_accumulator: float = 0.0


func _ready() -> void:
	pass

func _process(delta: float) -> void:
	var target: Node2D = _tower.get_current_target()
	if target == null:
		return
	_visuals.rotate_towards_target(target.global_position)
	_accumulate_attack(delta)


#> SHOOTING
# Uses a time accumulator instead of a Timer node. A Timer can only fire
# once per frame at best, which caps the effective attack_speed at the
# framerate once wait_time drops below a frame's duration. The accumulator
# has no such ceiling, can fire more than once per frame if needed, and
# always reflects the tower's current attack_speed instead of a value
# cached once at _ready().

func _accumulate_attack(delta: float) -> void:
	_attack_accumulator += delta
	var interval: float = _tower.get_attack_speed_timer()
	while _attack_accumulator >= interval:
		_attack_accumulator -= interval
		shoot()

func shoot() -> void:
	assert(_projectile != null, "_weapon not assigned")
	var projectile_instance = _projectile.instantiate()
	get_tree().current_scene.add_child(projectile_instance)
	var spawn_transform = get_pst()
	projectile_instance.global_position = spawn_transform.origin
	projectile_instance.global_rotation = spawn_transform.get_rotation()
	projectile_instance.setup(_tower)

func get_pst() -> Transform2D: # Get Proyectile Spawn Transform
	return _projectile_spawn.get_global_transform() #TODO: Fix rotation?
