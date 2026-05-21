@icon("res://addons/InventoryGodot/icon_bag.png")
extends Resource
class_name Inventory

## Inventory system with save/load support
## Supports both flat inventory and grid-based organization

enum OverflowMode {
	ITEM_SETTING, ## Each item decides via its overflow_to_new_stack property (default)
	ALWAYS,       ## Always create a new stack when full, ignoring the item setting
	NEVER         ## Always reject when full, ignoring the item setting
}

@export var items: Array[Item] = [] ## Slots in the inventory; overflow stacks may produce multiple entries for the same item type
@export var counts: Array[int] = [] ## Parallel array tracking the quantity of each item in items[]
@export var max_size: int = -1 ## Maximum number of slots (-1 = unlimited)
@export var inventory_name: String = "Default Inventory" ## Name of this inventory for identification
@export var overflow_mode: OverflowMode = OverflowMode.ITEM_SETTING ## Overrides each item's overflow_to_new_stack when not set to ITEM_SETTING

var item_counts: Dictionary ## Tracks item counts keyed by item key (runtime cache)
var is_initialized: bool = false ## Whether inventory has been initialized

signal item_added(item: Item, new_count: int) ## Emitted when an item is added
signal item_removed(item: Item, remaining_count: int) ## Emitted when an item is removed
signal inventory_cleared() ## Emitted when inventory is cleared
signal inventory_resized(old_max: int, new_max: int) ## Emitted when max size changes


func _init() -> void:
	pass


func _ensure_sync() -> void:
	# _init() fires before Godot sets @export properties on .tres resources, so item_counts
	# may be empty and counts may be shorter than items. Rebuild whenever out of sync.
	if counts.size() != items.size() or (not items.is_empty() and item_counts.is_empty()):
		_update_item_counts()


func _update_item_counts() -> void: ## Rebuild the item_counts cache from items[] and counts[]
	# Pad counts[] if it's shorter (e.g. loaded from a pre-stacking .tres file)
	while counts.size() < items.size():
		counts.append(1)
	if counts.size() > items.size():
		counts.resize(items.size())

	item_counts.clear()
	for i in range(items.size()):
		if items[i] == null:
			continue
		# Sum across all slots — the same item type may have multiple overflow slots
		var key := _get_item_key(items[i])
		item_counts[key] = item_counts.get(key, 0) + counts[i]


func _get_item_key(item: Item) -> String: ## Generate a unique key for an item
	if item == null:
		return ""
	return item.resource_path if item.resource_path else item.name


func _find_item_index_by_key(key: String) -> int: ## Find the first slot index with matching key, or -1
	for i in range(items.size()):
		if items[i] != null and _get_item_key(items[i]) == key:
			return i
	return -1


func _find_available_slot(key: String, max_stack: int) -> int: ## Find the first slot with matching key that still has space, or -1
	if counts.size() != items.size():
		_update_item_counts()
	for i in range(items.size()):
		if items[i] != null and _get_item_key(items[i]) == key:
			if max_stack <= 0 or counts[i] < max_stack:
				return i
	return -1


func _should_overflow(item: Item) -> bool: ## Resolve the effective overflow behaviour for an item, applying the inventory override if set
	match overflow_mode:
		OverflowMode.ALWAYS: return true
		OverflowMode.NEVER:  return false
		_: return item.overflow_to_new_stack


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

func add_item(item: Item) -> bool: ## Add an item to the inventory. Stacks onto a non-full slot if available; overflows to a new slot or rejects based on the item's overflow_to_new_stack and this inventory's overflow_mode. Returns true if successful.
	_ensure_sync()
	var item_key := _get_item_key(item)

	# Hard cap: max_amount limits total quantity regardless of how many slots exist
	if item.max_amount > 0 and item_counts.get(item_key, 0) >= item.max_amount:
		return false

	var slot := _find_available_slot(item_key, item.max_stack)

	if slot != -1:
		# Found a slot with room — stack onto it
		counts[slot] += 1
		item_counts[item_key] = item_counts.get(item_key, 0) + 1
		item_added.emit(items[slot], item_counts[item_key])
		return true

	# All existing slots for this item are full (or none exist yet)
	if has_item(item) and not _should_overflow(item):
		return false  # Reject: overflow not allowed

	# Create a new slot (either first time, or overflow)
	if not _can_add_new_slot():
		return false

	items.append(item)
	counts.append(1)
	item_counts[item_key] = item_counts.get(item_key, 0) + 1
	item_added.emit(item, item_counts[item_key])
	return true


