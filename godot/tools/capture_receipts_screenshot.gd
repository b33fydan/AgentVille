extends SceneTree

const OUTPUT_PATH := "res://artifacts/screenshots/agentville-receipts.png"


func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	call_deferred("_capture")


func _capture() -> void:
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

	await create_timer(0.65).timeout

	var image := root.get_texture().get_image()
	image.save_png(OUTPUT_PATH)
	quit()
