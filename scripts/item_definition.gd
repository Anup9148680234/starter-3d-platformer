extends Resource
class_name ItemDefinition

@export var item_id: StringName = &""
@export var display_name := "Item"
@export_multiline var description := ""
@export var icon: Texture2D
@export_enum("common", "uncommon", "rare", "legendary") var rarity := "common"
@export_enum("resource", "ability", "consumable", "skill") var category := "resource"
@export var ability_id: StringName = &""
@export var stackable := true
