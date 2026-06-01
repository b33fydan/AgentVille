extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_mission_tracker_surfaces_progress_and_completion()
	quit()


func _test_mission_tracker_surfaces_progress_and_completion() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var game_ui = scene.get_node("GameUI")
	var clear_target := Vector2i(1, 1)
	var harvest_target := Vector2i(2, 1)
	var clear_tile = grid.get_tile(clear_target)
	var harvest_tile = grid.get_tile(harvest_target)
	if clear_tile == null or harvest_tile == null:
		_fail("Mission tracker setup could not find target tiles.")
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
		],
		"completion_resource_delta": {"grain": 1}
	}, {
		"agent_id": "marigold",
		"agent_name": "Marigold"
	}))
	if mission_id == "":
		_fail("Mission tracker setup did not create a mission.")
		return
	await process_frame

	_assert_mission_tracker_row(game_ui, mission_id, "Marigold Growth Run", "Marigold", "Step 1/2", "Clear Growth Patch")

	var first_demand := _latest_open_mission_demand(scene, mission_id)
	if first_demand.is_empty():
		_fail("Mission tracker setup did not create the first mission demand.")
		return
	_complete_demand_step(scene, grid, first_demand)
	await process_frame
	await process_frame
	_assert_mission_tracker_row(game_ui, mission_id, "Marigold Growth Run", "Marigold", "Step 2/2", "Harvest Growth Crop")

	var second_demand := _latest_open_mission_demand(scene, mission_id)
	if second_demand.is_empty():
		_fail("Mission tracker setup did not create the second mission demand.")
		return
	_complete_demand_step(scene, grid, second_demand)
	await process_frame
	await process_frame
	_assert_mission_tracker_row(game_ui, mission_id, "Marigold Growth Run", "Marigold", "Done", "Completed")

	scene.queue_free()
	await process_frame


func _complete_demand_step(scene: Node, grid, demand: Dictionary) -> void:
	var target: Vector2i = demand.get("target_tile", Vector2i(-1, -1))
	var kind := str(demand.get("kind", ""))
	if kind == "clear_brush":
		grid.get_tile(target).cut_with_sickle()
		scene.call("_on_player_action_logged", {
			"actor": "player",
			"tool": "sickle",
			"action": "clear_brush",
			"grid_pos": target,
			"item_id": "sickle",
			"success": true,
			"message": "Cleared mission patch.",
			"value": 0,
			"resources": {"fiber": 2},
			"crafted_cost": {}
		})
	elif kind == "harvest_crop":
		grid.get_tile(target).harvest()
		scene.call("_on_player_action_logged", {
			"actor": "player",
			"tool": "sickle",
			"action": "harvest_crop",
			"grid_pos": target,
			"item_id": "sickle",
			"success": true,
			"message": "Harvested mission crop.",
			"value": 6,
			"resources": {"grain": 2},
			"crafted_cost": {}
		})


func _assert_mission_tracker_row(game_ui, mission_id: String, mission_label: String, agent_name: String, status_text: String, step_text: String) -> void:
	var rows_value = game_ui.get("_crew_mission_rows")
	if typeof(rows_value) != TYPE_DICTIONARY:
		_fail("Mission tracker rows dictionary was not registered in the UI.")
		return
	var rows: Dictionary = rows_value
	if not rows.has(mission_id):
		_fail("Mission tracker did not register row %s." % mission_id)
		return
	var row: Dictionary = rows[mission_id]
	var label := row.get("label", null) as Label
	var agent := row.get("agent", null) as Label
	var status := row.get("status", null) as Label
	var step := row.get("step", null) as Label
	if label == null or agent == null or status == null or step == null:
		_fail("Mission tracker row did not expose label, agent, status, and step labels.")
		return
	if not label.text.contains(mission_label):
		_fail("Mission tracker row did not name the mission. saw=%s" % label.text)
		return
	if not agent.text.contains(agent_name):
		_fail("Mission tracker row did not name the agent. saw=%s" % agent.text)
		return
	if not status.text.contains(status_text):
		_fail("Mission tracker row did not show %s. saw=%s" % [status_text, status.text])
		return
	if not step.text.contains(step_text):
		_fail("Mission tracker row did not show step detail %s. saw=%s" % [step_text, step.text])
		return


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
	push_error(message)
	quit(1)
