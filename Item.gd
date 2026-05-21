@icon("res://addons/InventoryGodot/icon_boots.png")
extends Resource
class_name Item

@export var category: ItemCategory ## Optional category for filtering/grouping (e.g. Weapon, Consumable)
@export var name: String ## Display name shown in UI
@export var description: String ## Flavour or tooltip text
@export var sprite: Texture2D ## Icon displayed in inventory slots
@export var stats: Stats ## Optional Stats resource (e.g. damage, defence) attached to this item
@export var value: float ## Monetary/trade value of the item
@export var max_stack: int = 999 ## Maximum quantity per slot (0 = unlimited)
@export var max_amount: int = 0 ## Maximum total quantity across all slots in an inventory (0 = unlimited)
@export var overflow_to_new_stack: bool = true ## When a stack is full, create a new slot instead of rejecting the item
@export var use_trigger_nodes: Array[PackedScene] = [] ## Scenes instantiated and attached to the user when item.use() is called

## Uses the item, instantiating all trigger nodes and attaching them to the user
## Returns an array of instantiated nodes for further management
func use(user_node: Node = null) -> Array[Node]:
	var nodes: Array[Node] = []
	
	for packed_scene in use_trigger_nodes:
		if not packed_scene:
			push_warning("Item '%s' has a null PackedScene in use_trigger_nodes" % name)
			continue
			
		var instance: Node = packed_scene.instantiate()
		
		if user_node:
			user_node.add_child(instance)
			# Position the instance if both nodes support global_position
			if user_node.has_method("get_global_position") and instance.has_method("set_global_position"):
				instance.global_position = user_node.global_position
		
		nodes.append(instance)
	
	return nodes

## Returns whether the item has any use triggers
func can_use() -> bool:
	return not use_trigger_nodes.is_empty()

## Returns a formatted string with item info (useful for UI)
func get_info_string() -> String:
	var info = "%s\n" % name
	if value > 0:
		info += "Value: $%.2f\n" % value
	if not description.is_empty():
		info += "\n%s" % description
	return info
