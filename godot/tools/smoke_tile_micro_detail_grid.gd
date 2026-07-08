extends SceneTree

var _has_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid_manager = scene.get_node("FarmWorld/GridManager")
	if grid_manager.tiles.size() != grid_manager.width * grid_manager.height:
		_fail("Micro detail layer should not change the gameplay tile count.")
		return

	var tile = grid_manager.get_tile(Vector2i(6, 6))
	if tile == null:
		_fail("Could not inspect center gameplay tile.")
		return
	if not tile.has_method("micro_detail_grid_size") or tile.call("micro_detail_grid_size") != 4:
		_fail("Tile should expose a 4x4 visual micro-detail grid.")
		return
	if not tile.has_method("micro_detail_count") or tile.call("micro_detail_count") != 16:
		_fail("Tile should render 16 visual micro-detail cells.")
		return
	if not tile.has_method("micro_detail_surface_id"):
		_fail("Tile should expose its visual-only micro-detail surface id.")
		return
	_expect_micro_surface(tile, "grass", "plain grass tile")
	if _has_failed:
		return

	var path_tile = grid_manager.get_tile(Vector2i(5, 4))
	_expect_micro_surface(path_tile, "dirt_path", "dirt path tile")
	if _has_failed:
		return
	var adjacent_path_tile = grid_manager.get_tile(Vector2i(6, 4))
	_expect_micro_surface(adjacent_path_tile, "dirt_path", "adjacent dirt path tile")
	if _has_failed:
		return
	var path_detail_signature := _road_detail_signature(path_tile, "dirt path tile")
	if _has_failed:
		return
	var adjacent_detail_signature := _road_detail_signature(adjacent_path_tile, "adjacent dirt path tile")
	if _has_failed:
		return
	if path_detail_signature == adjacent_detail_signature:
		_fail("Adjacent dirt path tiles should vary their visual-only edge and pebble details.")
		return
	var crop_tile = grid_manager.get_tile(Vector2i(1, 5))
	_expect_micro_surface(crop_tile, "crop_soil", "planted crop tile")
	if _has_failed:
		return
	var decor_tile = grid_manager.get_tile(Vector2i(0, 6))
	_expect_micro_surface(decor_tile, "decor_grass", "decor tile")
	if _has_failed:
		return
	var structure_tile = grid_manager.get_tile(Vector2i(7, 1))
	_expect_micro_surface(structure_tile, "foundation_grass", "structure tile")
	if _has_failed:
		return

	var subcell_offsets := [
		Vector3(-0.375, 0.0, -0.375),
		Vector3(-0.125, 0.0, 0.125),
		Vector3(0.125, 0.0, -0.125),
		Vector3(0.375, 0.0, 0.375)
	]
	for offset in subcell_offsets:
		var sampled_tile = grid_manager.get_tile_from_world(tile.global_position + offset)
		if sampled_tile != tile:
			_fail("Subcell world sample %s should still resolve to the original gameplay tile." % str(offset))
			return

	if not tile.till():
		_fail("Could not till the original gameplay tile after micro-detail rendering.")
		return
	_expect_micro_surface(tile, "soil", "freshly tilled gameplay tile")
	if _has_failed:
		return
	if not tile.place_item("flower_patch"):
		_fail("Could not place decor on the original gameplay tile after micro-detail rendering.")
		return
	_expect_micro_surface(tile, "decor_grass", "refreshed decor gameplay tile")
	if _has_failed:
		return
	if grid_manager.get_tile(Vector2i(6, 6)) != tile:
		_fail("Micro detail should not replace the original gameplay tile.")
		return
	if tile.call("micro_detail_count") != 16:
		_fail("Refreshing tile decor should preserve the 4x4 visual micro-detail cells.")
		return

	quit()


func _expect_micro_surface(tile, expected_surface: String, context: String) -> void:
	if tile == null:
		_fail("Could not inspect %s." % context)
		return
	if tile.call("micro_detail_surface_id") != expected_surface:
		_fail("%s should use %s micro detail, saw %s." % [
			context,
			expected_surface,
			str(tile.call("micro_detail_surface_id"))
		])
		return
	var detail_count := int(tile.call("micro_detail_count"))
	if detail_count != 16:
		_fail("%s should keep 16 visual micro-detail cells, saw %s." % [context, detail_count])
		return


func _road_detail_signature(tile, context: String) -> String:
	var edge = tile.get_node_or_null("TerrainDetails/RoadEdgeA") as MeshInstance3D
	var pebble = tile.get_node_or_null("TerrainDetails/PebbleA") as MeshInstance3D
	if edge == null or pebble == null:
		_fail("%s should render road edge and pebble detail nodes." % context)
		return ""
	if edge.mesh == null or pebble.mesh == null:
		_fail("%s should render mesh-backed road detail nodes." % context)
		return ""
	return "%s|%s|%s|%s" % [
		str(edge.position),
		str(edge.mesh.get("size")),
		str(pebble.position),
		str(pebble.mesh.get("size"))
	]


func _fail(message: String) -> void:
	_has_failed = true
	push_error(message)
	quit(1)