func add_items(items_to_add: Array[Item]) -> int: ## Add multiple items. Returns number of items successfully added.
	var added_count: int = 0
	for item in items_to_add:
		if add_item(item):
			added_count += 1
	return added_count


func remove_item(item: Item, quantity: int = 1) -> bool: ## Remove a specific quantity of an item, draining across overflow slots if needed. Returns true if the full quantity was removed.
	_ensure_sync()
	var item_key := _get_item_key(item)

	if item_counts.get(item_key, 0) < quantity:
		return false

	var left := quantity
	var i := items.size() - 1
	while i >= 0 and left > 0:
		if items[i] != null and _get_item_key(items[i]) == item_key:
			var take := mini(counts[i], left)
			counts[i] -= take
			left -= take
			if counts[i] <= 0:
				items.remove_at(i)
				counts.remove_at(i)
		i -= 1

	var total_remaining: int = item_counts.get(item_key, 0) - quantity
	if total_remaining <= 0:
		item_counts.erase(item_key)
	else:
		item_counts[item_key] = total_remaining

	item_removed.emit(item, maxi(total_remaining, 0))
	return true


func delete_item(item: Item) -> bool: ## Remove one of the item from the inventory. Returns true if found and removed.
	return remove_item(item, 1)


func use_item(user: Node, item: Item, consume: bool = true) -> void: ## Use an item, optionally consuming it.
	item.use(user)
	if consume:
		delete_item(item)


func get_amount(item: Item) -> int: ## Get the count of a specific item in the inventory.
	_ensure_sync()
	return item_counts.get(_get_item_key(item), 0)


func has_item(item: Item) -> bool: ## Check if the inventory contains at least one of the item.
	_ensure_sync()
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


func get_count_at(index: int) -> int: ## Get the stack count at a specific index.
	_ensure_sync()
	if index >= 0 and index < counts.size():
		return counts[index]
	return 0


func remove_at(index: int) -> bool: ## Remove one item from the stack at a specific index. Returns true if successful.
	_ensure_sync()
	if index >= 0 and index < items.size():
		var item := items[index]
		var item_key := _get_item_key(item)
		counts[index] -= 1

		if counts[index] <= 0:
			items.remove_at(index)
			counts.remove_at(index)

		var total_remaining: int = item_counts.get(item_key, 0) - 1
		if total_remaining <= 0:
			item_counts.erase(item_key)
		else:
			item_counts[item_key] = total_remaining

		item_removed.emit(item, maxi(total_remaining, 0))
		return true
	return false


# ============ INVENTORY QUERIES ============

func get_total_count() -> int: ## Get the number of unique item slots (each stack counts as one).
	return items.size()


func get_all_items_count() -> int: ## Get the total number of items across all stacks.
	_ensure_sync()
	var total := 0
	for c in counts:
		total += c
	return total


func get_unique_items() -> Array[Item]: ## Get one Item entry per unique item type (first slot of each type), no nulls.
	var seen: Dictionary = {}
	var unique: Array[Item] = []
	for item in items:
		if item == null:
			continue
		var key := _get_item_key(item)
		if not seen.has(key):
			seen[key] = true
			unique.append(item)
	return unique


func get_items_of_type(category: ItemCategory) -> Array[Item]: ## Get all items matching a specific category.
	var result: Array[Item] = []
	for item in items:
		if item == null:
			continue
		if item.category == category:
			result.append(item)
	return result


func get_items_by_name(item_name: String) -> Array[Item]: ## Get all items with a specific name.
	var result: Array[Item] = []
	for item in items:
		if item == null:
			continue
		if item.name == item_name:
			result.append(item)
	return result


func is_empty() -> bool: ## Check if inventory is empty.
	return items.is_empty()


func is_full() -> bool: ## Check if inventory is at maximum unique-slot capacity.
	return max_size != -1 and items.size() >= max_size


func can_add_item(item: Item) -> bool: ## Check if an item can be added, respecting max_amount, max_stack, overflow_to_new_stack, and overflow_mode.
	_ensure_sync()
	if item.max_amount > 0 and get_amount(item) >= item.max_amount:
		return false
	var item_key := _get_item_key(item)
	if _find_available_slot(item_key, item.max_stack) != -1:
		return true
	if has_item(item) and not _should_overflow(item):
		return false
	return _can_add_new_slot()


