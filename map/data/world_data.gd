class_name WorldData
extends Resource

const DEBUG := false

@export var terrain: TerrainGenerator

# -------------------------
# State
# -------------------------

enum ChunkState { NULL, PATH, EMPTY, ORIGIN }

# chunk coords -> state
var chunks: Dictionary[Vector2i, ChunkState] = {}

# chunk coords -> depth (0 = origin, increases with distance)
var chunk_depths: Dictionary[Vector2i, int] = {}

# ghost coords -> entry direction (direction path comes FROM)
var ghost_chunks: Dictionary[Vector2i, Constants.Directions] = {}

# ghost coords -> depth it will have when activated
var ghost_depths: Dictionary[Vector2i, int] = {}

# dead end coords -> entry direction (the single connection this chunk has)
# a dead end is a PATH chunk with no exits (dirs has only the entry)
var dead_ends: Dictionary[Vector2i, Constants.Directions] = {}

var expansion_tokens: int = 50

const FORK_COST_3WAY: int = 100
const FORK_COST_4WAY: int = 110
const REVEAL_RADIUS: int = 5


# -------------------------
# Setup
# -------------------------

func setup() -> void:
	terrain.set_random_seed()
	if DEBUG: print("[WorldData] Setup completed, random seed set")


# -------------------------
# Chunk registration
# -------------------------

# Register a real chunk and update all derived state automatically.
# dirs = all connection directions for this chunk (entry + exits).
# For ORIGIN, dirs contains only exits (no entry).
func register_chunk(c: Vector2i, state: ChunkState, dirs: Array[Constants.Directions] = []) -> void:
	if DEBUG: print("[WorldData] Register chunk: ", c, " state=", state, " dirs=", dirs)
	assert(not chunks.has(c), "Chunk already registered at: " + str(c))

	chunks[c] = state

	# Assign depth: origin is 0, others inherit from their ghost record
	if state == ChunkState.ORIGIN:
		chunk_depths[c] = 0
	else:
		chunk_depths[c] = ghost_depths.get(c, 0)

	# Remove from ghost maps if pending
	ghost_chunks.erase(c)
	ghost_depths.erase(c)

	if state == ChunkState.PATH or state == ChunkState.ORIGIN:
		expansion_tokens += 1
		_update_ghost_chunks(c, dirs)
		_register_empty_chunks_around(c)
		_update_dead_ends(c, dirs)


# Determine if this chunk is a dead end and update the registry accordingly.
# Dead end = PATH chunk with no exits (dirs has only the entry direction).
# ORIGIN with no exits is also a dead end (unusual but handled).
func _update_dead_ends(c: Vector2i, dirs: Array[Constants.Directions]) -> void:
	var is_origin: bool = chunks[c] == ChunkState.ORIGIN
	var exit_count: int = dirs.size() if is_origin else dirs.size() - 1

	if exit_count == 0:
		# Store the entry direction so MapDirector knows which edge to use
		var entry_dir: Constants.Directions = dirs[0] if not is_origin else Constants.Directions.NORTH
		dead_ends[c] = entry_dir
		if DEBUG: print("[WorldData] Dead end registered: ", c, " entry=", entry_dir)
	else:
		# Chunk has exits: no longer a dead end (expanded from ghost state)
		if dead_ends.has(c):
			dead_ends.erase(c)
			if DEBUG: print("[WorldData] Dead end removed: ", c)


# Register ghost neighbors reachable from a newly placed chunk.
func _update_ghost_chunks(c: Vector2i, dirs: Array[Constants.Directions]) -> void:
	var current_height: int = terrain.get_height(c)
	var current_depth: int = chunk_depths.get(c, 0)

	for dir in dirs:
		var neighbor: Vector2i = c + Constants.direction_to_vector(dir)

		if chunks.has(neighbor):
			continue

		var neighbor_height: int = terrain.get_height(neighbor)
		if neighbor_height > current_height:
			continue

		_register_ghost(neighbor, Constants.opposite_direction(dir), current_depth + 1)


func _register_ghost(neighbor: Vector2i, entry_dir: Constants.Directions, depth: int) -> void:
	if chunks.has(neighbor):
		return
	if ghost_chunks.has(neighbor):
		return
	ghost_chunks[neighbor] = entry_dir
	ghost_depths[neighbor] = depth
	if DEBUG: print("[WorldData] Ghost added: ", neighbor, " entry=", entry_dir, " depth=", depth)


