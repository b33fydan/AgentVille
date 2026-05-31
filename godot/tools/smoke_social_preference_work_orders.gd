extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_preference_context_survives_authored_work_order()
	quit()


func _test_preference_context_survives_authored_work_order() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var target := Vector2i(8, 4)
	var tile = grid.get_tile(target)
	if tile == null:
		_fail("Smoke setup could not find the preference work-order target tile.")
		return
	tile.erase()
	tile.place_item("tall_grass")

	var demand_id := str(scene.call("_create_crafting_demand", {
		"kind": "clear_brush",
		"required_action": "clear_brush",
		"amount": 1,
		"label": "Clear Brush",
		"target_tile": target,
		"preference_source": "truce",
		"preference_label": "Rush Kit"
	}, {
		"agent_id": "chuck",
		"agent_name": "Chuck"
	}))
	if demand_id == "":
		_fail("Smoke setup did not create a truce-influenced field demand.")
		return

	var order_id := str(scene.call("_maybe_author_work_order_for_demand", demand_id))
	if order_id == "" or not scene.work_orders.has(order_id):
		_fail("Truce-influenced demand did not author a linked work order.")
		return

	var order: Dictionary = scene.work_orders[order_id]
	if str(order.get("social_preference_source", "")) != "truce" or str(order.get("social_preference_label", "")) != "Rush Kit":
		_fail("Authored work order did not preserve truce preference context.")
		return

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	for agent in agent_manager.agents:
		agent.move_speed = 36.0

	scene.call("_on_work_order_requested", order_id)
	await process_frame
	await process_frame

	var active_agent_id := _active_social_agent_id(agent_manager, "truce", "Rush Kit")
	if active_agent_id == "":
		_fail("Assigned crew member did not expose active truce work context.")
		return

	var social_label := _crew_social_label(scene, active_agent_id)
	if social_label == null or not social_label.visible:
		_fail("Assigned crew row did not show active truce work.")
		return
	if not str(social_label.text).contains("Truce") or not str(social_label.text).contains("Rush Kit"):
		_fail("Assigned crew row did not show the truce order context. saw=%s" % str(social_label.text))
		return

	await create_timer(1.0).timeout
	if str(tile.decor_id) != "":
		_fail("Truce-influenced authored work order did not clear the brush target.")
		return

	var saw_agent_action := false
	var saw_world_action := false
	for event in scene.get_node("GameEventLog").get("events"):
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("social_preference_source", "")) != "truce" or str(event.get("social_preference_label", "")) != "Rush Kit":
			continue
		match str(event.get("type", "")):
			"agent_action":
				saw_agent_action = true
			"agent_world_action":
				if bool(event.get("success", false)):
					saw_world_action = true
	if not saw_agent_action:
		_fail("Assigned agent action did not record truce preference context.")
		return
	if not saw_world_action:
		_fail("Completed agent work did not record truce preference context.")
		return

	var summary: Dictionary = scene.get_node("GameEventLog").call("build_day_summary", grid.day)
	var social_actions: Dictionary = summary.get("agent_social_preference_actions", {})
	if social_actions.is_empty():
		_fail("Day summary did not count the preference-driven authored order work.")
		return
	var saw_summary_context := false
	for receipt in social_actions.values():
		if typeof(receipt) == TYPE_DICTIONARY and str(receipt.get("last_source", "")) == "truce" and str(receipt.get("last_label", "")) == "Rush Kit":
			saw_summary_context = true
			break
	if not saw_summary_context:
		_fail("Day summary did not preserve authored-order truce context.")
		return

	scene.queue_free()
	await process_frame


func _active_social_agent_id(agent_manager, source: String, label: String) -> String:
	for snapshot in agent_manager.call("get_agent_snapshots"):
		if typeof(snapshot) != TYPE_DICTIONARY:
			continue
		if str(snapshot.get("active_social_preference_source", "")) == source and str(snapshot.get("active_social_preference_label", "")) == label:
			return str(snapshot.get("id", ""))
	return ""


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
