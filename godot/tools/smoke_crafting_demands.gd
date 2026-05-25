extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	for index in range(3):
		scene.call("_on_player_action_logged", {
			"actor": "player",
			"tool": "place",
			"action": "place",
			"grid_pos": Vector2i(index, 0),
			"item_id": "fence",
			"success": false,
			"message": "Cannot place that here.",
			"value": 0,
			"resources": {},
			"crafted_cost": {}
		})
		await process_frame

	scene.call("_on_adversarial_encounter_requested", "")
	await process_frame
	scene.call("_on_adversarial_response_selected", "own_mistake")
	await process_frame
	scene.call("_on_adversarial_response_selected", "own_mistake")
	await process_frame

	var demand_ids = scene.get("crafting_demand_ids")
	var demands = scene.get("crafting_demands")
	if typeof(demand_ids) != TYPE_ARRAY or typeof(demands) != TYPE_DICTIONARY or demand_ids.is_empty():
		_fail("Resolved Parley did not create a crafting demand.")
		return

	var demand_id := str(demand_ids[0])
	var demand: Dictionary = demands.get(demand_id, {})
	if str(demand.get("status", "")) != "open":
		_fail("New crafting demand was not open.")
		return
	if str(demand.get("required_item", "")) != "fence_kit":
		_fail("Resolved Parley did not ask for a Fence Kit.")
		return

	var game_ui = scene.get_node("GameUI")
	var demand_rows = game_ui.get("_crafting_demand_rows")
	if typeof(demand_rows) != TYPE_DICTIONARY or not demand_rows.has(demand_id):
		_fail("Crew UI did not show the crafting demand.")
		return

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	var agent_id := str(demand.get("agent_id", ""))
	var irritation_before := _agent_irritation(agent_manager, agent_id)

	scene.call("_add_resources", {
		"fiber": 2,
		"grain": 1
	})
	scene.call("_on_craft_requested", "fence_kit")
	await process_frame

	demands = scene.get("crafting_demands")
	demand = demands.get(demand_id, {})
	if str(demand.get("status", "")) != "done":
		_fail("Crafting a Fence Kit did not complete the demand.")
		return
	if int(scene.get("crafted_items").get("fence_kit", 0)) != 0:
		_fail("Completed crafting demand did not consume the delivered Fence Kit.")
		return

	var irritation_after := _agent_irritation(agent_manager, agent_id)
	if irritation_after >= irritation_before:
		_fail("Completing the crafting demand did not reduce NPC irritation.")
		return

	var log = scene.get_node("GameEventLog")
	var completed_receipt := false
	for event in log.get("events"):
		if typeof(event) == TYPE_DICTIONARY and str(event.get("type", "")) == "crafting_demand" and str(event.get("status", "")) == "done":
			completed_receipt = true
	if not completed_receipt:
		_fail("Completed crafting demand did not record a receipt.")
		return

	scene.queue_free()
	await process_frame
	quit()


func _agent_irritation(agent_manager, agent_id: String) -> float:
	for snapshot in agent_manager.call("get_agent_snapshots"):
		if str(snapshot.get("id", "")) == agent_id:
			return float(snapshot.get("irritation", 0.0))
	return -1.0


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
