class_name TileMapBuilder
extends RefCounted

## Converts custom tile_cells data into Godot native TileMap + TileSet.
## Supports terrain-based auto-tiling and physics layers.

const GRID_SIZE := 32

const TERRAIN_DEFS := {
	"ground": {"color": Color("334155"), "physics": false, "z_index": -10},
	"wall":   {"color": Color("475569"), "physics": true,  "z_index": -5},
	"water":  {"color": Color("1d4ed8"), "physics": true,  "z_index": -10},
	"grass":  {"color": Color("166534"), "physics": false, "z_index": -8},
	"sand":   {"color": Color("a16207"), "physics": false, "z_index": -9},
	"path":   {"color": Color("78716c"), "physics": false, "z_index": -7},
}

const LAYER_Z := {
	"ground": -10,
	"decoration": -5,
	"collision": 0,
}

## Build a TileSet with one source per terrain type.
## Each terrain is a single-color 32x32 tile generated via Image.
static func build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(GRID_SIZE, GRID_SIZE)

	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 1)

	var source_id := 0
	for terrain_name in TERRAIN_DEFS.keys():
		var def: Dictionary = TERRAIN_DEFS[terrain_name]
		var image := Image.create(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_RGBA8)
		image.fill(def.get("color", Color.WHITE))
		var texture := ImageTexture.create_from_image(image)

		var atlas_src := TileSetAtlasSource.new()
		atlas_src.texture = texture
		atlas_src.texture_region_size = Vector2i(GRID_SIZE, GRID_SIZE)
		atlas_src.create_tile(Vector2i.ZERO)

		if bool(def.get("physics", false)):
			var tile_data := atlas_src.get_tile_data(Vector2i.ZERO, 0)
			if tile_data:
				var hs := GRID_SIZE / 2.0
				var poly := PackedVector2Array([
					Vector2(-hs, -hs), Vector2(hs, -hs),
					Vector2(hs, hs), Vector2(-hs, hs),
				])
				tile_data.add_collision_polygon(0)
				tile_data.set_collision_polygon_points(0, 0, poly)

		ts.add_source(atlas_src, source_id)
		source_id += 1
	return ts

## Get the source_id for a terrain name.
static func terrain_source_id(terrain_name: String) -> int:
	var keys := TERRAIN_DEFS.keys()
	return keys.find(terrain_name)

## Build a TileMap node and populate it from tile_cells data.
## Returns a TileMap ready to add to the scene tree.
static func build_tilemap(tile_cells: Array, tileset: TileSet = null) -> TileMap:
	if tileset == null:
		tileset = build_tileset()

	var tilemap := TileMap.new()
	tilemap.name = "TileMapWorld"
	tilemap.tile_set = tileset
	tilemap.z_index = -10

	for tile_data in tile_cells:
		var terrain := String(tile_data.get("terrain", "ground"))
		var cell := Vector2i(int(tile_data.get("x", 0)), int(tile_data.get("y", 0)))
		var src_id := terrain_source_id(terrain)
		if src_id < 0:
			continue
		tilemap.set_cell(0, cell, src_id, Vector2i.ZERO)

	return tilemap

## Update an existing TileMap with new tile_cells data (full rebuild).
static func update_tilemap(tilemap: TileMap, tile_cells: Array) -> void:
	tilemap.clear()
	for tile_data in tile_cells:
		var terrain := String(tile_data.get("terrain", "ground"))
		var cell := Vector2i(int(tile_data.get("x", 0)), int(tile_data.get("y", 0)))
		var src_id := terrain_source_id(terrain)
		if src_id < 0:
			continue
		tilemap.set_cell(0, cell, src_id, Vector2i.ZERO)

## Convert a TileMap back to tile_cells array (for saving).
static func tilemap_to_cells(tilemap: TileMap) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var keys := TERRAIN_DEFS.keys()
	var used_cells := tilemap.get_used_cells(0)
	for cell in used_cells:
		var src_id := tilemap.get_cell_source_id(0, cell)
		if src_id < 0 or src_id >= keys.size():
			continue
		result.append({
			"x": cell.x,
			"y": cell.y,
			"terrain": keys[src_id],
			"layer": _terrain_to_layer(keys[src_id]),
		})
	return result

static func _terrain_to_layer(terrain: String) -> String:
	match terrain:
		"wall": return "collision"
		"grass", "sand", "path": return "decoration"
		_: return "ground"
