extends Node2D

@export var algorithm: Node
@export var tempo: Timer

var chunk_scene: PackedScene = preload("res://map/chunks/chunk.tscn")
var chunks: Dictionary[Vector2i, Chunk] = {}
var chunk_size: Vector2i = Constants.CHUNK_SIZE
var cell_size: int = Constants.CELL_SIZE

var ghost_chunks: Dictionary[Vector2i, Chunk.Direction] = {}

func _ready() -> void:
	starting_chunk_spawn()
	tempo.start()
	expand()

func expand() -> void:
	var coords: Vector2i
	var coord_pool: Array[Vector2i]
	
	for gc in ghost_chunks:
		coord_pool.append(gc)
	if coord_pool.size() == 0: coords = coord_pool[0]
	else: coords = coord_pool.get(randi() % coord_pool.size())
	
	spawn_chunk(coords)
	chunks[coords].draw_connections([ghost_chunks[coords]])
	
	var expand_directions := [
		Chunk.Direction.NORTH,
		Chunk.Direction.SOUTH,
		Chunk.Direction.EAST,
		Chunk.Direction.WEST
	]
	expand_directions.erase(ghost_chunks[coords])
	expand_directions = decide_path(expand_directions, coords)
	chunks[coords].draw_connections(expand_directions)
	

func decide_path(directions: Array[Chunk.Direction], coords: Vector2i):
	var h = algorithm.get_height(coords)
	var n:Array[Vector2i]
	var d: Array[Chunk.Direction]
	for dir in directions:
		match dir:
			Chunk.Direction.NORTH:
				pass
			Chunk.Direction.SOUTH:
				pass
			Chunk.Direction.EAST:
				pass
			Chunk.Direction.WEST:
				pass

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

func starting_chunk_spawn() -> void:
	algorithm.set_random_seed()
	spawn_chunk(Vector2i(0,0))
	chunks[Vector2i(0, 0)].draw_connections([Chunk.Direction.NORTH])
	ghost_chunks[Vector2i(0, -1)] = Chunk.Direction.SOUTH
