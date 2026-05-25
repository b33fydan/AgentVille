extends SceneTree

const AdversarialSessionManagerScript := preload("res://scripts/ai/AdversarialSessionManager.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_session_demand_selection()
	await _test_scene_demand_aging_and_perk()
	quit()


func _test_session_demand_selection() -> void:
	var clear_manager = AdversarialSessionManagerScript.new()
	clear_manager.start_session({
		"id": "bert",
		"name": "Bert",
		"trait": "grizzled",
		"irritation": 36.0
	}, {
		"day": 1,
		"demand_hint": "clear_brush",
		"recent_failures": 3
	})
	clear_manager.choose_response("own_mistake")
	var clear_result: Dictionary = clear_manager.choose_response("own_mistake")
	var clear_demand: Dictionary = clear_result.get("crafting_demand", {})
	if str(clear_demand.get("kind", "")) != "clear_brush":
		_fail("Resolved Parley did not select a clear-brush demand from context.")
		return

	var harvest_manager = AdversarialSessionManagerScript.new()
	harvest_manager.start_session({
		"id": "marigold",
		"name": "Marigold",
		"trait": "hopeful",
		"irritation": 18.0
	}, {
		"day": 1,
		"demand_hint": "harvest_crop",
		"recent_failures": 1
	})
	harvest_manager.choose_response("own_mistake")
	var harvest_result: Dictionary = harvest_manager.choose_response("own_mistake")
	var harvest_demand: Dictionary = harvest_result.get("crafting_demand", {})
	if str(harvest_demand.get("kind", "")) != "harvest_crop":
		_fail("Resolved Parley did not select a harvest demand from context.")
		return


func _test_scene_demand_aging_and_perk() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	scene.call("_queue_adversarial_grievance", "bert", "Bert wants brush cleared before the fence parade continues.", {
		"demand_hint": "clear_brush",
		"grievance_text": "The brush is winning the visual argument.",
		"npc_goal": "make the player clear one patch of brush"
	})
	scene.call("_on_adversarial_encounter_requested", "")
	await process_frame
	scene.call("_on_adversarial_response_selected", "own_mistake")
	await process_frame
	scene.call("_on_adversarial_response_selected", "own_mistake")
	await process_frame

	var demand_ids = scene.get("crafting_demand_ids")
	var demands = scene.get("crafting_demands")
	if typeof(demand_ids) != TYPE_ARRAY or typeof(demands) != TYPE_DICTIONARY or demand_ids.is_empty():
		_fail("Resolved brush Parley did not create a crew demand.")
		return

	var demand_id := str(demand_ids[0])
	var demand: Dictionary = demands.get(demand_id, {})
	if str(demand.get("kind", "")) != "clear_brush":
		_fail("Brush Parley created the wrong demand kind.")
		return
	if str(demand.get("status", "")) != "open":
		_fail("Brush demand did not start open.")
		return

	var game_ui = scene.get_node("GameUI")
	var demand_rows = game_ui.get("_crafting_demand_rows")
	if typeof(demand_rows) != TYPE_DICTIONARY or not demand_rows.has(demand_id):
		_fail("Crew UI did not show the brush demand.")
		return

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	var irritation_before_age := _agent_irritation(agent_manager, "bert")
	scene.call("_on_advance_day_requested")
	await process_frame

	demands = scene.get("crafting_demands")
	demand = demands.get(demand_id, {})
	if int(demand.get("age_days", 0)) < 1:
		_fail("Open demand did not age when the day advanced.")
		return
	if _agent_irritation(agent_manager, "bert") <= irritation_before_age:
		_fail("Aging an open demand did not add NPC pressure.")
		return

	scene.call("_on_player_action_logged", {
		"actor": "player",
		"tool": "sickle",
		"action": "sickle",
		"grid_pos": Vector2i(0, 1),
		"item_id": "sickle",
		"success": true,
		"message": "Sickle cut it clean.",
		"value": 0,
		"resources": {"fiber": 2},
		"crafted_cost": {}
	})
	await process_frame

	demands = scene.get("crafting_demands")
	demand = demands.get(demand_id, {})
	if str(demand.get("status", "")) != "done":
		_fail("Successful brush clearing did not complete the brush demand.")
		return
	if str(demand.get("perk_id", "")) == "":
		_fail("Completed demand did not carry an NPC-specific perk.")
		return

	var boosted := false
	for snapshot in agent_manager.call("get_agent_snapshots"):
		if float(snapshot.get("morale_boost", 0.0)) > 0.0:
			boosted = true
	if not boosted:
		_fail("Demand completion did not apply the perk boost.")
		return

	var log = scene.get_node("GameEventLog")
	var aged_receipt := false
	var done_receipt_with_perk := false
	for event in log.get("events"):
		if typeof(event) != TYPE_DICTIONARY or str(event.get("type", "")) != "crafting_demand":
			continue
		if str(event.get("status", "")) == "aged":
			aged_receipt = true
		if str(event.get("status", "")) == "done" and str(event.get("perk_id", "")) != "":
			done_receipt_with_perk = true
	if not aged_receipt:
		_fail("Aged demand did not record an aged receipt.")
		return
	if not done_receipt_with_perk:
		_fail("Completed demand did not record a perk receipt.")
		return

	scene.queue_free()
	await process_frame


func _agent_irritation(agent_manager, agent_id: String) -> float:
	for snapshot in agent_manager.call("get_agent_snapshots"):
		if str(snapshot.get("id", "")) == agent_id:
			return float(snapshot.get("irritation", 0.0))
	return -1.0


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
