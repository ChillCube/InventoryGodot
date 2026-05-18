@icon("res://addons/InventoryGodot/icon_bag.png")
extends Resource
class_name Inventory

## Inventory system with save/load support
## Supports both flat inventory and grid-based organization

@export var items: Array[Item] = [] ## Array of items in the inventory
@export var max_size: int = -1 ## Maximum inventory size (-1 = unlimited)
@export var inventory_name: String = "Default Inventory" ## Name of this inventory for identification

var item_counts: Dictionary ## Tracks item counts for stackable items
var is_initialized: bool = false ## Whether inventory has been initialized

signal item_added(item: Item, new_count: int) ## Emitted when an item is added
signal item_removed(item: Item, remaining_count: int) ## Emitted when an item is removed
signal inventory_cleared() ## Emitted when inventory is cleared
signal inventory_resized(old_max: int, new_max: int) ## Emitted when max size changes


func _init() -> void: ## Initialize inventory and update item counts
	_update_item_counts()


func _update_item_counts() -> void: ## Rebuild the item count dictionary from the items array
	item_counts.clear()
	for item in items:
		var item_key = _get_item_key(item)
		item_counts[item_key] = item_counts.get(item_key, 0) + 1


func _get_item_key(item: Item) -> String: ## Generate a unique key for an item (can be overridden for more complex identification)
	return item.resource_path if item.resource_path else item._name


# ============ GRID SYSTEM ============

func get_item_on_grid(grid_dimensions: Vector2, grid_position: Vector2, stacked: bool = true) -> Item: ## Get item at a grid position. Parameters: grid_dimensions: Vector2(x_cells, y_cells), grid_position: Vector2(x, y) position in grid (0-indexed), stacked: If true, shows unique items only (one per type). If false, shows every individual item in the inventory. Returns Item at position, or null if none exists
	if grid_position.x >= grid_dimensions.x or grid_position.x < 0:
		return null
	if grid_position.y >= grid_dimensions.y or grid_position.y < 0:
		return null
	
	var flat_index: int = int(grid_position.y * grid_dimensions.x + grid_position.x)
	
	if stacked:
		var unique_items: Array[Item] = get_unique_items()
		if flat_index < unique_items.size():
			return unique_items[flat_index]
	else:
		if flat_index < items.size():
			return items[flat_index]
	
	return null


func get_grid_position(item: Item, grid_dimensions: Vector2, stacked: bool = true) -> Vector2: ## Find the grid position of a specific item. Returns Vector2(-1, -1) if not found.
	if stacked:
		var unique_items = get_unique_items()
		var index = unique_items.find(item)
		if index != -1:
			return Vector2(index % int(grid_dimensions.x), floor(index / grid_dimensions.x))
	else:
		var index = items.find(item)
		if index != -1:
			return Vector2(index % int(grid_dimensions.x), floor(index / grid_dimensions.x))
	
	return Vector2(-1, -1)


# ============ ITEM MANAGEMENT ============

func add_item(item: Item) -> bool: ## Add an item to the inventory. Returns true if successful.
	if not can_add_item(item):
		return false
	
	items.append(item)
	var item_key = _get_item_key(item)
	var new_count = item_counts.get(item_key, 0) + 1
	item_counts[item_key] = new_count
	
	item_added.emit(item, new_count)
	return true


func add_items(items_to_add: Array[Item]) -> int: ## Add multiple items. Returns number of items successfully added.
	var added_count: int = 0
	for item in items_to_add:
		if add_item(item):
			added_count += 1
	return added_count


func remove_item(item: Item, quantity: int = 1) -> bool: ## Remove a specific quantity of an item. Returns true if successful (all requested items removed).
	var removed_count: int = 0
	var indices_to_remove: Array[int] = []
	
	for i in range(items.size() - 1, -1, -1):
		if items[i] == item and removed_count < quantity:
			indices_to_remove.append(i)
			removed_count += 1
	
	if removed_count == quantity:
		for index in indices_to_remove:
			items.remove_at(index)
		
		var item_key = _get_item_key(item)
		var remaining = item_counts.get(item_key, 0) - quantity
		if remaining <= 0:
			item_counts.erase(item_key)
		else:
			item_counts[item_key] = remaining
		
		item_removed.emit(item, remaining)
		return true
	
	return false


