extends Camera2D

const SPEED: float = 4000
const ZOOM_STEP: float = 0.1
const MIN_ZOOM: float = 0.03
const MAX_ZOOM: float = 4.0


func _process(delta: float) -> void:
	var input := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	
	if input != Vector2.ZERO:
		position += input * SPEED * delta * (1 / zoom.length())


func _input(event: InputEvent) -> void:

	if event.is_action_pressed("ui_accept"):
		position = Vector2.ZERO
	
	if event is InputEventMouseButton and event.pressed:
		
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var new_zoom := zoom - Vector2(ZOOM_STEP, ZOOM_STEP)
			new_zoom.x = clamp(new_zoom.x, MIN_ZOOM, MAX_ZOOM)
			new_zoom.y = clamp(new_zoom.y, MIN_ZOOM, MAX_ZOOM)
			zoom = new_zoom
		
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var new_zoom := zoom + Vector2(ZOOM_STEP, ZOOM_STEP)
			new_zoom.x = clamp(new_zoom.x, MIN_ZOOM, MAX_ZOOM)
			new_zoom.y = clamp(new_zoom.y, MIN_ZOOM, MAX_ZOOM)
			zoom = new_zoom
