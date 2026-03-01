extends Node2D

@export var chunk_size: Vector2i = Vector2i(16, 16)
@onready var world_tilemap: TileMapLayer = $WorldTiles
@onready var path_tilemap: TileMapLayer = $PathTiles

var connections := {
	"north": false,
	"south": false,
	"east": false,
	"west": false
}

# Called when the node enters the scene tree for the first time.
func _ready():
	pass
