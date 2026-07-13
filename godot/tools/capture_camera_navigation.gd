extends SceneTree

const OUTPUT_PATH := "res://artifacts/screenshots/agentville-camera-navigation.png"
const CAPTURE_SIZE := Vector2i(1600, 900)
const TEMP_PROGRESS_PATH := "user://agentville_camera_navigation_capture.json"

var _failed := false


func _initialize() -> void:
	root.content_scale_size = CAPTURE_SIZE
	root.size = CAPTURE_SIZE
	_cleanup_temp_progress()
	call_deferred("_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("Camera navigation capture needs a normal renderer; run without --headless.")
		return

	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	scene.set("progress_storage_path", TEMP_PROGRESS_PATH)
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame

	var game_ui = scene.get_node_or_null("GameUI")
	var grid = scene.get_node_or_null("FarmWorld/GridManager")
	var placement_tool = scene.get_node_or_null("PlacementTool")
	var camera_controller = scene.get_node_or_null("CameraController")
	var camera := camera_controller.camera as Camera3D if camera_controller != null else null
	if game_ui == null or grid == null or placement_tool == null or camera_controller == null or camera == null:
		_fail("Could not capture camera navigation: scene integration is unavailable.")
		return

	var tab_buttons_value = game_ui.get("_command_tab_buttons")
	if typeof(tab_buttons_value) != TYPE_DICTIONARY:
		_fail("Could not capture camera navigation: command tabs are unavailable.")
		return
	var world_tab = (tab_buttons_value as Dictionary).get("world", null) as Button
	if world_tab == null:
		_fail("Could not capture camera navigation: WORLD tab is unavailable.")
		return
	world_tab.pressed.emit()
	await process_frame

	camera_controller.center_on_farm()
	var target_tile = _find_obscured_corner(grid, game_ui, camera)
	if target_tile == null:
		target_tile = grid.get_tile(Vector2i(0, 8))
	if target_tile == null:
		_fail("Could not capture camera navigation: no farm corner is available.")
		return

	placement_tool.call("_set_selected_tile", target_tile)
	camera_controller.focus_world_position(target_tile.global_position, 6.4)
	await process_frame
	await process_frame
	var focused_position := camera.unproject_position(target_tile.global_position + Vector3(0.0, 0.08, 0.0))
	if game_ui.is_pointer_over_ui(focused_position):
		_fail("Could not capture camera navigation: focused corner is still behind the HUD.")
		return

	game_ui.show_message("VIEW SHIFT  ·  Corner (%s, %s) moved clear of the panels" % [target_tile.grid_pos.x, target_tile.grid_pos.y])
	await create_timer(0.35).timeout

	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		_fail("Could not capture camera navigation: viewport texture is unavailable.")
		return
	var image := viewport_texture.get_image()
	if image == null:
		_fail("Could not capture camera navigation: viewport image is unavailable.")
		return
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		_fail("Could not save camera navigation capture to %s." % OUTPUT_PATH)
		return

	scene.queue_free()
	await process_frame
	_cleanup_temp_progress()
	print("Captured shifted camera view to %s." % OUTPUT_PATH)
	quit()


func _find_obscured_corner(grid, game_ui, camera: Camera3D):
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(CAPTURE_SIZE))
	for grid_pos in [Vector2i(0, 0), Vector2i(10, 0), Vector2i(0, 8), Vector2i(10, 8)]:
		var tile = grid.get_tile(grid_pos)
		if tile == null:
			continue
		var screen_position := camera.unproject_position(tile.global_position + Vector3(0.0, 0.08, 0.0))
		if not viewport_rect.has_point(screen_position) or game_ui.is_pointer_over_ui(screen_position):
			return tile
	return null


func _cleanup_temp_progress() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEMP_PROGRESS_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	_cleanup_temp_progress()
	push_error(message)
	quit(1)
