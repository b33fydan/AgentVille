extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var placement_tool = scene.get_node("PlacementTool")
	var rock_tile = grid.get_tile(Vector2i(0, 0))
	var grass_tile = grid.get_tile(Vector2i(0, 1))

	placement_tool.call("set_tool", "place")
	placement_tool.call("set_selected_item", "rock")
	placement_tool.call("_apply_to_tile", rock_tile)
	if rock_tile.decor_id != "rock":
		push_error("Rock placement failed.")
		quit(1)
		return

	placement_tool.call("set_selected_item", "pickaxe")
	placement_tool.call("_apply_to_tile", rock_tile)
	if rock_tile.decor_id != "":
		push_error("Pickaxe did not break rock.")
		quit(1)
		return

	placement_tool.call("set_selected_item", "tall_grass")
	placement_tool.call("_apply_to_tile", grass_tile)
	if grass_tile.decor_id != "tall_grass":
		push_error("Tall grass placement failed.")
		quit(1)
		return

	placement_tool.call("set_selected_item", "sickle")
	placement_tool.call("_apply_to_tile", grass_tile)
	if grass_tile.decor_id != "":
		push_error("Sickle did not cut tall grass.")
		quit(1)
		return

	await create_timer(1.0).timeout
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit()
