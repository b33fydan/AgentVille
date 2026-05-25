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
		agent.move_speed = 24.0

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
		_fail("Smoke setup did not create the clear-brush demand.")
		return
	if scene.work_order_ids.size() != 0:
		_fail("Fresh demand unexpectedly created a work order before it aged.")
		return

	var demand: Dictionary = scene.crafting_demands[demand_id]
	var target_tile: Vector2i = demand.get("target_tile", Vector2i(-1, -1))
	if target_tile == Vector2i(-1, -1):
		_fail("Clear-brush demand did not receive a target tile.")
		return

	scene.call("_on_advance_day_requested")
	await process_frame

	demand = scene.crafting_demands[demand_id]
	if int(demand.get("age_days", 0)) < 1:
		_fail("Demand did not age during day advance.")
		return
	if str(demand.get("authored_order_id", "")) == "":
		_fail("Aged targeted demand did not record its authored work order.")
		return
	if scene.work_order_ids.size() != 1:
		_fail("Aged targeted demand did not create exactly one NPC-authored order.")
		return

	var order_id := str(demand.get("authored_order_id", ""))
	if not scene.work_orders.has(order_id):
		_fail("Demand referenced an authored order that does not exist.")
		return
	var order: Dictionary = scene.work_orders[order_id]
	if str(order.get("source", "")) != "npc_demand":
		_fail("Authored work order did not carry npc_demand source metadata.")
		return
	if str(order.get("source_demand_id", "")) != demand_id:
		_fail("Authored work order did not link back to the demand.")
		return
	if str(order.get("author_agent_id", "")) != "bert":
		_fail("Authored work order did not preserve the NPC author.")
		return
	if str(order.get("action", "")) != "clear_brush":
		_fail("Authored work order used the wrong action.")
		return
	if order.get("target_tile", Vector2i(-1, -1)) != target_tile:
		_fail("Authored work order did not target the demand tile.")
		return
	if not str(order.get("label", "")).contains("Bert"):
		_fail("Authored work order label did not name the NPC author.")
		return
	if not grid.get_tile(target_tile).get_node("OrderMarker").visible:
		_fail("Authored work order did not place an order marker.")
		return

	var authored_receipt := false
	var log = scene.get_node("GameEventLog")
	for event in log.get("events"):
		if typeof(event) == TYPE_DICTIONARY and str(event.get("type", "")) == "work_order" and str(event.get("status", "")) == "authored":
			if str(event.get("source_demand_id", "")) == demand_id:
				authored_receipt = true
	if not authored_receipt:
		_fail("Authored work order did not record an authored receipt.")
		return

	scene.call("_on_work_order_requested", order_id)
	await create_timer(0.9).timeout

	order = scene.work_orders[order_id]
	demand = scene.crafting_demands[demand_id]
	if str(order.get("status", "")) != "done":
		_fail("Crew did not complete the NPC-authored order.")
		return
	if str(demand.get("status", "")) != "done":
		_fail("Completing the NPC-authored order did not complete the source demand.")
		return
	if str(grid.get_tile(target_tile).decor_id) != "":
		_fail("NPC-authored clear order did not clear the target brush.")
		return

	scene.queue_free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