func delete_item(item: Item) -> bool: ## Remove the first occurrence of an item. Returns true if found and removed.
	var index = items.find(item)
	if index != -1:
		items.remove_at(index)
		var item_key = _get_item_key(item)
		var remaining = item_counts.get(item_key, 0) - 1
		if remaining <= 0:
			item_counts.erase(item_key)
		else:
			item_counts[item_key] = remaining
		
		item_removed.emit(item, remaining)
		return true
	return false


func use_item(user: Node, item: Item, consume: bool = true) -> void: ## Use an item, optionally consuming it.
	item.use(user)
	if consume:
		delete_item(item)


func get_amount(item: Item) -> int: ## Get the count of a specific item in the inventory.
	return item_counts.get(_get_item_key(item), 0)


func has_item(item: Item) -> bool: ## Check if the inventory contains at least one of the item.
	return _get_item_key(item) in item_counts


func has_items(items_to_check: Array[Item]) -> bool: ## Check if the inventory contains all specified items.
	for item in items_to_check:
		if not has_item(item):
			return false
	return true


func get_item_at(index: int) -> Item: ## Get item at a specific index.
	if index >= 0 and index < items.size():
		return items[index]
	return null


func remove_at(index: int) -> bool: ## Remove item at a specific index. Returns true if successful.
	if index >= 0 and index < items.size():
		var item = items[index]
		items.remove_at(index)
		var item_key = _get_item_key(item)
		var remaining = item_counts.get(item_key, 0) - 1
		if remaining <= 0:
			item_counts.erase(item_key)
		else:
			item_counts[item_key] = remaining
		
		item_removed.emit(item, remaining)
		return true
	return false


# ============ INVENTORY QUERIES ============

func get_total_count() -> int: ## Get total number of items (including duplicates).
	return items.size()


func get_unique_items() -> Array[Item]: ## Get array of unique items (no duplicates).
	var unique: Array[Item] = []
	for item in items:
		if not unique.has(item):
			unique.append(item)
	return unique


func get_items_of_type(category: ItemCategory) -> Array[Item]: ## Get all items matching a specific category.
	var result: Array[Item] = []
	for item in items:
		if item.category == category:
			result.append(item)
	return result


func get_items_by_name(item_name: String) -> Array[Item]: ## Get all items with a specific name.
	var result: Array[Item] = []
	for item in items:
		if item._name == item_name:
			result.append(item)
	return result


func is_empty() -> bool: ## Check if inventory is empty.
	return items.is_empty()


func is_full() -> bool: ## Check if inventory is at maximum capacity.
	return max_size != -1 and items.size() >= max_size


func can_add_item(item: Item) -> bool: ## Check if another item can be added.
	return max_size == -1 or items.size() < max_size


func get_free_space() -> int: ## Get remaining free space (-1 means unlimited).
	if max_size == -1:
		return -1
	return max_size - items.size()


# ============ INVENTORY OPERATIONS ============

func clear() -> void: ## Remove all items from inventory.
	items.clear()
	item_counts.clear()
	inventory_cleared.emit()


func sort_items() -> void: ## Sort items alphabetically by name.
	items.sort_custom(func(a, b): return a._name < b._name)
	_update_item_counts()


func sort_items_custom(comparator: Callable) -> void: ## Sort items with a custom comparator function.
	items.sort_custom(comparator)
	_update_item_counts()


func shuffle_items() -> void: ## Randomly shuffle items.
	items.shuffle()
	_update_item_counts()


func transfer_item(item: Item, target_inventory: Inventory, quantity: int = 1) -> bool: ## Transfer a specific quantity of an item to another inventory. Returns true if successful.
	if has_item(item) and target_inventory.can_add_item(item):
		if remove_item(item, quantity):
			for i in range(quantity):
				target_inventory.add_item(item.duplicate())
			return true
	return false


func merge_from(other_inventory: Inventory) -> int: ## Merge all items from another inventory into this one. Returns number of items successfully merged.
	var merged_count: int = 0
	for item in other_inventory.items.duplicate():
		if add_item(item):
			merged_count += 1
			other_inventory.delete_item(item)
	return merged_count


func split_stack(item: Item, quantity: int, target_inventory: Inventory) -> bool: ## Split a stack of items into another inventory. Returns true if successful.
	if get_amount(item) >= quantity and target_inventory.can_add_item(item):
		remove_item(item, quantity)
		for i in range(quantity):
			target_inventory.add_item(item.duplicate())
		return true
	return false


