extends SceneTree

const LocalMegavoxAssets := preload("res://scripts/world/LocalMegavoxAssets.gd")

var _has_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid_manager = scene.get_node("FarmWorld/GridManager")
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

	var homestead_tree_tile = grid_manager.get_tile(Vector2i(8, 0))
	if homestead_tree_tile == null:
		_fail("Could not inspect homestead-edge tree tile.")
		return

	if LocalMegavoxAssets.has_prop("tree"):
		_expect_child(homestead_tree_tile, "Decor/MegavoxTree", "homestead-edge tree should use local MEGAVOX art")
		_expect_local_prop_bounds(homestead_tree_tile, "Decor/MegavoxTree", 1.35, 1.55, "homestead-edge tree should stay tile-scale")
	else:
		_expect_child(homestead_tree_tile, "Decor/TreeTrunk", "homestead-edge tree should keep procedural fallback")
	if _failed():
		return

	var homestead_flower_tile = grid_manager.get_tile(Vector2i(9, 0))
	if homestead_flower_tile == null:
		_fail("Could not inspect homestead-edge flower tile.")
		return

	if LocalMegavoxAssets.has_prop("flower_patch"):
		_expect_child(homestead_flower_tile, "Decor/MegavoxFlowerPatch", "homestead-edge flowers should use local MEGAVOX art")
		_expect_local_prop_bounds(homestead_flower_tile, "Decor/MegavoxFlowerPatch", 0.95, 0.55, "homestead-edge flowers should stay tile-scale")
	else:
		_expect_child(homestead_flower_tile, "Decor/FlowerSoil", "homestead-edge flowers should keep procedural fallback")
	if _failed():
		return

	var homestead_grass_tile = grid_manager.get_tile(Vector2i(6, 0))
	if homestead_grass_tile == null:
		_fail("Could not inspect homestead-edge grass tile.")
		return

	if LocalMegavoxAssets.has_prop("tall_grass"):
		_expect_child(homestead_grass_tile, "Decor/MegavoxTallGrass", "homestead-edge tall grass should use local MEGAVOX art")
		_expect_local_prop_bounds(homestead_grass_tile, "Decor/MegavoxTallGrass", 0.80, 0.65, "homestead-edge tall grass should stay tile-scale")
	else:
		_expect_child(homestead_grass_tile, "Decor/TallGrass0", "homestead-edge tall grass should keep procedural fallback")
	if _failed():
		return

	var homestead_rock_tile = grid_manager.get_tile(Vector2i(10, 3))
	if homestead_rock_tile == null:
		_fail("Could not inspect homestead-edge rock tile.")
		return

	if LocalMegavoxAssets.has_prop("rock"):
		_expect_child(homestead_rock_tile, "Decor/MegavoxRock", "homestead-edge rock should use local MEGAVOX art")
		_expect_local_prop_bounds(homestead_rock_tile, "Decor/MegavoxRock", 0.75, 0.60, "homestead-edge rock should stay tile-scale")
	else:
		_expect_child(homestead_rock_tile, "Decor/RockBase", "homestead-edge rock should keep procedural fallback")
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
