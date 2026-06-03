extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_mission_momentum_work_receipts_keep_origin_context()
	if not _failed:
		quit()


func _test_mission_momentum_work_receipts_keep_origin_context() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var target := Vector2i(8, 4)
	var tile = grid.get_tile(target)
	if tile == null:
		_fail("Smoke setup could not find the Mission Momentum work target tile.")
		return
	tile.erase()
	tile.place_item("tall_grass")

	var demand_id := str(scene.call("_create_crafting_demand", {
		"kind": "clear_brush",
		"required_action": "clear_brush",
		"amount": 1,
		"label": "Clear Brush",
		"target_tile": target,
		"preference_source": "completed_mission",
		"preference_label": "Chuck Cleanup Sprint",
		"preference_origin_source": "ignored_ask",
		"preference_origin_label": "Rush Kit"
	}, {
		"agent_id": "chuck",
		"agent_name": "Chuck"
	}))
	if demand_id == "":
		_fail("Smoke setup did not create a Mission Momentum field demand.")
		return

	var order_id := str(scene.call("_maybe_author_work_order_for_demand", demand_id))
	if order_id == "" or not scene.work_orders.has(order_id):
		_fail("Mission Momentum demand did not author a linked work order.")
		return

	var order: Dictionary = scene.work_orders[order_id]
	if str(order.get("preference_origin_source", "")) != "ignored_ask" or str(order.get("preference_origin_label", "")) != "Rush Kit":
		_fail("Authored work order did not preserve Mission Momentum origin context.")
		return

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	for agent in agent_manager.agents:
		agent.move_speed = 36.0

	scene.call("_on_work_order_requested", order_id)
	await process_frame
	await process_frame
	await create_timer(1.0).timeout

	if str(tile.decor_id) != "":
		_fail("Mission Momentum authored work order did not clear the brush target.")
		return

	var completed_event: Dictionary = _completed_social_world_action(scene)
	if completed_event.is_empty():
		_fail("Completed work did not record Mission Momentum preference context.")
		return
	if str(completed_event.get("social_preference_origin_source", "")) != "ignored_ask":
		_fail("Completed work did not record Mission Momentum origin source. saw=%s" % str(completed_event))
		return
	if str(completed_event.get("social_preference_origin_label", "")) != "Rush Kit":
		_fail("Completed work did not record Mission Momentum origin label. saw=%s" % str(completed_event))
		return

	var receipt := str(scene.call("_format_agent_receipt", completed_event))
	if not receipt.contains("[Momentum: Chuck Cleanup Sprint]"):
		_fail("Work receipt did not name Mission Momentum context. saw=%s" % receipt)
		return
	if not receipt.contains("[Pressure: Rush Kit]"):
		_fail("Work receipt did not name readable origin context. saw=%s" % receipt)
		return
	if receipt.contains("ignored_ask"):
		_fail("Work receipt leaked raw origin context. saw=%s" % receipt)
		return

	var summary: Dictionary = scene.get_node("GameEventLog").call("build_day_summary", grid.day)
	if not _social_summary_has_origin(summary):
		_fail("Day summary did not preserve Mission Momentum origin context. saw=%s" % str(summary.get("agent_social_preference_actions", {})))
		return
	var formatted_summary := str(scene.call("_format_day_summary", summary))
	if not formatted_summary.contains("Pressure: Rush Kit") or formatted_summary.contains("ignored_ask"):
		_fail("Formatted day summary did not use readable Mission Momentum origin context. saw=%s" % formatted_summary)
		return

	var vibe: Dictionary = summary.get("vibe", {})
	if not _strings_contain(vibe.get("reasons", []), "Pressure: Rush Kit"):
		_fail("Vibe reasons did not include Mission Momentum origin context. saw=%s" % str(vibe.get("reasons", [])))
		return

	var comment := str(agent_manager.call("_summary_comment", summary))
	if not comment.contains("Pressure: Rush Kit") or comment.contains("ignored_ask"):
		_fail("NPC verdict did not read Mission Momentum origin context. saw=%s" % comment)
		return

	scene.queue_free()
	await process_frame


func _completed_social_world_action(scene: Node) -> Dictionary:
	for event in scene.get_node("GameEventLog").get("events"):
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) != "agent_world_action":
			continue
		if not bool(event.get("success", false)):
			continue
		if str(event.get("social_preference_source", "")) != "completed_mission":
			continue
		if str(event.get("social_preference_label", "")) != "Chuck Cleanup Sprint":
			continue
		return event
	return {}


func _social_summary_has_origin(summary: Dictionary) -> bool:
	var social_actions: Dictionary = summary.get("agent_social_preference_actions", {})
	for receipt in social_actions.values():
		if typeof(receipt) != TYPE_DICTIONARY:
			continue
		if str(receipt.get("last_source", "")) != "completed_mission":
			continue
		if str(receipt.get("last_label", "")) != "Chuck Cleanup Sprint":
			continue
		if str(receipt.get("last_origin_source", "")) == "ignored_ask" and str(receipt.get("last_origin_label", "")) == "Rush Kit":
			return true
	return false


func _strings_contain(values, needle: String) -> bool:
	if typeof(values) != TYPE_ARRAY:
		return false
	for value in values:
		if str(value).contains(needle):
			return true
	return false


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
