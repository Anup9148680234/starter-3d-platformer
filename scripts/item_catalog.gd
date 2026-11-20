extends RefCounted
class_name ItemCatalog

const DEFINITIONS: Dictionary = {
	&"gold_coin": preload("res://items/gold_coin.tres"),
	&"combo_punch": preload("res://items/combo_punch.tres"),
	&"sword_regular_combo": preload("res://items/sword_regular_combo.tres"),
	&"sword_heavy_combo": preload("res://items/sword_heavy_combo.tres"),
	&"double_jump": preload("res://items/double_jump.tres"),
	&"sword": preload("res://items/sword.tres"),
	&"glider": preload("res://items/glider.tres"),
	&"jetpack": preload("res://items/jetpack.tres"),
	&"health_potion": preload("res://items/health_potion.tres"),
}


static func get_item_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for item_id in DEFINITIONS.keys():
		result.append(StringName(str(item_id)))
	result.sort()
	return result


static func get_definition(item_id: StringName) -> Resource:
	return DEFINITIONS.get(item_id) as Resource


static func has_item(item_id: StringName) -> bool:
	return DEFINITIONS.has(item_id)


static func display_name(item_id: StringName) -> String:
	var definition := get_definition(item_id)
	return str(definition.get("display_name")) if definition != null else str(item_id).replace("_", " ").capitalize()


static func icon_for(item_id: StringName) -> Texture2D:
	var definition := get_definition(item_id)
	return definition.get("icon") as Texture2D if definition != null else null


static func rarity_for(item_id: StringName) -> String:
	var definition := get_definition(item_id)
	return str(definition.get("rarity")) if definition != null else "common"


static func is_ability(item_id: StringName) -> bool:
	var definition := get_definition(item_id)
	return definition != null and str(definition.get("category")) == "ability"


static func ability_for(item_id: StringName) -> StringName:
	var definition := get_definition(item_id)
	if definition == null or not is_ability(item_id):
		return &""
	var ability_id := StringName(str(definition.get("ability_id")))
	return ability_id if ability_id != &"" else item_id
