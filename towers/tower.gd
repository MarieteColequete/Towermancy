extends Node2D

@export_category("Tower info")
@export var _mods: Array[TowerMod]
@export var _level: int = 1
@export var _weapon_spawn: Marker2D

@export var _stats: TowerStats
@export var _stats_scaling: TowerStats

@export var _weapon: PackedScene
@export var _visuals: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


#
#> GETTERS & SETTERS
#

func get_mods() -> Array[TowerMod]:
	return _mods

func get_level() -> int:
	return _level

func get_weapon_spawn_transform() -> Transform2D:
	return _weapon_spawn.transform

func get_damage(level: int) -> float:
	return _stats.damage + _stats_scaling.damage_scaling * level

func get_attack_speed(level: int) -> float:
	return _stats.attack_speed + _stats_scaling.attack_speed_scaling * level

func get_optics(level: int) -> float:
	return _stats.optics + _stats_scaling.optics_scaling * level

func get_spread() -> float:
	return _stats.spread

func get_weapon() -> PackedScene:
	return _weapon

func get_visuals() -> PackedScene:
	return _visuals
