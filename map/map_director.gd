extends Node2D

@export var world: WorldData
@export var cells: TileMapLayer
@export var wave_director: WaveDirector

const TERRAIN_PATH: int = 1
const TERRAIN_EMPTY: int = 0


# -------------------------
# Lifecycle
# -------------------------

func _ready() -> void:
	world.setup()
	_generate_map()
	# Pass dead end spawn data to WaveDirector — no WorldData reference crosses over
	wave_director.receive_spawn_data(_build_spawn_data())
	wave_director.spawn_wave(0, 100)
	wave_director.spawn_wave(1, 100)
	wave_director.spawn_wave(2, 100)
	wave_director.spawn_wave(3, 100)
	wave_director.spawn_wave(4, 100)
	wave_director.spawn_wave(5, 100)


# -------------------------
# Generation
# -------------------------

func _generate_map() -> void:
	_place_origin()
	_expand_all(500)


func _place_origin() -> void:
	var origin := Vector2i.ZERO
	var all_dirs: Array = [
		Constants.Directions.NORTH,
		Constants.Directions.SOUTH,
		Constants.Directions.EAST,
		Constants.Directions.WEST,
	]
	all_dirs.shuffle()
	var dirs: Array[Constants.Directions] = [all_dirs[0] as Constants.Directions]
	world.register_chunk(origin, WorldData.ChunkState.ORIGIN, dirs)
	_render_path_chunk(origin, dirs, true)


func _expand_all(max_steps: int = 500) -> void:
	var steps := 0
	while world.has_ghosts() and steps < max_steps:
		_expand_step()
		steps += 1


func _expand_step() -> void:
	if not world.has_ghosts():
		return
	var ghost_coords: Vector2i = world.pick_random_ghost()
	var entry_dir: Constants.Directions = world.get_ghost_entry(ghost_coords)
	var dirs: Array[Constants.Directions] = world.compute_expansion_dirs(ghost_coords, entry_dir)
	world.register_chunk(ghost_coords, WorldData.ChunkState.PATH, dirs)
	_render_path_chunk(ghost_coords, dirs, false)
	_render_pending_empty_chunks()


# -------------------------
# Spawn data for WaveDirector
# -------------------------

# Builds a self-contained array of spawn descriptors.
# Each entry has: spawn world position, waypoints to base, and weight.
# WaveDirector receives this and never needs to query WorldData again.
func _build_spawn_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for dead_end in world.get_dead_end_data():
		var coords: Vector2i = dead_end["coords"]
		result.append({
			"spawn_position": _chunk_center_world(coords),
			"waypoints": _build_waypoints(coords),
			"weight": dead_end["weight"]
		})
	return result


# Build the ordered world-space positions from dead end to origin.
# Follows the depth gradient: each step picks the neighbor with depth - 1.
func _build_waypoints(start: Vector2i) -> Array[Vector2]:
	var waypoints: Array[Vector2] = []
	var current: Vector2i = start
	var visited: Dictionary[Vector2i, bool] = {}

	while true:
		if visited.has(current):
			push_warning("[MapDirector] Cycle detected in waypoint build from " + str(start))
			break

		visited[current] = true
		waypoints.append(_chunk_center_world(current))

		var depth: int = world.get_chunk_depth(current)
		if depth == 0:
			break

		var parent: Vector2i = _find_parent_chunk(current, depth)
		if parent == current:
			push_warning("[MapDirector] No parent found for chunk " + str(current))
			break

		current = parent

	return waypoints


# Returns the neighboring registered chunk with depth = current_depth - 1.
# With no convergences in the graph, there is always exactly one such neighbor.
func _find_parent_chunk(coords: Vector2i, current_depth: int) -> Vector2i:
	for dir in _all_directions():
		var neighbor: Vector2i = coords + Constants.direction_to_vector(dir)
		if not world.is_chunk_registered(neighbor):
			continue
		if world.get_chunk_depth(neighbor) == current_depth - 1:
			return neighbor
	return coords  # Fallback: should never happen in a well-formed graph


# -------------------------
# Enemy navigation query
# -------------------------

# Called by Enemy nodes when they arrive at a chunk and need the next destination.
# Returns the world-space center of the next chunk toward the base (depth - 1).
# Returns Vector2.ZERO if already at the base.
func get_next_waypoint(current_chunk: Vector2i) -> Vector2:
	var depth: int = world.get_chunk_depth(current_chunk)
	if depth == 0:
		return Vector2.ZERO  # Already at base

	var parent: Vector2i = _find_parent_chunk(current_chunk, depth)
	return _chunk_center_world(parent)


# -------------------------
# Coordinate helpers
# -------------------------

