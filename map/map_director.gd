extends Node2D

@export var world: WorldData
@export var cells: TileMapLayer
@export var wave_director: WaveDirector
@export var game_ui: CanvasLayer

const TERRAIN_PATH: int = 1
const TERRAIN_EMPTY: int = 0


# -------------------------
# Lifecycle
# -------------------------

func _ready() -> void:
	world.setup()
	_generate_map()
	_sync_spawn_points()
	game_ui.initialize()
	wave_director.start_wave(30, false)


# -------------------------
# Generation
# -------------------------

func _generate_map() -> void:
	_place_origin()
	_expand_all(150)


# Public: expand map further and refresh spawn points
func expand_map(max_steps: int = 500) -> void:
	_expand_all(max_steps)
	_sync_spawn_points()


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
# Spawn points for WaveDirector
# -------------------------

func _sync_spawn_points() -> void:
	var data: Array[Dictionary] = []
	for entry in world.get_spawn_point_data():
		var coords: Vector2i = entry["coords"]

		# Ghosts are not rendered: spawn enemies at the parent chunk center instead
		var spawn_pos: Vector2
		if world.is_ghost(coords):
			var parent_dir: int = world.get_parent_dir(coords)
			var parent_coords: Vector2i = coords + Constants.direction_to_vector(parent_dir)
			spawn_pos = chunk_center_world(parent_coords)
		else:
			spawn_pos = chunk_center_world(coords)

		data.append({
			"spawn_position": spawn_pos,
			"chunk_coords": coords,
			"weight": entry["weight"]
		})
	wave_director.update_spawn_points(data)


# -------------------------
# Enemy navigation query
# -------------------------

# Called by Enemy each time it arrives at a new chunk center.
# Returns the world-space position of the next chunk toward the base.
# Returns Vector2.ZERO if the enemy is already at the origin.
func get_next_position(current_chunk: Vector2i) -> Vector2:
	var parent_dir: int = world.get_parent_dir(current_chunk)
	if parent_dir == -1:
		return Vector2.ZERO  # At origin, signal base reached
	var parent_coords: Vector2i = current_chunk + Constants.direction_to_vector(parent_dir)
	return chunk_center_world(parent_coords)


# Converts a world-space position to the chunk it belongs to.
func world_to_chunk(world_pos: Vector2) -> Vector2i:
	var cell: Vector2i = Vector2i(world_pos / Constants.CELL_SIZE)
	return Vector2i(
		floori(float(cell.x) / Constants.CHUNK_SIZE.x),
		floori(float(cell.y) / Constants.CHUNK_SIZE.y)
	)


# -------------------------
# Coordinate helpers
# -------------------------

# World-space pixel center of a chunk.
func chunk_center_world(chunk: Vector2i) -> Vector2:
	var center_cell: Vector2i = chunk * Constants.CHUNK_SIZE + Constants.CHUNK_SIZE / 2
	return Vector2(center_cell * Constants.CELL_SIZE) + Vector2(Constants.CELL_SIZE, Constants.CELL_SIZE) * 0.5

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
