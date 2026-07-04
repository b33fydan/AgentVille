extends SceneTree

const LocalMegavoxAssets := preload("res://scripts/world/LocalMegavoxAssets.gd")
const EXPECTED_STARTER_DECOR_CLUSTER_ORDER := [
	"homestead_edge",
	"silo_garden_gap",
	"north_field_edge",
	"north_homestead_gap",
	"well_garden_gap",
	"west_field_gap",
	"west_meadow_edge",
	"lower_field_gap",
	"south_meadow_edge",
	"south_grove_gap",
	"east_grove_edge"
]
const EXPECTED_STARTER_DECOR_CLUSTERS := {
	"homestead_edge": 5,
	"silo_garden_gap": 1,
	"north_field_edge": 4,
	"north_homestead_gap": 1,
	"well_garden_gap": 1,
	"west_field_gap": 1,
	"west_meadow_edge": 3,
	"lower_field_gap": 1,
	"south_meadow_edge": 6,
	"south_grove_gap": 1,
	"east_grove_edge": 6
}
const RESERVED_STARTER_CLUSTER_TILES := {
	"work_order_smoke": [
		Vector2i(0, 0),
		Vector2i(0, 1),
		Vector2i(0, 3),
		Vector2i(1, 0),
		Vector2i(1, 5),
		Vector2i(1, 6),
		Vector2i(4, 5),
		Vector2i(6, 2)
	],
	"ui_field_targeting_smoke": [
		Vector2i(0, 0),
		Vector2i(4, 5),
		Vector2i(4, 7),
		Vector2i(6, 5),
		Vector2i(6, 7),
		Vector2i(10, 8)
	],
	"skill_forge_scan_targets": [
		Vector2i(0, 0),
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(1, 5),
		Vector2i(1, 6),
		Vector2i(4, 5),
		Vector2i(6, 2)
	]
}
const STARTER_DECOR_DENSITY_ZONES := {
	"west_field_readability": {
		"min": Vector2i(0, 0),
		"max": Vector2i(5, 3),
		"max_entries": 6
	},
	"central_aisle_readability": {
		"min": Vector2i(4, 2),
		"max": Vector2i(6, 6),
		"max_entries": 2
	},
	"north_homestead_readability": {
		"min": Vector2i(6, 0),
		"max": Vector2i(10, 3),
		"max_entries": 7
	},
	"lower_field_readability": {
		"min": Vector2i(0, 5),
		"max": Vector2i(4, 8),
		"max_entries": 8
	},
	"south_grove_bridge_readability": {
		"min": Vector2i(5, 7),
		"max": Vector2i(7, 8),
		"max_entries": 3
	},
	"east_grove_readability": {
		"min": Vector2i(7, 5),
		"max": Vector2i(10, 8),
		"max_entries": 8
	}
}

