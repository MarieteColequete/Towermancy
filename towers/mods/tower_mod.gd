@abstract class_name TowerMod
extends Resource

@export_category("Info")
@export var _title: String = "Title?"
@export var _description: String = "Description?"

func get_title() -> String:
	return _title

func get_description() -> String:
	return _description
