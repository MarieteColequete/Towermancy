extends Node2D

@export var algorithm: Node
@export var tempo: Timer

var chunk_scene: PackedScene = preload("res://map/chunks/chunk.tscn")

var chunks: Dictionary[Vector2i, Chunk] = {}

var ghost_chunks: Dictionary[Vector2i, Chunk.Direction] = {}

var chunk_size: Vector2i = Constants.CHUNK_SIZE
var cell_size: int = Constants.CELL_SIZE

var fork_credits: int = -20

func _ready():
	tempo.timeout.connect(_on_timer_timeout)
	
	create_initial_chunk(1)
	
	tempo.start()
	
	run_expansion_test(300)


func _on_timer_timeout():
	#test_expand_step()
	pass


# --------------------------------------------------
# Chunk spawning
# --------------------------------------------------

func spawn_chunk(chunk_coords: Vector2i):
	
	if chunks.has(chunk_coords):
		return
	
	var chunk_instance: Chunk = chunk_scene.instantiate()
	
	chunk_instance.set_chunk_coords(chunk_coords)
	
	chunk_instance.position = chunk_to_world(chunk_coords)
	
	add_child(chunk_instance)
	
	chunks[chunk_coords] = chunk_instance


func chunk_to_world(coords: Vector2i) -> Vector2:
	return Vector2(
		coords.x * chunk_size.x * cell_size,
		coords.y * chunk_size.y * cell_size
	)


# --------------------------------------------------
# Initial map creation
# --------------------------------------------------

func create_initial_chunk(num_paths: int = 2):
	
	var origin := Vector2i.ZERO
	
	spawn_chunk(origin)
	
	var dirs: Array[Chunk.Direction] = Chunk.all_directions()
	dirs.shuffle()
	
	var selected: Array[Chunk.Direction] = []
	
	for i in range(num_paths):
		selected.append(dirs[i])
	
	chunks[origin].draw_connections(selected)
	
	for dir in selected:
		var ghost = origin + direction_to_vector(dir)
		ghost_chunks[ghost] = opposite(dir)


# --------------------------------------------------
# Expansion test (lab logic)
# --------------------------------------------------

func test_expand_step():
	
	if ghost_chunks.is_empty():
		return
	
	var ghost_coords: Vector2i = ghost_chunks.keys().pick_random()
	
	var entry_dir: Chunk.Direction = ghost_chunks[ghost_coords]
	
	expand_into_chunk(ghost_coords, entry_dir)


func expand_into_chunk(coords: Vector2i, entry_dir: Chunk.Direction):
	
	ghost_chunks.erase(coords)
	
	spawn_chunk(coords)
	
	fork_credits += 1
	
	var dirs: Array[Chunk.Direction] = [entry_dir]
	
	var possible_dirs: Array[Chunk.Direction] = Chunk.all_directions()
	possible_dirs.erase(entry_dir)
	
	var current_height: int = algorithm.get_height(coords)
	
	# -----------------------------
	# Best direction
	# -----------------------------
	var best_dir: Chunk.Direction
	var best_height := -INF
	var found := false
	
	for dir in possible_dirs:
	
		var next_coords: Vector2i = coords + direction_to_vector(dir)
	
		if chunks.has(next_coords):
			continue
	
		if ghost_chunks.has(next_coords):
			continue
	
		var next_height: int = algorithm.get_height(next_coords)
	
		if next_height > current_height:
			continue
	
		if next_height > best_height:
			best_height = next_height
			best_dir = dir
			found = true
	
	if found:
		dirs.append(best_dir)
	
	# -----------------------------
	# Fork logic
	# -----------------------------
	var available_ghosts: Array[Chunk.Direction] = []
	
	for dir in possible_dirs:
		var next_coords = coords + direction_to_vector(dir)
		if not chunks.has(next_coords) and not ghost_chunks.has(next_coords):
			var next_height: int = algorithm.get_height(next_coords)
			if next_height <= current_height:
				available_ghosts.append(dir)
	
	var fork_cost: int = 10
	
	if fork_credits >= fork_cost and available_ghosts.size() > 1:
		var fork_prob: float = min(0.5 + 0.25 * ((fork_credits / fork_cost) - 1), 0.9)
		if randf() < fork_prob:
			var max_paths: int = min(available_ghosts.size(), fork_credits / fork_cost)
			available_ghosts.shuffle()
			var fork_paths := available_ghosts.slice(0, max_paths)
			dirs += fork_paths
			fork_credits -= fork_cost * fork_paths.size()
	
	chunks[coords].draw_connections(dirs)
	update_ghost_chunks(coords, dirs)


# --------------------------------------------------
# Ghost chunk system
# --------------------------------------------------

func update_ghost_chunks(coords: Vector2i, dirs: Array):
	
	for dir in dirs:
		
		var neighbor = coords + direction_to_vector(dir)
		
		if chunks.has(neighbor):
			continue
		
		ghost_chunks[neighbor] = opposite(dir)


# --------------------------------------------------
# Direction helpers
# --------------------------------------------------

func direction_to_vector(dir: Chunk.Direction) -> Vector2i:
	
	match dir:
		Chunk.Direction.NORTH:
			return Vector2i(0, -1)
		
		Chunk.Direction.SOUTH:
			return Vector2i(0, 1)
		
		Chunk.Direction.EAST:
			return Vector2i(1, 0)
		
		Chunk.Direction.WEST:
			return Vector2i(-1, 0)
	
	return Vector2i.ZERO


func opposite(dir: Chunk.Direction) -> Chunk.Direction:
	
	match dir:
		Chunk.Direction.NORTH:
			return Chunk.Direction.SOUTH
		
		Chunk.Direction.SOUTH:
			return Chunk.Direction.NORTH
		
		Chunk.Direction.EAST:
			return Chunk.Direction.WEST
		
		Chunk.Direction.WEST:
			return Chunk.Direction.EAST
	
	return dir


# --------------------------------------------------
# Testing
# --------------------------------------------------
func run_expansion_test(max_steps: int = 1000) -> void:
	var initial_chunks := chunks.size()
	var initial_ghosts := ghost_chunks.size()
	
	print("=== Starting expansion test ===")
	print("Initial chunks:", initial_chunks, "Initial ghosts:", initial_ghosts)
	
	var steps := 0
	
	while not ghost_chunks.is_empty() and steps < max_steps:
		test_expand_step()
		steps += 1
	
	if ghost_chunks.is_empty():
		print("Expansion finished: no more possible expansions.")
	else:
		print("Expansion stopped: reached max steps.")
	
	print("Steps executed:", steps)
	print("Chunks generated:", chunks.size())
	print("Remaining ghost chunks:", ghost_chunks.size())
