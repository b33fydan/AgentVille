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

	var game_ui = scene.get_node("GameUI")
	var order_rows: Dictionary = game_ui.get("_work_order_rows")
	if not order_rows.has(order_id):
		_fail("Work order row disappeared after escalation.")
		return

	var row: Dictionary = order_rows[order_id]
	var status_text := str((row["status"] as Label).text)
	if not status_text.contains("Bonus") or not status_text.contains("Grain"):
		_fail("Active escalation bargain did not appear in the work order row. saw=%s" % status_text)
		return

	await create_timer(0.9).timeout

	order_rows = game_ui.get("_work_order_rows")
	if not order_rows.has(order_id):
		_fail("Work order row disappeared after bargain payout.")
		return

	row = order_rows[order_id]
	status_text = str((row["status"] as Label).text)
	if not status_text.contains("Claimed"):
		_fail("Claimed escalation bargain did not appear in the work order row. saw=%s" % status_text)
		return

	scene.queue_free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
