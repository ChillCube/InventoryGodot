@icon("res://addons/InventoryGodot/icon_boots.png")
extends Resource
class_name ItemCategory

## Used to define defaults for Items

@export var Name : String; ## Category display name (e.g. "Weapon", "Armour", "Consumable")
@export var Icon : Texture2D; ## Icon used to represent this category in UI
@export var Description : String; ## Tooltip or flavour text describing the category