var _has_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid_manager = scene.get_node("FarmWorld/GridManager")
	_expect_starter_decor_catalog_safe(grid_manager)
	if _failed():
		return
	_expect_starter_decor_catalog_props(grid_manager)
	if _failed():
		return

	var fence_tile = grid_manager.get_tile(Vector2i(8, 1))
	if fence_tile == null:
		_fail("Could not inspect starter fence tile.")
		return

	if LocalMegavoxAssets.has_prop("fence"):
		_expect_child(fence_tile, "Decor/MegavoxFence", "starter fence should use local MEGAVOX art")
	else:
		_expect_child(fence_tile, "Decor/PostA", "starter fence should keep procedural fallback")
	if _failed():
		return

	var flower_tile = grid_manager.get_tile(Vector2i(7, 2))
	if flower_tile == null:
		_fail("Could not inspect starter flower-patch tile.")
		return

	if LocalMegavoxAssets.has_prop("flower_patch"):
		_expect_child(flower_tile, "Decor/MegavoxFlowerPatch", "starter flower patch should use local MEGAVOX art")
		_expect_local_prop_bounds(flower_tile, "Decor/MegavoxFlowerPatch", 0.95, 0.55, "starter flower patch should stay tile-scale")
	else:
		_expect_child(flower_tile, "Decor/FlowerSoil", "starter flower patch should keep procedural fallback")
	if _failed():
		return

	var starter_tree_tile = grid_manager.get_tile(Vector2i(4, 1))
	if starter_tree_tile == null:
		_fail("Could not inspect starter tree tile.")
		return

	if LocalMegavoxAssets.has_prop("tree_alt"):
		_expect_child(starter_tree_tile, "Decor/MegavoxTreeAlt", "starter tree should use the alternate local MEGAVOX art")
		_expect_local_prop_bounds(starter_tree_tile, "Decor/MegavoxTreeAlt", 1.35, 1.55, "starter alternate tree should stay tile-scale")
	elif LocalMegavoxAssets.has_prop("tree"):
		_expect_child(starter_tree_tile, "Decor/MegavoxTree", "starter tree should use local MEGAVOX art")
		_expect_local_prop_bounds(starter_tree_tile, "Decor/MegavoxTree", 1.35, 1.55, "starter tree should stay tile-scale")
	else:
		_expect_child(starter_tree_tile, "Decor/TreeTrunk", "starter tree should keep procedural fallback")
	if _failed():
		return

	var starter_rock_tile = grid_manager.get_tile(Vector2i(0, 6))
	if starter_rock_tile == null:
		_fail("Could not inspect starter rock tile.")
		return

	if LocalMegavoxAssets.has_prop("rock_alt"):
		_expect_child(starter_rock_tile, "Decor/MegavoxRockAlt", "starter rock should use the alternate local MEGAVOX art")
		_expect_local_prop_bounds(starter_rock_tile, "Decor/MegavoxRockAlt", 0.75, 0.60, "starter alternate rock should stay tile-scale")
	elif LocalMegavoxAssets.has_prop("rock"):
		_expect_child(starter_rock_tile, "Decor/MegavoxRock", "starter rock should use local MEGAVOX art")
		_expect_local_prop_bounds(starter_rock_tile, "Decor/MegavoxRock", 0.75, 0.60, "starter rock should stay tile-scale")
	else:
		_expect_child(starter_rock_tile, "Decor/RockBase", "starter rock should keep procedural fallback")
	if _failed():
		return

	var starter_grass_tile = grid_manager.get_tile(Vector2i(0, 1))
	if starter_grass_tile == null:
		_fail("Could not inspect starter tall-grass tile.")
		return

	if LocalMegavoxAssets.has_prop("tall_grass_alt"):
		_expect_child(starter_grass_tile, "Decor/MegavoxTallGrassAlt", "starter edge tall grass should use the alternate local MEGAVOX art")
		_expect_local_prop_bounds(starter_grass_tile, "Decor/MegavoxTallGrassAlt", 0.80, 0.65, "starter alternate tall grass should stay tile-scale")
	elif LocalMegavoxAssets.has_prop("tall_grass"):
		_expect_child(starter_grass_tile, "Decor/MegavoxTallGrass", "starter edge tall grass should use local MEGAVOX art")
		_expect_local_prop_bounds(starter_grass_tile, "Decor/MegavoxTallGrass", 0.80, 0.65, "starter tall grass should stay tile-scale")
	else:
		_expect_child(starter_grass_tile, "Decor/TallGrass0", "starter edge tall grass should keep procedural fallback")
	if _failed():
		return

	var grass_tile = grid_manager.get_tile(Vector2i(1, 0))
	if grass_tile == null:
		_fail("Could not inspect tall-grass test tile.")
		return
	grass_tile.erase()
	if not grass_tile.place_item("tall_grass"):
		_fail("Could not place tall grass for optional MEGAVOX art check.")
		return

	if LocalMegavoxAssets.has_prop("tall_grass"):
		_expect_child(grass_tile, "Decor/MegavoxTallGrass", "placed tall grass should use local MEGAVOX art")
		_expect_local_prop_bounds(grass_tile, "Decor/MegavoxTallGrass", 0.80, 0.65, "placed tall grass should stay tile-scale")
	else:
		_expect_child(grass_tile, "Decor/TallGrass0", "placed tall grass should keep procedural fallback")
	if _failed():
		return

	var tree_tile = grid_manager.get_tile(Vector2i(10, 0))
	if tree_tile == null:
		_fail("Could not inspect tree test tile.")
		return
	tree_tile.erase()
	if not tree_tile.place_item("tree"):
		_fail("Could not place tree for optional MEGAVOX art check.")
		return

	if LocalMegavoxAssets.has_prop("tree"):
		_expect_child(tree_tile, "Decor/MegavoxTree", "placed tree should use local MEGAVOX art")
		_expect_local_prop_bounds(tree_tile, "Decor/MegavoxTree", 1.35, 1.55, "placed tree should stay tile-scale")
	else:
		_expect_child(tree_tile, "Decor/TreeTrunk", "placed tree should keep procedural fallback")
	if _failed():
		return

	var rock_tile = grid_manager.get_tile(Vector2i(0, 0))
	rock_tile.erase()
	if not rock_tile.place_item("rock"):
		_fail("Could not place rock for optional MEGAVOX art check.")
		return

	if LocalMegavoxAssets.has_prop("rock"):
		_expect_child(rock_tile, "Decor/MegavoxRock", "placed rock should use local MEGAVOX art")
		_expect_local_prop_bounds(rock_tile, "Decor/MegavoxRock", 0.75, 0.60, "placed rock should stay tile-scale")
	else:
		_expect_child(rock_tile, "Decor/RockBase", "placed rock should keep procedural fallback")
	if _failed():
		return

	quit()


