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
	if str(order.get("status", "")) != "ready":
		_fail("Fresh NPC-authored order did not wait for player action first.")
		return

	agent_manager.call("apply_adversarial_result", {
		"agent_id": "bert",
		"outcome": "uneasy_truce",
		"agent_mood_delta": 0.0,
		"agent_irritation_delta": 0.0,
		"remembered_help_label": "Fence Kit"
	})
	await process_frame

	var irritation_before := _agent_irritation(agent_manager, "bert")
	scene.call("_on_advance_day_requested")
	await process_frame

	order = scene.work_orders[order_id]
	if int(order.get("escalation_count", 0)) != 0:
		_fail("Fresh memory truce did not delay the ignored NPC-authored escalation.")
		return
	if int(order.get("truce_delayed_day", 0)) != int(scene.grid_manager.day):
		_fail("Truce-delayed order did not record the delay day.")
		return
	if str(order.get("last_escalation", "")) != "truce":
		_fail("Truce-delayed order did not mark last_escalation as truce.")
		return
	if _agent_irritation(agent_manager, "bert") > irritation_before:
		_fail("Truce-delayed order still added pressure to the NPC author.")
		return

	var truce_snapshot := _agent_snapshot(agent_manager, "bert")
	if int(truce_snapshot.get("truce_absorbed_today", 0)) != 1:
		_fail("Bert's truce did not record absorbing the escalation.")
		return
	var social_label := _crew_social_label(scene, "bert")
	if social_label == null or not social_label.visible:
		_fail("Crew row did not expose Bert's held-truce social signal.")
		return
	if not social_label.text.contains("Truce held") or not social_label.text.contains("Fence Kit"):
		_fail("Crew row did not show the held-truce signal. saw=%s" % social_label.text)
		return
	if social_label.text.contains("Queued") or social_label.text.contains("Bonus"):
		_fail("Held-truce signal was hidden behind the demand/order state. saw=%s" % social_label.text)
		return

	var delayed_receipt := false
	var log = scene.get_node("GameEventLog")
	for event in log.get("events"):
		if typeof(event) != TYPE_DICTIONARY or str(event.get("type", "")) != "work_order":
			continue
		if str(event.get("order_id", "")) == order_id and str(event.get("status", "")) == "truce_delayed":
			delayed_receipt = true
	if not delayed_receipt:
		_fail("Truce-delayed order did not record a work-order receipt.")
		return

	var summary: Dictionary = log.call("build_day_summary", int(scene.grid_manager.day))
	var work_order_events: Dictionary = summary.get("work_order_events", {})
	if int(work_order_events.get("truce_delayed", 0)) != 1:
		_fail("Day summary did not count the truce-delayed order.")
		return
	var summary_line := str(scene.call("_format_day_summary", summary))
	if not summary_line.contains("truce delayed") or not summary_line.contains("1 order"):
		_fail("Formatted day summary did not mention the truce-delayed order. saw=%s" % summary_line)
		return

	scene.call("_on_advance_day_requested")
	await process_frame

	order = scene.work_orders[order_id]
	if int(order.get("escalation_count", 0)) < 1:
		_fail("Ignored NPC-authored order did not escalate after the one-day truce ended.")
		return

	scene.queue_free()
	await process_frame
	quit()


func _agent_snapshot(agent_manager, agent_id: String) -> Dictionary:
	for snapshot in agent_manager.call("get_agent_snapshots"):
		if typeof(snapshot) == TYPE_DICTIONARY and str(snapshot.get("id", "")) == agent_id:
			return snapshot
	return {}


func _agent_irritation(agent_manager, agent_id: String) -> float:
	for snapshot in agent_manager.call("get_agent_snapshots"):
		if str(snapshot.get("id", "")) == agent_id:
			return float(snapshot.get("irritation", 0.0))
	return -1.0


func _crew_social_label(scene: Node, agent_id: String) -> Label:
	var game_ui = scene.get_node("GameUI")
	var rows: Dictionary = game_ui.get("_crew_rows")
	if not rows.has(agent_id):
		return null
	var row: Dictionary = rows[agent_id]
	return row.get("social", null) as Label


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
