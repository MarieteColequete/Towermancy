extends Node2D

var chunk_scene: PackedScene = preload("res://map/chunks/chunk.tscn")
var chunks: Dictionary[Vector2i, Chunk] = {}
var chunk_size: Vector2i = Constants.CHUNK_SIZE
var cell_size: int = Constants.CELL_SIZE

func _ready() -> void:
	spawn_chunk(Vector2i(0,0))
	chunks[Vector2i(0, 0)].draw_connections([Chunk.Direction.NORTH, Chunk.Direction.SOUTH])

func spawn_chunk(chunk_coords: Vector2i):
	if chunks.has(chunk_coords):
		return
	
	var chunk_instance = chunk_scene.instantiate()
	
	chunk_instance.set_chunk_coords(chunk_coords)
	
	chunk_instance.position = chunk_to_world(chunk_coords)
	
	add_child(chunk_instance)
	chunks[chunk_coords] = chunk_instance

func chunk_to_world(coords: Vector2i) -> Vector2:
	return Vector2(
		coords.x * chunk_size.x * cell_size,
		coords.y * chunk_size.y * cell_size
	)