func _expect_child(root: Node, node_path: String, context: String) -> void:
	if root.get_node_or_null(node_path) == null:
		_fail("Missing %s: %s." % [node_path, context])


func _expect_starter_decor_catalog_safe(grid_manager) -> void:
	if not grid_manager.has_method("starter_decor_clusters"):
		_fail("GridManager should expose starter decor clusters for map-art validation.")
		return
	if not grid_manager.has_method("starter_decor_cluster_order"):
		_fail("GridManager should expose starter decor cluster order for map-art validation.")
		return

	var clusters: Dictionary = grid_manager.call("starter_decor_clusters")
	_expect_starter_decor_cluster_order(grid_manager, clusters)
	if _failed():
		return

	for cluster_id in EXPECTED_STARTER_DECOR_CLUSTERS.keys():
		if not clusters.has(cluster_id):
			_fail("Starter decor catalog is missing %s." % cluster_id)
			return
		var entries = clusters.get(cluster_id, [])
		if typeof(entries) != TYPE_ARRAY:
			_fail("Starter decor catalog %s should be an array of entries." % cluster_id)
			return
		if entries.size() != int(EXPECTED_STARTER_DECOR_CLUSTERS[cluster_id]):
			_fail("Starter decor catalog %s should have %s entries, saw %s." % [
				cluster_id,
				int(EXPECTED_STARTER_DECOR_CLUSTERS[cluster_id]),
				entries.size()
			])
			return

	var reserved_by_tile := _reserved_starter_cluster_tiles()
	var protected_by_tile := _protected_starter_cluster_tiles()
	var catalog_tiles := {}
	var catalog_entries := []
	for cluster_id in clusters.keys():
		if not EXPECTED_STARTER_DECOR_CLUSTERS.has(str(cluster_id)):
			_fail("Starter decor catalog has unexpected cluster %s." % str(cluster_id))
			return
		var entries = clusters.get(cluster_id, [])
		if typeof(entries) != TYPE_ARRAY:
			_fail("Starter decor catalog %s should be an array of entries." % cluster_id)
			return
		for entry in entries:
			if typeof(entry) != TYPE_DICTIONARY:
				_fail("Starter decor catalog %s contains a non-dictionary entry." % cluster_id)
				return
			var grid_pos = entry.get("grid_pos", Vector2i(-1, -1))
			if typeof(grid_pos) != TYPE_VECTOR2I:
				_fail("Starter decor catalog %s contains an entry without a Vector2i grid_pos." % cluster_id)
				return
			if catalog_tiles.has(grid_pos):
				_fail("Starter decor catalog %s reuses tile %s already used by %s." % [
					cluster_id,
					_format_tile(grid_pos),
					str(catalog_tiles[grid_pos])
				])
				return
			catalog_tiles[grid_pos] = str(cluster_id)
			var decor_id := str(entry.get("decor_id", ""))
			if not ["flower_patch", "rock", "tall_grass", "tree"].has(decor_id):
				_fail("Starter decor catalog %s uses unsupported decor %s." % [cluster_id, decor_id])
				return
			if reserved_by_tile.has(grid_pos):
				_fail("Starter decor catalog %s uses reserved target tile %s from %s." % [
					cluster_id,
					_format_tile(grid_pos),
					str(reserved_by_tile[grid_pos])
				])
				return
			if protected_by_tile.has(grid_pos):
				_fail("Starter decor catalog %s uses protected starter tile %s from %s." % [
					cluster_id,
					_format_tile(grid_pos),
					str(protected_by_tile[grid_pos])
				])
				return
			var tile = grid_manager.get_tile(grid_pos)
			if tile == null:
				_fail("Starter decor catalog %s points outside the grid at %s." % [cluster_id, _format_tile(grid_pos)])
				return
			if str(tile.decor_id) != decor_id:
				_fail("Starter decor catalog %s expected %s at %s, saw %s." % [
					cluster_id,
					decor_id,
					_format_tile(grid_pos),
					str(tile.decor_id)
				])
				return
			catalog_entries.append({
				"cluster_id": str(cluster_id),
				"decor_id": decor_id,
				"grid_pos": grid_pos
			})
	_expect_starter_decor_density(catalog_tiles)
	if _failed():
		return
	_expect_starter_decor_variety(catalog_entries)


