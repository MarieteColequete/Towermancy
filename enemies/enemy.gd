class_name Enemy
extends Node2D

# -------------------------
# Enemy types
# -------------------------

enum EnemyType { ROGUE, NORMIE, WARRIOR, WIZARD, BOSS, UBER_BOSS }

# -------------------------
# Stats
# -------------------------

var enemy_type: EnemyType = EnemyType.NORMIE

# Icons per type — assign textures in the Inspector (order matches EnemyType enum).
@export var icons: Array[Texture2D] = []

# Rotation speed of the icon in radians per second.
@export var rotation_speed: float = 1.5
var max_hp: int = 10
var current_hp: int = 10
var speed: float = 80.0   # Pixels per second
var damage: int = 1       # Damage dealt to base on arrival
var size: float = 1.0     # Visual scale
var armor: int = 0        # Percentage damage reduction: final = raw * (100 / (100 + armor))
var plating: int = 0      # Flat reduction per hit before armor, minimum 1 after

# -------------------------
# Signals
# -------------------------

signal reached_base(damage: int)
signal died

# -------------------------
# Movement state
# -------------------------

# Pre-built world-space positions from spawn to base, assigned by WaveDirector.
var waypoints: Array[Vector2] = []
var _current_waypoint_index: int = 0
var _active: bool = false


# -------------------------
# Lifecycle
# -------------------------

func _ready() -> void:
	scale = Vector2(size * 10.0, size * 10.0)
	_apply_icon()

func _physics_process(delta: float) -> void:
	_rotate_icon(delta)
	if not _active or waypoints.is_empty():
		return
	_move_along_path(delta)


# -------------------------
# Icon
# -------------------------

func _apply_icon() -> void:
	var icon: Sprite2D = get_node_or_null("Icon")
	if icon == null:
		push_warning("[Enemy] No Icon child found.")
		return
	var idx: int = enemy_type as int
	if icons.size() > idx and icons[idx] != null:
		icon.texture = icons[idx]
	else:
		push_warning("[Enemy] No icon assigned for type: " + str(enemy_type))

func _rotate_icon(delta: float) -> void:
	var icon: Sprite2D = get_node_or_null("Icon")
	if icon != null:
		icon.rotation += rotation_speed * delta


# -------------------------
# Activation
# -------------------------

# Called by WaveDirector after waypoints are assigned.
func activate() -> void:
	if waypoints.is_empty():
		push_warning("[Enemy] Activated with no waypoints.")
		return
	_active = true
	position = waypoints[0]
	_current_waypoint_index = 1  # waypoints[0] is spawn; head toward index 1


# -------------------------
# Movement
# -------------------------

func _move_along_path(delta: float) -> void:
	if _current_waypoint_index >= waypoints.size():
		_on_reached_base()
		return

	var target: Vector2 = waypoints[_current_waypoint_index]
	var to_target: Vector2 = target - position
	var dist: float = to_target.length()
	var move: float = speed * delta

	if move >= dist:
		position = target
		_current_waypoint_index += 1
		if _current_waypoint_index >= waypoints.size():
			_on_reached_base()
	else:
		position += to_target.normalized() * move


# -------------------------
# Damage
# -------------------------

# Returns the actual damage dealt after reductions.
func take_damage(raw: int) -> int:
	# Step 1: plating — flat reduction, minimum 1 result
	var after_plating: int = max(1, raw - plating)

	# Step 2: armor — percentage reduction: final = after_plating * (100 / (100 + armor))
	var after_armor: int = max(1, int(float(after_plating) * (100.0 / (100.0 + float(armor)))))

	current_hp -= after_armor
	if current_hp <= 0:
		_on_died()

	return after_armor


# -------------------------
# Events
# -------------------------

func _on_reached_base() -> void:
	_active = false
	reached_base.emit(damage)
	queue_free()

func _on_died() -> void:
	_active = false
	died.emit()
	queue_free()