# -------------------------
# Empty chunk registration
# -------------------------

func _register_empty_chunks_around(c: Vector2i) -> void:
	var highest_ghost_height: int = _get_highest_ghost_height()

	for dx in range(-REVEAL_RADIUS, REVEAL_RADIUS + 1):
		for dy in range(-REVEAL_RADIUS, REVEAL_RADIUS + 1):
			var candidate: Vector2i = c + Vector2i(dx, dy)
			if chunks.has(candidate) or ghost_chunks.has(candidate):
				continue
			var h: int = terrain.get_height(candidate)
			if h > highest_ghost_height:
				chunks[candidate] = ChunkState.EMPTY


func _get_highest_ghost_height() -> int:
	var highest: int = -INF
	for ghost_coords in ghost_chunks.keys():
		var h: int = terrain.get_height(ghost_coords)
		if h > highest:
			highest = h
	return highest


# -------------------------
# Expansion logic
# -------------------------

func compute_expansion_dirs(coords: Vector2i, entry_dir: Constants.Directions) -> Array[Constants.Directions]:
	var dirs: Array[Constants.Directions] = [entry_dir]
	var current_height: int = terrain.get_height(coords)

	var possible: Array[Constants.Directions] = _get_free_downhill_dirs(coords, entry_dir, current_height)

	if possible.is_empty():
		return dirs  # Dead end

	var chosen_dir: Constants.Directions = possible.pick_random()
	dirs.append(chosen_dir)
	possible.erase(chosen_dir)

	if not possible.is_empty():
		dirs = _apply_fork_logic(dirs, possible)

	return dirs


func _get_free_downhill_dirs(
	coords: Vector2i,
	exclude_dir: Constants.Directions,
	current_height: int
) -> Array[Constants.Directions]:
	var result: Array[Constants.Directions] = []

	for dir in _all_directions():
		if dir == exclude_dir:
			continue
		var neighbor: Vector2i = coords + Constants.direction_to_vector(dir)
		if chunks.has(neighbor) or ghost_chunks.has(neighbor):
			continue
		if terrain.get_height(neighbor) <= current_height:
			result.append(dir)

	return result


func _apply_fork_logic(
	dirs: Array[Constants.Directions],
	candidates: Array[Constants.Directions]
) -> Array[Constants.Directions]:
	candidates.shuffle()

	for candidate in candidates:
		var exits_after: int = dirs.size()
		var cost: int = FORK_COST_3WAY if exits_after == 2 else FORK_COST_4WAY

		if expansion_tokens < cost:
			break

		var fork_prob: float = minf(0.5 + 0.25 * ((expansion_tokens / cost) - 1), 0.9)
		if randf() < fork_prob:
			dirs.append(candidate)
			expansion_tokens -= cost

		if dirs.size() >= 4:
			break

	return dirs


# -------------------------
# Queries
# -------------------------

func is_chunk_registered(c: Vector2i) -> bool:
	return chunks.has(c)

func is_ghost(c: Vector2i) -> bool:
	return ghost_chunks.has(c)

func get_chunk_state(c: Vector2i) -> ChunkState:
	return chunks.get(c, ChunkState.NULL)

func get_chunk_depth(c: Vector2i) -> int:
	return chunk_depths.get(c, 0)

func get_ghost_entry(c: Vector2i) -> Constants.Directions:
	return ghost_chunks.get(c, Constants.Directions.NORTH)

func pick_random_ghost() -> Vector2i:
	return ghost_chunks.keys().pick_random()

func has_ghosts() -> bool:
	return not ghost_chunks.is_empty()

# Returns all dead ends with their distance-from-origin weight.
# Array of { coords, entry_dir, weight }
func get_dead_end_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for coords in dead_ends.keys():
		result.append({
			"coords": coords,
			"entry_dir": dead_ends[coords],
			"weight": coords.length()
		})
	return result


# -------------------------
# Helpers
# -------------------------

func _all_directions() -> Array[Constants.Directions]:
	return [
		Constants.Directions.NORTH,
		Constants.Directions.SOUTH,
		Constants.Directions.EAST,
		Constants.Directions.WEST,
	]