func get_free_space() -> int: ## Get remaining free unique-item slots (-1 means unlimited).
	if max_size == -1:
		return -1
	return max_size - items.size()


func _can_add_new_slot() -> bool:
	return max_size == -1 or items.size() < max_size


# ============ INVENTORY OPERATIONS ============

func clear() -> void: ## Remove all items from inventory.
	items.clear()
	counts.clear()
	item_counts.clear()
	inventory_cleared.emit()


func sort_items() -> void: ## Sort items alphabetically by name.
	_ensure_sync()
	_sort_with_counts(func(a, b):
		if a.item == null: return false
		if b.item == null: return true
		return a.item._name < b.item._name
	)
	_update_item_counts()


func sort_items_custom(comparator: Callable) -> void: ## Sort items with a custom comparator function. The comparator receives Item values.
	_ensure_sync()
	_sort_with_counts(func(a, b): return comparator.call(a.item, b.item))
	_update_item_counts()


func shuffle_items() -> void: ## Randomly shuffle items.
	_ensure_sync()
	var combined := _zip_items_counts()
	combined.shuffle()
	_unzip_items_counts(combined)
	_update_item_counts()


func _sort_with_counts(comparator: Callable) -> void:
	var combined := _zip_items_counts()
	combined.sort_custom(comparator)
	_unzip_items_counts(combined)


func _zip_items_counts() -> Array:
	var result := []
	for i in range(items.size()):
		result.append({"item": items[i], "count": counts[i]})
	return result


func _unzip_items_counts(combined: Array) -> void:
	items.clear()
	counts.clear()
	for entry in combined:
		items.append(entry.item)
		counts.append(entry.count)


func transfer_item(item: Item, target_inventory: Inventory, quantity: int = 1) -> bool: ## Transfer a specific quantity of an item to another inventory. Returns true if successful.
	if get_amount(item) >= quantity and target_inventory.can_add_item(item):
		if remove_item(item, quantity):
			for i in range(quantity):
				target_inventory.add_item(item)
			return true
	return false


func move_to_slot(from_index: int, to_index: int) -> bool: ## Swap the items at from_index and to_index. Returns true if both indices are valid.
	_ensure_sync()
	if from_index < 0 or from_index >= items.size(): return false
	if to_index < 0 or to_index >= items.size(): return false
	if from_index == to_index: return true
	var tmp_item := items[from_index]
	var tmp_count := counts[from_index]
	items[from_index] = items[to_index]
	counts[from_index] = counts[to_index]
	items[to_index] = tmp_item
	counts[to_index] = tmp_count
	return true


func insert_after_slot(from_index: int, to_index: int) -> bool: ## Removes the item at from_index and inserts it after to_index. Returns true if both indices are valid.
	_ensure_sync()
	if from_index < 0 or from_index >= items.size(): return false
	if to_index < 0 or to_index >= items.size(): return false
	if from_index == to_index: return true
	var item := items[from_index]
	var count := counts[from_index]
	items.remove_at(from_index)
	counts.remove_at(from_index)
	var insert_at := to_index if from_index < to_index else to_index + 1
	items.insert(insert_at, item)
	counts.insert(insert_at, count)
	return true


func move_item(item: Item, slot: int, before: bool = true) -> bool: ## Move an item to before or after a given slot index. Returns true if successful.
	_ensure_sync()
	var from_index := items.find(item)
	if from_index == -1:
		return false
	var item_count := counts[from_index]
	var insert_at := clamp(slot if before else slot + 1, 0, items.size())
	items.remove_at(from_index)
	counts.remove_at(from_index)
	if from_index < insert_at:
		insert_at -= 1
	var clamped := clamp(insert_at, 0, items.size())
	items.insert(clamped, item)
	counts.insert(clamped, item_count)
	return true


