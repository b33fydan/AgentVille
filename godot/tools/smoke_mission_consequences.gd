extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_completed_mission_shapes_next_day_intention_and_ask()
	if not _failed:
		quit()


func _test_completed_mission_shapes_next_day_intention_and_ask() -> void:
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
		_fail("Mission consequence setup could not find target tiles.")
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
		_fail("Mission consequence setup did not create a mission.")
		return
	await process_frame

	var first_demand := _latest_open_mission_demand(scene, mission_id)
	if first_demand.is_empty():
		_fail("Mission consequence setup did not create the first mission demand.")
		return
	_complete_demand_step(scene, grid, first_demand)
	await process_frame
	await process_frame

	var second_demand := _latest_open_mission_demand(scene, mission_id)
	if second_demand.is_empty():
		_fail("Mission consequence setup did not create the second mission demand.")
		return
	_complete_demand_step(scene, grid, second_demand)
	await process_frame
	await process_frame

	var mission: Dictionary = scene.crew_missions.get(mission_id, {})
	if str(mission.get("status", "")) != "done":
		_fail("Mission consequence setup did not complete the mission.")
		return

	scene.call("_on_advance_day_requested")
	await process_frame

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	var snapshot := _agent_snapshot(agent_manager, "marigold")
	if str(snapshot.get("memory_consequence_source", "")) != "completed_mission":
		_fail("Completed mission did not roll into a next-day consequence memory.")
		return
	if str(snapshot.get("memory_consequence_label", "")) != "Marigold Growth Run":
		_fail("Completed mission consequence did not preserve the mission label.")
		return
	if str(snapshot.get("daily_intention_id", "")) != "mission_momentum":
		_fail("Completed mission did not shape Marigold's next daily intention.")
		return

	var session_manager = preload("res://scripts/ai/AdversarialSessionManager.gd").new()
	session_manager.start_session(snapshot, {
		"day": int(scene.grid_manager.day),
		"demand_hint": "deliver_agent_supply"
	})
	session_manager.choose_response("own_mistake")
	var result: Dictionary = session_manager.choose_response("own_mistake")
	var demand: Dictionary = result.get("crafting_demand", {})
	if str(demand.get("preference_source", "")) != "completed_mission":
		_fail("Completed mission consequence did not shape Marigold's next ask.")
		return

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


func _latest_open_mission_demand(scene: Node, mission_id: String) -> Dictionary:
	var demand_ids: Array = scene.get("crafting_demand_ids")
	var demands: Dictionary = scene.get("crafting_demands")
	for index in range(demand_ids.size() - 1, -1, -1):
		var demand_id := str(demand_ids[index])
		var demand: Dictionary = demands.get(demand_id, {})
		if str(demand.get("status", "")) == "open" and str(demand.get("mission_id", "")) == mission_id:
			return demand
	return {}


func _agent_snapshot(agent_manager, agent_id: String) -> Dictionary:
	for snapshot in agent_manager.call("get_agent_snapshots"):
		if typeof(snapshot) == TYPE_DICTIONARY and str(snapshot.get("id", "")) == agent_id:
			return snapshot
	return {}


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
