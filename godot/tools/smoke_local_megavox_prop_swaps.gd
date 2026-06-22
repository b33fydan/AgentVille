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
	elif LocalMegavoxAssets.has_prop("tree"):
		_expect_child(starter_tree_tile, "Decor/MegavoxTree", "starter tree should use local MEGAVOX art")
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
	elif LocalMegavoxAssets.has_prop("rock"):
		_expect_child(starter_rock_tile, "Decor/MegavoxRock", "starter rock should use local MEGAVOX art")
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
	elif LocalMegavoxAssets.has_prop("tall_grass"):
		_expect_child(starter_grass_tile, "Decor/MegavoxTallGrass", "starter edge tall grass should use local MEGAVOX art")
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
	else:
		_expect_child(rock_tile, "Decor/RockBase", "placed rock should keep procedural fallback")
	if _failed():
		return

	quit()


func _expect_child(root: Node, node_path: String, context: String) -> void:
	if root.get_node_or_null(node_path) == null:
		_fail("Missing %s: %s." % [node_path, context])


func _failed() -> bool:
	return _has_failed


func _fail(message: String) -> void:
	_has_failed = true
	push_error(message)
	quit(1)