# World-space center of a chunk in pixels.
func _chunk_center_world(chunk: Vector2i) -> Vector2:
	var center_cell: Vector2i = chunk * Constants.CHUNK_SIZE + Constants.CHUNK_SIZE / 2
	return Vector2(center_cell * Constants.CELL_SIZE) + Vector2(Constants.CELL_SIZE, Constants.CELL_SIZE) * 0.5


# World-space top-left cell of a chunk.
func _chunk_to_cell_origin(chunk: Vector2i) -> Vector2i:
	return chunk * Constants.CHUNK_SIZE

func _local_to_global_cell(chunk: Vector2i, local: Vector2i) -> Vector2i:
	return _chunk_to_cell_origin(chunk) + local

func _chunk_center_local() -> Vector2i:
	return Constants.CHUNK_SIZE / 2

func _edge_cell_local(dir: Constants.Directions) -> Vector2i:
	var half: Vector2i = Constants.CHUNK_SIZE / 2
	match dir:
		Constants.Directions.NORTH:
			return Vector2i(half.x, 0)
		Constants.Directions.SOUTH:
			return Vector2i(half.x, Constants.CHUNK_SIZE.y - 1)
		Constants.Directions.EAST:
			return Vector2i(Constants.CHUNK_SIZE.x - 1, half.y)
		Constants.Directions.WEST:
			return Vector2i(0, half.y)
	return half


# -------------------------
# Rendering: path chunks
# -------------------------

func _build_path_cells(chunk: Vector2i, dirs: Array[Constants.Directions], is_origin: bool) -> Array[Vector2i]:
	var path_cells: Array[Vector2i] = []
	var center_local: Vector2i = _chunk_center_local()
	path_cells.append(_local_to_global_cell(chunk, center_local))

	if is_origin:
		for dir in dirs:
			_add_line_cells(path_cells, chunk, center_local, _edge_cell_local(dir))
	else:
		_add_line_cells(path_cells, chunk, _edge_cell_local(dirs[0]), center_local)
		for i in range(1, dirs.size()):
			_add_line_cells(path_cells, chunk, center_local, _edge_cell_local(dirs[i]))

	return path_cells


func _add_line_cells(
	path_cells: Array[Vector2i],
	chunk: Vector2i,
	local_a: Vector2i,
	local_b: Vector2i
) -> void:
	var step := Vector2i(sign(local_b.x - local_a.x), sign(local_b.y - local_a.y))
	var current := local_a
	while current != local_b:
		var g := _local_to_global_cell(chunk, current)
		if not path_cells.has(g):
			path_cells.append(g)
		current += step
	var end_g := _local_to_global_cell(chunk, local_b)
	if not path_cells.has(end_g):
		path_cells.append(end_g)


func _render_path_chunk(chunk: Vector2i, dirs: Array[Constants.Directions], is_origin: bool) -> void:
	# Paint whole chunk as buildable, then overlay path cells
	var all_cells: Array[Vector2i] = []
	var origin := _chunk_to_cell_origin(chunk)
	for x in range(origin.x, origin.x + Constants.CHUNK_SIZE.x):
		for y in range(origin.y, origin.y + Constants.CHUNK_SIZE.y):
			all_cells.append(Vector2i(x, y))
	_render_buildable_cells(all_cells)

	_render_path_cells(_build_path_cells(chunk, dirs, is_origin))


# -------------------------
# Rendering: empty chunks
# -------------------------

var _rendered_empty: Dictionary[Vector2i, bool] = {}

func _render_pending_empty_chunks() -> void:
	for chunk_coords in world.chunks.keys():
		if world.chunks[chunk_coords] != WorldData.ChunkState.EMPTY:
			continue
		if _rendered_empty.has(chunk_coords):
			continue
		_render_empty_chunk(chunk_coords)
		_rendered_empty[chunk_coords] = true


func _render_empty_chunk(chunk: Vector2i) -> void:
	var cells_list: Array[Vector2i] = []
	for x in range(Constants.CHUNK_SIZE.x):
		for y in range(Constants.CHUNK_SIZE.y):
			cells_list.append(_local_to_global_cell(chunk, Vector2i(x, y)))
	_render_buildable_cells(cells_list)


# -------------------------
# Rendering primitives
# -------------------------

func _render_path_cells(cell_list: Array[Vector2i]) -> void:
	cells.set_cells_terrain_connect(cell_list, 0, TERRAIN_PATH)

func _render_buildable_cells(cell_list: Array[Vector2i]) -> void:
	cells.set_cells_terrain_connect(cell_list, 0, TERRAIN_EMPTY)


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
