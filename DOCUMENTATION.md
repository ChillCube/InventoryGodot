# InventoryGodot API Reference
Generated: 2026-05-20

Provides an inventory and item resource used for inventory management

## Class: Inventory
**Inherits:** [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html)


### ⚙️ Inspector Variables (Exported)
| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| **items** | `Array[Item]` | `[]` | Array of items in the inventory |
| **max_size** | `int` | `-1` | Maximum inventory size (-1 = unlimited) |
| **inventory_name** | `String` | `"Default Inventory"` | Name of this inventory for identification |

### 💾 Class Variables (Standard)
| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| **item_counts** | `Dictionary` | `-` | Tracks item counts for stackable items |
| **is_initialized** | `bool` | `false` | Whether inventory has been initialized |

### 🔔 Signals
| Signal | Arguments | Description |
| :--- | :--- | :--- |
| **item_added** | `item: Item`<br>`new_count: int` |  Emitted when an item is added |
| **item_removed** | `item: Item`<br>`remaining_count: int` |  Emitted when an item is removed |
| **inventory_cleared** | `` |  Emitted when inventory is cleared |
| **inventory_resized** | `old_max: int`<br>`new_max: int` |  Emitted when max size changes |

### 🛠️ Methods
| Method | Arguments | Returns | Description |
| :--- | :--- | :--- | :--- |
| **get_item_on_grid()** | `grid_dimensions: Vector2`<br>`grid_position: Vector2`<br>`stacked: bool = true` | `Item` |  Get item at a grid position. Parameters: grid_dimensions: Vector2(x_cells, y_cells), grid_position: Vector2(x, y) position in grid (0-indexed), stacked: If true, shows unique items only (one per type). If false, shows every individual item in the inventory. Returns Item at position, or null if none exists |
| **get_grid_position()** | `item: Item`<br>`grid_dimensions: Vector2`<br>`stacked: bool = true` | `Vector2` |  Find the grid position of a specific item. Returns Vector2(-1, -1) if not found. |
| **add_item()** | `item: Item` | `bool` |  Add an item to the inventory. Returns true if successful. |
| **add_items()** | `items_to_add: Array[Item]` | `int` |  Add multiple items. Returns number of items successfully added. |
| **remove_item()** | `item: Item`<br>`quantity: int = 1` | `bool` |  Remove a specific quantity of an item. Returns true if successful (all requested items removed). |
| **delete_item()** | `item: Item` | `bool` |  Remove the first occurrence of an item. Returns true if found and removed. |
| **use_item()** | `user: Node`<br>`item: Item`<br>`consume: bool = true` | `void` |  Use an item, optionally consuming it. |
| **get_amount()** | `item: Item` | `int` |  Get the count of a specific item in the inventory. |
| **has_item()** | `item: Item` | `bool` |  Check if the inventory contains at least one of the item. |
| **has_items()** | `items_to_check: Array[Item]` | `bool` |  Check if the inventory contains all specified items. |
| **get_item_at()** | `index: int` | `Item` |  Get item at a specific index. |
| **remove_at()** | `index: int` | `bool` |  Remove item at a specific index. Returns true if successful. |
| **get_total_count()** | - | `int` |  Get total number of items (including duplicates). |
| **get_unique_items()** | - | `Array[Item]` |  Get array of unique items (no duplicates). |
| **get_items_of_type()** | `category: ItemCategory` | `Array[Item]` |  Get all items matching a specific category. |
| **get_items_by_name()** | `item_name: String` | `Array[Item]` |  Get all items with a specific name. |
| **is_empty()** | - | `bool` |  Check if inventory is empty. |
| **is_full()** | - | `bool` |  Check if inventory is at maximum capacity. |
| **can_add_item()** | `item: Item` | `bool` |  Check if another item can be added. |
| **get_free_space()** | - | `int` |  Get remaining free space (-1 means unlimited). |
| **clear()** | - | `void` |  Remove all items from inventory. |
| **sort_items()** | - | `void` |  Sort items alphabetically by name. |
| **sort_items_custom()** | `comparator: Callable` | `void` |  Sort items with a custom comparator function. |
| **shuffle_items()** | - | `void` |  Randomly shuffle items. |
| **transfer_item()** | `item: Item`<br>`target_inventory: Inventory`<br>`quantity: int = 1` | `bool` |  Transfer a specific quantity of an item to another inventory. Returns true if successful. |
| **merge_from()** | `other_inventory: Inventory` | `int` |  Merge all items from another inventory into this one. Returns number of items successfully merged. |
| **split_stack()** | `item: Item`<br>`quantity: int`<br>`target_inventory: Inventory` | `bool` |  Split a stack of items into another inventory. Returns true if successful. |
| **save_to_file()** | `file_path: String` | `bool` |  Save inventory to a file. Parameters: file_path: Path to save the inventory (e.g., "user://inventory.save"). Returns true if save successful, false otherwise |
| **load_from_file()** | `file_path: String` | `bool` |  Load inventory from a file. Parameters: file_path: Path to load the inventory from (e.g., "user://inventory.save"). Returns true if load successful, false otherwise |
| **get_save_data()** | - | `Dictionary` |  Get inventory data as a Dictionary for saving. Returns Dictionary containing all inventory data |
| **load_from_data()** | `save_data: Dictionary` | `bool` |  Load inventory data from a Dictionary. Parameters: save_data: Dictionary containing inventory data. Returns true if load successful, false otherwise |
| **export_to_json()** | - | `String` |  Export inventory to JSON string. Returns JSON string representation of the inventory |
| **import_from_json()** | `json_string: String` | `bool` |  Import inventory from JSON string. Parameters: json_string: JSON string containing inventory data. Returns true if import successful, false otherwise |
| **duplicate_inventory()** | - | `Inventory` |  Create a deep copy of the inventory. |
| **get_inventory_summary()** | - | `String` |  Get a string summary of the inventory contents. |
| **print_inventory()** | - | `void` |  Print inventory contents to console (debugging). |

---

## Class: ItemCategory
**Inherits:** [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html)


### ⚙️ Inspector Variables (Exported)
| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| **Name** | `String;` | `-` | Category display name (e.g. "Weapon", "Armour", "Consumable") |
| **Icon** | `Texture2D;` | `-` | Icon used to represent this category in UI |
| **Description** | `String;` | `-` | Tooltip or flavour text describing the category |

---

## Class: Item
**Inherits:** [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html)


### ⚙️ Inspector Variables (Exported)
| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| **category** | `ItemCategory` | `-` | Optional category for filtering/grouping (e.g. Weapon, Consumable) |
| **name** | `String` | `-` | Display name shown in UI |
| **description** | `String` | `-` | Flavour or tooltip text |
| **sprite** | `Texture2D` | `-` | Icon displayed in inventory slots |
| **stats** | `Stats` | `-` | Optional Stats resource (e.g. damage, defence) attached to this item |
| **value** | `float` | `-` | Monetary/trade value of the item |
| **use_trigger_nodes** | `Array[PackedScene]` | `[]` | Scenes instantiated and attached to the user when item.use() is called |

---

