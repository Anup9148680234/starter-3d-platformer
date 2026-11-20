extends RefCounted
class_name ItemRarity

const ITEM_CATALOG = preload("res://scripts/item_catalog.gd")

const COMMON := Color(0.36, 0.82, 0.48, 1.0)
const UNCOMMON := Color(0.35, 0.68, 1.0, 1.0)
const RARE := Color(0.72, 0.43, 1.0, 1.0)
const LEGENDARY := Color(1.0, 0.76, 0.24, 1.0)


static func color_for(item_id: StringName) -> Color:
	match ITEM_CATALOG.rarity_for(item_id):
		"uncommon":
			return UNCOMMON
		"rare":
			return RARE
		"legendary":
			return LEGENDARY
		_:
			return COMMON


static func display_name(item_id: StringName) -> String:
	return ITEM_CATALOG.display_name(item_id)
