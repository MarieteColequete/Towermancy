extends Node2D
class_name Chunk

var chunk_size: Vector2i = Constants.CHUNK_SIZE
var cell_size: int = Constants.CELL_SIZE
@onready var world_tilemap: TileMapLayer = $WorldTiles
@onready var path_tilemap: TileMapLayer = $PathTiles

@onready var chunk_tool: Node = $ChunkTool

enum Direction { NORTH, SOUTH , EAST, WEST}

var _connections := {
	Direction.NORTH: false,
	Direction.SOUTH: false,
	Direction.EAST: false,
	Direction.WEST: false
}

var chunk_coords: Vector2i

func _ready():
	world_tilemap.tile_set.tile_size = Vector2i(cell_size, cell_size)
	path_tilemap.tile_set.tile_size = Vector2i(cell_size, cell_size)
	assert(chunk_size.x % 2 != 0, "Chunk size must be odd")
	assert(chunk_size.y % 2 != 0, "Chunk size must be odd")
	pass

func get_connections() -> Dictionary[StringName, bool]:
	return _connections;	

func get_active_connections() -> Dictionary[StringName, bool]:
	var result: Dictionary[StringName, bool]
	for i in _connections:
		if i == true: result.assign(i)
	return result

func is_connection_active(dir: Direction) -> bool:
	return _connections.get(dir, false)

func clear_connections():
	for dir in _connections:
		_connections[dir] = false

func draw_connections(directions: Array[Direction]) -> void:
	clear_connections()
	
	for dir in directions:
		_connections[dir] = true
		_draw_path_from_center(dir)
	chunk_tool.auto_tile()


func _draw_path_from_center(dir: Direction) -> void:
	var middle := Vector2i(chunk_size.x / 2, chunk_size.y / 2)
	var pos := middle
	
	match dir:
		Direction.NORTH:
			while pos.y > 0:
				path_tilemap.set_cells_terrain_connect([pos], 0, 1, false)
				pos.y -= 1
	
		Direction.SOUTH:
			while pos.y < chunk_size.y - 1:
				path_tilemap.set_cells_terrain_connect([pos], 0, 1, false)
				pos.y += 1
	
		Direction.WEST:
			while pos.x > 0:
				path_tilemap.set_cells_terrain_connect([pos], 0, 1, false)
				pos.x -= 1
	
		Direction.EAST:
			while pos.x < chunk_size.x - 1:
				path_tilemap.set_cells_terrain_connect([pos], 0, 1, false)
				pos.x += 1

func set_chunk_coords(coords: Vector2i):
	chunk_coords = coords