func _expect_starter_decor_density(catalog_tiles: Dictionary) -> void:
	var coverage_by_tile := {}
	for grid_pos in catalog_tiles.keys():
		coverage_by_tile[grid_pos] = []

	for zone_id in STARTER_DECOR_DENSITY_ZONES.keys():
		var zone: Dictionary = STARTER_DECOR_DENSITY_ZONES[zone_id]
		var min_pos: Vector2i = zone.get("min", Vector2i.ZERO)
		var max_pos: Vector2i = zone.get("max", Vector2i.ZERO)
		var max_entries := int(zone.get("max_entries", 0))
		var occupied := []
		for grid_pos in catalog_tiles.keys():
			if _is_tile_in_density_zone(grid_pos, min_pos, max_pos):
				occupied.append("%s from %s" % [_format_tile(grid_pos), str(catalog_tiles[grid_pos])])
				var covered_zones: Array = coverage_by_tile[grid_pos]
				covered_zones.append(str(zone_id))
				coverage_by_tile[grid_pos] = covered_zones
		if occupied.size() > max_entries:
			occupied.sort()
			_fail("Starter decor density zone %s allows %s entries, saw %s: %s." % [
				str(zone_id),
				max_entries,
				occupied.size(),
				", ".join(occupied)
			])
			return

	var uncovered := []
	for grid_pos in coverage_by_tile.keys():
		var covered_zones: Array = coverage_by_tile[grid_pos]
		if covered_zones.size() == 0:
			uncovered.append("%s from %s" % [_format_tile(grid_pos), str(catalog_tiles[grid_pos])])
	if uncovered.size() > 0:
		uncovered.sort()
		_fail("Starter decor density zones do not cover %s." % ", ".join(uncovered))
		return


func _is_tile_in_density_zone(grid_pos: Vector2i, min_pos: Vector2i, max_pos: Vector2i) -> bool:
	return (
		grid_pos.x >= min_pos.x
		and grid_pos.x <= max_pos.x
		and grid_pos.y >= min_pos.y
		and grid_pos.y <= max_pos.y
	)


