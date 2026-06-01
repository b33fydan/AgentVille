extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_resolved_parley_result_starts_growth_mission()
	await _test_two_step_growth_mission_tracks_and_resolves()
	quit()


func _test_resolved_parley_result_starts_growth_mission() -> void:
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
		_fail("Mission result setup could not find target tiles.")
		return
	clear_tile.erase()
	clear_tile.place_item("tall_grass")
	harvest_tile.erase()
	harvest_tile.till()
	harvest_tile.plant_wheat()
	harvest_tile.crop.setup("wheat", 3)

	var session_manager = preload("res://scripts/ai/AdversarialSessionManager.gd").new()
	var session: Dictionary = session_manager.start_session({
		"id": "marigold",
		"name": "Marigold",
		"trait": "hopeful",
		"irritation": 0.0
	}, {
		"day": grid.day,
		"demand_hint": "growth_run",
		"grievance_text": "The west row needs a clear path before anything can grow.",
		"npc_goal": "turn the repair promise into two practical field steps"
	})
	if session.is_empty():
		_fail("Mission Parley setup did not create a local session.")
		return

	session_manager.choose_response("own_mistake")
	var result: Dictionary = session_manager.choose_response("own_mistake")
	scene.call("_apply_adversarial_result", result)
	await process_frame
	await process_frame

	if scene.crew_mission_ids.is_empty():
		_fail("Resolved growth-run Parley did not start a crew mission.")
		return

	var mission_id := str(scene.crew_mission_ids.back())
	var mission: Dictionary = scene.crew_missions.get(mission_id, {})
	if str(mission.get("agent_id", "")) != "marigold" or int(mission.get("total_steps", 0)) != 2:
		_fail("Growth-run mission did not preserve Marigold and its two-step shape.")
		return

	var first_demand := _latest_open_mission_demand(scene, mission_id)
	if first_demand.is_empty() or str(first_demand.get("kind", "")) != "clear_brush":
		_fail("Growth-run mission did not open with a clear-brush step.")
		return

	var summary: Dictionary = scene.get_node("GameEventLog").call("build_day_summary", grid.day)
	if int(summary.get("crew_mission_count", 0)) < 1:
		_fail("Started growth-run mission did not enter the day summary.")
		return

	scene.queue_free()
	await process_frame


func _test_two_step_growth_mission_tracks_and_resolves() -> void:
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
		_fail("Mission setup could not find target tiles.")
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
		"completion_resource_delta": {
			"grain": 1
		}
	}, {
		"agent_id": "marigold",
		"agent_name": "Marigold"
	}))
	if mission_id == "":
		_fail("Mission layer did not create a multi-step mission.")
		return

	var mission: Dictionary = scene.crew_missions.get(mission_id, {})
	if str(mission.get("status", "")) != "active":
		_fail("New mission did not start active.")
		return
	if int(mission.get("total_steps", 0)) != 2 or int(mission.get("current_step_index", -1)) != 0:
		_fail("New mission did not track its two-step plan.")
		return

	var first_demand := _latest_open_mission_demand(scene, mission_id)
	if first_demand.is_empty():
		_fail("Mission did not create its first demand step.")
		return
	if int(first_demand.get("mission_step_index", -1)) != 0:
		_fail("First mission demand did not record step index 0.")
		return
	if str(first_demand.get("mission_label", "")) != "Marigold Growth Run":
		_fail("First mission demand did not preserve the mission label.")
		return

	scene.call("_on_player_action_logged", {
		"actor": "player",
		"tool": "sickle",
		"action": "clear_brush",
		"grid_pos": clear_target,
		"item_id": "sickle",
		"success": true,
		"message": "Cleared first mission patch.",
		"value": 0,
		"resources": {"fiber": 2},
		"crafted_cost": {}
	})
	await process_frame
	await process_frame

	mission = scene.crew_missions.get(mission_id, {})
	if int(mission.get("completed_steps", 0)) != 1 or int(mission.get("current_step_index", -1)) != 1:
		_fail("Mission did not advance after the first step.")
		return
	var second_demand := _latest_open_mission_demand(scene, mission_id)
	if second_demand.is_empty():
		_fail("Mission did not create its second demand step.")
		return
	if int(second_demand.get("mission_step_index", -1)) != 1:
		_fail("Second mission demand did not record step index 1.")
		return
	if str(second_demand.get("kind", "")) != "harvest_crop":
		_fail("Second mission step was not the harvest demand.")
		return

	scene.call("_on_player_action_logged", {
		"actor": "player",
		"tool": "sickle",
		"action": "harvest_crop",
		"grid_pos": harvest_target,
		"item_id": "sickle",
		"success": true,
		"message": "Harvested second mission crop.",
		"value": 5,
		"resources": {"grain": 1},
		"crafted_cost": {}
	})
	await process_frame
	await process_frame

	mission = scene.crew_missions.get(mission_id, {})
	if str(mission.get("status", "")) != "done":
		var second_after: Dictionary = scene.crafting_demands.get(str(second_demand.get("id", "")), {})
		_fail("Mission did not resolve after its second step. mission=%s demand=%s" % [str(mission), str(second_after)])
		return
	if int(mission.get("completed_steps", 0)) != 2:
		_fail("Resolved mission did not count both completed steps.")
		return
	if int(scene.resources.get("grain", 0)) < 2:
		_fail("Resolved mission did not pay its completion resource through inventory.")
		return

	var saw_started := false
	var saw_step_done := false
	var saw_done := false
	var saw_step_demand_receipt := false
	for event in scene.get_node("GameEventLog").get("events"):
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("mission_id", "")) != mission_id:
			continue
		if str(event.get("type", "")) == "crew_mission":
			match str(event.get("status", "")):
				"started":
					saw_started = true
				"step_done":
					saw_step_done = true
				"done":
					saw_done = true
		elif str(event.get("type", "")) == "crafting_demand" and str(event.get("status", "")) == "open":
			saw_step_demand_receipt = true
	if not saw_started:
		_fail("Mission did not record a started receipt.")
		return
	if not saw_step_done:
		_fail("Mission did not record a step_done receipt.")
		return
	if not saw_done:
		_fail("Mission did not record a done receipt.")
		return
	if not saw_step_demand_receipt:
		_fail("Mission step demand did not preserve mission receipt metadata.")
		return

	var summary: Dictionary = scene.get_node("GameEventLog").call("build_day_summary", grid.day)
	var missions: Dictionary = summary.get("crew_missions", {})
	if not missions.has(mission_id):
		_fail("Day summary did not include the resolved crew mission.")
		return
	var mission_receipt: Dictionary = missions.get(mission_id, {})
	if int(mission_receipt.get("completed_steps", 0)) != 2 or str(mission_receipt.get("status", "")) != "done":
		_fail("Day summary did not preserve mission completion progress.")
		return
	var formatted_summary := str(scene.call("_format_day_summary", summary))
	if not formatted_summary.contains("completed 1 mission"):
		_fail("Formatted day summary did not call out the completed crew mission.")
		return

	scene.queue_free()
	await process_frame


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
