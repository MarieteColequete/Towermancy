extends Node2D

@export var chunk_size: Vector2i = Vector2i(15, 15)
@onready var world_tilemap: TileMapLayer = $WorldTiles
@onready var path_tilemap: TileMapLayer = $PathTiles

#var directions := {
	#0: "dead_end",
	#1: "straight",
	#2: "turn",
	#3: "t_cross",
	#4: "x_cross"
#}

func _ready():
	assert(chunk_size.x % 2 != 0, "Chunk size must be odd")
	assert(chunk_size.y % 2 != 0, "Chunk size must be odd")
	pass

func get_connections() -> Dictionary :
	var middle: Vector2i = chunk_size / 2
	var output := {
	"north": false,
	"south": false,
	"east": false,
	"west": false
	}
	
	if path_tilemap.get_cell_tile_data(Vector2i(middle.x, 0)) != null:
		output.north = true
	if path_tilemap.get_cell_tile_data(Vector2i(middle.x, chunk_size.y - 1)) != null:
		output.south = true
	if path_tilemap.get_cell_tile_data(Vector2i(0, middle.y)) != null:
		output.west = true
	if path_tilemap.get_cell_tile_data(Vector2i(chunk_size.x - 1, middle.y)) != null:
		output.east = true
	
	return output

func _get_path_amount(connections: Dictionary) -> int:
	var amount: int = 0
	for x in connections:
		if connections[x] == true: amount += 1
	
	assert(amount > 0, "There are no paths")
	return amount

func get_direction() -> String:
	var connections := get_connections()
	var path_amount: int = _get_path_amount(connections)
	
	match path_amount:
		1:
			return "dead_end"
		2:
			if (connections.get("north") == true and connections.get("south") == true) or (connections.get("west") == true and connections.get("east") == true):
				return "straight"
			else: return "turn"
		3:
			return "t_cross"
		4:
			return "x_cross"
	
	assert(true, "No direction found")
	return "not found"
