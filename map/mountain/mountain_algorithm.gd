@tool
extends Node

# --------------------------------------------------
# Exports / Parameters
# --------------------------------------------------
@export var seed_param: int
@export var coords_param: Vector2i
@export var noise: Noise

# Tool button to run a test
@export_tool_button("Run Test")
var run_test_button: Callable = run_test

# --------------------------------------------------
# Utility functions
# --------------------------------------------------

# Set the noise seed explicitly
func set_seed(s: int) -> void:
	noise.seed = s

# Set a random seed
func set_random_seed() -> void:
	set_seed(randi() % 100_000_001)

# Compute height at coordinates
func get_height(coords: Vector2i) -> int:
	# Base height decreases with distance from origin
	var h: int = -max(abs(coords.x), abs(coords.y)) * 50
	# Add 2D noise
	return h + noise.get_noise_2d(coords.x, coords.y) * 10

# Compute slope at coordinates using central differences
func get_slope(coords: Vector2i) -> float:
	var h_n = get_height(coords + Vector2i(0, -1))
	var h_s = get_height(coords + Vector2i(0, 1))
	var h_e = get_height(coords + Vector2i(1, 0))
	var h_w = get_height(coords + Vector2i(-1, 0))

	var dx = (h_e - h_w) * 0.5
	var dz = (h_s - h_n) * 0.5

	return sqrt(dx * dx + dz * dz)

# Determine if there is a lower neighbor
func can_go_down(coords: Vector2i) -> bool:
	var h = get_height(coords)

	# Offsets for immediate neighbors (N, S, E, W)
	var neighbors := [
		Vector2i(-1, 0),
		Vector2i(1, 0),
		Vector2i(0, -1),
		Vector2i(0, 1)
	]

	for offset in neighbors:
		if get_height(coords + offset) < h:
			return true

	return false

# --------------------------------------------------
# Testing / Debug
# --------------------------------------------------
func run_test() -> void:
	print_test(5)

# Print a grid of heights around the origin
func print_test(size: int) -> void:
	print("PRINT TEST:")
	for y in range(-size, size + 1):
		var line_str: String = ""
		for x in range(-size, size + 1):
			line_str += str(get_height(Vector2i(x, y))) + ", "
		print(line_str)
