@tool
extends Node

@export var seed_param: int
@export var coords_param: Vector2i
@export var noise: Noise

@export_tool_button("Run Test")
var run_test_button: Callable = run_test

func run_test():
	print_test(5)

func set_seed(s):
	noise.seed = s

func set_random_seed():
	set_seed(randi() % 100000001)

func get_height(coords: Vector2i) -> int:
	#var h: int = -max(abs(coords.x), abs(coords.y)) * 2
	var h: int = -coords.length() * 11
	return h + noise.get_noise_2d(coords.x, coords.y) * 100

func print_test(size: int):
	print("PRINT TEST:")
	for line in range(-size, size + 1):
		var ps: String = ""
		for comp in range(-size, size + 1):
			ps += str(get_height(Vector2i(line, comp)))
			ps += ", "
		print(ps)

func get_slope(coords: Vector2i) -> float:
	var h_n = get_height(coords + Vector2i(0, -1))
	var h_s = get_height(coords + Vector2i(0, 1))
	var h_e = get_height(coords + Vector2i(1, 0))
	var h_w = get_height(coords + Vector2i(-1, 0))
	
	var dx = (h_e - h_w) * 0.5
	var dz = (h_s - h_n) * 0.5
	
	return sqrt(dx * dx + dz * dz)

func can_go_down(coords: Vector2i) -> bool:
	var h = get_height(coords)
	
	var neighbors = [
		Vector2i(-1, 0),
		Vector2i(1, 0),
		Vector2i(0, -1),
		Vector2i(0, 1)
	]
	
	for offset in neighbors:
		var neighbor_coords = coords + offset
		if get_height(neighbor_coords) < h:
			return true
	
	return false
