# Handles tower placement: snapping to chunks, range preview, confirmation.
# Lives as a child of MapDirector and is activated by TowerShop.
class_name TowerPlacer
extends Node2D

# -------------------------
# References
# -------------------------

@export var world: WorldData
@export var game_ui: GameUI
@export var player: Player
@export var tower_container: Node2D

# -------------------------
# Signals
# -------------------------

# Emitted after a tower is successfully placed. Carries the slot index.
signal tower_placed(slot_index: int)

# -------------------------
# State
# -------------------------

var _active: bool = false
var _tower_scene: PackedScene = null
var _slot_index: int = -1
var _price: int = 0
var _current_chunk: Vector2i = Vector2i(-9999, -9999)
var _placement_valid: bool = false

# Cursor icon sprite — shows the tower icon following the mouse
var _cursor_sprite: Sprite2D = null

# Ghost tower instance kept OFF the tree, only used to read optics radius
var _stat_ghost: Tower = null

# Range circle drawn via _draw()
var _draw_range: bool = false
var _draw_position: Vector2 = Vector2.ZERO
var _draw_radius: float = 0.0

const _VALID_COLOR:   Color = Color(0.2, 0.8, 0.2, 0.25)
const _INVALID_COLOR: Color = Color(0.8, 0.2, 0.2, 0.25)

var _map_director: Node


# -------------------------
# Setup
# -------------------------

func _ready() -> void:
	_map_director = get_parent()

	# Cursor sprite that follows the mouse
	_cursor_sprite = Sprite2D.new()
	_cursor_sprite.visible = false
	_cursor_sprite.z_index = 10
	add_child(_cursor_sprite)


# -------------------------
# Activation
# -------------------------

# Called by TowerShop when the player clicks a tower slot with enough gold.
# icon_texture is the tower's icon. stat_source is a pre-built ghost Tower
# (not in the tree) used only for stat queries.
func begin_placement(tower_scene: PackedScene, price: int, slot_index: int, icon_texture: Texture2D, stat_source: Tower) -> void:
	if _active:
		cancel_placement()

	_tower_scene = tower_scene
	_price = price
	_slot_index = slot_index
	_active = true

	# Show icon on cursor
	_cursor_sprite.texture = icon_texture
	_cursor_sprite.visible = true

	# Keep stat ghost for optics queries (never added to scene tree)
	_stat_ghost = stat_source

	game_ui.notify("Select a location — right-click to cancel.")


func cancel_placement() -> void:
	if not _active:
		return
	_active = false
	_tower_scene = null
	_slot_index = -1
	_price = 0
	_draw_range = false
	_stat_ghost = null

	_cursor_sprite.visible = false
	_cursor_sprite.texture = null

	queue_redraw()
	game_ui.notify("Placement cancelled.")


# -------------------------
# Input
# -------------------------

func _input(event: InputEvent) -> void:
	if not _active:
		return

	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placement()
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_try_confirm_placement()

	elif event is InputEventMouseMotion:
		_update_cursor_position(get_global_mouse_position())


# -------------------------
# Cursor movement
# -------------------------

func _update_cursor_position(mouse_world: Vector2) -> void:
	# Icon follows mouse exactly
	_cursor_sprite.global_position = mouse_world

	# Snap position for range preview and placement snaps to chunk center
	var chunk: Vector2i = _map_director.world_to_chunk(mouse_world)
	_current_chunk = chunk
	_placement_valid = world.is_buildable(chunk)

	var snap_pos: Vector2 = _map_director.chunk_center_world(chunk)

	# Update range circle
	_draw_range = true
	_draw_position = snap_pos
	_draw_radius = _stat_ghost.get_optics() if _stat_ghost != null else 0.0
	queue_redraw()


# -------------------------
# Confirmation
# -------------------------

func _try_confirm_placement() -> void:
	if not _placement_valid:
		game_ui.notify("Cannot place here.")
		return
	if player.gold < _price:
		game_ui.notify("Not enough gold.")
		return

	player.spend_gold(_price)
	world.build_on_chunk(_current_chunk)

	var tower: Tower = _tower_scene.instantiate()
	tower.set_level(_map_director.get_current_wave())
	tower.global_position = _map_director.chunk_center_world(_current_chunk)
	tower_container.add_child(tower)

	game_ui.notify("Tower placed!")
	tower_placed.emit(_slot_index)

	_active = false
	_tower_scene = null
	_slot_index = -1
	_price = 0
	_draw_range = false
	_stat_ghost = null
	_cursor_sprite.visible = false
	_cursor_sprite.texture = null
	queue_redraw()


# -------------------------
# Range circle rendering
# -------------------------

func _draw() -> void:
	if not _draw_range or _draw_radius <= 0.0:
		return

	var local_pos: Vector2 = to_local(_draw_position)
	var color: Color = _VALID_COLOR if _placement_valid else _INVALID_COLOR

	draw_circle(local_pos, _draw_radius, color)
	draw_arc(local_pos, _draw_radius, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.8), 2.0)
