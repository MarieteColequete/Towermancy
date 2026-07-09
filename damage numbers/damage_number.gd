class_name DamageNumber
extends Node2D

#> STATS

@export var rise_speed: float = 3000.0
@export var lifetime: float = 1.0

var _elapsed: float = 0.0
var _label: Label


#> LIFECYCLE

func _ready() -> void:
	_label = get_node_or_null("Label")
	assert(_label != null, "[DamageNumber] No Label child found.")

func _process(delta: float) -> void:
	_elapsed += delta
	position.y -= rise_speed * delta
	var t: float = clamp(_elapsed / lifetime, 0.0, 1.0)
	modulate.a = 1.0 - t
	if t >= 1.0:
		queue_free()


#> SETUP
# Called right after instantiating and adding this scene to the tree.
# Displays the post-mitigation damage value.

func setup(damage: int) -> void:
	assert(_label != null, "[DamageNumber] setup() called before _ready().")
	_label.text = str(damage)
