class_name WaveDirector
extends Node

# -------------------------
# Exports
# -------------------------

@export var enemy_scene: PackedScene

# -------------------------
# Internal state
# -------------------------

# Received from MapDirector after map generation.
# Each entry: { spawn_position: Vector2, waypoints: Array[Vector2], weight: float }
var _spawn_data: Array[Dictionary] = []

# Reference to MapDirector for enemy navigation queries.
# Assigned automatically since WaveDirector is a child of MapDirector.
var _map_director: Node


# -------------------------
# Setup
# -------------------------

func _ready() -> void:
	_map_director = get_parent()


# Called by MapDirector with the fully built spawn descriptors.
func receive_spawn_data(data: Array[Dictionary]) -> void:
	_spawn_data = data


# -------------------------
# Spawn interface
# -------------------------

# Spawn one enemy of the given type at every dead end.
func spawn_at_all_dead_ends(type: Enemy.EnemyType) -> void:
	for entry in _spawn_data:
		_spawn_enemy(entry, type)


# Spawn at dead ends sorted by weight, up to a count limit.
# Useful for wave logic: farther dead ends get harder enemies.
func spawn_wave(type: Enemy.EnemyType, count: int, from_heaviest: bool = false) -> void:
	var sorted := _spawn_data.duplicate()
	sorted.sort_custom(func(a, b):
		return a["weight"] < b["weight"] if not from_heaviest else a["weight"] > b["weight"]
	)
	for i in range(mini(count, sorted.size())):
		_spawn_enemy(sorted[i], type)


# -------------------------
# Internal spawn
# -------------------------

func _spawn_enemy(spawn_entry: Dictionary, type: Enemy.EnemyType) -> void:
	if enemy_scene == null:
		push_error("[WaveDirector] enemy_scene is not assigned!")
		return

	var enemy: Enemy = enemy_scene.instantiate()
	_apply_stats(enemy, type)

	# Give the enemy its pre-built waypoint list
	enemy.waypoints = (spawn_entry["waypoints"] as Array[Vector2]).duplicate()

	# Connect base-reach signal — replace handler with PlayerHealth node later
	enemy.reached_base.connect(_on_enemy_reached_base)

	# Enemies are children of WaveDirector in the scene tree
	add_child(enemy)
	enemy.activate()


# -------------------------
# Stat templates
# Speed is in pixels/sec. Multiplied by 50 to match world scale (CELL_SIZE = 2000).
# Size is a scale factor multiplied by 10 in Enemy._ready().
# -------------------------

func _apply_stats(enemy: Enemy, type: Enemy.EnemyType) -> void:
	enemy.enemy_type = type
	match type:
		Enemy.EnemyType.ROGUE:
			enemy.max_hp     = 6
			enemy.current_hp = 6
			enemy.speed      = 250.0 * 50
			enemy.damage     = 1
			enemy.size       = 0.6
			enemy.armor      = 0
			enemy.plating    = 0

		Enemy.EnemyType.NORMIE:
			enemy.max_hp     = 10
			enemy.current_hp = 10
			enemy.speed      = 80.0 * 50
			enemy.damage     = 1
			enemy.size       = 1.0
			enemy.armor      = 0
			enemy.plating    = 0

		Enemy.EnemyType.WARRIOR:
			enemy.max_hp     = 30
			enemy.current_hp = 30
			enemy.speed      = 50.0 * 50
			enemy.damage     = 2
			enemy.size       = 1.2
			enemy.armor      = 30
			enemy.plating    = 1

		Enemy.EnemyType.WIZARD:
			enemy.max_hp     = 15
			enemy.current_hp = 15
			enemy.speed      = 100.0 * 50
			enemy.damage     = 2
			enemy.size       = 1.0
			enemy.armor      = 0
			enemy.plating    = 0

		Enemy.EnemyType.BOSS:
			enemy.max_hp     = 100
			enemy.current_hp = 100
			enemy.speed      = 30.0 * 50
			enemy.damage     = 5
			enemy.size       = 2.0
			enemy.armor      = 50
			enemy.plating    = 3

		Enemy.EnemyType.UBER_BOSS:
			enemy.max_hp     = 300
			enemy.current_hp = 300
			enemy.speed      = 20.0 * 50
			enemy.damage     = 10
			enemy.size       = 3.0
			enemy.armor      = 100
			enemy.plating    = 5


# -------------------------
# Signal handlers
# -------------------------

# Placeholder: connect enemy.reached_base to a PlayerHealth node in the future.
func _on_enemy_reached_base(damage: int) -> void:
	print("[WaveDirector] Enemy reached base! Damage: ", damage)
