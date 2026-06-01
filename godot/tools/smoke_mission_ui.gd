extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_mission_progress_surfaces_in_demand_and_crew_rows()
	quit()


func _test_mission_progress_surfaces_in_demand_and_crew_rows() -> void:
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
		_fail("Mission UI setup could not find target tiles.")
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
		_fail("Mission UI setup did not create a mission.")
		return
	await process_frame

	var first_demand := _latest_open_mission_demand(scene, mission_id)
	if first_demand.is_empty():
		_fail("Mission UI setup did not create the first mission demand.")
		return
	_assert_mission_row(game_ui, str(first_demand.get("id", "")), "Step 1/2", "Marigold Growth Run")
	_assert_crew_signal(game_ui, "marigold", "Mission 1/2", "Marigold Growth Run")

	var first_target: Vector2i = first_demand.get("target_tile", clear_target)
	grid.get_tile(first_target).cut_with_sickle()
	scene.call("_on_player_action_logged", {
		"actor": "player",
		"tool": "sickle",
		"action": "clear_brush",
		"grid_pos": first_target,
		"item_id": "sickle",
		"success": true,
		"message": "Cleared first mission patch.",
		"value": 0,
		"resources": {"fiber": 2},
		"crafted_cost": {}
	})
	await process_frame
	await process_frame

	var second_demand := _latest_open_mission_demand(scene, mission_id)
	if second_demand.is_empty():
		_fail("Mission UI setup did not create the second mission demand.")
		return
	_assert_mission_row(game_ui, str(second_demand.get("id", "")), "Step 2/2", "Marigold Growth Run")
	_assert_crew_signal(game_ui, "marigold", "Mission 2/2", "Marigold Growth Run")

	scene.queue_free()
	await process_frame


func _assert_mission_row(game_ui, demand_id: String, step_text: String, mission_label: String) -> void:
	var rows: Dictionary = game_ui.get("_crafting_demand_rows")
	if not rows.has(demand_id):
		_fail("Mission demand row was not registered in the UI.")
		return
	var row: Dictionary = rows[demand_id]
	if not row.has("mission"):
		_fail("Mission demand row did not expose a mission progress chip.")
		return
	var chip := row["mission"] as Label
	if chip == null or not chip.visible:
		_fail("Mission progress chip was not visible.")
		return
	if not chip.text.contains(step_text):
		_fail("Mission progress chip did not show %s. saw=%s" % [step_text, chip.text])
		return
	if not chip.tooltip_text.contains(mission_label):
		_fail("Mission progress tooltip did not name the mission.")
		return


func _assert_crew_signal(game_ui, agent_id: String, step_text: String, mission_label: String) -> void:
	var rows: Dictionary = game_ui.get("_crew_rows")
	if not rows.has(agent_id):
		_fail("Crew row was not registered for %s." % agent_id)
		return
	var row: Dictionary = rows[agent_id]
	var signal_label := row["social"] as Label
	if signal_label == null or not signal_label.visible:
		_fail("Crew row mission signal was not visible.")
		return
	if not signal_label.text.contains(step_text) or not signal_label.text.contains(mission_label):
		_fail("Crew row did not show mission progress. saw=%s" % signal_label.text)
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