func _expect_starter_decor_variety(catalog_entries: Array) -> void:
	var west_edge_tall_grass := []
	for entry in catalog_entries:
		var grid_pos: Vector2i = entry.get("grid_pos", Vector2i(-1, -1))
		if str(entry.get("decor_id", "")) == "tall_grass" and grid_pos.x == 0:
			west_edge_tall_grass.append("%s from %s" % [
				_format_tile(grid_pos),
				str(entry.get("cluster_id", ""))
			])
	if west_edge_tall_grass.size() == 0:
		_fail("Starter decor catalog should include west-edge tall grass for meadow art variety.")
		return


func _expect_starter_decor_cluster_order(grid_manager, clusters: Dictionary) -> void:
	var raw_order = grid_manager.call("starter_decor_cluster_order")
	if typeof(raw_order) != TYPE_ARRAY:
		_fail("Starter decor cluster order should be an array.")
		return
	if raw_order.size() != EXPECTED_STARTER_DECOR_CLUSTER_ORDER.size():
		_fail("Starter decor cluster order should have %s entries, saw %s." % [
			EXPECTED_STARTER_DECOR_CLUSTER_ORDER.size(),
			raw_order.size()
		])
		return

	var seen := {}
	for index in range(EXPECTED_STARTER_DECOR_CLUSTER_ORDER.size()):
		var cluster_id := str(raw_order[index])
		var expected_id := str(EXPECTED_STARTER_DECOR_CLUSTER_ORDER[index])
		if cluster_id != expected_id:
			_fail("Starter decor cluster order at %s should be %s, saw %s." % [index, expected_id, cluster_id])
			return
		if seen.has(cluster_id):
			_fail("Starter decor cluster order repeats %s." % cluster_id)
			return
		seen[cluster_id] = true
		if not clusters.has(cluster_id):
			_fail("Starter decor cluster order references missing cluster %s." % cluster_id)
			return

	for cluster_id in clusters.keys():
		if not seen.has(str(cluster_id)):
			_fail("Starter decor cluster %s is missing from the authored order." % str(cluster_id))
			return


func _reserved_starter_cluster_tiles() -> Dictionary:
	var reserved := {}
	for source_id in RESERVED_STARTER_CLUSTER_TILES.keys():
		for grid_pos in RESERVED_STARTER_CLUSTER_TILES[source_id]:
			_add_starter_cluster_tile_source(reserved, grid_pos, str(source_id))
	return reserved


func _protected_starter_cluster_tiles() -> Dictionary:
	var protected := {}
	for x in range(0, 11):
		_add_starter_cluster_tile_source(protected, Vector2i(x, 4), "starter_paths")
	for z in range(1, 8):
		_add_starter_cluster_tile_source(protected, Vector2i(5, z), "starter_paths")
	for grid_pos in [Vector2i(6, 3), Vector2i(7, 3), Vector2i(8, 3), Vector2i(9, 3)]:
		_add_starter_cluster_tile_source(protected, grid_pos, "starter_paths")

	for grid_pos in [Vector2i(7, 1), Vector2i(9, 1), Vector2i(4, 3)]:
		_add_starter_cluster_tile_source(protected, grid_pos, "starter_structures")

	for grid_pos in [
		Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5),
		Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6),
		Vector2i(7, 5), Vector2i(8, 5), Vector2i(8, 6),
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
		Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)
	]:
		_add_starter_cluster_tile_source(protected, grid_pos, "starter_crop_fields")

	for grid_pos in [
		Vector2i(8, 2), Vector2i(8, 1), Vector2i(6, 1),
		Vector2i(7, 2), Vector2i(4, 1), Vector2i(0, 6),
		Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 7),
		Vector2i(2, 7), Vector2i(9, 7), Vector2i(10, 2), Vector2i(10, 6)
	]:
		_add_starter_cluster_tile_source(protected, grid_pos, "starter_anchor_decor")
	return protected


