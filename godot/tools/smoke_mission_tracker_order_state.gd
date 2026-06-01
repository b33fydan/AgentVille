extends SceneTree

var _failed := false


func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	call_deferred("_run")


func _run() -> void:
	await _test_mission_tracker_shows_linked_order_state()
	if not _failed:
		quit()


func _test_mission_tracker_shows_linked_order_state() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var clear_target := Vector2i(1, 1)
	var harvest_target := Vector2i(2, 1)
	var clear_tile = grid.get_tile(clear_target)
	var harvest_tile = grid.get_tile(harvest_target)
	if clear_tile == null or harvest_tile == null:
		_fail("Mission tracker state setup could not find target tiles.")
		return
	clear_tile.erase()
	clear_tile.place_item("tall_grass")
	harvest_tile.erase()
	harvest_tile.till()
	harvest_tile.plant_wheat()
	harvest_tile.crop.setup("wheat", 3)

	var mission_id := str(scene.call("_create_crew_mission", {
		"label": "Marigold Growth Run",
		"steps": [
			{
				"kind": "clear_brush",
				"required_action": "clear_brush",
				"amount": 1,
				"label": "Clear Growth Patch",
				"target_tile": clear_target
			},
			{
				"kind": "harvest_crop",
				"required_action": "harvest_crop",
				"amount": 1,
				"label": "Harvest Growth Crop",
				"target_tile": harvest_target
			}
		]
	}, {
		"agent_id": "marigold",
		"agent_name": "Marigold"
	}))
	if mission_id == "":
		_fail("Mission tracker state setup did not create a mission.")
		return
	await process_frame
	_assert_tracker_status(scene, mission_id, "Step 1/2")

	var first_demand := _latest_open_mission_demand(scene, mission_id)
	if first_demand.is_empty():
		_fail("Mission tracker state setup did not create the first mission demand.")
		return

	scene.call("_on_advance_day_requested")
	await process_frame
	await process_frame

	var demand: Dictionary = scene.crafting_demands.get(str(first_demand.get("id", "")), {})
	var order_id := str(demand.get("authored_order_id", ""))
	if order_id == "" or not scene.work_orders.has(order_id):
		_fail("Aged mission demand did not draft a linked work order.")
		return
	_assert_tracker_status(scene, mission_id, "Queued 1/2")

	var row_panel := _mission_row_panel(scene, mission_id)
	if row_panel == null:
		_fail("Mission tracker row disappeared after linked order draft.")
		return
	_click(row_panel)
	await process_frame
	_assert_tracker_status(scene, mission_id, "Sent 1/2")

	scene.queue_free()
	await process_frame


func _assert_tracker_status(scene: Node, mission_id: String, expected_text: String) -> void:
	var game_ui = scene.get_node("GameUI")
	var rows: Dictionary = game_ui.get("_crew_mission_rows")
	if not rows.has(mission_id):
		_fail("Mission tracker did not register row %s." % mission_id)
		return
	var row: Dictionary = rows[mission_id]
	var status := row.get("status", null) as Label
	if status == null:
		_fail("Mission tracker row did not expose a status label.")
		return
	if not status.text.contains(expected_text):
		_fail("Mission tracker status did not show %s. saw=%s" % [expected_text, status.text])
		return


func _click(control: Control) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	control.gui_input.emit(click)


func _mission_row_panel(scene: Node, mission_id: String) -> PanelContainer:
	var game_ui = scene.get_node("GameUI")
	var rows: Dictionary = game_ui.get("_crew_mission_rows")
	if not rows.has(mission_id):
		return null
	var row: Dictionary = rows[mission_id]
	return row.get("panel", null) as PanelContainer


func _latest_open_mission_demand(scene: Node, mission_id: String) -> Dictionary:
	var demand_ids: Array = scene.get("crafting_demand_ids")
	var demands: Dictionary = scene.get("crafting_demands")
	for index in range(demand_ids.size() - 1, -1, -1):
		var demand_id := str(demand_ids[index])
		var demand: Dictionary = demands.get(demand_id, {})
		if str(demand.get("status", "")) == "open" and str(demand.get("mission_id", "")) == mission_id:
			return demand
	return {}


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
