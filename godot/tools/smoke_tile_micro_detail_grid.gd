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

	if not tile.place_item("flower_patch"):
		_fail("Could not place an item on the original gameplay tile after micro-detail rendering.")
		return
	if grid_manager.get_tile(Vector2i(6, 6)) != tile:
		_fail("Micro detail should not replace the original gameplay tile.")
		return
	if tile.call("micro_detail_count") != 16:
		_fail("Refreshing tile decor should preserve the 4x4 visual micro-detail cells.")
		return

	quit()


func _fail(message: String) -> void:
	_has_failed = true
	push_error(message)
	quit(1)