func _add_starter_cluster_tile_source(tile_sources: Dictionary, grid_pos: Vector2i, source_id: String) -> void:
	if not tile_sources.has(grid_pos):
		tile_sources[grid_pos] = []
	tile_sources[grid_pos].append(source_id)


func _format_tile(grid_pos: Vector2i) -> String:
	return "%s,%s" % [grid_pos.x, grid_pos.y]


func _expect_starter_decor_catalog_props(grid_manager) -> void:
	var clusters: Dictionary = grid_manager.call("starter_decor_clusters")
	for cluster_id in clusters.keys():
		var entries: Array = clusters.get(cluster_id, [])
		for entry in entries:
			var grid_pos: Vector2i = entry.get("grid_pos", Vector2i(-1, -1))
			var decor_id := str(entry.get("decor_id", ""))
			var spec := _starter_decor_prop_spec(grid_pos, decor_id, str(cluster_id))
			if spec.is_empty():
				_fail("Starter decor catalog %s has no prop smoke spec for %s at %s." % [
					str(cluster_id),
					decor_id,
					_format_tile(grid_pos)
				])
				return
			_expect_optional_prop_tile(grid_manager, spec)
			if _failed():
				return


func _starter_decor_prop_spec(grid_pos: Vector2i, decor_id: String, cluster_id: String) -> Dictionary:
	var context := "%s %s at %s" % [
		cluster_id.replace("_", " "),
		decor_id.replace("_", " "),
		_format_tile(grid_pos)
	]
	match decor_id:
		"flower_patch":
			return {
				"grid_pos": grid_pos,
				"primary_prop": "flower_patch",
				"primary_node": "Decor/MegavoxFlowerPatch",
				"fallback_node": "Decor/FlowerSoil",
				"max_footprint": 0.95,
				"max_height": 0.55,
				"context": context
			}
		"rock":
			return {
				"grid_pos": grid_pos,
				"primary_prop": "rock_alt" if grid_pos.y >= 5 else "rock",
				"primary_node": "Decor/MegavoxRockAlt" if grid_pos.y >= 5 else "Decor/MegavoxRock",
				"secondary_prop": "rock" if grid_pos.y >= 5 else "",
				"secondary_node": "Decor/MegavoxRock" if grid_pos.y >= 5 else "",
				"fallback_node": "Decor/RockBase",
				"max_footprint": 0.75,
				"max_height": 0.60,
				"context": context
			}
		"tall_grass":
			return {
				"grid_pos": grid_pos,
				"primary_prop": "tall_grass_alt" if grid_pos.x == 0 else "tall_grass",
				"primary_node": "Decor/MegavoxTallGrassAlt" if grid_pos.x == 0 else "Decor/MegavoxTallGrass",
				"secondary_prop": "tall_grass" if grid_pos.x == 0 else "",
				"secondary_node": "Decor/MegavoxTallGrass" if grid_pos.x == 0 else "",
				"fallback_node": "Decor/TallGrass0",
				"max_footprint": 0.80,
				"max_height": 0.65,
				"context": context
			}
		"tree":
			return {
				"grid_pos": grid_pos,
				"primary_prop": "tree_alt" if grid_pos.x <= 4 else "tree",
				"primary_node": "Decor/MegavoxTreeAlt" if grid_pos.x <= 4 else "Decor/MegavoxTree",
				"secondary_prop": "tree" if grid_pos.x <= 4 else "",
				"secondary_node": "Decor/MegavoxTree" if grid_pos.x <= 4 else "",
				"fallback_node": "Decor/TreeTrunk",
				"max_footprint": 1.35,
				"max_height": 1.55,
				"context": context
			}
	return {}


