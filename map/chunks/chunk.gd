extends Node2D
class_name Chunk

# --------------------------------------------------
# Exports / Constants
# --------------------------------------------------
@export var chunk_size: Vector2i = Constants.CHUNK_SIZE
@export var cell_size: int = Constants.CELL_SIZE

# --------------------------------------------------
# Nodes
# --------------------------------------------------
@onready var world_tilemap: TileMapLayer = $WorldTiles
@onready var path_tilemap: TileMapLayer = $PathTiles
@onready var chunk_tool: Node = $ChunkTool

# --------------------------------------------------
# Directions
# --------------------------------------------------
enum Direction { NORTH, SOUTH, EAST, WEST }

var _connections: Dictionary = {
	Direction.NORTH: false,
	Direction.SOUTH: false,
	Direction.EAST: false,
	Direction.WEST: false
}

var chunk_coords: Vector2i

# --------------------------------------------------
# Life cycle
# --------------------------------------------------
func _ready():
	# Ensure tilemaps have correct tile size
	world_tilemap.tile_set.tile_size = Vector2i(cell_size, cell_size)
	path_tilemap.tile_set.tile_size = Vector2i(cell_size, cell_size)
	
	# Ensure chunk dimensions are odd for proper centering
	assert(chunk_size.x % 2 != 0, "Chunk size x must be odd")
	assert(chunk_size.y % 2 != 0, "Chunk size y must be odd")

# --------------------------------------------------
# Connections
# --------------------------------------------------
func get_connections() -> Dictionary:
	return _connections.duplicate()

func get_active_connections() -> Array[Direction]:
	var active: Array[Direction] = []
	for dir in _connections.keys():
		if _connections[dir]:
			active.append(dir)
	return active

func is_connection_active(dir: Direction) -> bool:
	return _connections.get(dir, false)

func clear_connections():
	for dir in _connections.keys():
		_connections[dir] = false

func draw_connections(directions: Array[Direction]) -> void:
	clear_connections()
	for dir in directions:
		_connections[dir] = true
		_draw_path_from_center(dir)
	chunk_tool.auto_tile()

# --------------------------------------------------
# Path drawing
# --------------------------------------------------
func _draw_path_from_center(dir: Direction) -> void:
	# Compute center position
	var middle := Vector2i(chunk_size.x / 2, chunk_size.y / 2)
	var pos := middle

	var delta: Vector2i
	match dir:
		Direction.NORTH: delta = Vector2i(0, -1)
		Direction.SOUTH: delta = Vector2i(0, 1)
		Direction.WEST:  delta = Vector2i(-1, 0)
		Direction.EAST:  delta = Vector2i(1, 0)

	# Loop until edge of chunk
	while pos.x >= 0 and pos.x < chunk_size.x and pos.y >= 0 and pos.y < chunk_size.y:
		path_tilemap.set_cells_terrain_connect([pos], 0, 1, false)
		pos += delta

# --------------------------------------------------
# Chunk coordinates
# --------------------------------------------------
func set_chunk_coords(coords: Vector2i):
	chunk_coords = coords

# --------------------------------------------------
# Static helpers
# --------------------------------------------------
static func all_directions() -> Array[Direction]:
	return [Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST]
