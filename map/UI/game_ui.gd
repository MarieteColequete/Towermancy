extends CanvasLayer

# -------------------------
# References (assign in Inspector)
# -------------------------

@export var player: Player
@export var wave_director: WaveDirector

# Notification settings
@export var notification_duration: float = 3.0
@export var notification_bg_color: Color = Color(0.1, 0.1, 0.1, 0.85)
@export var notification_text_color: Color = Color(1.0, 1.0, 1.0, 1.0)

# -------------------------
# Internal nodes
# -------------------------

var _hp_label: Label
var _wave_label: Label
var _enemies_label: Label
var _gold_label: Label

# VBoxContainer that stacks notifications bottom-up
var _notif_container: VBoxContainer


# -------------------------
# Setup
# -------------------------

func _ready() -> void:
	_build_ui()
	_update_wave(0)


# Called by MapDirector after all nodes are initialized.
func initialize() -> void:
	_connect_signals()


func _build_ui() -> void:
	# --- Top-left stats panel ---
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(10, 10)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	_hp_label      = _make_label("HP: --/--")
	_wave_label    = _make_label("Wave: 0")
	_enemies_label = _make_label("Enemies: 0")
	_gold_label    = _make_label("Gold: 0")

	vbox.add_child(_hp_label)
	vbox.add_child(_wave_label)
	vbox.add_child(_enemies_label)
	vbox.add_child(_gold_label)

	# --- Bottom-right notification stack ---
	_notif_container = VBoxContainer.new()
	_notif_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_notif_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_notif_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_notif_container.add_theme_constant_override("separation", 4)
	_notif_container.position = Vector2(-10, -10)
	add_child(_notif_container)


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	return label


func _connect_signals() -> void:
	if player != null:
		player.hp_changed.connect(_update_hp)
		player.gold_changed.connect(_update_gold)
		player.player_died.connect(_on_player_died)
		_update_hp(player.current_hp, player.max_hp)
		_update_gold(player.gold)
	else:
		push_warning("[GameUI] player not assigned.")

	if wave_director != null:
		wave_director.enemies_remaining_changed.connect(_update_enemies)
		wave_director.wave_started.connect(_on_wave_started)
	else:
		push_warning("[GameUI] wave_director not assigned.")


# -------------------------
# Stat update handlers
# -------------------------

func _update_hp(current: int, maximum: int) -> void:
	_hp_label.text = "HP: %d / %d" % [current, maximum]

func _update_wave(wave_number: int) -> void:
	_wave_label.text = "Wave: %d" % wave_number

func _update_enemies(count: int) -> void:
	_enemies_label.text = "Enemies: %d" % count


func _on_wave_started(wave_number: int) -> void:
	set_wave(wave_number)
	notify("Wave %d started!" % wave_number)

func _update_gold(amount: int) -> void:
	_gold_label.text = "Gold: %d" % amount

func _on_player_died() -> void:
	_hp_label.text = "HP: 0 / %d  —  GAME OVER" % player.max_hp


# -------------------------
# Public
# -------------------------

func set_wave(wave_number: int) -> void:
	_update_wave(wave_number)


# Show a notification in the bottom-right corner.
# Notifications stack vertically and fade out after notification_duration seconds.
func notify(text: String) -> void:
	# Wrap label in a panel for background color
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = notification_bg_color
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.modulate.a = 0.0

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", notification_text_color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(label)

	_notif_container.add_child(panel)

	# Fade in, hold, fade out, then remove
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	tween.tween_interval(notification_duration)
	tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(panel.queue_free)
