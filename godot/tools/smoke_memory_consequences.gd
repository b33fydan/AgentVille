extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_repeated_help_shapes_next_ask()
	await _test_completed_authored_order_shapes_next_intention()
	await _test_ignored_ask_shapes_next_intention()
	await _test_held_truce_shapes_next_intention()
	quit()


func _test_repeated_help_shapes_next_ask() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	var marigold = _agent_actor(agent_manager, "marigold")
	if marigold == null:
		_fail("Could not find Marigold for repeated-help consequence setup.")
		return

	marigold.state["remembered_help_label"] = "Seed Bundle"
	marigold.state["remembered_help_days"] = 1
	marigold.call("acknowledge_supply_delivery", "Seed Bundle", "Spring Hands")

	scene.call("_on_advance_day_requested")
	await process_frame

	var snapshot := _agent_snapshot(agent_manager, "marigold")
	if str(snapshot.get("memory_consequence_source", "")) != "repeated_help":
		_fail("Repeated help did not roll into a next-day consequence memory.")
		return
	if str(snapshot.get("daily_intention_id", "")) != "repeat_goodwill":
		_fail("Repeated help did not shape Marigold's next daily intention.")
		return

	var session_manager = preload("res://scripts/ai/AdversarialSessionManager.gd").new()
	session_manager.start_session(snapshot, {
		"day": int(scene.grid_manager.day),
		"demand_hint": "deliver_agent_supply"
	})
	session_manager.choose_response("own_mistake")
	var result: Dictionary = session_manager.choose_response("own_mistake")
	var demand: Dictionary = result.get("crafting_demand", {})
	if str(demand.get("preference_source", "")) != "repeated_help":
		_fail("Repeated-help consequence did not shape Marigold's next ask.")
		return

	scene.queue_free()
	await process_frame


func _test_completed_authored_order_shapes_next_intention() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	for agent in agent_manager.agents:
		agent.move_speed = 28.0

	var demand_id := str(scene.call("_create_crafting_demand", {
		"kind": "clear_brush",
		"required_action": "clear_brush",
		"amount": 1,
		"label": "Clear Brush"
	}, {
		"agent_id": "bert",
		"agent_name": "Bert"
	}))
	if demand_id == "":
		_fail("Could not create Bert demand for completed-order consequence setup.")
		return

	scene.call("_on_advance_day_requested")
	await process_frame

	var demand: Dictionary = scene.crafting_demands[demand_id]
	var order_id := str(demand.get("authored_order_id", ""))
	if order_id == "" or not scene.work_orders.has(order_id):
		_fail("Completed-order setup did not create an authored order.")
		return

	scene.call("_on_work_order_requested", order_id)
	await create_timer(0.9).timeout

	var order: Dictionary = scene.work_orders[order_id]
	if str(order.get("status", "")) != "done":
		_fail("Completed-order setup did not finish the authored order.")
		return

	scene.call("_on_advance_day_requested")
	await process_frame

	var snapshot := _agent_snapshot(agent_manager, "bert")
	if str(snapshot.get("memory_consequence_source", "")) != "completed_order":
		_fail("Completed authored order did not roll into a next-day consequence memory.")
		return
	if str(snapshot.get("daily_intention_id", "")) != "follow_through":
		_fail("Completed authored order did not shape Bert's next daily intention.")
		return

	scene.queue_free()
	await process_frame


func _test_ignored_ask_shapes_next_intention() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var demand_id := str(scene.call("_create_crafting_demand", {
		"kind": "clear_brush",
		"required_action": "clear_brush",
		"amount": 1,
		"label": "Clear Brush"
	}, {
		"agent_id": "chuck",
		"agent_name": "Chuck"
	}))
	if demand_id == "":
		_fail("Could not create Chuck demand for ignored-ask consequence setup.")
		return

	scene.call("_on_advance_day_requested")
	await process_frame
	scene.call("_on_advance_day_requested")
	await process_frame
	scene.call("_on_advance_day_requested")
	await process_frame

	var snapshot := _agent_snapshot(scene.get_node("FarmWorld/AgentManager"), "chuck")
	if str(snapshot.get("memory_consequence_source", "")) != "ignored_ask":
		_fail("Ignored ask did not roll into a next-day consequence memory.")
		return
	if str(snapshot.get("daily_intention_id", "")) != "press_the_ask":
		_fail("Ignored ask did not shape Chuck's next daily intention.")
		return

	scene.queue_free()
	await process_frame


func _test_held_truce_shapes_next_intention() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	var bert = _agent_actor(agent_manager, "bert")
	if bert == null:
		_fail("Could not find Bert for held-truce consequence setup.")
		return

	bert.state["truce_label"] = "Fence Kit"
	bert.state["truce_days"] = 1
	var receipt: Dictionary = bert.call("try_absorb_order_escalation_with_truce", "Fence 1,1")
	if receipt.is_empty():
		_fail("Held-truce setup did not absorb the order escalation.")
		return

	scene.call("_on_advance_day_requested")
	await process_frame

	var snapshot := _agent_snapshot(agent_manager, "bert")
	if str(snapshot.get("memory_consequence_source", "")) != "held_truce":
		_fail("Held truce did not roll into a next-day consequence memory.")
		return
	if str(snapshot.get("daily_intention_id", "")) != "keep_the_truce":
		_fail("Held truce did not shape Bert's next daily intention.")
		return

	scene.queue_free()
	await process_frame


func _agent_actor(agent_manager, agent_id: String):
	for agent in agent_manager.agents:
		if str(agent.get("agent_id")) == agent_id:
			return agent
	return null


func _agent_snapshot(agent_manager, agent_id: String) -> Dictionary:
	for snapshot in agent_manager.call("get_agent_snapshots"):
		if typeof(snapshot) == TYPE_DICTIONARY and str(snapshot.get("id", "")) == agent_id:
			return snapshot
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
