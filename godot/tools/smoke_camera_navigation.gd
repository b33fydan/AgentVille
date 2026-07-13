extends SceneTree

const VIEWPORT_SIZES := [Vector2i(1600, 900), Vector2i(1280, 720)]

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for index in range(VIEWPORT_SIZES.size()):
		await _test_resolution(VIEWPORT_SIZES[index], index == 0)
		if _failed:
			return
	quit()


func _test_resolution(viewport_size: Vector2i, run_input_contract: bool) -> void:
	root.content_scale_size = viewport_size
	root.size = viewport_size
	await process_frame

	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame

	var camera_controller = scene.get_node("CameraController")
	var camera := camera_controller.camera as Camera3D
	var game_ui = scene.get_node("GameUI")
	var dock := game_ui.get("_command_dock") as Control
	if camera == null or dock == null:
		_fail("Camera navigation smoke could not find the live camera or command dock.")
		return

	if float(camera_controller.max_zoom) < 15.0 or float(camera_controller.min_zoom) > 4.4:
		_fail("Camera zoom range is too narrow to inspect behind the HUD. min=%s max=%s" % [camera_controller.min_zoom, camera_controller.max_zoom])
		return
	if float(camera_controller.pan_limit_x) < 5.0 or float(camera_controller.pan_limit_z) < 5.0:
		_fail("Camera pan range is too narrow to move farm edges out from behind the HUD.")
		return

	var zoom_in := dock.find_child("CameraZoomIn", true, false) as Button
	var zoom_out := dock.find_child("CameraZoomOut", true, false) as Button
	var recenter := dock.find_child("CameraRecenter", true, false) as Button
	for entry in [[zoom_in, "zoom_in"], [zoom_out, "zoom_out"], [recenter, "recenter"]]:
		var button := entry[0] as Button
		if button == null or not dock.is_ancestor_of(button):
			_fail("World tab lost a camera navigation command.")
			return
		var icon := button.get_node_or_null("VoxelIcon")
		if icon == null or str(icon.get("icon_id")) != str(entry[1]):
			_fail("Camera command lost voxel icon %s." % entry[1])
			return

	for index in range(20):
		zoom_out.pressed.emit()
	if not is_equal_approx(camera.size, float(camera_controller.max_zoom)) or camera.size <= 10.8:
		_fail("Zoom Out command did not reach the expanded overview range. size=%s" % camera.size)
		return

	for index in range(30):
		zoom_in.pressed.emit()
	if not is_equal_approx(camera.size, float(camera_controller.min_zoom)):
		_fail("Zoom In command did not clamp at the close inspection limit. size=%s" % camera.size)
		return

	camera_controller.center_on_farm()
	var centered_zoom := camera.size
	camera_controller.call("_pan_screen_delta", Vector2(-5000.0, 5000.0))
	var shifted_target: Vector3 = camera_controller.target_position
	if absf(shifted_target.x) <= 2.2 and absf(shifted_target.z) <= 2.0:
		_fail("Camera still cannot move beyond the old panel-obscured pan clamp. target=%s" % shifted_target)
		return
	if absf(shifted_target.x) > float(camera_controller.pan_limit_x) + 0.001 or absf(shifted_target.z) > float(camera_controller.pan_limit_z) + 0.001:
		_fail("Camera escaped its expanded safe pan bounds. target=%s" % shifted_target)
		return

	zoom_out.pressed.emit()
	recenter.pressed.emit()
	if camera_controller.target_position != Vector3.ZERO or not is_equal_approx(camera.size, centered_zoom):
		_fail("Center command did not restore the default farm view.")
		return

	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	camera_controller.call("_unhandled_input", wheel)
	if camera.size <= centered_zoom:
		_fail("Mouse wheel zoom-out no longer changes the camera.")
		return

	if not game_ui.is_pointer_over_ui(zoom_out.get_global_rect().get_center()):
		_fail("Camera navigation controls are not protected as UI hit regions.")
		return

	if run_input_contract:
		await _assert_input_contract(scene, camera_controller, camera, game_ui, dock)
		if _failed:
			return

	await _assert_corner_clearance(scene, camera_controller, camera, game_ui, viewport_size)
	if _failed:
		return

	scene.queue_free()
	await process_frame
	await process_frame


