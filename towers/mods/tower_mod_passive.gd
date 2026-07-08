class_name TowerModPassive
extends TowerMod

enum Operation {
	ADDITIVE,
	MULT_MORE,
	MULT_INCREASED,
	SET
}

@export_category("Info")
@export var tower_stats: TowerStats
