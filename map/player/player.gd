class_name Player
extends Node

# -------------------------
# Stats
# -------------------------

@export var max_hp: int = Constants.STARTING_HP
var current_hp: int
var gold: int = 1000

# -------------------------
# Signals
# -------------------------

signal hp_changed(current: int, maximum: int)
signal gold_changed(amount: int)
signal player_died

# -------------------------
# Setup
# -------------------------

func _ready() -> void:
	current_hp = max_hp


# -------------------------
# Damage
# -------------------------

func take_damage(amount: int) -> void:
	current_hp = maxi(0, current_hp - amount)
	hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		player_died.emit()


# -------------------------
# Gold
# -------------------------

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true
