class_name Tower
extends Node2D

enum TargetMode { FIRST, LAST, MOST_HP, LEAST_HP, CLOSEST, FARTHEST }

@export_category("Tower info")
@export var _title: String = "Title?"
@export var _description: String = "Description?"
@export var _mods: Array[TowerMod]
@export var _level: int = 1
@export var _stats: TowerStats
@export var _stats_scaling: TowerStats
@export var target_mode: TargetMode = TargetMode.CLOSEST

var _current_target: Node2D = null


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_update_target()


#> TARGETING
# Scans every enemy inside the tower's optics radius and picks the ideal one
# based on target_mode. If the chosen mode doesn't resolve to a target
# (e.g. FIRST / LAST, whose logic lives elsewhere), falls back to the first
# enemy found in range as a safeguard.

func get_current_target() -> Node2D:
	return _current_target

func _update_target() -> void:
	var enemies_in_range: Array = _get_enemies_in_range()
	_current_target = _select_target(enemies_in_range)

func _get_enemies_in_range() -> Array:
	var enemies_in_range: Array = []
	var range_radius: float = get_optics()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) <= range_radius:
			enemies_in_range.append(enemy)
	return enemies_in_range

func _select_target(enemies: Array) -> Node2D:
	if enemies.is_empty():
		return null
	var target: Node2D = null
	match target_mode:
		TargetMode.FIRST:
			pass # TODO: implement
		TargetMode.LAST:
			pass # TODO: implement
		TargetMode.MOST_HP:
			target = _get_hp_extreme(enemies, true)
		TargetMode.LEAST_HP:
			target = _get_hp_extreme(enemies, false)
		TargetMode.CLOSEST:
			target = _get_distance_extreme(enemies, true)
		TargetMode.FARTHEST:
			target = _get_distance_extreme(enemies, false)
	if target == null:
		target = enemies[0]
	return target

func _get_hp_extreme(enemies: Array, most: bool) -> Node2D:
	var picked: Node2D = enemies[0]
	for enemy in enemies:
		if most and enemy.current_hp > picked.current_hp:
			picked = enemy
		elif not most and enemy.current_hp < picked.current_hp:
			picked = enemy
	return picked

func _get_distance_extreme(enemies: Array, closest: bool) -> Node2D:
	var picked: Node2D = enemies[0]
	var picked_dist: float = global_position.distance_to(picked.global_position)
	for enemy in enemies:
		var dist: float = global_position.distance_to(enemy.global_position)
		if closest and dist < picked_dist:
			picked = enemy
			picked_dist = dist
		elif not closest and dist > picked_dist:
			picked = enemy
			picked_dist = dist
	return picked


#> GETTERS & SETTERS
# get() and set() functions

func get_mods() -> Array[TowerMod]:
	return _mods

func get_level() -> int:
	return _level

func get_damage() -> float:
	return _stats.damage + _stats_scaling.damage * _level

func get_attack_speed() -> float:
	return _stats.attack_speed + _stats_scaling.attack_speed * _level

func get_attack_speed_timer() -> float:
	var attack_speed = get_attack_speed()
	assert(attack_speed > 0, "attack_speed must be greater than 0")
	return 1.0 / attack_speed

func get_optics() -> float:
	return _stats.optics + _stats_scaling.optics * _level

func get_spread() -> float:
	return _stats.spread + _stats_scaling.spread * _level

func get_title() -> String:
	return _title

func get_description() -> String:
	return _description
