extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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
		"agent_id": "bert",
		"agent_name": "Bert"
	}))
	await process_frame
	if demand_id == "":
		_fail("Targeted clear-brush demand was not created.")
		return

	var social_label := _crew_social_label(scene, "bert")
	if social_label == null:
		_fail("Crew row did not expose Bert's social label.")
		return
	if not social_label.text.contains("Wants"):
		_fail("Fresh demand did not start as a crew-row Wants signal.")
		return

	scene.call("_on_advance_day_requested")
	await process_frame

	var demand: Dictionary = scene.crafting_demands[demand_id]
	var order_id := str(demand.get("authored_order_id", ""))
	if order_id == "" or not scene.work_orders.has(order_id):
		_fail("Aged targeted demand did not draft a linked work order.")
		return
	if not social_label.text.contains("Queued"):
		_fail("Drafted work order did not switch the crew-row demand signal to Queued.")
		return

	scene.call("_on_advance_day_requested")
	await process_frame

	var order: Dictionary = scene.work_orders[order_id]
	var incentive: Dictionary = order.get("incentive_resource_delta", {})
	if int(order.get("escalation_count", 0)) < 1:
		_fail("Ignored NPC-authored order did not escalate.")
		return
	if incentive.is_empty():
		_fail("Escalated NPC-authored order did not attach a bargain incentive.")
		return
	if not social_label.visible:
		_fail("Crew row hid Bert's escalated demand signal.")
		return
	if social_label.text.contains("Queued"):
		_fail("Crew row still showed Queued after Bert escalated the linked order.")
		return
	if not social_label.text.contains("Bonus") or not social_label.text.contains("Grain"):
		_fail("Crew row did not show Bert's escalated bargain signal.")
		return

	scene.queue_free()
	await process_frame
	quit()


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
