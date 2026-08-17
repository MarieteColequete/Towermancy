# Tower shop UI. Lives as a CanvasLayer.
# Each slot is configured via TowerShopSlot resources assigned in the Inspector.
class_name TowerShop
extends CanvasLayer

# -------------------------
# Slot definition
# -------------------------

class TowerShopSlot:
	var tower_scene: PackedScene
	var base_price: int
	var price_increment: int
	var current_price: int
	var ghost: Tower  # Phantom instance used for stat queries

	func init(scene: PackedScene, price: int, increment: int, wave: int) -> void:
		tower_scene = scene
		base_price = price
		price_increment = increment
		current_price = price
		ghost = scene.instantiate()
		ghost.set_level(wave)

	func increment_price() -> void:
		current_price += price_increment

	func update_level(wave: int) -> void:
		ghost.set_level(wave)


# -------------------------
# Exports
# -------------------------

@export var slot_configs: Array[TowerShopSlotConfig] = []

@export var tower_placer: TowerPlacer
@export var player: Player
@export var game_ui: GameUI

# -------------------------
# Internal state
# -------------------------

var _slots: Array[TowerShopSlot] = []
var _current_wave: int = 0

# UI nodes
var _panel: PanelContainer
var _grid: GridContainer
var _tooltip: PanelContainer
var _tooltip_label: Label


# -------------------------
# Setup
# -------------------------

func _ready() -> void:
	_build_ui()


func initialize(wave: int) -> void:
	_current_wave = wave
	_build_slots()
	_populate_grid()
	assert(tower_placer != null, "[TowerShop] tower_placer not assigned!")
	tower_placer.tower_placed.connect(_on_tower_placed)


func refresh_wave(wave: int) -> void:
	_current_wave = wave
	for slot in _slots:
		slot.update_level(wave)
	_populate_grid()


# -------------------------
# Slot building
# -------------------------

func _build_slots() -> void:
	_slots.clear()
	for config in slot_configs:
		var slot := TowerShopSlot.new()
		slot.init(config.tower_scene, config.base_price, config.price_increment, _current_wave)
		_slots.append(slot)


# -------------------------
# UI construction
# -------------------------

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -160
	add_child(_panel)

	var vbox := VBoxContainer.new()
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Towers"
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(_grid)

	# Tooltip panel (hidden by default, shown on hover)
	_tooltip = PanelContainer.new()
	_tooltip.visible = false
	_tooltip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_tooltip.offset_left  = -360
	_tooltip.offset_top   = -200
	_tooltip.offset_right = -165
	_tooltip.offset_bottom = 0
	add_child(_tooltip)

	_tooltip_label = Label.new()
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip.add_child(_tooltip_label)


func _populate_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()

	for i in range(_slots.size()):
		var slot := _slots[i]
		var btn := _make_slot_button(slot, i)
		_grid.add_child(btn)


func _make_slot_button(slot: TowerShopSlot, idx: int) -> Control:
	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(64, 80)

	var btn := TextureButton.new()
	btn.custom_minimum_size = Vector2(64, 64)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	if slot.ghost.icon != null:
		btn.texture_normal = slot.ghost.icon
	container.add_child(btn)

	var price_label := Label.new()
	price_label.text = str(slot.current_price) + "g"
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 12)
	container.add_child(price_label)

	if player != null and player.gold < slot.current_price:
		container.modulate = Color(0.5, 0.5, 0.5, 1.0)

	btn.pressed.connect(_on_slot_pressed.bind(idx))
	btn.mouse_entered.connect(_on_slot_hover.bind(idx))
	btn.mouse_exited.connect(_on_tooltip_hide)

	return container


# -------------------------
# Slot interaction
# -------------------------

func _on_slot_pressed(idx: int) -> void:
	var slot := _slots[idx]

	if player != null and player.gold < slot.current_price:
		game_ui.notify("Not enough gold!")
		return

	tower_placer.begin_placement(slot.tower_scene, slot.current_price, idx, slot.ghost.icon, slot.ghost)


func _on_tower_placed(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < _slots.size():
		_slots[slot_index].increment_price()
	_populate_grid()


# -------------------------
# Tooltip
# -------------------------

func _on_slot_hover(idx: int) -> void:
	var slot := _slots[idx]
	var g := slot.ghost

	var text := "%s\n%s\n\nLevel: %d\nDamage: %.1f\nAtk Speed: %.2f\nOptics: %.1f\nSpread: %.1f\n\nPrice: %dg" % [
		g.get_title(),
		g.get_description(),
		g.get_level(),
		g.get_damage(),
		g.get_attack_speed(),
		g.get_optics(),
		g.get_spread(),
		slot.current_price
	]
	_tooltip_label.text = text
	_tooltip.visible = true


func _on_tooltip_hide() -> void:
	_tooltip.visible = false
