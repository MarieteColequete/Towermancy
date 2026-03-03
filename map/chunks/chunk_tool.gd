@tool
extends Node

@export var chunk_size: Vector2i = Vector2i(15, 15)

func _notification(what):
	if Engine.is_editor_hint() and what == NOTIFICATION_EDITOR_POST_SAVE:
		auto_tile()
		clamp_tilemaps()
		assert(chunk_size.x % 2 != 0, "Chunk size must be odd")
		assert(chunk_size.y % 2 != 0, "Chunk size must be odd")


func clamp_tilemaps():
	var tilemaps = [$"../PathTiles", $"../WorldTiles"]
	for tilemap in tilemaps:
		var used_cells = tilemap.get_used_cells()
		for cell in used_cells:
			if cell.x < 0 \
			or cell.y < 0 \
			or cell.x >= chunk_size.x \
			or cell.y >= chunk_size.y:
				tilemap.erase_cell(cell)

func auto_tile():
	var world_layer: TileMapLayer = $"../WorldTiles"
	var path_layer: TileMapLayer = $"../PathTiles"
	
	var arr = []
	for x in range(chunk_size.x):
		for y in range(chunk_size.y):
			arr.append(Vector2i(x, y))
	
	world_layer.set_cells_terrain_connect(arr, 0, 0)
	
	for cell in path_layer.get_used_cells():
		world_layer.erase_cell(cell)
