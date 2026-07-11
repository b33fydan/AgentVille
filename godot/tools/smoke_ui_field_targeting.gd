extends SceneTree


func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var placement_tool = scene.get_node("PlacementTool")
	var game_ui = scene.get_node("GameUI")
	var camera = scene.get_node("CameraController").camera
	var command_tabs: Dictionary = game_ui.get("_command_tab_buttons")
	if not command_tabs.has("crew"):
		_fail("Crew command tab was not registered.")
		return
	var crew_tab := command_tabs["crew"] as Button
	var crew_tab_position := crew_tab.get_global_rect().get_center()
	_move_mouse(crew_tab_position)
	_click(crew_tab_position)
	await process_frame
	if str(game_ui.get("_active_command_tab")) != "crew":
		_fail("Clicking the Crew command tab did not reveal crew targeting controls.")
		return

	var action_buttons: Dictionary = game_ui.get("_work_order_action_buttons")
	if not action_buttons.has("build_fence"):
		_fail("Fence work-order button was not registered.")
		return

	var fence_button: Button = action_buttons["build_fence"]
	var button_position := fence_button.get_global_rect().get_center()
	if not game_ui.is_pointer_over_ui(button_position):
		_fail("Fence work-order button was not inside a registered UI hit region.")
		return

	_move_mouse(button_position)
	await process_frame
	_click(button_position)
	await process_frame

	if str(game_ui.get("_active_work_order_tool")) != "build_fence":
		_fail("Clicking the fence work-order button did not select the fence order tool.")
		return
	if str(placement_tool.get("_crew_order_action_id")) != "build_fence":
		_fail("Placement tool did not enter fence order targeting after the UI click.")
		return
	if scene.work_order_ids.size() != 0:
		_fail("Clicking the UI button unexpectedly created a field order.")
		return

	var target_data := _find_field_target(grid, game_ui, camera)
	if target_data.is_empty():
		_fail("Could not find a visible field target outside the UI.")
		return

	var target_tile = target_data["tile"]
	var target_position: Vector2 = target_data["screen_position"]

	_move_mouse(target_position)
	await process_frame

	if placement_tool.get("_hovered_tile") != target_tile:
		_fail("Hovering a valid field tile after a UI click did not update the placement hover.")
		return

	_click(target_position)
	await process_frame

	if scene.work_order_ids.size() != 1:
		_fail("Clicking the field after selecting a work-order button did not create exactly one order.")
		return

	var order_id := str(scene.work_order_ids[0])
	var order: Dictionary = scene.work_orders[order_id]
	if str(order.get("action", "")) != "build_fence":
		_fail("Field click created the wrong order action.")
		return
	if order.get("target_tile") != target_tile.grid_pos:
		_fail("Field click created an order for the wrong tile.")
		return
	if not target_tile.get_node("OrderMarker").visible:
		_fail("Field click did not show the in-world order marker.")
		return

	await process_frame
	quit()


func _find_field_target(grid, game_ui, camera: Camera3D) -> Dictionary:
	var candidates := [
		Vector2i(4, 5),
		Vector2i(6, 5),
		Vector2i(4, 7),
		Vector2i(6, 7),
		Vector2i(0, 0),
		Vector2i(10, 8)
	]

	for grid_pos in candidates:
		var tile = grid.get_tile(grid_pos)
		if tile == null:
			continue
		var screen_position := camera.unproject_position(tile.global_position + Vector3(0.0, 0.12, 0.0))
		if not game_ui.is_pointer_over_ui(screen_position):
			return {
				"tile": tile,
				"screen_position": screen_position
			}

	return {}


func _click(position: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.pressed = true
	down.position = position
	down.global_position = position
	root.push_input(down, true)

	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.button_mask = 0
	up.pressed = false
	up.position = position
	up.global_position = position
	root.push_input(up, true)


func _move_mouse(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	motion.relative = Vector2.ZERO
	root.push_input(motion, true)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