# ============ SAVE / LOAD SYSTEM ============

func save_to_file(file_path: String) -> bool: ## Save inventory to a file. Parameters: file_path: Path to save the inventory (e.g., "user://inventory.save"). Returns true if save successful, false otherwise
	var save_data = get_save_data()
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open file for saving: ", file_path)
		return false
	
	var json_string = JSON.stringify(save_data)
	file.store_string(json_string)
	file.close()
	
	print("Inventory saved to: ", file_path)
	return true


func load_from_file(file_path: String) -> bool: ## Load inventory from a file. Parameters: file_path: Path to load the inventory from (e.g., "user://inventory.save"). Returns true if load successful, false otherwise
	if not FileAccess.file_exists(file_path):
		push_error("Save file does not exist: ", file_path)
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open file for loading: ", file_path)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse JSON: ", json.get_error_message())
		return false
	
	var save_data = json.data
	return load_from_data(save_data)


func get_save_data() -> Dictionary: ## Get inventory data as a Dictionary for saving. Returns Dictionary containing all inventory data
	var save_data = {
		"version": 1,
		"inventory_name": inventory_name,
		"max_size": max_size,
		"items": []
	}
	
	# Save each item's resource path and any custom data
	for item in items:
		var item_data = {
			"resource_path": item.resource_path if item.resource_path else "",
			"item_name": item._name,
			"value": item.value
		}
		
		# Save category if it exists
		if item.category:
			item_data["category_path"] = item.category.resource_path if item.category.resource_path else ""
		
		save_data["items"].append(item_data)
	
	return save_data


func load_from_data(save_data: Dictionary) -> bool: ## Load inventory data from a Dictionary. Parameters: save_data: Dictionary containing inventory data. Returns true if load successful, false otherwise
	# Validate save data
	if not save_data.has("version") or not save_data.has("items"):
		push_error("Invalid save data format")
		return false
	
	# Clear current inventory
	clear()
	
	# Load basic properties
	if save_data.has("inventory_name"):
		inventory_name = save_data["inventory_name"]
	if save_data.has("max_size"):
		max_size = save_data["max_size"]
	
	# Load items
	for item_data in save_data["items"]:
		var item: Item = null
		
		# Try to load from resource path first
		if item_data.has("resource_path") and item_data["resource_path"] != "":
			item = load(item_data["resource_path"])
		
		# If that fails, create a new item from saved data
		if item == null:
			item = Item.new()
			item._name = item_data.get("item_name", "Unknown Item")
			item.value = item_data.get("value", 0.0)
			
			# Load category if available
			if item_data.has("category_path") and item_data["category_path"] != "":
				var category = load(item_data["category_path"])
				if category is ItemCategory:
					item.category = category
		
		if item:
			items.append(item)
	
	_update_item_counts()
	is_initialized = true
	
	print("Inventory loaded: ", inventory_name, " (", items.size(), " items)")
	return true


func export_to_json() -> String: ## Export inventory to JSON string. Returns JSON string representation of the inventory
	return JSON.stringify(get_save_data())


func import_from_json(json_string: String) -> bool: ## Import inventory from JSON string. Parameters: json_string: JSON string containing inventory data. Returns true if import successful, false otherwise
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse JSON: ", json.get_error_message())
		return false
	
	return load_from_data(json.data)


# ============ UTILITY ============

func duplicate_inventory() -> Inventory: ## Create a deep copy of the inventory.
	var new_inventory = Inventory.new()
	new_inventory.inventory_name = inventory_name + " (Copy)"
	new_inventory.max_size = max_size
	
	for item in items:
		new_inventory.add_item(item.duplicate())
	
	return new_inventory


func get_inventory_summary() -> String: ## Get a string summary of the inventory contents.
	var summary = "%s: %d/%d items, %d unique types\n" % [
		inventory_name,
		items.size(),
		max_size if max_size != -1 else items.size(),
		get_unique_items().size()
	]
	
	for item in get_unique_items():
		summary += "- %s x%d\n" % [item._name, get_amount(item)]
	
	return summary


func print_inventory() -> void: ## Print inventory contents to console (debugging).
	print(get_inventory_summary())


# ============ RESOURCE MANAGEMENT ============

func _notification(what: int) -> void: ## Handle resource notifications.
	if what == NOTIFICATION_PREDELETE:
		# Cleanup before deletion
		clear()
