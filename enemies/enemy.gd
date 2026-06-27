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

@export var icons: Array[Texture2D] = []
@export var rotation_speed: float = 1.5

var max_hp: int = 10
var current_hp: int = 10
var speed: float = 80.0
var damage: int = 1
var size: float = 1.0
var armor: int = 0
var plating: int = 0

# -------------------------
# Signals
# -------------------------

signal reached_base(damage: int)
signal died

# -------------------------
# Movement state
# -------------------------

# Reference to MapDirector, set by WaveDirector before activation.
var map_director: Node = null

# Current movement target in world-space. Updated on arrival at each chunk center.
var _target: Vector2 = Vector2.ZERO
var _active: bool = false


# -------------------------
# Lifecycle
# -------------------------

func _ready() -> void:
	scale = Vector2(size * 10.0, size * 10.0)
	_apply_icon()

func _physics_process(delta: float) -> void:
	_rotate_icon(delta)
	if not _active:
		return
	_move_toward_target(delta)


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

# Called by WaveDirector after map_director and spawn position are set.
func activate(spawn_position: Vector2) -> void:
	if map_director == null:
		push_error("[Enemy] map_director not set before activate().")
		return
	position = spawn_position
	_request_next_target()
	_active = true


# -------------------------
# Movement
# -------------------------

func _move_toward_target(delta: float) -> void:
	var to_target: Vector2 = _target - position
	var dist: float = to_target.length()
	var move: float = speed * delta

	if move >= dist:
		# Arrived at chunk center
		position = _target
		_request_next_target()
	else:
		position += to_target.normalized() * move


# Ask MapDirector for the next chunk center to move toward.
func _request_next_target() -> void:
	var current_chunk: Vector2i = map_director.world_to_chunk(position)
	var next_pos: Vector2 = map_director.get_next_position(current_chunk)

	if next_pos == Vector2.ZERO:
		# get_next_position returns ZERO when at origin = base reached
		_on_reached_base()
		return

	_target = next_pos


# -------------------------
# Damage
# -------------------------

func take_damage(raw: int) -> int:
	var after_plating: int = max(1, raw - plating)
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