func set_slot(index: int, new_item: Item, slot_count: int = 1) -> void: ## Place an item (or null for empty) directly into a slot. slot_count sets the exact quantity for that slot.
	_ensure_sync()
	if index < 0 or index >= items.size():
		return
	var old_item := items[index]
	var old_count := counts[index]

	if old_item != null:
		var old_key := _get_item_key(old_item)
		item_counts[old_key] = item_counts.get(old_key, 0) - old_count
		if item_counts.get(old_key, 0) <= 0:
			item_counts.erase(old_key)
		item_removed.emit(old_item, item_counts.get(old_key, 0))

	var clamped_count := maxi(slot_count, 0)
	items[index] = new_item
	counts[index] = clamped_count if new_item != null else 0

	if new_item != null:
		var new_key := _get_item_key(new_item)
		item_counts[new_key] = item_counts.get(new_key, 0) + clamped_count
		item_added.emit(new_item, item_counts[new_key])


func merge_from(other_inventory: Inventory) -> int: ## Merge all items from another inventory into this one. Returns number of items successfully merged.
	var merged_count: int = 0
	for i in range(other_inventory.items.size()):
		var item := other_inventory.items[i]
		var amount := other_inventory.counts[i] if i < other_inventory.counts.size() else 1
		for _j in range(amount):
			if add_item(item):
				merged_count += 1
	other_inventory.clear()
	return merged_count


func split_stack(item: Item, quantity: int, target_inventory: Inventory) -> bool: ## Split a stack of items into another inventory. Returns true if successful.
	if get_amount(item) >= quantity and target_inventory.can_add_item(item):
		remove_item(item, quantity)
		for i in range(quantity):
			target_inventory.add_item(item)
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
	_ensure_sync()
	var save_data = {
		"version": 2,
		"inventory_name": inventory_name,
		"max_size": max_size,
		"items": []
	}

	for i in range(items.size()):
		var item := items[i]
		if item == null:
			continue
		var item_data = {
			"resource_path": item.resource_path if item.resource_path else "",
			"item_name": item.name,
			"value": item.value,
			"count": counts[i] if i < counts.size() else 1
		}

		if item.category:
			item_data["category_path"] = item.category.resource_path if item.category.resource_path else ""

		save_data["items"].append(item_data)

	return save_data


func load_from_data(save_data: Dictionary) -> bool: ## Load inventory data from a Dictionary. Parameters: save_data: Dictionary containing inventory data. Returns true if load successful, false otherwise
	if not save_data.has("version") or not save_data.has("items"):
		push_error("Invalid save data format")
		return false

	clear()

	if save_data.has("inventory_name"):
		inventory_name = save_data["inventory_name"]
	if save_data.has("max_size"):
		max_size = save_data["max_size"]

	for item_data in save_data["items"]:
		if item_data.get("empty", false):
			continue

		var item: Item = null

		if item_data.has("resource_path") and item_data["resource_path"] != "":
			item = load(item_data["resource_path"])

		if item == null:
			item = Item.new()
			item.name = item_data.get("item_name", "Unknown Item")
			item.value = item_data.get("value", 0.0)

			if item_data.has("category_path") and item_data["category_path"] != "":
				var category = load(item_data["category_path"])
				if category is ItemCategory:
					item.category = category

		var count: int = item_data.get("count", 1)
		items.append(item)
		counts.append(count)

	_update_item_counts()
	is_initialized = true

	print("Inventory loaded: ", inventory_name, " (", items.size(), " unique items)")
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
	_ensure_sync()
	var new_inventory = Inventory.new()
	new_inventory.inventory_name = inventory_name + " (Copy)"
	new_inventory.max_size = max_size

	for i in range(items.size()):
		if items[i] != null:
			new_inventory.items.append(items[i].duplicate())
			new_inventory.counts.append(counts[i])

	new_inventory._update_item_counts()
	return new_inventory


func get_inventory_summary() -> String: ## Get a string summary of the inventory contents.
	_ensure_sync()
	var summary = "%s: %d unique types (%d total), max_slots=%s\n" % [
		inventory_name,
		items.size(),
		get_all_items_count(),
		str(max_size) if max_size != -1 else "unlimited"
	]

	for i in range(items.size()):
		if items[i] != null:
			summary += "- %s x%d\n" % [items[i].name, counts[i]]

	return summary


func print_inventory() -> void: ## Print inventory contents to console (debugging).
	print(get_inventory_summary())


# ============ RESOURCE MANAGEMENT ============

func _notification(what: int) -> void: ## Handle resource notifications.
	if what == NOTIFICATION_PREDELETE:
		items = []
		counts = []
		item_counts = {}
