class_name TowerVisuals
extends Node2D

@export var _cannon: Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


#> AIMING
# Rotates the Cannon sprite in place to face target_position.
# Uses global_rotation so it aims correctly regardless of how this
# TowerVisuals node itself is rotated or nested.

func rotate_towards_target(target_position: Vector2) -> void:
	assert(_cannon != null, "[TowerVisuals] _cannon not assigned.")
	_cannon.global_rotation = (target_position - _cannon.global_position).angle()
