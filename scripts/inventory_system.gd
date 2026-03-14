class_name InventorySystem
extends RefCounted

## Item catalog + inventory bag model.
## Items have id, name, description, category, stackable, max_stack, usable, icon_color.

enum ItemCategory {
	CONSUMABLE,   # 消耗品（药水、食物）
	KEY_ITEM,     # 关键道具（钥匙、信件）
	EQUIPMENT,    # 装备（武器、护甲）
	MATERIAL,     # 素材（矿石、木材）
	QUEST,        # 任务物品
	MISC,         # 杂项
}

static var ITEM_CATALOG: Array[Dictionary] = [
	{
		"id": "health_potion",
		"name": "生命药水",
		"description": "恢复 50 点生命值",
		"category": ItemCategory.CONSUMABLE,
		"stackable": true,
		"max_stack": 99,
		"usable": true,
		"icon_color": Color(0.98, 0.30, 0.30),
		"effects": {"heal": 50},
	},
	{
		"id": "mana_potion",
		"name": "魔法药水",
		"description": "恢复 30 点魔法值",
		"category": ItemCategory.CONSUMABLE,
		"stackable": true,
		"max_stack": 99,
		"usable": true,
		"icon_color": Color(0.30, 0.50, 0.98),
		"effects": {"heal_mp": 30},
	},
	{
		"id": "iron_key",
		"name": "铁钥匙",
		"description": "打开铁门的钥匙",
		"category": ItemCategory.KEY_ITEM,
		"stackable": false,
		"max_stack": 1,
		"usable": false,
		"icon_color": Color(0.70, 0.70, 0.75),
		"effects": {},
	},
	{
		"id": "gold_key",
		"name": "金钥匙",
		"description": "打开宝藏室的钥匙",
		"category": ItemCategory.KEY_ITEM,
		"stackable": false,
		"max_stack": 1,
		"usable": false,
		"icon_color": Color(0.95, 0.80, 0.20),
		"effects": {},
	},
	{
		"id": "wooden_sword",
		"name": "木剑",
		"description": "简陋的木制短剑",
		"category": ItemCategory.EQUIPMENT,
		"stackable": false,
		"max_stack": 1,
		"usable": true,
		"icon_color": Color(0.72, 0.53, 0.30),
		"effects": {"atk": 5},
	},
	{
		"id": "iron_ore",
		"name": "铁矿石",
		"description": "可用于锻造的矿石",
		"category": ItemCategory.MATERIAL,
		"stackable": true,
		"max_stack": 99,
		"usable": false,
		"icon_color": Color(0.55, 0.55, 0.60),
		"effects": {},
	},
	{
		"id": "letter",
		"name": "神秘信件",
		"description": "一封密封的信件，交给村长",
		"category": ItemCategory.QUEST,
		"stackable": false,
		"max_stack": 1,
		"usable": false,
		"icon_color": Color(0.90, 0.85, 0.70),
		"effects": {},
	},
	{
		"id": "coin",
		"name": "金币",
		"description": "通用货币",
		"category": ItemCategory.MISC,
		"stackable": true,
		"max_stack": 9999,
		"usable": false,
		"icon_color": Color(0.95, 0.85, 0.10),
		"effects": {},
	},
]

static func get_catalog() -> Array[Dictionary]:
	return ITEM_CATALOG

static func get_item_def(item_id: String) -> Dictionary:
	for entry in ITEM_CATALOG:
		if String(entry.get("id", "")) == item_id:
			return entry
	return {}

static func register_item(def: Dictionary) -> void:
	for i in ITEM_CATALOG.size():
		if String(ITEM_CATALOG[i].get("id", "")) == String(def.get("id", "")):
			ITEM_CATALOG[i] = def
			return
	ITEM_CATALOG.append(def)

static func category_label(cat: int) -> String:
	match cat:
		ItemCategory.CONSUMABLE: return "消耗品"
		ItemCategory.KEY_ITEM: return "关键道具"
		ItemCategory.EQUIPMENT: return "装备"
		ItemCategory.MATERIAL: return "素材"
		ItemCategory.QUEST: return "任务物品"
		ItemCategory.MISC: return "杂项"
		_: return "未知"

# --- Inventory bag operations ---

static func create_inventory(capacity: int = 40) -> Dictionary:
	return {
		"slots": [],
		"capacity": capacity,
	}

static func add_item(inventory: Dictionary, item_id: String, amount: int = 1) -> Dictionary:
	var def := get_item_def(item_id)
	if def.is_empty():
		return {"success": false, "reason": "unknown_item", "remainder": amount}

	var slots: Array = inventory.get("slots", [])
	var remaining := amount
	var stackable: bool = def.get("stackable", false)
	var max_stack: int = int(def.get("max_stack", 1))

	if stackable:
		for slot in slots:
			if String(slot.get("item_id", "")) == item_id:
				var current: int = int(slot.get("amount", 0))
				var can_add := mini(remaining, max_stack - current)
				if can_add > 0:
					slot["amount"] = current + can_add
					remaining -= can_add
				if remaining <= 0:
					break

	while remaining > 0:
		var capacity: int = int(inventory.get("capacity", 40))
		if slots.size() >= capacity:
			break
		var stack_amount := mini(remaining, max_stack) if stackable else 1
		slots.append({"item_id": item_id, "amount": stack_amount})
		remaining -= stack_amount

	inventory["slots"] = slots
	return {"success": remaining < amount, "reason": "" if remaining == 0 else "inventory_full", "remainder": remaining}

static func remove_item(inventory: Dictionary, item_id: String, amount: int = 1) -> Dictionary:
	var slots: Array = inventory.get("slots", [])
	var remaining := amount

	var i := slots.size() - 1
	while i >= 0 and remaining > 0:
		if String(slots[i].get("item_id", "")) == item_id:
			var current: int = int(slots[i].get("amount", 0))
			var to_remove := mini(remaining, current)
			slots[i]["amount"] = current - to_remove
			remaining -= to_remove
			if int(slots[i]["amount"]) <= 0:
				slots.remove_at(i)
		i -= 1

	inventory["slots"] = slots
	return {"success": remaining < amount, "removed": amount - remaining}

static func has_item(inventory: Dictionary, item_id: String, amount: int = 1) -> bool:
	var total := 0
	for slot in inventory.get("slots", []):
		if String(slot.get("item_id", "")) == item_id:
			total += int(slot.get("amount", 0))
	return total >= amount

static func count_item(inventory: Dictionary, item_id: String) -> int:
	var total := 0
	for slot in inventory.get("slots", []):
		if String(slot.get("item_id", "")) == item_id:
			total += int(slot.get("amount", 0))
	return total

static func get_all_items(inventory: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in inventory.get("slots", []):
		var item_id := String(slot.get("item_id", ""))
		var def := get_item_def(item_id)
		result.append({
			"item_id": item_id,
			"amount": int(slot.get("amount", 0)),
			"name": String(def.get("name", item_id)),
			"description": String(def.get("description", "")),
			"category": int(def.get("category", ItemCategory.MISC)),
			"icon_color": def.get("icon_color", Color.WHITE),
			"usable": bool(def.get("usable", false)),
		})
	return result

# --- Serialization ---

static func serialize_inventory(inventory: Dictionary) -> Dictionary:
	return inventory.duplicate(true)

static func deserialize_inventory(data: Variant) -> Dictionary:
	if data is Dictionary:
		var inv := data.duplicate(true)
		if not inv.has("slots"):
			inv["slots"] = []
		if not inv.has("capacity"):
			inv["capacity"] = 40
		return inv
	return create_inventory()
