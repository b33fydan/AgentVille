extends SceneTree

const OUTPUT_PATH := "res://artifacts/screenshots/agentville-placement-preview.png"


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
	var game_ui = scene.get_node("GameUI")
	var tile = grid.get_tile(Vector2i(0, 0))

	placement_tool.call("set_tool", "place")
	placement_tool.call("set_selected_item", "rock")
	placement_tool.call("_set_hovered_tile", tile)
	placement_tool.call("_update_preview_visibility")
	game_ui.call("_set_cursor_item", "rock")

	var camera := root.get_camera_3d()
	if camera:
		var screen_pos := camera.unproject_position(tile.global_position + Vector3(0.0, 0.42, 0.0))
		Input.warp_mouse(screen_pos)

	await create_timer(0.65).timeout

	var image := root.get_texture().get_image()
	image.save_png(OUTPUT_PATH)
	quit()
