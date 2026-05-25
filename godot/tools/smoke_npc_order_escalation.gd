extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
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
	await process_frame

	if demand_id == "":
		_fail("Smoke setup did not create the targeted clear-brush demand.")
		return

	scene.call("_on_advance_day_requested")
	await process_frame

	var demand: Dictionary = scene.crafting_demands[demand_id]
	var order_id := str(demand.get("authored_order_id", ""))
	if order_id == "" or not scene.work_orders.has(order_id):
		_fail("First aging pass did not create the NPC-authored work order.")
		return

	var order: Dictionary = scene.work_orders[order_id]
	var target_tile: Vector2i = order.get("target_tile", Vector2i(-1, -1))
	if str(order.get("status", "")) != "ready":
		_fail("Fresh NPC-authored order did not wait for player action first.")
		return

	var irritation_before := _agent_irritation(agent_manager, "bert")
	scene.call("_on_advance_day_requested")
	await process_frame

	order = scene.work_orders[order_id]
	if int(order.get("escalation_count", 0)) < 1:
		_fail("Ignored NPC-authored order did not escalate on the next day.")
		return
	if int(order.get("escalated_day", 0)) != int(scene.grid_manager.day):
		_fail("Escalated order did not record the escalation day.")
		return
	if str(order.get("last_escalation", "")) != "auto_send":
		_fail("Free crew did not auto-send the escalated NPC-authored order.")
		return
	if _agent_irritation(agent_manager, "bert") <= irritation_before:
		_fail("Escalation did not add pressure to the NPC author.")
		return

	var escalated_receipt := false
	var log = scene.get_node("GameEventLog")
	for event in log.get("events"):
		if typeof(event) != TYPE_DICTIONARY or str(event.get("type", "")) != "work_order":
			continue
		if str(event.get("order_id", "")) == order_id and str(event.get("status", "")) == "escalated":
			escalated_receipt = true
	if not escalated_receipt:
		_fail("Ignored NPC-authored order did not record an escalated receipt.")
		return

	await create_timer(0.9).timeout

	order = scene.work_orders[order_id]
	demand = scene.crafting_demands[demand_id]
	if str(order.get("status", "")) != "done":
		_fail("Escalated NPC-authored order did not complete through the crew pipeline.")
		return
	if str(demand.get("status", "")) != "done":
		_fail("Escalated order completion did not complete the source demand.")
		return
	if str(grid.get_tile(target_tile).decor_id) != "":
		_fail("Escalated clear order did not clear the target brush.")
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
