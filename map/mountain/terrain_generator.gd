class_name TerrainGenerator
extends Resource

@export var noise: Noise

# -------------------------
# Seed control
# -------------------------
func set_seed(s: int) -> void:
	if noise:
		noise.seed = s

func set_random_seed() -> void:
	set_seed(randi() % 100_000_001)

# -------------------------
# Core generation
# -------------------------
func get_height(coords: Vector2i) -> int:
	var h: int = -max(abs(coords.x), abs(coords.y)) * 50
	return h + int(noise.get_noise_2d(coords.x, coords.y) * 10.0)

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

# -------------------------
# Debug helpers (optional but useful in runtime too)
# -------------------------
func debug_print_grid(size: int) -> void:
	print("PRINT TEST:")
	for y in range(-size, size + 1):
		var line_str := ""
		for x in range(-size, size + 1):
			line_str += str(get_height(Vector2i(x, y))) + ", "
		print(line_str)
