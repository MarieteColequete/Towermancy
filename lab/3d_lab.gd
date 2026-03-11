@tool
extends Node3D

@export var r: int
@export var height_scale: float

@export_tool_button("Run Test")
var run_test_button: Callable = run_test

@export_tool_button("Clear")
var clear_blocks_button: Callable = clear_blocks

# randi() % 50 -> random integer between 0 and 49
@export var algorithm: Node
@export var blocks: Node
@export var block: PackedScene

func run_test():
	print("///// RUNNING TEST /////")
	clear_blocks()
	algorithm.set_seed(randi() % 50000)
	
	
	
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			var coords = Vector2i(x, y)
			#	print("[Test]: Placing block in coords %s..." % coords)
			var block_instance = block.duplicate().instantiate()
			blocks.add_child(block_instance)
			var pos = Vector3(
				coords.x,
				algorithm.get_height(coords) * height_scale - 50,
				coords.y
			)
			block_instance.position = pos
			
			var mat := block_instance.get_active_material(0).duplicate() as StandardMaterial3D
			block_instance.set_surface_override_material(0, mat)
			
			var rel_x: float = float(coords.x + r) / float(2 * r)
			var rel_z: float = float(coords.y + r) / float(2 * r)
			
			var slope = algorithm.get_slope(coords)
			var slope_vis = clamp(slope / 4.0, 0.0, 1.0)
			
			var can_go_down = 0.0
			if algorithm.can_go_down(coords) == true: can_go_down = 1.0
			
			mat.albedo_color = Color(can_go_down, can_go_down, can_go_down)

func clear_blocks():
	for child in blocks.get_children():
		child.queue_free()
