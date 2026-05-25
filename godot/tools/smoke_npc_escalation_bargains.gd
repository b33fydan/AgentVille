extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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
	await process_frame

	scene.call("_on_advance_day_requested")
	await process_frame

	var demand: Dictionary = scene.crafting_demands[demand_id]
	var order_id := str(demand.get("authored_order_id", ""))
	if order_id == "" or not scene.work_orders.has(order_id):
		_fail("Smoke setup did not create the NPC-authored order.")
		return

	scene.call("_on_advance_day_requested")
	await process_frame

	var order: Dictionary = scene.work_orders[order_id]
	var incentive: Dictionary = order.get("incentive_resource_delta", {})
	if incentive.is_empty():
		_fail("Escalated NPC-authored order did not attach an incentive bargain.")
		return
	if int(incentive.get("grain", 0)) < 1:
		_fail("Bert's escalation bargain did not offer grain.")
		return
	if str(order.get("incentive_label", "")) == "":
		_fail("Escalation bargain did not carry a label.")
		return

	var game_ui = scene.get_node("GameUI")
	var rows: Dictionary = game_ui.get("_crafting_demand_rows")
	if not rows.has(demand_id):
		_fail("Demand row disappeared after escalation bargain.")
		return
	var row: Dictionary = rows[demand_id]
	if not str((row["status"] as Label).text).contains("1 Grain"):
		_fail("Demand row did not show the escalation bargain.")
		return

	await create_timer(0.9).timeout

	order = scene.work_orders[order_id]
	if not bool(order.get("incentive_claimed", false)):
		_fail("Completed escalated order did not mark the bargain claimed.")
		return
	if int(scene.resources.get("grain", 0)) < 1:
		_fail("Completed escalated order did not pay the bargain resource.")
		return

	var log = scene.get_node("GameEventLog")
	var claimed_receipt := false
	for event in log.get("events"):
		if typeof(event) != TYPE_DICTIONARY or str(event.get("type", "")) != "work_order":
			continue
		if str(event.get("order_id", "")) == order_id and str(event.get("status", "")) == "incentive_claimed":
			claimed_receipt = true
	if not claimed_receipt:
		_fail("Claiming the escalation bargain did not record a receipt.")
		return

	scene.queue_free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