func _assert_input_contract(scene: Node, camera_controller, camera: Camera3D, game_ui, dock: Control) -> void:
	var grid = scene.get_node("FarmWorld/GridManager")
	var placement_tool = scene.get_node("PlacementTool")
	var target_data := _find_visible_tile(grid, game_ui, camera)
	if target_data.is_empty():
		_fail("Camera input smoke could not find a visible farm tile outside the HUD.")
		return

	var tile = target_data["tile"]
	var start_position: Vector2 = target_data["screen_position"]
	var tile_signature := _tile_signature(tile)
	placement_tool.call("_set_selected_tile", tile)
	var selected_grid_pos: Vector2i = placement_tool.call("get_selected_grid_pos")
	placement_tool.call("set_tool", "pan")
	camera_controller.center_on_farm()

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	press.position = start_position
	press.global_position = start_position
	root.push_input(press, true)
	await process_frame
	if not bool(camera_controller.get("_dragging")) or int(camera_controller.get("_drag_button")) != MOUSE_BUTTON_LEFT:
		_fail("View tool left-drag did not reach the camera when it began over a real tile.")
		return

	var target_before_drag: Vector3 = camera_controller.target_position
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = start_position + Vector2(130.0, -85.0)
	motion.global_position = motion.position
	motion.relative = Vector2(130.0, -85.0)
	root.push_input(motion, true)
	await process_frame
	if camera_controller.target_position == target_before_drag:
		_fail("View tool left-drag did not pan the camera.")
		return
	if placement_tool.call("get_selected_grid_pos") != selected_grid_pos:
		_fail("Panning replaced the persistent Workbench tile selection.")
		return
	if _tile_signature(tile) != tile_signature:
		_fail("Panning over a farm tile mutated the tile.")
		return

	var release_position := dock.get_global_rect().get_center()
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.button_mask = 0
	release.pressed = false
	release.position = release_position
	release.global_position = release_position
	root.push_input(release, true)
	await process_frame
	if bool(camera_controller.get("_dragging")) or int(camera_controller.get("_drag_button")) != 0:
		_fail("Releasing a camera drag over the command panel left the camera latched.")
		return

	var target_after_release: Vector3 = camera_controller.target_position
	var stray_motion := InputEventMouseMotion.new()
	stray_motion.button_mask = 0
	stray_motion.position = release_position + Vector2(90.0, 40.0)
	stray_motion.global_position = stray_motion.position
	stray_motion.relative = Vector2(90.0, 40.0)
	root.push_input(stray_motion, true)
	await process_frame
	if camera_controller.target_position != target_after_release:
		_fail("Camera kept panning after its drag was released over the UI.")
		return

	var focus_probe := LineEdit.new()
	focus_probe.name = "CameraKeyboardFocusProbe"
	focus_probe.position = Vector2(360.0, 24.0)
	focus_probe.size = Vector2(180.0, 36.0)
	game_ui.get_node("UIRoot").add_child(focus_probe)
	focus_probe.grab_focus()
	await process_frame
	if not bool(camera_controller.call("_keyboard_pan_blocked")):
		_fail("Camera keyboard pan was not blocked while a LineEdit owned focus.")
		return
	var target_before_keyboard: Vector3 = camera_controller.target_position
	if bool(camera_controller.call("_apply_keyboard_pan", Vector2.RIGHT, 0.5)) or camera_controller.target_position != target_before_keyboard:
		_fail("Typing WASD in a LineEdit panned the farm camera.")
		return
	focus_probe.release_focus()
	focus_probe.queue_free()
	await process_frame


func _assert_corner_clearance(scene: Node, camera_controller, camera: Camera3D, game_ui, viewport_size: Vector2i) -> void:
	var grid = scene.get_node("FarmWorld/GridManager")
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	for grid_pos in [Vector2i(0, 0), Vector2i(10, 0), Vector2i(0, 8), Vector2i(10, 8)]:
		var tile = grid.get_tile(grid_pos)
		if tile == null:
			_fail("Camera clearance smoke could not find farm corner %s." % grid_pos)
			return
		camera_controller.focus_world_position(tile.global_position, camera_controller.default_zoom)
		await process_frame
		var tile_surface: Vector3 = tile.global_position + Vector3(0.0, 0.08, 0.0)
		var screen_position := camera.unproject_position(tile_surface)
		if not viewport_rect.has_point(screen_position):
			_fail("Farm corner %s escaped the %sx%s viewport after focus. screen=%s" % [grid_pos, viewport_size.x, viewport_size.y, screen_position])
			return
		if game_ui.is_pointer_over_ui(screen_position):
			_fail("Farm corner %s remained hidden behind the HUD at %sx%s. screen=%s" % [grid_pos, viewport_size.x, viewport_size.y, screen_position])
			return

		var ray_origin := camera.project_ray_origin(screen_position)
		var ray_direction := camera.project_ray_normal(screen_position)
		var hit = Plane(Vector3.UP, 0.08).intersects_ray(ray_origin, ray_direction)
		if hit == null or grid.get_tile_from_world(hit) != tile:
			_fail("Farm corner %s was visible but no longer ray-selectable at %sx%s." % [grid_pos, viewport_size.x, viewport_size.y])
			return


func _find_visible_tile(grid, game_ui, camera: Camera3D) -> Dictionary:
	for grid_pos in [Vector2i(5, 4), Vector2i(6, 4), Vector2i(4, 4), Vector2i(5, 3), Vector2i(5, 5)]:
		var tile = grid.get_tile(grid_pos)
		if tile == null:
			continue
		var screen_position := camera.unproject_position(tile.global_position + Vector3(0.0, 0.08, 0.0))
		if not game_ui.is_pointer_over_ui(screen_position):
			return {"tile": tile, "screen_position": screen_position}
	return {}


func _tile_signature(tile) -> Array:
	return [tile.terrain, tile.is_tilled, tile.crop, tile.decor_id, tile.structure_id]


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
