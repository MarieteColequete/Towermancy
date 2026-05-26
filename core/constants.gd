extends Node

enum Directions {NORTH, SOUTH, EAST, WEST}

const CHUNK_SIZE: Vector2i = Vector2i(3, 3)
const CELL_SIZE: int = 2000
const STARTING_HP: int = 100

static func direction_to_string(direction: int) -> String:
	match direction:
		Directions.NORTH:
			return "NORTH"
		Directions.SOUTH:
			return "SOUTH"
		Directions.EAST:
			return "EAST"
		Directions.WEST:
			return "WEST"
		_:
			return "UNKNOWN"

static func direction_to_vector(direction: int) -> Vector2i:
	match direction:
		Directions.NORTH:
			return Vector2i(0, -1)
		Directions.SOUTH:
			return Vector2i(0, 1)
		Directions.EAST:
			return Vector2i(1, 0)
		Directions.WEST:
			return Vector2i(-1, 0)

	return Vector2i.ZERO


static func opposite_direction(direction: int) -> int:
	match direction:
		Directions.NORTH:
			return Directions.SOUTH
		Directions.SOUTH:
			return Directions.NORTH
		Directions.EAST:
			return Directions.WEST
		Directions.WEST:
			return Directions.EAST

	return -1
