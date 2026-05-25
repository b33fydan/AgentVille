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
	var tile = grid.get_tile(Vector2i(0, 0))

	placement_tool.call("set_tool", "till")
	placement_tool.call("_apply_to_tile", tile)
	placement_tool.call("set_tool", "plant")
	placement_tool.call("_apply_to_tile", tile)
	scene.call("_on_advance_day_requested")

	await create_timer(1.0).timeout
	quit()