func _expect_optional_prop_tile(grid_manager, spec: Dictionary) -> void:
	var grid_pos: Vector2i = spec["grid_pos"]
	var context := str(spec.get("context", "starter prop"))
	var tile = grid_manager.get_tile(grid_pos)
	if tile == null:
		_fail("Could not inspect %s tile." % context)
		return

	var primary_prop := str(spec.get("primary_prop", ""))
	var primary_node := str(spec.get("primary_node", ""))
	var secondary_prop := str(spec.get("secondary_prop", ""))
	var secondary_node := str(spec.get("secondary_node", ""))
	var fallback_node := str(spec.get("fallback_node", ""))
	var max_footprint := float(spec.get("max_footprint", 1.0))
	var max_height := float(spec.get("max_height", 1.0))

	if primary_prop != "" and LocalMegavoxAssets.has_prop(primary_prop):
		_expect_child(tile, primary_node, "%s should use local MEGAVOX art" % context)
		if _failed():
			return
		_expect_local_prop_bounds(tile, primary_node, max_footprint, max_height, "%s should stay tile-scale" % context)
	elif secondary_prop != "" and LocalMegavoxAssets.has_prop(secondary_prop):
		_expect_child(tile, secondary_node, "%s should use secondary local MEGAVOX art" % context)
		if _failed():
			return
		_expect_local_prop_bounds(tile, secondary_node, max_footprint, max_height, "%s should stay tile-scale" % context)
	else:
		_expect_child(tile, fallback_node, "%s should keep procedural fallback" % context)


func _expect_local_prop_bounds(root: Node, node_path: String, max_footprint: float, max_height: float, context: String) -> void:
	var root_3d := root as Node3D
	if root_3d == null:
		_fail("Could not measure %s: root is not Node3D." % node_path)
		return

	var prop_node := root.get_node_or_null(node_path)
	if prop_node == null:
		_fail("Could not measure missing %s: %s." % [node_path, context])
		return

	var report := _measure_mesh_bounds(root_3d, prop_node)
	if not bool(report.get("has_aabb", false)):
		_fail("Could not measure %s: no mesh bounds found." % node_path)
		return

	var aabb: AABB = report["aabb"]
	var size := aabb.size
	var footprint := maxf(size.x, size.z)
	if footprint > max_footprint or size.y > max_height:
		_fail("%s exceeded bounds: footprint=%.2f/%.2f height=%.2f/%.2f." % [
			context,
			footprint,
			max_footprint,
			size.y,
			max_height
		])


func _measure_mesh_bounds(root_node: Node3D, asset_node: Node) -> Dictionary:
	var combined := AABB()
	var has_aabb := false
	var root_inverse := root_node.global_transform.affine_inverse()

	for node in _node_tree(asset_node):
		if node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			var local_aabb := mesh_instance.mesh.get_aabb()
			var root_space_aabb := _transform_aabb(root_inverse * mesh_instance.global_transform, local_aabb)
			combined = root_space_aabb if not has_aabb else combined.merge(root_space_aabb)
			has_aabb = true

	return {
		"has_aabb": has_aabb,
		"aabb": combined
	}


func _node_tree(root_node: Node) -> Array[Node]:
	var nodes: Array[Node] = [root_node]
	var index := 0
	while index < nodes.size():
		var node := nodes[index]
		for child in node.get_children():
			nodes.append(child)
		index += 1
	return nodes


func _transform_aabb(transform: Transform3D, aabb: AABB) -> AABB:
	var min_corner := aabb.position
	var max_corner := aabb.position + aabb.size
	var corners := [
		Vector3(min_corner.x, min_corner.y, min_corner.z),
		Vector3(max_corner.x, min_corner.y, min_corner.z),
		Vector3(min_corner.x, max_corner.y, min_corner.z),
		Vector3(max_corner.x, max_corner.y, min_corner.z),
		Vector3(min_corner.x, min_corner.y, max_corner.z),
		Vector3(max_corner.x, min_corner.y, max_corner.z),
		Vector3(min_corner.x, max_corner.y, max_corner.z),
		Vector3(max_corner.x, max_corner.y, max_corner.z),
	]

	var transformed := AABB(transform * corners[0], Vector3.ZERO)
	for i in range(1, corners.size()):
		transformed = transformed.expand(transform * corners[i])
	return transformed


func _failed() -> bool:
	return _has_failed


func _fail(message: String) -> void:
	_has_failed = true
	push_error(message)
	quit(1)
