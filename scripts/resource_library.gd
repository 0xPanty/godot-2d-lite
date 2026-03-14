class_name ResourceLibrary
extends RefCounted

## Built-in resource library — template projects and placeholder assets.
## Provides starter content so users don't start from zero.

enum AssetCategory {
	CHARACTER,
	TILESET,
	UI,
	EFFECT,
	TEMPLATE,
}

static var BUILT_IN_ASSETS: Array[Dictionary] = [
	{
		"id": "char_player_placeholder",
		"name": "玩家角色（占位）",
		"category": AssetCategory.CHARACTER,
		"description": "蓝色方块占位角色",
		"color": Color("60a5fa"),
		"size": Vector2(32, 32),
	},
	{
		"id": "char_npc_placeholder",
		"name": "NPC（占位）",
		"category": AssetCategory.CHARACTER,
		"description": "绿色方块占位NPC",
		"color": Color("34d399"),
		"size": Vector2(32, 32),
	},
	{
		"id": "char_enemy_placeholder",
		"name": "敌人（占位）",
		"category": AssetCategory.CHARACTER,
		"description": "红色方块占位敌人",
		"color": Color("f87171"),
		"size": Vector2(32, 32),
	},
	{
		"id": "tile_basic_set",
		"name": "基础地块集",
		"category": AssetCategory.TILESET,
		"description": "6种基础地形的色块图块",
		"color": Color("94a3b8"),
		"size": Vector2(32, 32),
	},
	{
		"id": "ui_dialog_frame",
		"name": "对话框背景",
		"category": AssetCategory.UI,
		"description": "半透明黑底对话框",
		"color": Color("1e293b"),
		"size": Vector2(400, 120),
	},
	{
		"id": "effect_particle_placeholder",
		"name": "粒子效果（占位）",
		"category": AssetCategory.EFFECT,
		"description": "白色小方块粒子",
		"color": Color("e2e8f0"),
		"size": Vector2(8, 8),
	},
]

static var PROJECT_TEMPLATES: Array[Dictionary] = [
	{
		"id": "template_rpg_topdown",
		"name": "俯视角RPG模板",
		"description": "一个玩家 + 一个NPC + 一个宝箱 + 围墙地图",
		"objects": [
			{"type": "player", "name": "主角", "x": 160, "y": 160},
			{"type": "npc", "name": "村长", "x": 320, "y": 160, "dialogue": "欢迎来到新手村！"},
			{"type": "chest", "name": "宝箱", "x": 480, "y": 160},
		],
		"tiles": "wall_border",
	},
	{
		"id": "template_platformer",
		"name": "横版平台跳跃模板",
		"description": "一个平台跳跃玩家 + 地面平台",
		"objects": [
			{"type": "player", "name": "主角", "x": 96, "y": 320},
		],
		"tiles": "platform_ground",
	},
	{
		"id": "template_empty",
		"name": "空白项目",
		"description": "只有一个玩家的空白项目",
		"objects": [
			{"type": "player", "name": "主角", "x": 160, "y": 160},
		],
		"tiles": "none",
	},
]

static func get_assets() -> Array[Dictionary]:
	return BUILT_IN_ASSETS

static func get_assets_by_category(cat: AssetCategory) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for asset in BUILT_IN_ASSETS:
		if int(asset.get("category", -1)) == cat:
			result.append(asset)
	return result

static func get_templates() -> Array[Dictionary]:
	return PROJECT_TEMPLATES

static func get_template(template_id: String) -> Dictionary:
	for t in PROJECT_TEMPLATES:
		if String(t.get("id", "")) == template_id:
			return t
	return {}

static func category_label(cat: int) -> String:
	match cat:
		AssetCategory.CHARACTER: return "角色"
		AssetCategory.TILESET: return "图块"
		AssetCategory.UI: return "界面"
		AssetCategory.EFFECT: return "特效"
		AssetCategory.TEMPLATE: return "模板"
		_: return "其他"

## Generate a placeholder texture from a built-in asset definition.
static func generate_placeholder_texture(asset_id: String) -> ImageTexture:
	var asset := {}
	for a in BUILT_IN_ASSETS:
		if String(a.get("id", "")) == asset_id:
			asset = a
			break
	if asset.is_empty():
		return null

	var size: Vector2 = asset.get("size", Vector2(32, 32))
	var color: Color = asset.get("color", Color.WHITE)
	var image := Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

## Apply a project template — returns objects and tile_cells arrays.
static func apply_template(template_id: String) -> Dictionary:
	var tmpl := get_template(template_id)
	if tmpl.is_empty():
		return {"objects": [], "tile_cells": []}

	var objects: Array[Dictionary] = []
	var obj_defs: Array = tmpl.get("objects", [])
	for i in obj_defs.size():
		var def: Dictionary = obj_defs[i]
		objects.append({
			"type": String(def.get("type", "prop")),
			"name": String(def.get("name", "对象 %d" % (i + 1))),
			"x": float(def.get("x", 96)),
			"y": float(def.get("y", 96)),
			"dialogue": String(def.get("dialogue", "")),
		})

	var tile_cells: Array[Dictionary] = []
	var tile_pattern := String(tmpl.get("tiles", "none"))
	match tile_pattern:
		"wall_border":
			tile_cells = _generate_wall_border(20, 15)
		"platform_ground":
			tile_cells = _generate_platform_ground(20, 15)

	return {"objects": objects, "tile_cells": tile_cells}

static func _generate_wall_border(width: int, height: int) -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	for x in width:
		cells.append({"x": x, "y": 0, "terrain": "wall", "layer": "collision"})
		cells.append({"x": x, "y": height - 1, "terrain": "wall", "layer": "collision"})
	for y in range(1, height - 1):
		cells.append({"x": 0, "y": y, "terrain": "wall", "layer": "collision"})
		cells.append({"x": width - 1, "y": y, "terrain": "wall", "layer": "collision"})
	for x in range(1, width - 1):
		for y in range(1, height - 1):
			cells.append({"x": x, "y": y, "terrain": "ground", "layer": "ground"})
	return cells

static func _generate_platform_ground(width: int, height: int) -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	for x in width:
		cells.append({"x": x, "y": height - 1, "terrain": "wall", "layer": "collision"})
		cells.append({"x": x, "y": height - 2, "terrain": "ground", "layer": "ground"})
	for x in range(5, 10):
		cells.append({"x": x, "y": height - 5, "terrain": "wall", "layer": "collision"})
	for x in range(12, 17):
		cells.append({"x": x, "y": height - 8, "terrain": "wall", "layer": "collision"})
	return cells
