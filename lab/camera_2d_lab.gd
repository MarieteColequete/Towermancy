extends Camera2D

const SPEED: float = 1000

func _process(delta: float) -> void:
	var input: Vector2 = Vector2(Input.get_axis("ui_left","ui_right"), Input.get_axis("ui_up","ui_down"))
	
	if input:
		position += input * delta * SPEED

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		position = Vector2(0, 0)
