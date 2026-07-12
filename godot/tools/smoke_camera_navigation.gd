extends SceneTree

var _failed := false


func _initialize() -> void:
	root.content_scale_size = Vector2i(1600, 900)
	root.size = Vector2i(1600, 900)
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
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

	scene.queue_free()
	await process_frame
	if not _failed:
		quit()


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
